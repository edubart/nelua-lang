# Detect variables based on the host system.
DEVNULL=/dev/null
ifeq ($(OS), Windows_NT)
	SYS=Windows
	ifeq ($(wildcard /dev/null),)
    	DEVNULL=NUL
	endif
	# Unix compatible environment?
	ifeq (, $(shell where which 2>$(DEVNULL)))
		WINMODE=1
	endif
else
	SYS=$(shell uname -s)
endif

NELUALUA=./nelua-lua
NELUALUAC=./nelua-luac
ifeq ($(SYS), Windows)
	NELUALUA=./nelua-lua.exe
	NELUALUAC=./nelua-luac.exe
endif

###############################################################################
# Nelua's Lua interpreter

# Compiler Flags
INCS=-Isrc/lua
DEFS=-DNDEBUG -DLUA_COMPAT_5_3 -DMAXRECLEVEL=400
SRCS=src/lua/onelua.c src/lfs.c src/sys.c src/hasher.c src/lpeglabel/*.c src/luainit.c
HDRS=src/lua/*.h src/lua/*.c src/lpeglabel/*.h src/luainit.h
CFLAGS=-O2
ifeq ($(SYS), Linux)
	CC=gcc
	CFLAGS=-O2 -fno-plt -flto
	LDFLAGS+=-Wl,-E
	LIBS+=-lm -ldl
	DEFS+=-DLUA_USE_LINUX
else ifeq ($(SYS), Windows)
	ifneq (,$(findstring cygdrive,$(ORIGINAL_PATH)))
		# Cygwin
		CC=$(shell uname -m)-w64-mingw32-gcc
	else ifneq (, $(shell where clang 2>$(DEVNULL)))
		# prefer clang (Visual Studio + Clang)
		CC=clang
	else # gcc (MSYS)
		CC=gcc
	endif
	LDFLAGS+=-static
	DEFS+=-D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS # disable some warnings
else ifeq ($(SYS), Darwin)
	CC=clang
	LIBS+=-lm
	LDFLAGS+=-rdynamic
	DEFS+=-DLUA_USE_MACOSX
else # probably POSIX
	CC=gcc
	LIBS+=-lm
	DEFS+=-DLUA_USE_POSIX
	NO_RPMALLOC=1
endif
ifndef NO_RPMALLOC
	ifeq ($(SYS), Windows)
		LIBS+=-ladvapi32
	endif
	SRCS+=src/rpmalloc/rpmalloc.c
	HDRS+=src/rpmalloc/rpmalloc.h
	DEFS+=-DLUA_USE_RPMALLOC -DENABLE_GLOBAL_CACHE=0 -DBUILD_DYNAMIC_LINK
endif

# The default target.
default: $(NELUALUA)

# Compile Nelua's bundled Lua interpreter.
$(NELUALUA): $(SRCS) $(HDRS)
	$(CC) \
		$(DEFS) $(MYDEFS) \
		$(INCS) $(MYINCS) \
		$(CFLAGS) $(MYCFLAGS) \
		$(SRCS) $(MYSRCS) \
		-o $(NELUALUA) \
		$(LDFLAGS) $(MYLDFLAGS) $(LIBS) $(MYLIBS)

# Compile Nelua's bundled Lua interpreter using PGO (Profile Guided optimization) and native,
# this can usually speed up compilation speed by ~6%.
optimized-nelua-lua:
	$(RM_DIR) pgo
	$(MAKE) --no-print-directory MYCFLAGS="-O3 -march=native -fprofile-generate=pgo" clean-nelualua default
	$(NELUALUA) nelua.lua -qb tests/all_test.nelua
	$(MAKE) --no-print-directory MYCFLAGS="-O3 -march=native -fprofile-use=pgo" clean-nelualua default
	$(RM_DIR) pgo

###############################################################################
## Lua init script

LUAC=$(NELUALUAC)
LUAC_SRCS=src/lua/onelua.c
LUAC_HDRS=src/lua/*.h
XXD=xxd

# Compile Nelua's Lua compiler.
$(NELUALUAC): $(LUAC_SRCS) $(LUAC_HDRS)
	$(CC) \
		-D MAKE_LUAC $(DEFS) $(MYDEFS) \
		$(INCS) $(MYINCS) \
		$(CFLAGS) $(MYCFLAGS) \
		$(SRCS) $(MYSRCS) \
		-o $(NELUALUAC) \
		$(LDFLAGS) $(MYLDFLAGS) $(LIBS) $(MYLIBS)

# Generates src/luainit.c (requires xxd tool from Vim)
gen-luainit: $(NELUALUAC) src/luainit.lua
	$(LUAC) -o src/luainit.luabc src/luainit.lua
	$(XXD) -i src/luainit.luabc > src/luainit.h

###############################################################################
# Testing

LUA=$(NELUALUA)
LUACHECK=luacheck
LUACOV=luacov
LUAMON=luamon -w nelua,spec,examples,lib,tests -e lua,nelua -q -x

# Run test suite.
test: $(NELUALUA)
	$(LUA) spec/init.lua

# Run test suite, stop on the first error.
test-quick: $(NELUALUA)
	@LESTER_QUIET=true LESTER_STOP_ON_FAIL=true $(LUA) spec/init.lua

# Run lua static analysis using lua check.
check:
	@$(LUACHECK) -q .

# Generate coverage report.
coverage-genreport:
	@$(LUACOV)
	@$(LUA) spec/tools/covreporter.lua

# Run the test suite analyzing code coverage.
coverage-test: $(NELUALUA)
	@$(MAKE) --no-print-directory clean-coverage
	$(LUA) -lluacov  spec/init.lua
	@$(MAKE) --no-print-directory coverage-genreport

# Compile each example.
examples/*.nelua: %.nelua:
	$(LUA) nelua.lua -qb $@
.PHONY: examples/*.nelua

# Compile all examples.
compile-examples: $(NELUALUA) examples/*.nelua

# Run the test suite, code coverage, lua checker and compile all examples.
test-full: $(NELUALUA) coverage-test check compile-examples

# Run the test suite on any file change (requires luamon).
live-dev:
	$(LUAMON) "make -Ss _live-dev"

_live-dev:
	@clear
	@$(MAKE) $(NELUALUA)
	@$(MAKE) test-quick
	@$(MAKE) check

###############################################################################
# Docker

# Variables for Docker
DOCKER_UID=$(shell id -u $(USER))
DOCKER_GID=$(shell id -g $(USER))
DOCKER=docker
DOCKER_RUN=$(DOCKER) run -u $(DOCKER_UID):$(DOCKER_GID) --rm -it -v "$(shell pwd):/nelua" nelua

# Make the docker image used to test inside docker containers.
docker-image:
	$(DOCKER) build -t "nelua" .

# Run tests inside a docker container.
docker-test:
	$(DOCKER_RUN) make -s test

# Run the test suite, code coverage, lua checker and compile all examples and install.
docker-test-full:
	$(MAKE) clean-nelualua
	$(DOCKER_RUN) make coverage-test check compile-examples

# Get a shell inside a new docker container.
docker-term:
	$(DOCKER_RUN) /bin/bash

###############################################################################
# Documentation

JEKYLL=bundle exec jekyll

# Compile documentation.
docs:
	cd docs && $(JEKYLL) build
.PHONY: docs

# Serve documentation in a local web server, recompile on any change.
docs-serve:
	cd docs && $(JEKYLL) serve

# Generate documentation (requires `nldoc` cloned and nelua installed).
docs-gen:
	cd ../nldoc && nelua --script nelua-docs.lua ../nelua-lang

###############################################################################
# Install

# Install paths
PREFIX?=/usr/local
DPREFIX=$(DESTDIR)$(PREFIX)
PREFIX_BIN=$(DPREFIX)/bin
PREFIX_LIB=$(DPREFIX)/lib
PREFIX_NELUALIB=$(PREFIX_LIB)/nelua/lib
PREFIX_LUALIB=$(PREFIX_LIB)/nelua/lualib

# Utilities
SED=sed
GIT=git
RM_FILE=rm -f
RM_DIR=rm -rf
MKDIR=mkdir -p
INSTALL_EXE=install -m755
INSTALL_FILE=install -m644
INSTALL_FILES=cp -Rf
ifdef WINMODE
	RM_FILE=del /Q
	RM_DIR=del /S /Q
else ifeq ($(OS), Windows_NT)
	# maybe the shell has unix like tools (e.g. BusyBox)
	RM_FILE=$(shell which rm) -f
	RM_DIR=$(shell which rm) -rf
	MKDIR=$(shell which mkdir) -p
	INSTALL_EXE=$(shell which install) -m755
	INSTALL_FILE=$(shell which install) -m644
	INSTALL_FILES=$(shell which cp) -Rf
endif

# In git directory?
ISGIT=$(shell $(GIT) rev-parse --is-inside-work-tree 2>$(DEVNULL))

_update_install_version:
ifeq ($(ISGIT),true)
	$(eval NELUA_GIT_HASH := $(shell $(GIT) rev-parse HEAD))
	$(eval NELUA_GIT_DATE := $(shell $(GIT) log -1 --format=%ci))
	$(eval NELUA_GIT_BUILD := $(shell $(GIT) rev-list HEAD --count))
	$(SED) -i.bak 's/NELUA_GIT_HASH = nil/NELUA_GIT_HASH = "$(NELUA_GIT_HASH)"/' "$(PREFIX_LUALIB)/nelua/version.lua"
	$(SED) -i.bak 's/NELUA_GIT_DATE = nil/NELUA_GIT_DATE = "$(NELUA_GIT_DATE)"/' "$(PREFIX_LUALIB)/nelua/version.lua"
	$(SED) -i.bak 's/NELUA_GIT_BUILD = nil/NELUA_GIT_BUILD = $(NELUA_GIT_BUILD)/' "$(PREFIX_LUALIB)/nelua/version.lua"
	$(RM_FILE) "$(PREFIX_LUALIB)/nelua/version.lua.bak"
endif

# Install Nelua using PREFIX into DESTDIR.
install: $(NELUALUA)
	$(MKDIR) "$(PREFIX_BIN)"
	$(INSTALL_EXE) $(NELUALUA) "$(PREFIX_BIN)/nelua-lua"
	$(INSTALL_EXE) nelua.sh "$(PREFIX_BIN)/nelua"
	$(MKDIR) "$(PREFIX_LUALIB)/nelua"
	$(INSTALL_FILE) nelua.lua "$(PREFIX_LUALIB)/nelua.lua"
	$(INSTALL_FILES) nelua/* "$(PREFIX_LUALIB)/nelua/"
	$(MKDIR) "$(PREFIX_NELUALIB)"
	$(INSTALL_FILES) lib/* "$(PREFIX_NELUALIB)/"
	$(MAKE) _update_install_version

# Install Nelua using this folder in the system.
install-as-symlink: $(NELUALUA)
	$(RM_FILE) "$(PREFIX_BIN)/nelua-lua"
	ln -fs "$(realpath $(NELUALUA))" "$(PREFIX_BIN)/nelua-lua"
	$(RM_FILE) "$(PREFIX_BIN)/nelua"
	ln -fs "$(realpath nelua.sh)" "$(PREFIX_BIN)/nelua"

# Uninstall Nelua
uninstall:
	$(RM_FILE) "$(PREFIX_BIN)/nelua-lua"
	$(RM_FILE) "$(PREFIX_BIN)/nelua"
	$(RM_DIR) "$(PREFIX_LIB)/nelua"

###############################################################################
# Clean

CACHE_DIR=.cache
ifdef HOME
	CACHE_DIR=$(HOME)/.cache/nelua
else ifdef USERPROFILE
	CACHE_DIR=$(USERPROFILE)\\.cache\\nelua
endif

# Clean the nelua cache directory.
clean-cache:
	$(RM_DIR) "$(CACHE_DIR)"

# Clean coverage files.
clean-coverage:
	$(RM_FILE) luacov.report.out
	$(RM_FILE) luacov.stats.out

# Clean the Lua interpreter.
clean-nelualua:
	$(RM_FILE) "$(NELUALUA)"

# Clean the Lua interpreter.
clean-nelualuac:
	$(RM_FILE) "$(NELUALUAC)"

# Clean documentation.
clean-docs:
	cd docs && $(JEKYLL) clean

# Clean everything.
clean: clean-nelualua clean-cache clean-coverage clean-nelualuac
