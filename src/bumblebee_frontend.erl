%
% Copyright (c) 2026 Bumblebee contributors
% All rights reserved.
% Distributed under the terms of the MIT License. See the LICENSE file.
%
-module(bumblebee_frontend).

-export([
    mode/0,
    asset_dir/0,
    index_file/0,
    frontend_dir/0,
    build/1,
    build_dev/0,
    build_prod/0,
    ensure_mode_build/0,
    start_dev_hot_reload/0,
    hot_mode_enabled/0,
    dev_server_origin/0,
    dev_server_host/0,
    dev_server_port/0,
    maybe_wait_for_dev_server/0,
    ensure_dev_server_running/0
]).

-define(DEFAULT_MODE, dev).
-define(WATCH_NAME, bumblebee_frontend_watch).
-define(DEV_SERVER_NAME, bumblebee_frontend_dev_server).
-define(DEFAULT_DEV_HOST, "127.0.0.1").
-define(DEFAULT_DEV_PORT, "5173").
-define(DEV_READY_ATTEMPTS, 8).
-define(DEV_READY_DELAY_MS, 150).
-define(KILL_SUPPORTED_KEY, {?MODULE, kill_supported}).

%% Returns the configured frontend mode based on BUMBLEBEE_FRONTEND_ENV.
mode() ->
    Raw =
        case os:getenv("BUMBLEBEE_FRONTEND_ENV") of
            false -> "dev";
            Value -> Value
        end,
    case string:lowercase(Raw) of
        "prod" -> prod;
        "production" -> prod;
        _ -> ?DEFAULT_MODE
    end.

%% Absolute path to the UI workspace.
frontend_dir() ->
    filename:absname("ui").

%% Directory that Cowboy should serve assets from, based on mode.
asset_dir() ->
    Base = frontend_dir(),
    case mode() of
        prod -> filename:join(Base, "dist");
        _ -> filename:join(Base, "dist-dev")
    end.

%% Absolute path to the compiled index.html.
index_file() ->
    filename:join(asset_dir(), "index.html").

build_dev() -> build(dev).
build_prod() -> build(prod).

%% Ensure the current mode's assets exist; build them if missing.
ensure_mode_build() ->
    Mode = mode(),
    case Mode of
        dev ->
            case hot_mode_enabled() of
                true ->
                    %% Vite dev server serves assets; skip prebuilding.
                    ok;
                false ->
                    ensure_index_exists(Mode)
            end;
        _ ->
            ensure_index_exists(Mode)
    end.

ensure_index_exists(Mode) ->
    Index = index_file(),
    case filelib:is_regular(Index) of
        true ->
            ok;
        false ->
            io:format("UI index missing (~s); building ~p assets...~n", [Index, Mode]),
            build(Mode)
    end.

%% Start a watch build for dev mode (rebuilds on file changes).
start_dev_hot_reload() ->
    case mode() of
        dev ->
            case hot_mode_enabled() of
                true ->
                    ensure_dev_server_running(),
                    maybe_wait_for_dev_server();
                false ->
                    case whereis(?WATCH_NAME) of
                        undefined ->
                            %% Use spawn to avoid crashing caller if the watch process exits.
                            Pid = spawn(fun() -> start_watch_loop() end),
                            register(?WATCH_NAME, Pid),
                            ok;
                        _Pid ->
                            ok
                    end
            end;
        _ ->
            ok
    end.

%% Invokes the frontend build scripts from Erlang for dev/prod.
build(Target) ->
    Dir = frontend_dir(),
    ok = ensure_frontend_dir(Dir),
    maybe_install_deps(Dir),
    Script =
        case Target of
            prod -> "npm run build:prod";
            _ -> "npm run build:dev"
        end,
    run_command(Dir, Script).

ensure_frontend_dir(Dir) ->
    case filelib:is_dir(Dir) of
        true -> ok;
        false -> erlang:error({missing_frontend_dir, Dir})
    end.

maybe_install_deps(Dir) ->
    NodeModules = filename:join(Dir, "node_modules"),
    case filelib:is_dir(NodeModules) of
        true ->
            ok;
        false ->
            _ = run_command(Dir, "npm install"),
            ok
    end.

start_dev_server() ->
    case whereis(?DEV_SERVER_NAME) of
        undefined ->
            Pid = spawn(fun() -> run_dev_server() end),
            case catch register(?DEV_SERVER_NAME, Pid) of
                true ->
                    ok;
                {'EXIT', Reason} ->
                    io:format("Failed to register dev server process: ~p~n", [Reason]),
                    ok
            end;
        _Pid ->
            ok
    end.

start_watch_loop() ->
    Dir = frontend_dir(),
    ok = ensure_frontend_dir(Dir),
    maybe_install_deps(Dir),
    Cmd = lists:flatten(
        io_lib:format("cd \"~s\" && exec npm run build:dev:watch", [Dir])
    ),
    io:format("Starting UI watch: ~s~n", [Cmd]),
    Port = open_port(
        {spawn, "/bin/sh -c \"" ++ Cmd ++ "\""},
        port_options()
    ),
    watch_port(Port).

run_dev_server() ->
    %% Start Vite dev server; never crash the caller if it fails.
    try run_dev_server_internal() of
        _ -> ok
    catch
        Class:Reason:Stack ->
            io:format("Frontend dev server failed (~p:~p): ~p~n", [Class, Reason, Stack]),
            ok
    end.

