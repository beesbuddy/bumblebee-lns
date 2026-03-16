# Build container
FROM erlang:26-alpine AS scratch

RUN apk add --no-cache --virtual build-deps git make wget nodejs-npm && \
    git clone https://github.com/gotthardp/bumblebee.git && \
    cd bumblebee && \
    make release

# Deployment container
FROM erlang:26-alpine

## Not likely to change with rebuilds

# data from port_forwarders
EXPOSE 1680/udp
# http admin interface
EXPOSE 8080/tcp
# https admin interface
EXPOSE 8443/tcp

# volume for the mnesia database and logs
VOLUME /storage
ENV BUMBLEBEE_LNS_HOME=/storage

# Base directory
WORKDIR /usr/lib/bumblebee_lns
CMD bin/bumblebee_lns

## Changes with every rebuild
COPY --from=scratch /bumblebee/_build/default/rel/ /usr/lib/
