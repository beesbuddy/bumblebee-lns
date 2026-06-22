# rebar3 logic by Bjorn-Egil Dahlberg
# https://gist.github.com/psyeugenic/d2d53a15463b218fd20c2fe7fd73ced0
REBAR3_URL=https://s3.amazonaws.com/rebar3/rebar3

ifeq ($(wildcard rebar3),rebar3)
REBAR3 ?= $(CURDIR)/rebar3
endif

REBAR3 ?= $(shell test -e `which rebar3` 2>/dev/null && which rebar3 || echo "./rebar3")

ifeq ($(REBAR3),)
REBAR3 = $(CURDIR)/rebar3
endif

COOKIE ?= COOKIE
NODE ?= dapnode@localhost
.PHONY: build upgrade clean distclean test release dist dpkg fmt fmt-check debug phx-server mix-setup

mix-setup:
	mix deps.get

phx-server:
	mix phx.server

build: $(REBAR3)
	@$(REBAR3) compile

$(REBAR3):
	wget $(REBAR3_URL) || curl -Lo rebar3 $(REBAR3_URL)
	@chmod a+x rebar3

upgrade: $(REBAR3)
	@$(REBAR3) upgrade

clean: $(REBAR3)
	@$(REBAR3) clean --all
	rm -rf node_modules

test: $(REBAR3)
	@$(REBAR3) eunit

fmt: $(REBAR3)
	@ERL_AFLAGS="-enable-feature all" $(REBAR3) as format format

fmt-check: $(REBAR3)
	@ERL_AFLAGS="-enable-feature all" $(REBAR3) as format format --verify

release: $(REBAR3)
	@$(REBAR3) release

dist: $(REBAR3)
	@$(REBAR3) tar

BUILD_DIR = _build/default/rel/bumblebee_lns

install:
	install -d $(DESTDIR)/usr/lib/bumblebee_lns
	cp -r $(BUILD_DIR)/bin $(BUILD_DIR)/lib $(BUILD_DIR)/releases $(DESTDIR)/usr/lib/bumblebee_lns

dpkg:
	./scripts/dpkg-deb/build-deb

debug:
	BUMBLEBEE_DEV_RELOAD=1 ERL_FLAGS="+D" rebar3 as test shell --name dapnode@localhost --setcookie COOKIE

# end of file