run_dev_server_internal() ->
    Dir = frontend_dir(),
    ok = ensure_frontend_dir(Dir),
    maybe_install_deps(Dir),
    PortArg = io_lib:format(" --port ~s", [dev_server_port()]),
    HostArg = io_lib:format(" --host ~s", [dev_server_host()]),
    Cmd = lists:flatten(
        io_lib:format(
            "cd \"~s\" && exec npm run dev -- --clearScreen false --strictPort~s~s",
            [Dir, PortArg, HostArg]
        )
    ),
    io:format(
        "Starting UI dev server (~s) for hot reload: ~s~n",
        [dev_server_origin(), Cmd]
    ),
    Port = open_port(
        {spawn, "/bin/sh -c \"" ++ Cmd ++ "\""},
        port_options()
    ),
    watch_port(Port).

watch_port(Port) ->
    process_flag(trap_exit, true),
    receive
        % {'EXIT', _From, _Reason} ->
        %     port_close(Port);
        {Port, {data, Data}} ->
            io:put_chars(Data),
            watch_port(Port);
        {Port, eof} ->
            watch_port(Port);
        {Port, {exit_status, Status}} ->
            io:format("Frontend watch exited with status ~p~n", [Status]);
        stop ->
            port_close(Port)
    end.

port_options() ->
    Base = [exit_status, use_stdio, stderr_to_stdout, eof],
    case kill_supported() of
        true -> Base ++ [{kill, true}];
        false -> Base
    end.

kill_supported() ->
    case persistent_term:get(?KILL_SUPPORTED_KEY, undefined) of
        undefined ->
            Supported = detect_kill_support(),
            persistent_term:put(?KILL_SUPPORTED_KEY, Supported),
            Supported;
        Value ->
            Value
    end.

detect_kill_support() ->
    case os:find_executable("true") of
        false ->
            false;
        TrueExe ->
            Opts = [exit_status, use_stdio, stderr_to_stdout, eof, {kill, true}],
            try
                Port = open_port({spawn_executable, TrueExe}, Opts),
                port_close(Port),
                true
            catch
                error:badarg -> false
            end
    end.

run_command(Dir, Script) ->
    Cmd = lists:flatten(io_lib:format("cd \"~s\" && ~s", [Dir, Script])),
    io:format("Running UI command: ~s~n", [Cmd]),
    os:cmd(Cmd).

hot_mode_enabled() ->
    is_truthy_env("BUMBLEBEE_FRONTEND_HOT").

ensure_dev_server_running() ->
    ensure_http_client(),
    case dev_server_running() of
        true ->
            ok;
        false ->
            try
                start_dev_server()
            catch
                Class:Reason ->
                    io:format("Failed to start dev server (~p:~p); continuing without crash.~n", [
                        Class, Reason
                    ]),
                    ok
            end
    end.

dev_server_running() ->
    Origin = dev_server_origin(),
    try
        case httpc:request(get, {Origin, []}, [{timeout, 1000}], [{body_format, binary}]) of
            {ok, _} -> true;
            {error, _} -> false
        end
    catch
        _:_ -> false
    end.

dev_server_origin() ->
    case os:getenv("BUMBLEBEE_FRONTEND_DEV_SERVER_ORIGIN") of
        false ->
            Host = dev_server_host(),
            Port = dev_server_port(),
            lists:flatten(io_lib:format("http://~s:~s", [Host, Port]));
        Value ->
            string:trim(Value, trailing, "/")
    end.

dev_server_host() ->
    case os:getenv("BUMBLEBEE_FRONTEND_DEV_HOST") of
        false -> ?DEFAULT_DEV_HOST;
        HostValue -> HostValue
    end.

dev_server_port() ->
    case os:getenv("bumblebee_FRONTEND_DEV_PORT") of
        false -> ?DEFAULT_DEV_PORT;
        PortValue -> PortValue
    end.

is_truthy_env(Name) ->
    case os:getenv(Name) of
        false ->
            false;
        Value ->
            Lower = string:lowercase(Value),
            case Lower of
                "0" -> false;
                "false" -> false;
                "no" -> false;
                "" -> false;
                _ -> true
            end
    end.

ensure_http_client() ->
    _ = application:ensure_all_started(inets),
    ok.

maybe_wait_for_dev_server() ->
    case wait_for_dev_server(dev_server_origin(), ?DEV_READY_ATTEMPTS) of
        ok ->
            ok;
        {error, Reason} ->
            io:format("Dev server not ready (~p); continuing...~n", [Reason]),
            ok
    end.

wait_for_dev_server(Origin, Attempts) ->
    wait_for_dev_server(Origin, Attempts, undefined).

wait_for_dev_server(Origin, Attempts, _LastReason) when Attempts > 0 ->
    case httpc:request(get, {Origin, []}, [{timeout, 2000}], [{body_format, binary}]) of
        {ok, _} ->
            ok;
        {error, Reason} ->
            timer:sleep(?DEV_READY_DELAY_MS),
            wait_for_dev_server(Origin, Attempts - 1, Reason)
    end;
wait_for_dev_server(_Origin, _Attempts, LastReason) ->
    {error, LastReason}.
