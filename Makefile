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

NELUALUA=nelua-lua
NELUALUAC=nelua-luac
NELUA=nelua
ifeq ($(SYS), Windows)
	NELUALUA=nelua-lua.exe
	NELUALUAC=nelua-luac.exe
	NELUA=nelua.bat
endif
NELUA_RUN=./$(NELUA)

###############################################################################
# Nelua's Lua interpreter

# Compiler Flags
INCS=-Isrc/lua
DEFS=-DNDEBUG
LUA_DEFS=-DMAXRECLEVEL=400
SRCS=$(wildcard src/*.c) \
	 $(wildcard src/lpeglabel/*.c)
HDRS=$(wildcard src/*.h) \
	 $(wildcard src/lua/*.h) \
	 $(wildcard src/lua/*.c) \
	 $(wildcard src/lpeglabel/*.h)
CFLAGS=-O2
OPT_CFLAGS=-O3 -flto -fno-plt -fno-stack-protector
ifeq ($(SYS), Linux)
	CFLAGS=-std=gnu99 -O2
	CC=gcc
	DEFS+=-DLUA_USE_LINUX
	LIBS+=-lm -ldl
	LDFLAGS+=-Wl,-E
	ifeq ($(CC), musl-gcc)
		LDFLAGS+=-static
	endif
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
	DEFS+=-D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_WARNINGS
else ifeq ($(SYS), Darwin)
	CC=clang
	DEFS+=-DLUA_USE_MACOSX
	LIBS+=-lm
	LDFLAGS+=-rdynamic
else # probably POSIX
	CC=gcc
	DEFS+=-DLUA_USE_POSIX
	LIBS+=-lm
	NO_RPMALLOC=1
endif
ifndef NO_RPMALLOC
	SRCS+=src/srpmalloc/srpmalloc.c
	HDRS+=src/srpmalloc/srpmalloc.h
	LUA_DEFS+=-DLUA_USE_RPMALLOC
endif

# The default target.
default: $(NELUALUA)

# Compile Nelua's bundled Lua interpreter.
$(NELUALUA): $(SRCS) $(HDRS)
	$(CC) \
		$(LUA_DEFS) $(DEFS) $(MYDEFS) \
		$(INCS) $(MYINCS) \
		$(CFLAGS) $(MYCFLAGS) \
		$(SRCS) $(MYSRCS) \
		-o $(NELUALUA) \
		$(LDFLAGS) $(MYLDFLAGS) $(LIBS) $(MYLIBS)

# Compile Nelua's bundled Lua interpreter using PGO (Profile Guided optimization) and native,
# this can usually speed up compilation speed by ~6%.
optimized-nelua-lua:
	$(RM_DIR) pgo
	$(MAKE) --no-print-directory CFLAGS="-march=native $(OPT_CFLAGS) -fprofile-generate=pgo" clean-nelualua default
	$(NELUA_RUN) -qb tests/all_test.nelua
	$(MAKE) --no-print-directory CFLAGS="-march=native $(OPT_CFLAGS) -fprofile-use=pgo" clean-nelualua default
	$(RM_DIR) pgo

###############################################################################
## Luac

LUAC=./$(NELUALUAC)
LUAC_DEFS=-DMAKE_LUAC
LUAC_SRCS=src/lua/onelua.c
LUAC_HDRS=$(wildcard src/lua/*.h) $(wildcard src/lua/*.c)

# Compile Nelua's Lua compiler.
$(NELUALUAC): $(LUAC_SRCS) $(LUAC_HDRS)
	$(CC) \
		$(LUAC_DEFS) $(DEFS) $(MYDEFS) \
		$(INCS) $(MYINCS) \
		$(CFLAGS) $(MYCFLAGS) \
		$(LUAC_SRCS) \
		-o $(NELUALUAC) \
		$(LDFLAGS) $(MYLDFLAGS) $(LIBS) $(MYLIBS)

###############################################################################
## Lua init script

XXD=xxd

# Generates src/luainit.c (requires xxd tool from Vim)
gen-luainit: src/luainit.lua
	$(XXD) -i src/luainit.lua > src/luainit.h

###############################################################################
# Testing

LUA=./$(NELUALUA)
LUACHECK=luacheck
LUACOV=luacov
LUAMON=luamon -w nelua,spec,examples,lib,lualib,tests -e lua,nelua -q -x

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
	$(NELUA_RUN) -qb $@
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
DOCKER_IMAGE=nelua
DOCKER_SHELL=/bin/bash
DOCKER=docker
DOCKER_RUN=$(DOCKER) run -u $(DOCKER_UID):$(DOCKER_GID) --rm -it -v "$(shell pwd):/mnt" $(DOCKER_IMAGE)

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
docker-shell:
	$(DOCKER_RUN) $(DOCKER_SHELL)

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
PREFIX=/usr/local
DPREFIX=$(DESTDIR)$(PREFIX)
PREFIX_BIN=$(DPREFIX)/bin
PREFIX_LIB=$(DPREFIX)/lib
PREFIX_LIB_NELUA=$(PREFIX_LIB)/nelua

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
IS_GIT=$(shell $(GIT) rev-parse --is-inside-work-tree 2>$(DEVNULL))

# Patch 'version.lua' file using the current Git information.
install-version-patch:
ifeq ($(IS_GIT),true)
	$(eval NELUA_GIT_HASH := $(shell $(GIT) rev-parse HEAD))
	$(eval NELUA_GIT_DATE := $(shell $(GIT) log -1 --format=%ci))
	$(eval NELUA_GIT_BUILD := $(shell $(GIT) rev-list HEAD --count))
	$(SED) -i.bak 's/NELUA_GIT_HASH = nil/NELUA_GIT_HASH = "$(NELUA_GIT_HASH)"/' "$(PREFIX_LIB_NELUA)/lualib/nelua/version.lua"
	$(SED) -i.bak 's/NELUA_GIT_DATE = nil/NELUA_GIT_DATE = "$(NELUA_GIT_DATE)"/' "$(PREFIX_LIB_NELUA)/lualib/nelua/version.lua"
	$(SED) -i.bak 's/NELUA_GIT_BUILD = nil/NELUA_GIT_BUILD = $(NELUA_GIT_BUILD)/' "$(PREFIX_LIB_NELUA)/lualib/nelua/version.lua"
	$(RM_FILE) "$(PREFIX_LIB_NELUA)/lualib/nelua/version.lua.bak"
endif

# Install Nelua using PREFIX into DESTDIR.
install: $(NELUALUA)
	$(MKDIR) "$(PREFIX_BIN)"
	$(INSTALL_EXE) $(NELUALUA) "$(PREFIX_BIN)/$(NELUALUA)"
	$(INSTALL_EXE) nelua "$(PREFIX_BIN)/nelua"
	$(RM_DIR) "$(PREFIX_LIB_NELUA)"
	$(MKDIR) "$(PREFIX_LIB_NELUA)"
	$(INSTALL_FILES) lualib "$(PREFIX_LIB_NELUA)/lualib"
	$(INSTALL_FILES) lib "$(PREFIX_LIB_NELUA)/lib"
	$(MAKE) --no-print-directory install-version-patch

# Install Nelua using this folder in the system.
install-as-symlink: $(NELUALUA)
	$(MAKE) --no-print-directory uninstall
	$(RM_FILE) "$(PREFIX_BIN)/$(NELUALUA)"
	ln -fs "$(realpath $(NELUALUA))" "$(PREFIX_BIN)/$(NELUALUA)"
	$(RM_FILE) "$(PREFIX_BIN)/nelua"
	ln -fs "$(realpath nelua)" "$(PREFIX_BIN)/nelua"

# Uninstall Nelua
uninstall:
	$(RM_FILE) "$(PREFIX_BIN)/$(NELUALUA)"
	$(RM_FILE) "$(PREFIX_BIN)/nelua"
	$(RM_DIR) "$(PREFIX_LIB_NELUA)"

###############################################################################
# Packaging

# Utilities
TAR_XZ=tar cfJ
ZIP_DIR=7z a -mm=Deflate -mx=9
STRIP=strip

# Package name
ifeq ($(SYS), Windows)
	ARCHNAME=x86_64
else
	ARCHNAME=$(shell uname -m)
endif
OSNAME=posix
ifeq ($(SYS), Linux)
	OSNAME=linux
else ifeq ($(SYS), Windows)
	OSNAME=windows
else ifeq ($(SYS), Darwin)
	OSNAME=macos
endif
PKGDIR=pkg
PKGNAME=nelua-$(OSNAME)-$(ARCHNAME)-latest

package: $(NELUALUA)
	$(RM_DIR) "$(PKGDIR)/$(PKGNAME)"
	$(MKDIR) "$(PKGDIR)/$(PKGNAME)"
	$(INSTALL_FILES) lib "$(PKGDIR)/$(PKGNAME)/lib"
	$(INSTALL_FILES) lualib "$(PKGDIR)/$(PKGNAME)/lualib"
	$(MAKE) --no-print-directory install-version-patch PREFIX_LIB_NELUA="$(PKGDIR)/$(PKGNAME)"
	$(INSTALL_FILE) LICENSE "$(PKGDIR)/$(PKGNAME)/LICENSE"
ifeq ($(SYS), Windows)
	$(INSTALL_EXE) nelua.bat "$(PKGDIR)/$(PKGNAME)/nelua.bat"
	$(INSTALL_EXE) nelua-lua.exe "$(PKGDIR)/$(PKGNAME)/nelua-lua.exe"
	$(STRIP) "$(PKGDIR)/$(PKGNAME)/nelua-lua.exe"
	$(RM_FILE) "$(PKGDIR)/$(PKGNAME).zip"
	cd $(PKGDIR); $(ZIP_DIR) "$(PKGNAME).zip" "$(PKGNAME)"
else
	$(INSTALL_EXE) nelua "$(PKGDIR)/$(PKGNAME)/nelua"
	$(INSTALL_EXE) nelua-lua "$(PKGDIR)/$(PKGNAME)/nelua-lua"
	$(STRIP) "$(PKGDIR)/$(PKGNAME)/nelua-lua"
	$(RM_FILE) "$(PKGDIR)/$(PKGNAME).tar.xz"
	cd $(PKGDIR); $(TAR_XZ) "$(PKGNAME).tar.xz" "$(PKGNAME)"
endif

package-versioned:
	$(MAKE) --no-print-directory package \
		PKGNAME=nelua-$(OSNAME)-$(ARCHNAME)-$(shell $(NELUA_RUN) --semver)

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
	$(RM_FILE) $(NELUALUA)

# Clean the Lua interpreter.
clean-nelualuac:
	$(RM_FILE) $(NELUALUAC)

clean-packages:
	$(RM_DIR) pkg

# Clean documentation.
clean-docs:
	cd docs && $(JEKYLL) clean

# Clean everything.
clean: clean-nelualua clean-cache clean-coverage clean-nelualuac clean-packages
