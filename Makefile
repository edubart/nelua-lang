# Paths in the current source directory
PWD=$(shell pwd)
EXAMPLES=$(wildcard examples/*.nelua)
BENCHMARKS=$(wildcard benchmarks/*.nelua)
EXAMPLESDIR=$(abspath examples)
NELUALUA=src/nelua-lua
NELUASH=nelua.sh

# LuaRocks related
ROCKSPEC_DEV=rockspecs/nelua-dev-1.rockspec
LUAROCKS_BUILTFILES=*.so *.dll src/*.o src/lua/*.o src/lpeglabel/*.o

# Install variables
DPREFIX=$(DESTDIR)$(PREFIX)
INSTALL_BIN=$(DPREFIX)/bin
INSTALL_LIB=$(DPREFIX)/lib/nelua
INSTALL_LUALIB=$(DPREFIX)/lib/nelua/lualib
TMPDIR=/tmp

# All used utilities
RM=rm -f
RM_R=rm -rf
MKDIR=mkdir -p
INSTALL_X=install -Dm755
INSTALL_F=install -Dm644
UNINSTALL=rm -f
LUACHECK=luacheck
LUAROCKS=luarocks
BUSTED=busted
LUACOV=luacov
LUAMON=luamon -w nelua,spec,tools,examples,lib,tests -e lua,nelua -q -x
JEKYLL=bundle exec jekyll
PREFIX=/usr/local

## Variables for Docker
UID=$(shell id -u $(USER))
GID=$(shell id -g $(USER))
DOCKER=docker
DOCKER_RUN=$(DOCKER) run -u $(UID):$(GID) --rm -it -v "$(PWD):/nelua" nelua

## Host system detection.
SYS:=$(shell uname -s)
ifneq (,$(findstring MINGW,$(SYS)))
	SYS=Windows
endif
ifneq (,$(findstring MSYS,$(SYS)))
	SYS=Windows
endif

## Detect the lua interpreter to use.
ifeq ($(SYS), Windows)
	LUA=$(realpath $(NELUALUA).exe)
else
	LUA=$(NELUALUA)
endif

## The default target.
default: nelua-lua

## Compile Nelua's bundled Lua interpreter.
nelua-lua:
	@$(MAKE) --no-print-directory -C src

## Run test suite.
test: nelua-lua
	$(BUSTED) --lua=$(LUA)

## Run test suite, stop on the first error.
test-quick: nelua-lua
	$(BUSTED) --lua=$(LUA) --no-keep-going

## Run lua static analysis using lua check.
check:
	$(LUACHECK) -q .

## Run nelua benchmarks.
benchmark: nelua-lua
	$(LUA) tools/benchmarker.lua

## Generate coverage report.
coverage-genreport:
	$(LUACOV)
	@$(LUA) -e "require('tools.covreporter')()"

## Run the test suite analyzing code coverage.
coverage-test: nelua-lua
	@$(MAKE) clean-coverage
	$(BUSTED) --lua=$(LUA) --coverage
	@$(MAKE) coverage-genreport

## Compile all examples and benchmarks.
compile-examples: nelua-lua
	@for FILE in $(EXAMPLES); do \
		echo 'compiling ' $$FILE; \
		$(LUA) nelua.lua -qb $$FILE || exit 1; \
	done
	@for FILE in $(BENCHMARKS); do \
		echo 'compiling ' $$FILE; \
		$(LUA) nelua.lua -qb $$FILE || exit 1; \
	done

## Run the test suite, code coverage, lua checker and compile all examples.
test-full: nelua-lua coverage-test check compile-examples

## Run the test suite on any file change (requires luamon).
live-dev:
	$(LUAMON) "make -Ss _live-dev"

_live-dev:
	@clear
	@$(MAKE) test-quick
	@$(MAKE) check

## Upload luarocks package.
upload-rocks:
	$(LUAROCKS) upload --api-key=$(LUAROCKS_APIKEY) --force rockspecs/nelua-dev-1.rockspec

## Make the docker image used to test inside docker containers.
docker-image:
	$(DOCKER) build -t "nelua" --build-arg USER_ID=$(UID) --build-arg GROUP_ID=$(GID) .

## Run tests inside a docker container.
docker-test:
	$(DOCKER_RUN) make -s PREFIX=/usr test

_docker-test-rocks:
	$(LUAROCKS) make --local $(ROCKSPEC_DEV)
	# luarocks can leave built C files in the folder, remove them
	$(RM) $(LUAROCKS_BUILTFILES)
	# run a example anywhere in the system to test if works
	cd $(TMPDIR) && ~/.luarocks/bin/nelua -g lua $(EXAMPLESDIR)/helloworld.nelua
	cd $(TMPDIR) && ~/.luarocks/bin/nelua -g c $(EXAMPLESDIR)/helloworld.nelua

## Run the test suite, code coverage, lua checker and compile all examples and install.
docker-test-full:
	@$(MAKE) -C src clean
	@$(MAKE) clean
	$(DOCKER_RUN) make PREFIX=/usr coverage-test check compile-examples _docker-test-rocks

## Get a shell inside a new docker container.
docker-term:
	$(DOCKER_RUN) /bin/bash

## Compile documentation.
docs:
	cd docs && $(JEKYLL) build
.PHONY: docs

## Serve documentation in a local web server, recompile on any change.
docs-serve:
	cd docs && $(JEKYLL) serve

## Clean documentation.
docs-clean:
	cd docs && $(JEKYLL) clean

## Clean the nelua cache directory.
clean-cache:
	$(RM_R) nelua_cache

## Clean coverage files.
clean-coverage:
	$(RM) luacov.report.out luacov.stats.out *.gcov *.gcda

## Clean the Lua interpreter.
clean-nelua-lua:
	$(MAKE) -C src clean

## Clean everything.
clean: clean-cache clean-coverage clean-nelua-lua

## Install Nelua using PREFIX into DESTDIR.
install:
	$(MAKE) --no-print-directory -C src
	$(INSTALL_X) $(NELUALUA) $(INSTALL_BIN)/nelua-lua
	$(INSTALL_X) $(NELUASH) $(INSTALL_BIN)/nelua
	$(INSTALL_F) nelua.lua $(INSTALL_LUALIB)/nelua.lua
	find nelua -name '*.lua' -exec $(INSTALL_F) {} $(INSTALL_LUALIB)/{} \;
	find lib -name '*.nelua' -exec $(INSTALL_F) {} $(INSTALL_LIB)/{} \;

## Uninstall Nelua
uninstall:
	$(UNINSTALL) $(INSTALL_BIN)/nelua-lua
	$(UNINSTALL) $(INSTALL_BIN)/nelua
	$(UNINSTALL) $(INSTALL_LUALIB)/nelua.lua
	find nelua -name '*.lua' -exec $(UNINSTALL) $(INSTALL_LUALIB)/{} \;
	find lib -name '*.nelua' -exec $(UNINSTALL) $(INSTALL_LIB)/{} \;
