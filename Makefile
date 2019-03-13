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

devtest: _clear-stdout coverage-test check check-duplication

test-full: test coverage check

livedev:
	@nodemon -e lua -q -x "make -Ss devtest || exit 1"

docker-image:
	docker build -t "euluna" .

docker-test:
	docker run --rm -it -v `pwd`:/euluna euluna make -s test

docker-test-rocks:
	docker run --rm -it -v `pwd`:/euluna euluna sudo luarocks install rockspecs/euluna-dev-1.rockspec

docker-test-full:
	docker run --rm -it -v `pwd`:/euluna euluna make -s test-full

docker-term:
	docker run --rm -it -v `pwd`:/euluna euluna /bin/bash

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

clean: coverage-clean docs-clean
