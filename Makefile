test: test-luajit test-lua5.3 test-lua5.1
.PHONY: test

test-luajit:
	@echo -n "test luajit "
	@busted --lua=luajit
.PHONY: test-luajit

test-lua5.3:
	@echo -n "test lua-5.3 "
	@busted --lua=lua5.3
.PHONY: test-lua5.3

test-lua5.1:
	@echo -n "test lua-5.1 "
	@busted --lua=lua5.1
.PHONY: test-lua5.1

check:
	@luacheck -q .
.PHONY: check

coverage:
	@rm -f luacov.report.out luacov.stats.out
	@busted --coverage > /dev/null
	@luacov
	@luajit -e "require('tools.covreporter')()"
.PHONY: coverage

coverage-test:
	@rm -f luacov.report.out luacov.stats.out
	@busted --coverage --no-keep-going
	@luacov
	@luajit -e "require('tools.covreporter')()"
	@rm -f luacov.report.out luacov.stats.out
.PHONY: coverage-test

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
.PHONY: _clear-stdout

devtest: _clear-stdout coverage-test check check-duplication
.PHONY: devtest

test-full: test coverage check
.PHONY: test-full

livedev:
	@nodemon -e lua -q -x "make -Ss devtest || exit 1"
.PHONY: livedev

docker-image:
	docker build -t "euluna" .
.PHONY: docker-image

docker-test:
	docker run --rm -it -v `pwd`:/euluna euluna make -s test
.PHONY: docker-test

docker-test-rocks:
	docker run --rm -it -v `pwd`:/euluna euluna sudo luarocks install rockspecs/euluna-dev-1.rockspec
.PHONY: docker-test-rocks

docker-test-full:
	docker run --rm -it -v `pwd`:/euluna euluna make -s test-full
.PHONY: docker-test-full

docker-term:
	docker run --rm -it -v `pwd`:/euluna euluna /bin/bash
.PHONY: docker-term

install-dev-deps:
	luarocks install --lua-version=5.1 --only-deps rockspecs/euluna-dev-1.rockspec --local
	luarocks install --lua-version=5.3 --only-deps rockspecs/euluna-dev-1.rockspec --local
.PHONY: install-dev-deps

clean:
	rm -f luacov.report.out luacov.stats.out
.PHONY: clean