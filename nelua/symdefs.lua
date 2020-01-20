local typedefs = require 'nelua.typedefs'
local types = require 'nelua.types'
local Symbol = require 'nelua.symbol'
local primtypes = typedefs.primtypes

local symdefs = {}

local function define_function(name, args, rets)
  local type = types.FunctionType(nil, args, rets)
  type:suggest_nick(name)
  type.sideeffect = false
  local symbol = Symbol{
    name = name,
    codename = name,
    type = type,
    const = true,
    builtin = true,
  }
  symdefs[name] = symbol
end

local function define_const(name, type, value)
  local symbol = Symbol{
    name = name,
    codename = name,
    type = type,
    const = value == nil,
    value = value,
    builtin = true,
  }
  symdefs[name] = symbol
end

-- nelua only
define_function('likely', {primtypes.boolean}, {primtypes.boolean})
define_function('unlikely', {primtypes.boolean}, {primtypes.boolean})
define_const('panic', primtypes.any)
define_const('nilptr', primtypes.nilptr)
define_const('C', primtypes.type, types.RecordType(nil, {}))

-- lua
define_const('assert', primtypes.any)
define_const('error', primtypes.any)
define_const('warn', primtypes.any)
define_const('print', primtypes.any)
define_function('type', {primtypes.any}, {primtypes.string})
define_const('require', primtypes.any)

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
