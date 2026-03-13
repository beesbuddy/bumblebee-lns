-module(bumblebee_utils).

-export([semtech_inspect/1]).

-define(INSPECT_FMT, "version=~p token=0x~4.16.0B id=~p mac=~s~njson=~p~n").

semtech_inspect([]) ->
    empty;
semtech_inspect(Data) when is_binary(Data) ->
    semtech_inspect_bytes(Data);
semtech_inspect(Data) when is_list(Data) ->
    Bin = list_to_binary(Data),
    semtech_inspect_bytes(Bin).

semtech_inspect_bytes(<<>>) ->
    empty;
semtech_inspect_bytes(Bin) ->
    <<Ver:8, Token:16, Id:8, Mac:8/binary, Json/binary>> = Bin,
    Map = jsx:decode(Json, [return_maps]),
    io:format(
        ?INSPECT_FMT,
        [Ver, Token, Id, string:uppercase(lorawan_utils:binary_to_hex(Mac)), Map]
    ),
    Map.

-include_lib("eunit/include/eunit.hrl").

semtech_inspect_test_() ->
    Json = <<"{\"rxpk\":[]}">>,
    Packet = <<2, 16#BEEF:16, 0, 1, 2, 3, 4, 5, 6, 7, 8, Json/binary>>,
    [
        ?_assertEqual(empty, semtech_inspect([])),
        ?_assertEqual(empty, semtech_inspect(<<>>)),
        ?_assertEqual(#{<<"rxpk">> => []}, semtech_inspect(Packet)),
        ?_assertEqual(#{<<"rxpk">> => []}, semtech_inspect(binary_to_list(Packet)))
    ].
