#!/bin/sh
set -eu

LAGER_FILE="_build/default/lib/lager/src/lager_transform.erl"
if [ -f "$LAGER_FILE" ]; then
  if ! grep -q "make_varname(Prefix, {Line, _Column})" "$LAGER_FILE"; then
    sed -i 's/^make_varname(Prefix, Line) ->$/make_varname(Prefix, {Line, _Column}) when is_integer(Line) ->\
    make_varname(Prefix, Line);\
make_varname(Prefix, Line) ->/' "$LAGER_FILE"
  fi
  erlc -I _build/default/lib/lager/include -o _build/default/lib/lager/ebin "$LAGER_FILE"
fi

CRED_FILE="_build/default/lib/credentials_obfuscation/src/credentials_obfuscation_pbe.erl"
if [ -f "$CRED_FILE" ]; then
  # Patch only legacy credentials_obfuscation (e.g. 1.1.0) that still uses removed crypto APIs.
  if grep -q "crypto:block_encrypt(" "$CRED_FILE" || grep -q "fun crypto:hmac/4" "$CRED_FILE"; then
    sed -i \
      -e 's/crypto:block_encrypt(Cipher, Key, Ivec, pad(Cipher, ClearText))/crypto:crypto_one_time(Cipher, Key, Ivec, pad(Cipher, ClearText), true)/' \
      -e 's/crypto:block_decrypt(Cipher, Key, Ivec, Binary)/crypto:crypto_one_time(Cipher, Key, Ivec, Binary, false)/' \
      -e 's/fun crypto:hmac\/4/fun prf_hmac_n\/4/' \
      "$CRED_FILE"

    if ! grep -q '^prf_hmac_n(Hash, Key, Data, N) ->' "$CRED_FILE"; then
      sed -i '/^ceiling(Float) ->/i\
prf_hmac_n(Hash, Key, Data, N) ->\
    crypto:macN(hmac, Hash, Key, Data, N).\
' "$CRED_FILE"
    fi

    erlc -I _build/default/lib/credentials_obfuscation/include -o _build/default/lib/credentials_obfuscation/ebin "$CRED_FILE"
  fi
fi
