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
	@rm -f luacov.report.out luacov.stats.out
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
		-threshold=5 \
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

fulltest: test coverage check
.PHONY: fulltest

livedev:
	@nodemon -e lua -q -x "make -Ss devtest || exit 1"
.PHONY: livedev

docker-image:
	docker build -t "euluna" .
.PHONY: docker-image

docker-test:
	docker run --rm -it -v `pwd`:/euluna euluna make -s test
.PHONY: docker-test

docker-fulltest:
	docker run --rm -it -v `pwd`:/euluna euluna make -s fulltest
.PHONY: docker-fulltest
