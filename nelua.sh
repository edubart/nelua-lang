#!/bin/sh

# implement realpath case it's not present (Mac OS X for example)
if ! [ -x "$(command -v realpath)" ]; then
  realpath() {
    OURPWD=$PWD
    cd "$(dirname "$1")"
    LINK=$(readlink "$(basename "$1")")
    while [ "$LINK" ]; do
      cd "$(dirname "$LINK")"
      LINK=$(readlink "$(basename "$1")")
    done
    REALPATH="$PWD/$(basename "$1")"
    cd "$OURPWD"
    echo "$REALPATH"
  }
fi

# detect the current directory for this script
SCRIPT=$(realpath "$0")
SCRIPT_DIR=$(dirname "$SCRIPT")
SCRIPT_DIRNAME=$(basename "$SCRIPT_DIR")

if [ "$SCRIPT_DIRNAME" = "bin" ]; then
  # in a system install
  if [ -z "$NELUA_LUA" ]; then
    NELUA_LUA="$SCRIPT_DIR/nelua-lua"
  fi
  if [ -z "$NELUA_LUALIB" ]; then
    USR_DIR=$(dirname "$SCRIPT_DIR")
    NELUA_LUALIB="$USR_DIR/lib/nelua/lualib"
  fi
else
  # in a repository clone
  if [ -z "$NELUA_LUA" ]; then
    NELUA_LUA="$SCRIPT_DIR/src/nelua-lua"
  fi
  if [ -z "$NELUA_LUALIB" ]; then
    NELUA_LUALIB="$SCRIPT_DIR"
  fi
fi

# fallback to system lua in case NELUA_LUA is not found
if [ ! -x "$NELUA_LUA" ]; then
  NELUA_LUA=$(command -v lua)
fi

# check if a lua is present
if [ ! -x "$NELUA_LUA" ]; then
  echo "Lua not found!"
  exit 1
fi

# check if the compiler is present
if [ ! -f "$NELUA_LUALIB/nelua.lua" ]; then
  echo "Nelua compiler not found!"
  exit 1
fi

# determine nelua's lua package path
if [ "$OSTYPE" = "msys" ] || [ "$OSTYPE" = "cygwin" ]; then
  NELUA_PACKAGE_PATH=$(cygpath -w "$NELUA_LUALIB/")
  NELUA_NELUALUA=$(cygpath -w "$NELUA_LUALIB/nelua.lua")
  NELUA_LUA=$(cygpath "$NELUA_LUA")
else
  NELUA_PACKAGE_PATH="$NELUA_LUALIB/"
  NELUA_NELUALUA="$NELUA_LUALIB/nelua.lua"
fi

# execute nelua compiler
exec "$NELUA_LUA" -e "package.path=[[${NELUA_PACKAGE_PATH}?.lua;]]..package.path" "$NELUA_NELUALUA" "$@"
