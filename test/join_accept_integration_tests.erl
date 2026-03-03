%
% Copyright (c) 2026 Bumblebee contributors
% All rights reserved.
% Distributed under the terms of the MIT License. See the LICENSE file.
%
-module(join_accept_integration_tests).
-include_lib("eunit/include/eunit.hrl").

-define(AREA, <<"itest-area">>).
-define(NET, <<"itest-net">>).
-define(GWMAC, <<16#0000000000000001:64>>).
-define(GROUP, <<"itest-group">>).
-define(PROF_ABP, <<"itest-prof-abp">>).
-define(PROF_OTAA, <<"itest-prof-otaa">>).
-define(NODE0, {
    <<16#11223344:32>>,
    <<"2B7E151628AED2A6ABF7158809CF4F3C">>,
    <<"2B7E151628AED2A6ABF7158809CF4F3C">>
}).
-define(OTAA_DEV_EUI, <<16#0102030405060708:64>>).
-define(OTAA_APP_EUI, <<16#1122334455667788:64>>).
-define(OTAA_APP_KEY_HEX, <<"00112233445566778899AABBCCDDEEFF">>).

-record(state, {gateway, node, appkey}).

join_accept_integration_test_() ->
    case test_env:probe_socket_permissions() of
        true ->
            {setup, fun setup/0, fun cleanup/1, fun run/1};
        false ->
            []
    end.

setup() ->
    _ = application:start(mnesia),
    _ = application:start(bumblebee),
    ok = test_env:configure_ports(),
    {ok, _} = application:ensure_all_started(bumblebee),
    ok = test_env:wait_http_ready(),
    lager:set_loglevel(lager_console_backend, debug),

    test_admin:add_area(?AREA),
    test_admin:add_gateway(?AREA, ?GWMAC),
    test_admin:add_network(?NET),
    test_admin:add_group(?NET, ?GROUP),
    test_admin:add_profile(?GROUP, ?PROF_ABP),
    test_admin:add_profile(?GROUP, ?PROF_OTAA),
    test_admin:add_node(?PROF_ABP, ?NODE0),
    test_admin:add_device(?PROF_OTAA, {?OTAA_DEV_EUI, ?OTAA_APP_EUI, ?OTAA_APP_KEY_HEX}),

    {ok, Gateway} = test_forwarder:start_link(?GWMAC, test_env:gateway_server()),
    {ok, Node} = test_mote:start_link(?NODE0, Gateway),

    #state{
        gateway = Gateway,
        node = Node,
        appkey = lorawan_utils:hex_to_binary(?OTAA_APP_KEY_HEX)
    }.

cleanup(#state{gateway = Gateway, node = Node}) ->
    test_forwarder:stop(Gateway),
    test_mote:stop(Node),
    application:stop(bumblebee),
    application:stop(mnesia).

run(#state{gateway = Gateway, node = Node, appkey = AppKey}) ->
    {timeout, 10, fun() ->
        {ok, DevNonce, JoinResp} = send_join_until_accept(Gateway, AppKey, 16#1234, 3),
        ?assertMatch({ok, _}, JoinResp),
        ?assertEqual(true, join_accept_received(JoinResp)),
        % replayed devnonce shall be rejected
        ?assertEqual({error, timeout}, send_join(Gateway, AppKey, DevNonce)),
        ?assertEqual(
            {ok, false, 2, <<1>>},
            test_mote:push_and_pull(Node, false, 1, 2, test_mote:semtech_payload(0))
        ),
        ?assertEqual(
            {ok, false, 2, <<0>>},
            test_mote:push_and_pull(Node, false, 2, 2, test_mote:semtech_payload(1))
        )
    end}.

send_join(Gateway, AppKey, DevNonce) ->
    Msg = join_request_payload(AppKey, DevNonce),
    test_forwarder:push_and_pull(Gateway, test_forwarder:rxpk(base64:encode(Msg)), 3500).

send_join_until_accept(_Gateway, _AppKey, _Nonce, 0) ->
    {error, timeout};
send_join_until_accept(Gateway, AppKey, Nonce, Retries) ->
    DevNonce = <<(Nonce band 16#FFFF):16>>,
    Resp = send_join(Gateway, AppKey, DevNonce),
    case join_accept_received(Resp) of
        true ->
            {ok, DevNonce, Resp};
        false ->
            timer:sleep(250),
            send_join_until_accept(Gateway, AppKey, Nonce + 1, Retries - 1)
    end.

join_request_payload(AppKey, DevNonce) ->
    MHDR = <<2#000:3, 0:3, 0:2>>,
    Msg =
        <<MHDR/binary, (lorawan_utils:reverse(?OTAA_APP_EUI))/binary,
            (lorawan_utils:reverse(?OTAA_DEV_EUI))/binary, DevNonce/binary>>,
    MIC = lorawan_compat:cmac_n(AppKey, Msg, 4),
    <<Msg/binary, MIC/binary>>.

join_accept_received({ok, Resp64}) when is_binary(Resp64) ->
    case base64:decode(Resp64) of
        <<2#001:3, _/bitstring>> ->
            true;
        _Else ->
            false
    end;
join_accept_received(_Else) ->
    false.

% end of file
