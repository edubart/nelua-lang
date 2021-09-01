## Base configurations.
INCS=-Ilua
DEFS=-DNDEBUG -DLUA_COMPAT_5_3 -DMAXRECLEVEL=400
SRCS=lua/onelua.c lfs.c sys.c hasher.c lpeglabel/*.c
HDRS=lua/*.h lua/*.c lpeglabel/*.h
EXE=nelua-lua
EXEO=-o 
CFLAGS=-O2

## Host system detection.
ifeq ($(OS), Windows_NT)
	SYS=Windows
	## Detect if running under unix compatible environment by finding 'rm'
	ifeq (, $(shell where rm))
		WINMODE=1
	endif
else
	SYS=$(shell uname -s)
endif

## Utilities
ifdef WINMODE
	RM=del /Q
else
	RM=rm -f
endif

## Setup flags for the host system.
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
	else ifneq (, $(shell where clang))
		# prefer clang (Visual Studio + Clang)
		CC=clang
	else # gcc (MSYS)
		CC=gcc
	endif
	EXE=nelua-lua.exe
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

## Enable rpmalloc?
ifndef NO_RPMALLOC
	SRCS+=rpmalloc/rpmalloc.c
	HDRS+=rpmalloc/rpmalloc.h
	DEFS+=-DLUA_USE_RPMALLOC -DENABLE_GLOBAL_CACHE=0 -DBUILD_DYNAMIC_LINK
	ifdef VSCMD_VER
		LIBS+=-ladvapi32
	endif
endif

default: $(EXE)

## Target to compile the Lua interpreter.
$(EXE): $(SRCS) $(HDRS) Makefile
	$(CC) \
		$(DEFS) $(MYDEFS) \
		$(INCS) $(MYINCS) \
		$(CFLAGS) $(MYCFLAGS) \
		$(SRCS) $(MYSRCS) \
		$(EXEO)$(EXE) \
		$(LDFLAGS) $(MYLDFLAGS) $(LIBS) $(MYLIBS)

clean:
	$(RM) $(EXE)
