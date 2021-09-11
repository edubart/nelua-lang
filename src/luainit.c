#include "luainit.h"

#include <lua.h>
#include <lauxlib.h>
#include <stdio.h>

/*
** Runs a builtin initialization script that adjusts 'package.path',
** so we can find Nelua lua files
*/
LUALIB_API void lua_luainit(lua_State *L) {
  int res = luaL_loadbufferx(L, (char*)src_luainit_lua, src_luainit_lua_len, "@luainit.lua", "t");
  if (res == LUA_OK) {
    lua_call(L, 0, 0);
  } else {
    lua_writestringerror("%s", lua_tostring(L, -1));
    lua_pop(L, 1);
  }
}
