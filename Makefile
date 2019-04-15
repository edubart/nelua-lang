UID=$(shell id -u $(USER))
GID=$(shell id -g $(USER))
PWD=$(shell pwd)
DRFLAGS=--rm -it -v "$(PWD):/euluna" euluna
DFLAGS=-u $(UID):$(GID) $(DRFLAGS)
LUAMONFLAGS=-w euluna,spec,tools,examples,runtime -e lua,euluna,h,c -q -x

test: test-luajit test-lua5.3 test-lua5.1

test-luajit:
	@echo -n "test luajit "
	@busted --lua=luajit

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
		`find euluna -name '*.lua'` | tail +5 | head -n -2

_clear-stdout:
	@clear

devtest: _clear-stdout coverage-test check

test-full: test coverage check

livedev:
	luamon $(LUAMONFLAGS) "make -Ss devtest"

docker-image:
	docker build -t "euluna" .

docker-test:
	docker run $(DFLAGS) make -s test

_docker-test-rocks:
	sudo luarocks-5.3 make rockspecs/euluna-dev-1.rockspec
	cd /tmp && euluna /euluna/examples/helloworld.euluna
	cd /tmp && euluna -g c /euluna/examples/helloworld.euluna

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
	luarocks install --lua-version=5.3 --local rockspecs/euluna-dev-1.rockspec

install-dev-deps:
	luarocks install --lua-version=5.1 --only-deps rockspecs/euluna-dev-1.rockspec --local
	luarocks install --lua-version=5.3 --only-deps rockspecs/euluna-dev-1.rockspec --local

upload-dev-rocks:
	luarocks upload --api-key=$(LUAROCKS_APIKEY) --force rockspecs/euluna-dev-1.rockspec

docs:
	cd docs && jekyll build
.PHONY: docs

docs-clean:
	cd docs && jekyll clean

docs-serve:
	cd docs && bundle exec jekyll serve

cache-clean:
	rm -rf euluna_cache

clean: cache-clean coverage-clean
