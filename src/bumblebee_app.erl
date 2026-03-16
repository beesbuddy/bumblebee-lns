%
% Copyright (c) 2016-2019 Petr Gotthard <petr.gotthard@centrum.cz>
% Copyright (c) 2026 Bumblebee contributors
% All rights reserved.
% Distributed under the terms of the MIT License. See the LICENSE file.
%
-module(bumblebee_app).
-behaviour(application).

-define(RELOADER_KEEPALIVE, bumblebee_reloader_keepalive).

-export([start/0]).
-export([start/2, stop/1]).

start() ->
    {ok, _Started} = application:ensure_all_started('bumblebee_lns').

start(_Type, _Args) ->
    ok = ensure_erlang_version(26),
    ok = log(debug, "Using config: ~p", [application:get_all_env('bumblebee_lns')]),

    bumblebee_db:ensure_tables(),

    FrontendRoot = bumblebee_frontend:asset_dir(),
    UseDevServer = bumblebee_frontend:hot_mode_enabled() andalso bumblebee_frontend:mode() =:= dev,
    ok = bumblebee_frontend:ensure_mode_build(),
    ok = bumblebee_frontend:start_dev_hot_reload(),
    ok = maybe_start_reloader(),

    io:format(
        "Frontend mode: ~p (~s) hot_reload=~p~n",
        [bumblebee_frontend:mode(), FrontendRoot, UseDevServer]
    ),

    case
        start_listeners(
            application:get_env('bumblebee_lns', http_admin_listen, []),
            retrieve_valid_ssl(),
            FrontendRoot,
            UseDevServer
        )
    of
        ok ->
            bumblebee_sup:start_link();
        {error, Reason} ->
            {error, Reason}
    end.

start_listeners(HttpOpts, SslOpts, FrontendRoot, UseDevServer) ->
    case {HttpOpts, SslOpts} of
        {[], []} ->
            ok = log(warning, "Web-admin does not listen on any port", []),
            ok;
        {_, []} ->
            start_http(HttpOpts, normal_dispatch(FrontendRoot, UseDevServer));
        {[], _} ->
            start_https(SslOpts, normal_dispatch(FrontendRoot, UseDevServer));
        {_, _} ->
            case start_https(SslOpts, normal_dispatch(FrontendRoot, UseDevServer)) of
                ok ->
                    start_http(
                        HttpOpts,
                        case application:get_env('bumblebee_lns', http_admin_redirect_ssl, true) of
                            false ->
                                normal_dispatch(FrontendRoot, UseDevServer);
                            true ->
                                redirect_dispatch()
                        end
                    );
                {error, _} = Error ->
                    Error
            end
    end.

retrieve_valid_ssl() ->
    case application:get_env('bumblebee_lns', http_admin_listen_ssl, []) of
        [] ->
            [];
        Config ->
            case file_configured(certfile, Config) and file_configured(keyfile, Config) of
                false ->
                    ok = log(warning, "http_admin_listen_ssl not configured", []),
                    [];
                true ->
                    Config
            end
    end.

file_configured(Name, Config) ->
    case proplists:get_value(Name, Config) of
        undefined ->
            false;
        File ->
            case file:read_file_info(File) of
                {ok, _} ->
                    true;
                {error, _} ->
                    false
            end
    end.

stop(_State) ->
    cowboy:stop_listener(http),
    cowboy:stop_listener(https),
    ok.

ensure_erlang_version(Min) ->
    case list_to_integer(erlang:system_info(otp_release)) of
        Num when Num >= Min -> ok;
        _Else -> {error, prerequisite_failed}
    end.

normal_dispatch(FrontendRoot, UseDevServer) ->
    cowboy_router:compile([
        {'_',
            bumblebee_http_registry:get_static(routes) ++ bumblebee_http_registry:get_custom(routes) ++
                bumblebee_http_registry:get_frontend(FrontendRoot, UseDevServer)}
    ]).

redirect_dispatch() ->
    Port = ranch:get_port(https),
    ok = log(info, "Redirecting to HTTPS port ~B", [Port]),
    cowboy_router:compile([
        {'_', [{'_', bumblebee_admin_redirect, #{scheme => <<"https">>, port => Port}}]}
    ]).

log(Level, Format, Args) ->
    case erlang:function_exported(logger, log, 3) of
        true ->
            _ = logger:log(Level, Format, Args),
            ok;
        false ->
            io:format("[~p] " ++ Format ++ "~n", [Level | Args]),
            ok
    end.

start_http(Opts, Dispatch) ->
    case
        cowboy:start_clear(http, Opts, #{
            env => #{dispatch => Dispatch},
            metrics_callback => fun prometheus_cowboy2_instrumenter:observe/1,
            stream_handlers => [
                bumblebee_admin_logger,
                cowboy_compress_h,
                cowboy_metrics_h,
                cowboy_stream_h
            ]
        })
    of
        {ok, _} ->
            ok;
        {error, _} = Error ->
            Error
    end.

start_https(Opts, Dispatch) ->
    % Entry point https
    case
        cowboy:start_tls(https, Opts, #{
            env => #{dispatch => Dispatch},
            metrics_callback => fun prometheus_cowboy2_instrumenter:observe/1,
            stream_handlers => [
                bumblebee_admin_logger,
                cowboy_compress_h,
                cowboy_metrics_h,
                cowboy_stream_h
            ]
        })
    of
        {ok, _} ->
            ok;
        {error, _} = Error ->
            Error
    end.

maybe_start_reloader() ->
    case should_start_reloader() of
        false ->
            ok;
        true ->
            case whereis(?RELOADER_KEEPALIVE) of
                undefined ->
                    Pid = spawn_link(fun reloader_keepalive/0),
                    true = register(?RELOADER_KEEPALIVE, Pid),
                    ok;
                _Pid ->
                    ok
            end
    end.

reloader_keepalive() ->
    case bumblebee_reloader:start() of
        ok ->
            wait_forever();
        {error, Reason} ->
            io:format("Code reloader failed to start: ~p~n", [Reason]),
            ok
    end.

should_start_reloader() ->
    case is_truthy_env("BUMBLEBEE_DEV_RELOAD") of
        true ->
            true;
        false ->
            bumblebee_frontend:mode() =:= dev andalso bumblebee_frontend:hot_mode_enabled()
    end.

is_truthy_env(Name) ->
    case os:getenv(Name) of
        false -> false;
        Value -> is_truthy(Value)
    end.

is_truthy(Value) when is_list(Value) ->
    Lower = string:lowercase(string:trim(Value)),
    lists:member(Lower, ["1", "true", "yes", "on", "enabled"]);
is_truthy(_) ->
    false.

wait_forever() ->
    receive
        stop -> ok;
        _ -> wait_forever()
    end.
% end of file
