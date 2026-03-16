%
% Copyright (c) 2016-2019 Petr Gotthard <petr.gotthard@centrum.cz>
% Copyright (c) 2026 Bumblebee contributors
% All rights reserved.
% Distributed under the terms of the MIT License. See the LICENSE file.
%
-module(bumblebee_gw_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-spec start_link() -> {ok, pid()}.
start_link() ->
    supervisor:start_link(?MODULE, []).

init([]) ->
    {ok, PktFwdOpts} = application:get_env('bumblebee-lns', packet_forwarder_listen),
    {ok,
        {{one_for_one, 2, 10}, [
            {gateway_router, {bumblebee_gw_router, start_link, []}, permanent, 5000, worker, [
                bumblebee_gw_router
            ]},
            {packet_forwarder, {bumblebee_gw_forwarder, start_link, [PktFwdOpts]}, permanent, 5000,
                worker, [bumblebee_gw_forwarder]},
            {handlers, {bumblebee_handler_sup, start_link, []}, permanent, infinity, supervisor, [
                bumblebee_handler_sup
            ]}
        ]}}.

% end of file
