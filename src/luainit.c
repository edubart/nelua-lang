#include "luainit.h"

#include <lua.h>
#include <lauxlib.h>
#include <stdio.h>

/*
** Runs a builtin initialization script that adjusts 'package.path',
** so we can find Nelua lua files
*/
LUALIB_API void lua_luainit(lua_State *L) {
  int res = luaL_loadbufferx(L, src_luainit_luabc, src_luainit_luabc_len, "@luainit.lua", "b");
  if (res == LUA_OK) {
    lua_call(L, 0, 0);
  } else {
    lua_writestringerror("%s", lua_tostring(L, -1));
    lua_pop(L, 1);
  }
}
