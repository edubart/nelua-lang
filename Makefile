UID=$(shell id -u $(USER))
GID=$(shell id -g $(USER))
PWD=$(shell pwd)
DFLAGS=--rm -it -u $(UID):$(GID) -v "$(PWD):/euluna" euluna

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
	@nodemon -e lua -q -x "make -Ss devtest || exit 1"

DOCKER_FLAGS="-u $(id -u ${USER}):$(id -g ${USER})"
docker-image:
	docker build -t "euluna" .

docker-test:
	docker run $(DFLAGS) make -s test

docker-test-rocks:
	docker run $(DFLAGS) sudo luarocks install rockspecs/euluna-dev-1.rockspec

docker-test-full:
	$(MAKE) cache-clean
	docker run $(DFLAGS) make -s test-full

docker-term:
	docker run $(DFLAGS) /bin/bash

install-dev:
	luarocks install --lua-version=5.3 --local rockspecs/euluna-dev-1.rockspec

install-dev-deps:
	luarocks install --lua-version=5.1 --only-deps rockspecs/euluna-dev-1.rockspec --local
	luarocks install --lua-version=5.3 --only-deps rockspecs/euluna-dev-1.rockspec --local

docs:
	cd docs && jekyll build
.PHONY: docs

docs-clean:
	cd docs && jekyll clean

docs-serve:
	cd docs && bundle exec jekyll serve

cache-clean:
	rm -rf euluna_cache

clean: cache-clean coverage-clean docs-clean
