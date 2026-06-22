-module(bumblebee_info).

-export([init/2]).

init(Req0, State) ->
    Req = cowboy_req:reply(
        200,
        #{<<"content-type">> => <<"text/plain">>},
        <<"Bubmblebee version 0.0.1">>,
        Req0
    ),
    {ok, Req, State}.



