%
% Copyright (c) 2026 Bumblebee contributors
% All rights reserved.
% Distributed under the terms of the MIT License. See the LICENSE file.
%
-module(test_env).

-export([
    configure_ports/0,
    probe_socket_permissions/0,
    gateway_server/0,
    http_port/0,
    base_url/0,
    wait_http_ready/0
]).

configure_ports() ->
    HttpPort = get_port_from_env("BUMBLEBEE_TEST_HTTP_PORT", tcp, 8080),
    UdpPort = get_port_from_env("BUMBLEBEE_TEST_UDP_PORT", udp, 1680),

    application:set_env(bumblebee, http_admin_listen, [{port, HttpPort}]),
    application:set_env(bumblebee, http_admin_listen_ssl, []),
    application:set_env(bumblebee, http_admin_redirect_ssl, false),
    application:set_env(bumblebee, packet_forwarder_listen, [{port, UdpPort}]),
    application:set_env(bumblebee, test_http_port, HttpPort),
    application:set_env(bumblebee, test_udp_port, UdpPort),
    ok.

probe_socket_permissions() ->
    case {free_port(tcp), free_port(udp)} of
        {{ok, _}, {ok, _}} ->
            true;
        _ ->
            false
    end.

gateway_server() ->
    {ok, Port} = application:get_env(bumblebee, test_udp_port),
    {{127, 0, 0, 1}, Port}.

http_port() ->
    {ok, Port} = application:get_env(bumblebee, test_http_port),
    Port.

base_url() ->
    "http://127.0.0.1:" ++ integer_to_list(http_port()).

wait_http_ready() ->
    wait_http_ready(120).

get_port_from_env(Var, Kind, Default) ->
    case os:getenv(Var) of
        false ->
            case free_port(Kind) of
                {ok, Port} -> Port;
                {error, _Reason} -> Default
            end;
        Value ->
            list_to_integer(Value)
    end.

free_port(tcp) ->
    case gen_tcp:listen(0, [binary, {active, false}]) of
        {ok, Sock} ->
            {ok, {_IP, Port}} = inet:sockname(Sock),
            ok = gen_tcp:close(Sock),
            {ok, Port};
        {error, Reason} ->
            {error, Reason}
    end;
free_port(udp) ->
    case gen_udp:open(0, [binary]) of
        {ok, Sock} ->
            {ok, {_IP, Port}} = inet:sockname(Sock),
            ok = gen_udp:close(Sock),
            {ok, Port};
        {error, Reason} ->
            {error, Reason}
    end.

wait_http_ready(0) ->
    ok;
wait_http_ready(Retries) ->
    case listener_port() of
        {ok, Port} ->
            application:set_env(bumblebee, test_http_port, Port),
            case probe_http_port(Port) of
                ok ->
                    ok;
                {error, _Reason} ->
                    timer:sleep(100),
                    wait_http_ready(Retries - 1)
            end;
        {error, _Reason} ->
            timer:sleep(100),
            wait_http_ready(Retries - 1)
    end.

probe_http_port(Port) ->
    case try_connect("127.0.0.1", Port, [inet]) of
        ok ->
            ok;
        _ ->
            case try_connect("localhost", Port, [inet]) of
                ok ->
                    ok;
                _ ->
                    case try_connect("::1", Port, [inet6]) of
                        ok ->
                            ok;
                        _ ->
                            try_connect("localhost", Port, [inet6])
                    end
            end
    end.

listener_port() ->
    case catch ranch:get_port(http) of
        Port when is_integer(Port), Port > 0 ->
            {ok, Port};
        _ ->
            {error, not_ready}
    end.

try_connect(Host, Port, InetOpt) ->
    case gen_tcp:connect(Host, Port, [binary, {active, false} | InetOpt], 200) of
        {ok, Sock} ->
            ok = gen_tcp:close(Sock),
            ok;
        {error, Reason} ->
            {error, Reason}
    end.

% end of file
