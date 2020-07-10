UID=$(shell id -u $(USER))
GID=$(shell id -g $(USER))
PWD=$(shell pwd)
DRFLAGS=--rm -it -v "$(PWD):/nelua" nelua
DFLAGS=-u $(UID):$(GID) $(DRFLAGS)
LUAMONFLAGS=-w nelua,spec,tools,examples,lib,tests -e lua,nelua -q -x
EXAMPLES=$(wildcard examples/*.nelua)
BENCHMARKS=$(wildcard benchmarks/*.nelua)
LUA?=lua

test:
	@busted --lua=$(LUA)

test-quick:
	@busted --lua=$(LUA) --no-keep-going

test-lua5.3:
	@echo -n "test lua-5.3 "
	@busted --lua=lua5.3

test-lua5.4:
	@echo -n "test lua-5.4 "
	@busted --lua=lua5.4

check:
	@luacheck -q .

benchmark:
	$(LUA) ./tools/benchmarker.lua

coverage-clean:
	@rm -f luacov.report.out luacov.stats.out

coverage-genreport:
	@luacov
	@$(LUA) -e "os.exit(require('tools.covreporter')() and 0 or 1)"

coverage:
	$(MAKE) coverage-clean
	@busted --coverage > /dev/null
	$(MAKE) coverage-genreport

coverage-test:
	$(MAKE) coverage-clean
	@busted --coverage --no-keep-going
	$(MAKE) coverage-genreport
	$(MAKE) coverage-clean

check-duplication:
	@simian \
		-threshold=6 \
		-ignoreCharacterCase- \
		-ignoreStringCase- \
		-ignoreModifiers- \
		-balanceParentheses+ \
		-balanceCurlyBraces+ \
		-reportDuplicateText+ \
		`find nelua -name '*.lua'` | tail +5 | head -n -2

_clear-stdout:
	@clear

devtest: _clear-stdout coverage-test check compile-examples
devtestlight: _clear-stdout test-quick check

test-full: test coverage check compile-examples

compile-examples:
	@echo -n "compile examples "
	@for FILE in $(EXAMPLES); do \
		$(LUA) nelua.lua -qb $$FILE || exit 1; \
		echo -n '+'; \
	done
	@for FILE in $(BENCHMARKS); do \
		$(LUA) nelua.lua -qb $$FILE || exit 1; \
		echo -n '+'; \
	done
	@echo ""

livedev:
	luamon $(LUAMONFLAGS) "make -Ss devtest"

livedevlight:
	luamon $(LUAMONFLAGS) "make -Ss devtestlight"

docker-image:
	docker build -t "nelua" .

docker-test:
	docker run $(DFLAGS) make -s test

_docker-test-rocks:
	sudo luarocks-5.3 make rockspecs/nelua-dev-1.rockspec
	cd /tmp && nelua -g lua /nelua/examples/helloworld.nelua
	cd /tmp && nelua -g c /nelua/examples/helloworld.nelua

docker-test-rocks:
	docker run $(DRFLAGS) make -s _docker-test-rocks

docker-test-all:
	$(MAKE) cache-clean
	docker run $(DFLAGS) make -s test-full

docker-test-full:
	$(MAKE) -s docker-test-all
	$(MAKE) -s docker-test-rocks

docker-term:
	docker run $(DFLAGS) /bin/bash

install-dev:
	luarocks install --local rockspecs/nelua-dev-1.rockspec

install-dev-deps:
	luarocks install --local --only-deps rockspecs/nelua-dev-1.rockspec

upload-dev-rocks:
	luarocks upload --api-key=$(LUAROCKS_APIKEY) --force rockspecs/nelua-dev-1.rockspec

docs:
	cd docs && jekyll build
.PHONY: docs

docs-clean:
	cd docs && jekyll clean

docs-serve:
	cd docs && bundle exec jekyll serve

cache-clean:
	rm -rf nelua_cache

clean: cache-clean coverage-clean
