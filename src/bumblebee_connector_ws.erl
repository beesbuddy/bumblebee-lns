%
% Copyright (c) 2016-2019 Petr Gotthard <petr.gotthard@centrum.cz>
% Copyright (c) 2026 Bumblebee contributors
% All rights reserved.
% Distributed under the terms of the MIT License. See the LICENSE file.
%
-module(bumblebee_connector_ws).

-export([start_connector/1, stop_connector/1]).
-export([init/2]).
-export([websocket_init/1, websocket_handle/2, websocket_info/2, terminate/3]).

-include("bumblebee_db.hrl").

-record(state, {conn, type, path, bindings}).

start_connector(
    #connector{connid = Id, publish_uplinks = PubUp, publish_events = PubEv} = Connector
) ->
    Routes =
        case bumblebee_connector:pattern_for_cowboy(PubUp) of
            undefined ->
                [];
            error ->
                bumblebee_connector:raise_failed(Id, {badarg, PubUp}),
                [];
            Pattern1 ->
                [{Pattern1, ?MODULE, [Connector, uplink]}]
        end ++
            case bumblebee_connector:pattern_for_cowboy(PubEv) of
                undefined ->
                    [];
                error ->
                    bumblebee_connector:raise_failed(Id, {badarg, PubEv}),
                    [];
                Pattern2 ->
                    [{Pattern2, ?MODULE, [Connector, event]}]
            end,
    bumblebee_http_registry:update({ws, Id}, #{routes => Routes}).

stop_connector(Id) ->
    bumblebee_http_registry:delete({ws, Id}).

init(Req, [#connector{connid = Id} = Connector, Type]) ->
    case authorize(Req, Connector) of
        {ok, Bindings} ->
            {ok, Timeout} = application:get_env('bumblebee_lns', websocket_timeout),
            {cowboy_websocket, Req,
                #state{
                    conn = Connector, type = Type, path = cowboy_req:path(Req), bindings = Bindings
                },
                #{idle_timeout => Timeout}};
        unauthorized ->
            bumblebee_utils:throw_error({connector, Id}, unauthorized),
            Req2 = cowboy_req:reply(403, Req),
            {ok, Req2, undefined};
        {error, Error} ->
            bumblebee_utils:throw_error({connector, Id}, Error),
            Req2 = cowboy_req:reply(404, Req),
            {ok, Req2, undefined}
    end.

authorize(Req, #connector{name = User}) when
    User == undefined; User == <<>>
->
    validate(Req);
authorize(Req, #connector{name = User, pass = Pass}) ->
    case cowboy_req:parse_header(<<"authorization">>, Req) of
        {basic, User, Pass} ->
            validate(Req);
        _Else ->
            unauthorized
    end.

validate(Req) ->
    Bindings = bumblebee_admin:parse(cowboy_req:bindings(Req)),
    case validate0(maps:to_list(Bindings)) of
        ok ->
            {ok, Bindings};
        Error ->
            Error
    end.

validate0([{Key, Value} | Other]) ->
    case validate_key(Key, Value) of
        ok ->
            validate0(Other);
        Else ->
            Else
    end;
validate0([]) ->
    ok.

validate_key(app, App) ->
    case mnesia:dirty_read(handler, App) of
        [#handler{}] ->
            ok;
        _Else ->
            {error, {unknown_application, App}}
    end;
validate_key(deveui, DevEUI) ->
    case mnesia:dirty_read(device, DevEUI) of
        [#device{}] ->
            ok;
        _Else ->
            {error, {unknown_deveui, bumblebee_utils:binary_to_hex(DevEUI)}}
    end;
validate_key(devaddr, DevAddr) ->
    V = fun(Key) ->
        case mnesia:dirty_read(multicast_channel, Key) of
            [#multicast_channel{}] ->
                ok;
            _Else ->
                {error, {unknown_devaddr, bumblebee_utils:binary_to_hex(Key)}}
        end
    end,

    case mnesia:dirty_read(node, DevAddr) of
        [#node{}] ->
            ok;
        _Else ->
            V(DevAddr)
    end;
validate_key(_Else, _) ->
    ok.

websocket_init(#state{conn = #connector{connid = Id, app = App}, bindings = Bindings} = State) ->
    _ = lager:debug("WebSocket connector ~p with ~p", [Id, Bindings]),
    ok = bumblebee_compat:pg_join({backend, App}, self()),
    {ok, State}.

websocket_handle({text, Msg}, State) ->
    handle_downlink(Msg, State);
websocket_handle({binary, Msg}, State) ->
    handle_downlink(Msg, State);
websocket_handle({ping, _}, State) ->
    % no action needed as server handles pings automatically
    {ok, State};
websocket_handle(Data, State) ->
    _ = lager:warning("Unknown handle ~w", [Data]),
    {ok, State}.

handle_downlink(Msg, #state{conn = Connector, bindings = Bindings} = State) ->
    case bumblebee_connector:decode_and_downlink(Connector, Msg, Bindings) of
        ok ->
            ok;
        {error, {Object, Error}} ->
            bumblebee_utils:throw_error(Object, Error);
        {error, Error} ->
            bumblebee_utils:throw_error({connector, Connector#connector.connid}, Error)
    end,
    {ok, State}.

websocket_info(nodes_changed, State) ->
    % nothing to do here
    {ok, State};
websocket_info(
    {uplink, _Node, Vars0},
    #state{conn = #connector{format = Format}, type = uplink, bindings = Bindings} = State
) ->
    case bumblebee_connector:same_common_vars(Vars0, Bindings) of
        true ->
            {reply, encode_uplink(Format, Vars0), State};
        false ->
            {ok, State}
    end;
websocket_info({uplink, _Node, _Vars}, #state{type = event} = State) ->
    % this is not for me
    {ok, State};
websocket_info(
    {event, _Node, Vars0},
    #state{type = event, bindings = Bindings} = State
) ->
    case bumblebee_connector:same_common_vars(Vars0, Bindings) of
        true ->
            {reply, {text, jsx:encode(bumblebee_admin:build(Vars0))}, State};
        false ->
            {ok, State}
    end;
websocket_info({event, _Node, _Vars0}, #state{type = uplink} = State) ->
    % this is not for me
    {ok, State};
websocket_info(
    {status, From}, #state{conn = #connector{connid = Id, app = App}, path = Uri} = State
) ->
    From !
        {status, [
            #{
                module => <<"ws">>,
                pid => bumblebee_connector:pid_to_binary(self()),
                connid => Id,
                app => App,
                uri => Uri,
                status => <<"connected">>
            }
        ]},
    {ok, State};
websocket_info(Info, State) ->
    _ = lager:warning("Unknown info ~p", [Info]),
    {ok, State}.

encode_uplink(<<"raw">>, Vars) ->
    {binary, maps:get(data, Vars, <<>>)};
encode_uplink(<<"json">>, Vars) ->
    {text, jsx:encode(bumblebee_admin:build(Vars))};
encode_uplink(<<"www-form">>, Vars) ->
    {text, bumblebee_connector:form_encode(Vars)}.

terminate(Reason, _Req, _State) ->
    _ = lager:debug("WebSocket terminated: ~p", [Reason]),
    ok.

% end of file
