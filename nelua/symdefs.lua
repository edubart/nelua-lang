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
define_function('panic', {Attr{name='message', type=primtypes.stringview}}, {}, {noreturn=true, sideeffect=true})
define_symbol('check')
define_symbol('nilptr', primtypes.nilptr)

-- lua
define_function('error', {Attr{name='message', type=primtypes.stringview}}, {}, {noreturn=true, sideeffect=true})
define_function('warn', {Attr{name='message', type=primtypes.stringview}}, {}, {sideeffect=true})
define_function('type', {Attr{name='value', type=primtypes.any}}, {primtypes.stringview})
define_symbol('assert')
define_symbol('print')
define_symbol('require')
define_symbol('_G', primtypes.table)
define_symbol('_VERSION', primtypes.stringview, {comptime=true, value=version.NELUA_VERSION})

return symdefs
