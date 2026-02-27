%
% Copyright (c) 2016-2019 Petr Gotthard <petr.gotthard@centrum.cz>
% All rights reserved.
% Distributed under the terms of the MIT License. See the LICENSE file.
%
-module(lorawan_compat).

-export([pg_create/1, pg_join/2, pg_get_members/1, pg_which_groups/0]).
-export([cmac_n/3, block_encrypt_ecb/2, block_decrypt_ecb/2, hmac_sha256/2]).
-export([uri_encode/1, parse_uri/1, parse_uri/2]).

pg_create(_Group) ->
    ensure_pg(),
    ok.

pg_join(Group, Pid) ->
    ensure_pg(),
    pg:join(Group, Pid).

pg_get_members(Group) ->
    ensure_pg(),
    case lists:member(Group, pg:which_groups()) of
        true ->
            pg:get_members(Group);
        false ->
            {error, {no_such_group, Group}}
    end.

pg_which_groups() ->
    ensure_pg(),
    pg:which_groups().

cmac_n(Key, Data, N) ->
    crypto:macN(cmac, aes_128_cbc, Key, Data, N).

block_encrypt_ecb(Key, Data) ->
    crypto:crypto_one_time(aes_128_ecb, Key, Data, true).

block_decrypt_ecb(Key, Data) ->
    crypto:crypto_one_time(aes_128_ecb, Key, Data, false).

hmac_sha256(Key, Data) ->
    crypto:mac(hmac, sha256, Key, Data).

uri_encode(Value) when is_binary(Value) ->
    uri_string:quote(binary_to_list(Value));
uri_encode(Value) when is_list(Value) ->
    uri_string:quote(Value).

parse_uri(Uri) ->
    parse_uri(Uri, []).

parse_uri(Uri, SchemeDefaults) ->
    UriList =
        case Uri of
            Bin when is_binary(Bin) -> binary_to_list(Bin);
            List when is_list(List) -> List
        end,
    case uri_string:parse(UriList) of
        Parsed when is_map(Parsed) ->
            Scheme = list_to_atom(maps:get(scheme, Parsed)),
            Host = maps:get(host, Parsed),
            Port = maps:get(port, Parsed, proplists:get_value(Scheme, SchemeDefaults)),
            Path = maps:get(path, Parsed, "/"),
            Query = maps:get(query, Parsed, undefined),
            UserInfo = maps:get(userinfo, Parsed, undefined),
            {ok, {Scheme, UserInfo, Host, Port, Path, Query}};
        Error ->
            Error
    end.

ensure_pg() ->
    case whereis(pg) of
        undefined ->
            case catch pg:start_link() of
                {ok, _Pid} ->
                    ok;
                {error, {already_started, _Pid}} ->
                    ok;
                {'EXIT', {already_started, _Pid}} ->
                    ok;
                _Other ->
                    ok
            end;
        _Pid ->
            ok
    end.

% end of file
