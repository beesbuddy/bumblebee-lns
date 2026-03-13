%
% Copyright (c) 2026 Bumblebee contributors
% All rights reserved.
% Distributed under the terms of the MIT License. See the LICENSE file.
%
-module(bumblebee_frontend_handler).

-behaviour(cowboy_handler).

-export([init/2]).

%% Serves built frontend assets (dev/prod) directly from Cowboy.
init(Req0, State0) ->
    UseDevServer = maps:get(use_dev_server, State0, false),
    case UseDevServer of
        true ->
            Req1 = proxy_to_dev_server(Req0, State0),
            {ok, Req1, State0};
        false ->
            Root = maps:get(root, State0, bumblebee_frontend:asset_dir()),
            Req1 = maybe_serve(Req0, Root),
            {ok, Req1, State0}
    end.

maybe_serve(Req0, Root0) ->
    Root = filename:absname(Root0),
    PathBin = cowboy_req:path(Req0),
    CleanPath = clean_path(PathBin),
    case CleanPath of
        [] ->
            serve_index(Root, Req0);
        _ ->
            case resolve_target(CleanPath, Root) of
                {ok, File} -> serve_file(File, Req0);
                not_found -> serve_index(Root, Req0)
            end
    end.

clean_path(PathBin) when is_binary(PathBin) ->
    string:trim(binary_to_list(PathBin), both, "/").

resolve_target(RelPath, Root) ->
    Candidate = filename:absname(RelPath, Root),
    case is_within_root(Root, Candidate) andalso filelib:is_regular(Candidate) of
        true -> {ok, Candidate};
        false -> not_found
    end.

is_within_root(Root, Candidate) ->
    RootWithSlash = ensure_trailing_slash(Root),
    CandidateWithSlash = ensure_trailing_slash(Candidate),
    lists:prefix(RootWithSlash, CandidateWithSlash).

ensure_trailing_slash([$/ | _] = Path) ->
    case lists:suffix("/", Path) of
        true -> Path;
        false -> Path ++ "/"
    end;
ensure_trailing_slash(Path) ->
    ensure_trailing_slash("/" ++ Path).

serve_file(Path, Req0) ->
    case file:read_file(Path) of
        {ok, Bin} ->
            Mime = mime_for(Path),
            cowboy_req:reply(200, #{<<"content-type">> => Mime}, Bin, Req0);
        {error, Reason} ->
            respond_text(
                500,
                io_lib:format("Failed to read ~s: ~p~n", [Path, Reason]),
                Req0
            )
    end.

serve_index(Root, Req0) ->
    IndexPath = filename:join(Root, "index.html"),
    case file:read_file(IndexPath) of
        {ok, Bin} ->
            cowboy_req:reply(200, #{<<"content-type">> => <<"text/html">>}, Bin, Req0);
        {error, enoent} ->
            respond_text(
                503,
                io_lib:format(
                    "UI build missing (~s). Run bumblebee_frontend:build_dev/0 or build_prod/0.~n",
                    [IndexPath]
                ),
                Req0
            );
        {error, Reason} ->
            respond_text(
                500,
                io_lib:format("Failed to read ~s: ~p~n", [IndexPath, Reason]),
                Req0
            )
    end.

respond_text(Status, Body, Req0) ->
    cowboy_req:reply(Status, #{<<"content-type">> => <<"text/plain">>}, Body, Req0).

proxy_to_dev_server(Req0, State) ->
    Origin = maps:get(dev_server_origin, State, bumblebee_frontend:dev_server_origin()),
    ok = bumblebee_frontend:ensure_dev_server_running(),
    ok = bumblebee_frontend:maybe_wait_for_dev_server(),
    Url = build_proxy_url(Origin, Req0),
    case httpc:request(get, {Url, []}, [], [{body_format, binary}]) of
        {ok, {{_, Status, _}, RespHeaders, Body}} ->
            Headers = filter_headers(RespHeaders),
            cowboy_req:reply(Status, Headers, Body, Req0);
        {error, Reason} ->
            respond_text(
                502,
                io_lib:format("Failed to proxy dev asset (~s): ~p~n", [Url, Reason]),
                Req0
            )
    end.

build_proxy_url(Origin, Req0) ->
    Path = cowboy_req:path(Req0),
    Query = cowboy_req:qs(Req0),
    OriginStr = binary_to_list(list_to_binary(Origin)),
    case Query of
        <<>> -> OriginStr ++ binary_to_list(Path);
        _ -> OriginStr ++ binary_to_list(Path) ++ "?" ++ binary_to_list(Query)
    end.

filter_headers(Headers) ->
    %% Keep content-type/cache headers; drop hop-by-hop ones.
    lists:foldl(
        fun({Key0, Val0}, Acc) ->
            Key = string:lowercase(to_list(Key0)),
            case lists:member(Key, ["content-type", "cache-control", "etag", "last-modified"]) of
                true -> maps:put(list_to_binary(Key), to_binary(Val0), Acc);
                false -> Acc
            end
        end,
        #{},
        Headers
    ).

to_list(Bin) when is_binary(Bin) -> binary_to_list(Bin);
to_list(List) when is_list(List) -> List.

to_binary(Bin) when is_binary(Bin) -> Bin;
to_binary(List) when is_list(List) -> list_to_binary(List).

mime_for(Path) ->
    BinPath = list_to_binary(Path),
    try
        {Type, SubType, _Params} = cow_mimetypes:web(BinPath),
        <<Type/binary, "/", SubType/binary>>
    catch
        _:_ -> <<"application/octet-stream">>
    end.
