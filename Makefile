# Paths in the current source directory
PWD=$(shell pwd)
EXAMPLES=$(wildcard examples/*.nelua)
EXAMPLESDIR=$(abspath examples)
NELUALUA=src/nelua-lua
NELUASH=nelua.sh

# Install variables
PREFIX?=/usr/local
DPREFIX=$(DESTDIR)$(PREFIX)
INSTALL_BIN=$(DPREFIX)/bin
INSTALL_LIB=$(DPREFIX)/lib/nelua
INSTALL_LUALIB=$(DPREFIX)/lib/nelua/lualib

# All used utilities
RM=rm -f
RM_R=rm -rf
SED=sed
MKDIR=mkdir -p
INSTALL_X=install -m755
INSTALL_F=install -m644
LUACHECK=luacheck
LUACOV=luacov
LUAMON=luamon -w nelua,spec,examples,lib,tests -e lua,nelua -q -x
JEKYLL=bundle exec jekyll

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
ifneq (,$(findstring CYGWIN,$(SYS)))
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

## Compile Nelua's bundled Lua interpreter using PGO (Profile Guided optimization) and native,
## this can usually speed up compilation speed by ~6%.
optimized-nelua-lua:
	rm -rf pgo
	$(MAKE) --no-print-directory -C src MYCFLAGS="-O3 -march=native -fprofile-generate=pgo" clean default
	$(NELUALUA) nelua.lua -qb tests/all_test.nelua
	$(MAKE) --no-print-directory -C src MYCFLAGS="-O3 -march=native -fprofile-use=../pgo" clean default
	rm -rf pgo

## Run test suite.
test: nelua-lua
	$(LUA) spec/init.lua

## Run test suite, stop on the first error.
test-quick:
	@LESTER_QUIET=true LESTER_STOP_ON_FAIL=true $(LUA) spec/init.lua

## Run lua static analysis using lua check.
check:
	@$(LUACHECK) -q .

## Generate coverage report.
coverage-genreport:
	@$(LUACOV)
	@$(LUA) spec/tools/covreporter.lua

## Run the test suite analyzing code coverage.
coverage-test: nelua-lua
	@$(MAKE) --no-print-directory clean-coverage
	$(LUA) -lluacov  spec/init.lua
	@$(MAKE) --no-print-directory coverage-genreport

## Compile all examples.
compile-examples: nelua-lua
	@for FILE in $(EXAMPLES); do \
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
	@$(MAKE) nelua-lua
	@$(MAKE) test-quick
	@$(MAKE) check

## Make the docker image used to test inside docker containers.
docker-image:
	$(DOCKER) build -t "nelua" .

## Run tests inside a docker container.
docker-test:
	$(DOCKER_RUN) make -s PREFIX=/usr test

## Run the test suite, code coverage, lua checker and compile all examples and install.
docker-test-full:
	@$(MAKE) -C src clean
	@$(MAKE) clean
	$(DOCKER_RUN) make PREFIX=/usr coverage-test check compile-examples

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

## Generate documentation (requires `nldoc` cloned and nelua installed).
docs-gen:
	cd ../nldoc && nelua --script nelua-docs.lua ../nelua-lang

## Clean the nelua cache directory.
clean-cache:
	$(RM_R) $(HOME)/.cache/nelua

## Clean coverage files.
clean-coverage:
	$(RM) luacov.report.out luacov.stats.out *.gcov *.gcda

## Clean the Lua interpreter.
clean-nelua-lua:
	$(MAKE) -C src clean

## Clean everything.
clean: clean-cache clean-coverage clean-nelua-lua

ISGIT:=$(shell git rev-parse --is-inside-work-tree 2> /dev/null)
ifeq ($(ISGIT),true)
_update_install_version:
	$(eval NELUA_GIT_HASH := $(shell git rev-parse HEAD))
	$(eval NELUA_GIT_DATE := $(shell git log -1 --format=%ci))
	$(eval NELUA_GIT_BUILD := $(shell git rev-list HEAD --count))
	$(SED) -i.bak 's/NELUA_GIT_HASH = nil/NELUA_GIT_HASH = "$(NELUA_GIT_HASH)"/' $(INSTALL_LUALIB)/nelua/version.lua
	$(SED) -i.bak 's/NELUA_GIT_DATE = nil/NELUA_GIT_DATE = "$(NELUA_GIT_DATE)"/' $(INSTALL_LUALIB)/nelua/version.lua
	$(SED) -i.bak 's/NELUA_GIT_BUILD = nil/NELUA_GIT_BUILD = $(NELUA_GIT_BUILD)/' $(INSTALL_LUALIB)/nelua/version.lua
	$(RM) $(INSTALL_LUALIB)/nelua/version.lua.bak
else
_update_install_version:
endif

## Install Nelua using PREFIX into DESTDIR.
install:
	$(MAKE) --no-print-directory -C src

	$(MKDIR) $(INSTALL_BIN)
	$(RM) $(INSTALL_BIN)/nelua-lua
	$(INSTALL_X) $(NELUALUA) $(INSTALL_BIN)/nelua-lua
	$(RM) $(INSTALL_BIN)/nelua
	$(INSTALL_X) $(NELUASH) $(INSTALL_BIN)/nelua

	$(MKDIR) $(INSTALL_LUALIB)
	$(INSTALL_F) nelua.lua $(INSTALL_LUALIB)/nelua.lua
	find nelua -type d -exec $(MKDIR) $(INSTALL_LUALIB)/{} \;
	find nelua -name '*.lua' -exec $(INSTALL_F) {} $(INSTALL_LUALIB)/{} \;

	$(MKDIR) $(INSTALL_LIB)
	find lib -type d -exec $(MKDIR) $(INSTALL_LIB)/{} \;
	find lib -name '*.nelua' -exec $(INSTALL_F) {} $(INSTALL_LIB)/{} \;
	$(MAKE) _update_install_version

## Install Nelua using this folder in the system.
install-as-symlink:
	$(MAKE) --no-print-directory -C src
	$(RM) $(INSTALL_BIN)/nelua-lua
	ln -fs $(realpath $(NELUALUA)) $(INSTALL_BIN)/nelua-lua
	$(RM) $(INSTALL_BIN)/nelua
	ln -fs $(realpath $(NELUASH)) $(INSTALL_BIN)/nelua

## Uninstall Nelua
uninstall:
	$(RM) $(INSTALL_BIN)/nelua-lua
	$(RM) $(INSTALL_BIN)/nelua
	$(RM) $(INSTALL_LUALIB)/nelua.lua
	$(RM_R) $(INSTALL_LUALIB)
	$(RM_R) $(INSTALL_LIB)
