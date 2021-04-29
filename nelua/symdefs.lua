local typedefs = require 'nelua.typedefs'
local tabler = require 'nelua.utils.tabler'
local types = require 'nelua.types'
local Symbol = require 'nelua.symbol'
local Attr = require 'nelua.attr'
local version = require 'nelua.version'
local primtypes = typedefs.primtypes

local symdefs = {}

local function define_symbol(name, type, attrs)
  local symbol = Symbol{
    name = name,
    codename = 'nelua_' .. name,
    type = type or primtypes.any,
    used = true,
    const = true,
    builtin = true,
    staticstorage = true
  }
  if attrs then
    tabler.update(symbol, attrs)
  end
  symdefs[name] = symbol
  return symbol
end

local function define_function(name, argattrs, rettypes, attrs)
  local type = types.FunctionType(argattrs, rettypes)
  type:suggest_nickname(name)
  type.sideeffect = (attrs and attrs.sideeffect) and true or false
  local symbol = define_symbol(name, type, attrs)
  type.symbol = symbol
  return symbol
end

-- nelua only
define_function('likely', {Attr{name='cond', type=primtypes.boolean}}, {primtypes.boolean})
define_function('unlikely', {Attr{name='cond', type=primtypes.boolean}}, {primtypes.boolean})
define_function('panic', {Attr{name='message', type=primtypes.string}}, {}, {noreturn=true, sideeffect=true})
define_symbol('check')
define_symbol('nilptr', primtypes.nilptr)

-- lua
define_function('error', {Attr{name='message', type=primtypes.string}}, {}, {noreturn=true, sideeffect=true})
define_function('warn', {Attr{name='message', type=primtypes.string}}, {}, {sideeffect=true})
define_function('require', {Attr{name='modname', type=primtypes.string}}, {})
define_symbol('print')
define_symbol('assert')
define_symbol('_G', primtypes.table)
define_symbol('_VERSION', primtypes.string, {comptime=true, value=version.NELUA_VERSION})

return symdefs
