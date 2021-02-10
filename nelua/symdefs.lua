local typedefs = require 'nelua.typedefs'
local tabler = require 'nelua.utils.tabler'
local types = require 'nelua.types'
local Symbol = require 'nelua.symbol'
local Attr = require 'nelua.attr'
local primtypes = typedefs.primtypes

local symdefs = {}

local function define_function(name, argtypes, rettypes, attrs)
  local args = tabler.imap(argtypes, function(argtype) return Attr{type = argtype} end)
  local type = types.FunctionType(args, rettypes)
  type:suggest_nickname(name)
  type.sideeffect = false
  local symbol = Symbol{
    name = name,
    codename = 'nelua_' .. name,
    type = type,
    used = true,
    const = true,
    builtin = true,
    staticstorage = true
  }
  if attrs then
    tabler.update(symbol, attrs)
  end
  type.symbol = symbol
  symdefs[name] = symbol
end

local function define_const(name, type, value)
  local symbol = Symbol{
    name = name,
    codename = 'nelua_' .. name,
    type = type,
    const = value == nil,
    value = value,
    builtin = true,
    staticstorage = true
  }
  symdefs[name] = symbol
end

-- nelua only
define_function('likely', {primtypes.boolean}, {primtypes.boolean})
define_function('unlikely', {primtypes.boolean}, {primtypes.boolean})
define_function('check', primtypes.any)
define_function('panic', {primtypes.stringview}, {}, {noreturn=true})
define_const('nilptr', primtypes.nilptr)

-- lua
define_const('assert', primtypes.any)
define_function('error', {primtypes.stringview}, {}, {noreturn=true})
define_function('warn', {primtypes.stringview}, {})
define_const('print', primtypes.any)
define_function('type', {primtypes.any}, {primtypes.stringview})
define_const('require', primtypes.any)
define_const('_G', primtypes.table)

return symdefs
