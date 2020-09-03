## Base configurations.
INCS=-Ilua
DEFS=-DNDEBUG
CFLAGS=-Wall -O2 -fno-plt -fno-stack-protector -flto
LDFLAGS=-s
LIBS=-lm
SRCS=lua/onelua.c rpmalloc/rpmalloc.c lfs.c sys.c hasher.c lpeglabel/*.c
HDRS=lua/*.h lpeglabel/*.h
EXE=nelua-lua
RM=rm -f
PREFIX=/usr/local

## Tune some values for the Lua interpreter
DEFS+=-DLUA_COMPAT_5_3 -DLUAI_MAXCSTACK=16384 -DLUA_USE_RPMALLOC

## Tune rpmalloc
DEFS+=-DENABLE_GLOBAL_CACHE=0 -DBUILD_DYNAMIC_LINK


## Host system detection.
SYS:=$(shell uname -s)
ifneq (,$(findstring MINGW,$(SYS)))
	SYS=Windows
endif
ifneq (,$(findstring MSYS,$(SYS)))
	SYS=Windows
endif

## Install path
DEFS+=-DLUA_ROOT='"$(PREFIX)/"'

## Setup flags for the host system.
ifeq ($(SYS), Linux)
	CC=gcc
	LDFLAGS+=-Wl,-E
	LIBS+=-ldl
	DEFS+=-DLUA_USE_LINUX
else ifeq ($(SYS), Windows)
	CC=x86_64-w64-mingw32-gcc
	EXE=nelua-lua.exe
else ifeq ($(SYS), Darwin)
	CC=clang
	LDFLAGS=-rdynamic
	DEFS+=-DLUA_USE_MACOSX
else # probably POSIX
	CC=cc
	LDFLAGS+=-Wl,-E
	DEFS+=LUA_USE_POSIX
endif

default: $(EXE)

## Target to compile the Lua interpreter.
$(EXE): $(SRCS) $(HDRS) lua/*.c Makefile
	$(CC) -o $(EXE) \
		$(DEFS) \
		$(INCS) \
		$(CFLAGS) $(MYCFLAGS) \
		$(LDFLAGS) $(MYLDFLAGS) \
		$(SRCS) $(MYSRCS) \
		$(LIBS) $(MYLIBS)

clean:
	$(RM) $(EXE)
