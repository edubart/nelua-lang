test: test-luajit test-lua5.3 test-lua5.1
.PHONY: test

test-luajit:
	@busted --lua=luajit
.PHONY: test-luajit

test-lua5.3:
	@busted --lua=lua5.3
.PHONY: test-lua5.3

test-lua5.1:
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

fulltest: test coverage check
.PHONY: fulltest

livedev:
	nodemon -e lua -q -x "make -Ss fulltest || exit 1"
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
