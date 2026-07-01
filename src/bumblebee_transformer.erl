%
% Copyright (c) 2026 Bumblebee contributors
% All rights reserved.
% Distributed under the terms of the MIT License. See the LICENSE file.
%
-module(bumblebee_transformer).

-export([transform/2, transform/3]).

-define(DEFAULT_TIMEOUT, 100).

-type script() :: iodata().
-type js_value() ::
    integer()
    | float()
    | binary()
    | true
    | false
    | null
    | undefined
    | [js_value()]
    | #{atom() | binary() => js_value()}.
-type opts() :: #{
    timeout => timeout(),
    context => map()
}.

-spec transform(script(), js_value()) -> {ok, js_value()} | {error, term()}.
transform(Script, Input) ->
    transform(Script, Input, #{}).

-spec transform(script(), js_value(), opts()) -> {ok, js_value()} | {error, term()}.
transform(Script, Input, Opts) when is_map(Opts) ->
    Timeout = maps:get(timeout, Opts, ?DEFAULT_TIMEOUT),
    Context = maps:get(context, Opts, #{}),
    with_context(fun(Ctx) ->
        case quickjs:eval(Ctx, Script, Timeout) of
            {ok, _} ->
                quickjs:call(Ctx, transform, [Input, Context], Timeout);
            {error, Reason} ->
                {error, {script_load_failed, Reason}}
        end
    end).

with_context(Fun) ->
    try
        case quickjs:new_context() of
            {ok, Ctx} ->
                try
                    Fun(Ctx)
                after
                    _ = quickjs:destroy_context(Ctx)
                end;
            {error, ContextReason} ->
                {error, {context_failed, ContextReason}}
        end
    catch
        error:{nif_not_loaded, _Module, _Line} ->
            {error, quickjs_nif_not_loaded};
        error:{nif_not_loaded, module, _Module, line, _Line} ->
            {error, quickjs_nif_not_loaded};
        Class:CatchReason:Stacktrace ->
            {error, {Class, CatchReason, Stacktrace}}
    end.
