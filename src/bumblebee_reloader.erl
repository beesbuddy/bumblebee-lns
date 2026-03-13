%
% Copyright (c) 2026 Bumblebee contributors
% All rights reserved.
% Distributed under the terms of the MIT License. See the LICENSE file.
%
-module(bumblebee_reloader).
-export([start/0, start/1]).

-define(POLL_MS, 1000).
-define(SRC, "src").
-define(NAME, bumblebee_code_reloader).

%% Starts a lightweight watcher that recompiles and reloads .erl files on change.
start() ->
    start(?SRC).

start(Dir) ->
    AbsDir = filename:absname(Dir),
    case filelib:is_dir(AbsDir) of
        true ->
            ensure_started(AbsDir);
        false ->
            {error, no_dir}
    end.

ensure_started(Dir) ->
    case whereis(?NAME) of
        undefined ->
            Pid = spawn(fun() -> run(Dir) end),
            case catch register(?NAME, Pid) of
                true -> ok;
                {'EXIT', _} -> ok
            end;
        _Pid ->
            ok
    end.

run(Dir) ->
    process_flag(trap_exit, true),
    loop(Dir, index_files(Dir)).

loop(Dir, State) ->
    receive
        stop ->
            ok;
        {'EXIT', _From, _Reason} ->
            loop(Dir, State)
    after ?POLL_MS ->
        try detect_changes(Dir, State) of
            {Changed, NextState} ->
                lists:foreach(
                    fun(File) ->
                        _ = (catch compile_and_load(File))
                    end,
                    Changed
                ),
                loop(Dir, NextState)
        catch
            Class:Reason:Stack ->
                io:format("Reloader loop error (~p:~p): ~p~n", [Class, Reason, Stack]),
                loop(Dir, State)
        end
    end.

index_files(Dir) ->
    filelib:fold_files(
        Dir,
        ".*\\.erl$",
        true,
        fun(File, Acc) ->
            Signature = file_signature(File),
            maps:put(File, Signature, Acc)
        end,
        #{}
    ).

file_signature(File) ->
    case file:read_file(File) of
        {ok, Bin} ->
            {ok, erlang:phash2(Bin)};
        {error, Reason} ->
            {error, Reason}
    end.

detect_changes(Dir, Prev) ->
    Current = index_files(Dir),
    Changed = [
        File
     || {File, MTime} <- maps:to_list(Current),
        maps:get(File, Prev, undefined) =/= MTime
    ],
    {Changed, Current}.

compile_and_load(File) ->
    EbinDir =
        case code:lib_dir(runlet, ebin) of
            {error, bad_name} -> filename:dirname(code:which(?MODULE));
            Path -> Path
        end,
    code:add_patha(EbinDir),
    WasInterpreted = is_interpreted(File),
    %% Include debug_info so breakpoints keep working after reloads.
    Options = [{outdir, EbinDir}, debug_info, report_errors, report_warnings],
    case compile:file(File, Options) of
        {ok, Module} ->
            handle_compiled(Module, File, WasInterpreted);
        {ok, Module, _Warnings} ->
            handle_compiled(Module, File, WasInterpreted);
        Error ->
            io:format("Reload failed for ~s: ~p~n", [File, Error]),
            Error
    end.

handle_compiled(Module, File, WasInterpreted) ->
    code:purge(Module),
    case code:load_file(Module) of
        {module, Module} ->
            maybe_reinterpret(WasInterpreted, Module),
            io:format("Reloaded ~p from ~s~n", [Module, File]),
            ok;
        LoadError ->
            io:format("Reload failed for ~s: ~p~n", [File, LoadError]),
            LoadError
    end.

%% Returns true if the module owning File is currently interpreted by the debugger.
is_interpreted(File) ->
    try
        Module = list_to_atom(filename:basename(File, ".erl")),
        int:is_interpreted(Module)
    catch
        _:_ -> false
    end.

%% Reinterpret a module after reload so existing VSCode breakpoints keep working.
maybe_reinterpret(true, Module) ->
    ensure_debugger_started(),
    %% Reload with the interpreter and reapply any existing breakpoints.
    _ = (catch int:ni(Module)),
    reapply_breakpoints(Module);
maybe_reinterpret(false, _Module) ->
    ok.

ensure_debugger_started() ->
    case whereis(int) of
        undefined ->
            _ = (catch int:start()),
            ok;
        _ ->
            ok
    end.

reapply_breakpoints(Module) ->
    case catch int:all_breaks(Module) of
        {'EXIT', _} ->
            ok;
        Breaks ->
            lists:foreach(
                fun({{_Mod, Line}, _Opts}) ->
                    _ = (catch int:break(Module, Line))
                end,
                Breaks
            ),
            ok
    end.
