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
NELUA_LUA=$SCRIPT_DIR/nelua-lua

# execute nelua compiler
exec "$SCRIPT_DIR/nelua-lua" -l nelua -- "$@"
