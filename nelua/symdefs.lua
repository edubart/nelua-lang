local typedefs = require 'nelua.typedefs'
local types = require 'nelua.types'
local primtypes = typedefs.primtypes

local symdefs = {
  -- nelua only
  nilptr = {type=primtypes.Nilptr},
  likely = {type=types.FunctionType(nil, {primtypes.boolean}, {primtypes.boolean})},
  unlikely = {type=types.FunctionType(nil, {primtypes.boolean}, {primtypes.boolean})},
  panic = {type=primtypes.any}, --types.FunctionType(nil, {primtypes.string})
  C = {type = primtypes.type, holdedtype=types.RecordType(nil, {})},

  -- lua
  assert = {type=primtypes.any}, --types.FunctionType(nil, {primtypes.boolean, primtypes.auto})
  error = {type=primtypes.any}, --types.FunctionType(nil, {primtypes.string}),
  warn = {type=primtypes.any}, --types.FunctionType(nil, {primtypes.string}),
  print = {type=primtypes.any}, --types.FunctionType(nil, {primtypes.varargs})
  type = {type=types.FunctionType(nil, {primtypes.any}, {primtypes.string})},
  require = {type=primtypes.any},

  --dofile
  --select
  --tostring
  --tonumber
  --_VERSION

  --_G
  --ipairs
  --next
  --pairs
  --load
  --loadfile
  --pcall
  --xpcall
  --rawequal
  --rawget
  --rawlen
  --rawset
  --setmetatable
  --getmetatable
  --collectgarbage
}

--[[
coroutine
coroutine.close
coroutine.create
coroutine.isyieldable
coroutine.resume
coroutine.running
coroutine.status
coroutine.wrap
coroutine.yield
debug
debug.debug
debug.gethook
debug.getinfo
debug.getlocal
debug.getmetatable
debug.getregistry
debug.getupvalue
debug.getuservalue
debug.sethook
debug.setlocal
debug.setmetatable
debug.setupvalue
debug.setuservalue
debug.traceback
debug.upvalueid
debug.upvaluejoin
package
package.config
package.cpath
package.loaded
package.loadlib
package.path
package.preload
package.searchers
package.searchpath
]]

return symdefs
