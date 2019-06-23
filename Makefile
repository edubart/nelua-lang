UID=$(shell id -u $(USER))
GID=$(shell id -g $(USER))
PWD=$(shell pwd)
DRFLAGS=--rm -it -v "$(PWD):/nelua" nelua
DFLAGS=-u $(UID):$(GID) $(DRFLAGS)
LUAMONFLAGS=-w nelua,spec,tools,examples,runtime -e lua,nelua,h,c -q -x

test: test-luajit test-lua5.3 test-lua5.1

test-luajit:
	@echo -n "test luajit "
	@busted --lua=luajit

test-luajit-quick:
	@echo -n "test luajit "
	@busted --lua=luajit --no-keep-going

test-lua5.3:
	@echo -n "test lua-5.3 "
	@busted --lua=lua5.3

test-lua5.1:
	@echo -n "test lua-5.1 "
	@busted --lua=lua5.1

check:
	@luacheck -q .

benchmark:
	luajit ./tools/benchmarker.lua

coverage:
	@rm -f luacov.report.out luacov.stats.out
	@busted --coverage > /dev/null
	@luacov
	@luajit -e "require('tools.covreporter')()"

coverage-test:
	@rm -f luacov.report.out luacov.stats.out
	@busted --coverage --no-keep-going
	@luacov
	@luajit -e "require('tools.covreporter')()"
	@rm -f luacov.report.out luacov.stats.out

coverage-clean:
	rm -f luacov.report.out luacov.stats.out

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

devtest: _clear-stdout coverage-test check
devtestlight: _clear-stdout test-luajit-quick check

test-full: test coverage check

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
	$(MAKE) docker-test-all
	$(MAKE) docker-test-rocks

docker-term:
	docker run $(DRFLAGS) /bin/bash

install-dev:
	luarocks install --lua-version=5.3 --local rockspecs/nelua-dev-1.rockspec

install-dev-deps:
	luarocks install --lua-version=5.1 --only-deps rockspecs/nelua-dev-1.rockspec --local
	luarocks install --lua-version=5.3 --only-deps rockspecs/nelua-dev-1.rockspec --local

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
