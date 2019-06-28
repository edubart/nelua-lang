local typedefs = require 'nelua.typedefs'
local types = require 'nelua.types'
local primtypes = typedefs.primtypes

local symdefs = {
  -- nelua only
  nilptr = primtypes.Nilptr,
  likely = types.FunctionType(nil, {primtypes.boolean}, {primtypes.boolean}),
  unlikely = types.FunctionType(nil, {primtypes.boolean}, {primtypes.boolean}),
  panic = primtypes.any, --types.FunctionType(nil, {primtypes.string}),

  -- lua
  assert = primtypes.any, --types.FunctionType(nil, {primtypes.boolean, primtypes.auto})
  error = primtypes.any, --types.FunctionType(nil, {primtypes.string}),
  warn = primtypes.any, --types.FunctionType(nil, {primtypes.string}),
  print = primtypes.any, --types.FunctionType(nil, {primtypes.varargs})
  type = types.FunctionType(nil, {primtypes.any}, {primtypes.string}),
  require = primtypes.any,

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
