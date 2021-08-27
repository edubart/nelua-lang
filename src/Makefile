## Base configurations.
INCS=-Ilua
DEFS=-DNDEBUG
CFLAGS=-Wall -O2 -fno-plt -flto
SRCS=lua/onelua.c lfs.c sys.c hasher.c lpeglabel/*.c
HDRS=lua/*.h lpeglabel/*.h
EXE=nelua-lua
RM=rm -f
PREFIX=/usr/local

## Tune some values for the Lua interpreter
DEFS+=-DLUA_COMPAT_5_3 -DMAXRECLEVEL=400

## Host system detection.
SYS:=$(shell uname -s)
CPUARCH:=$(shell uname -m)
ifneq (,$(findstring MINGW,$(SYS)))
	SYS=Windows
endif
ifneq (,$(findstring MSYS,$(SYS)))
	SYS=Windows
endif
ifneq (,$(findstring CYGWIN,$(SYS)))
	SYS=Windows
endif

ifndef NO_RPMALLOC
	## Enable rpmalloc
	DEFS+=-DLUA_USE_RPMALLOC
	SRCS+=rpmalloc/rpmalloc.c
	## Tune rpmalloc
	DEFS+=-DENABLE_GLOBAL_CACHE=0 -DENABLE_UNLIMITED_CACHE=1 -DBUILD_DYNAMIC_LINK
endif

## Setup flags for the host system.
ifeq ($(SYS), Linux)
	CC=gcc
	LDFLAGS+=-Wl,-E
	LIBS+=-lm -ldl
	DEFS+=-DLUA_USE_LINUX
else ifeq ($(SYS), Windows)
	CC=$(CPUARCH)-w64-mingw32-gcc
	EXE=nelua-lua.exe
	LDFLAGS+=-static
	DEFS+=-D_CRT_SECURE_NO_WARNINGS # disable some warnings on MSVC
else ifeq ($(SYS), Darwin)
	CC=clang
	LIBS+=-lm
	LDFLAGS+=-rdynamic
	DEFS+=-DLUA_USE_MACOSX
else # probably POSIX
	LIBS=-lm
	DEFS+=-DLUA_USE_POSIX
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
