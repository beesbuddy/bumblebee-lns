%
% Copyright (c) 2016-2019 Petr Gotthard <petr.gotthard@centrum.cz>
% Copyright (c) 2026 Bumblebee contributors
% All rights reserved.
% Distributed under the terms of the MIT License. See the LICENSE file.
%
-module(test_admin).

-export([
    add_area/1, add_gateway/2, add_network/1, add_group/2, add_profile/2, add_node/2, add_device/2
]).

add_area(AreaName) ->
    post_json("areas", [{name, AreaName}]).

add_gateway(AreaName, MAC) ->
    post_json("gateways", [
        {mac, bumblebee_utils:binary_to_hex(MAC)},
        {area, AreaName},
        {tx_rfch, 0},
        {gpspos, [{lat, 0}, {lon, 0}]},
        {gpsalt, 0}
    ]).

add_network(NetName) ->
    post_json("networks", [
        {name, NetName},
        {netid, <<"000000">>},
        {region, <<"EU868">>},
        {tx_codr, <<"4/5">>},
        {join1_delay, 1},
        {join2_delay, 2},
        {rx1_delay, 1},
        {rx2_delay, 2},
        {gw_power, 16},
        {max_eirp, 16},
        {rxwin_init, [{rx1_dr_offset, 0}, {rx2_dr, 0}, {rx2_freq, 869.525}]}
    ]).

add_group(NetName, GroupName) ->
    post_json("groups", [{name, GroupName}, {network, NetName}]).

add_profile(GroupName, ProfName) ->
    post_json("profiles", [
        {name, ProfName},
        {group, GroupName},
        {app, <<"semtech-mote">>},
        {join, 1},
        {fcnt_check, undefined},
        {adr_mode, 0}
    ]).

add_node(ProfName, {DevAddr, NwkSKey, AppSKey}) ->
    post_json("nodes", [
        {devaddr, bumblebee_utils:binary_to_hex(DevAddr)},
        {profile, ProfName},
        {nwkskey, NwkSKey},
        {appskey, AppSKey},
        {fcntup, 0},
        {fcntdown, 0},
        {adr_flag, 0},
        {adr_use, [{power, 1}, {datr, 0}, {chans, <<"0-2">>}]},
        {rxwin_use, [{rx1_dr_offset, 0}, {rx2_dr, 0}, {rx2_freq, 869.525}]},
        {devstat_time, calendar:universal_time()},
        {devstat_fcnt, 3}
    ]).

add_device(ProfName, {DevEUI, AppEUI, AppKey}) ->
    post_json("devices", [
        {deveui, bumblebee_utils:binary_to_hex(DevEUI)},
        {profile, ProfName},
        {appeui, bumblebee_utils:binary_to_hex(AppEUI)},
        {appkey, AppKey}
    ]).

post_json(Uri, Body) ->
    {ok, {{_Version, 200, _ReasonPhrase2}, _Headers2, _Body2}} =
        request_with_retry(Uri, Body, 200).

basic_auth() ->
    "Basic " ++ binary_to_list(base64:encode(<<"admin:admin">>)).

request_with_retry(Uri, Body, Retries) ->
    case
        httpc:request(
            post,
            {
                test_env:base_url() ++ "/api/" ++ Uri,
                [{"Authorization", basic_auth()}],
                "application/json",
                jsx:encode(Body)
            },
            [],
            []
        )
    of
        {ok, {{_Version, 200, _ReasonPhrase2}, _Headers2, _Body2}} = Ok ->
            Ok;
        {error, {failed_connect, _}} when Retries > 0 ->
            timer:sleep(100),
            request_with_retry(Uri, Body, Retries - 1);
        Error ->
            Error
    end.

% end of file
