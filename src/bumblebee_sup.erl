%
% Copyright (c) 2016-2019 Petr Gotthard <petr.gotthard@centrum.cz>
% Copyright (c) 2026 Bumblebee contributors
% All rights reserved.
% Distributed under the terms of the MIT License. See the LICENSE file.
%
-module(bumblebee_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-spec start_link() -> {ok, pid()}.
start_link() ->
    supervisor:start_link(?MODULE, []).

init([]) ->
    bumblebee_utils:throw_info({server, node()}, started, unique),
    {ok,
        {{one_for_one, 2, 10}, [
            {db_guard, {bumblebee_db_guard, start_link, []}, permanent, 5000, worker, [
                bumblebee_db_guard
            ]},
            {gateways, {bumblebee_gw_sup, start_link, []}, permanent, infinity, supervisor, [
                bumblebee_gw_sup
            ]},
            {http_registry, {bumblebee_http_registry, start_link, []}, permanent, 5000, worker, [
                bumblebee_http_registry
            ]},
            {prometheus, {bumblebee_prometheus, start_link, []}, permanent, 5000, worker, [
                bumblebee_prometheus
            ]},
            {backends, {bumblebee_backend_sup, start_link, []}, permanent, infinity, supervisor, [
                bumblebee_backend_sup
            ]}
        ]}}.

% end of file
