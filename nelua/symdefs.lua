--[[
This module contains definition for all builtins symbols.
These symbols are handled internally by the compiler.
]]

local typedefs = require 'nelua.typedefs'
local tabler = require 'nelua.utils.tabler'
local types = require 'nelua.types'
local Symbol = require 'nelua.symbol'
local Attr = require 'nelua.attr'
local version = require 'nelua.version'
local primtypes = typedefs.primtypes

-- List of builtin symbols.
local symdefs = {}

-- Defines a new symbol.
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
end

-- Defines a new function symbol.
local function define_function_symbol(name, argattrs, rettypes, attrs)
  local type = types.FunctionType(argattrs, rettypes)
  type:suggest_nickname(name)
  type.sideeffect = (attrs and attrs.sideeffect) and true or false
  type.symbol = define_symbol(name, type, attrs)
end

-- Defines all builtins symbols.
define_function_symbol('likely', {Attr{name='cond', type=primtypes.boolean}}, {primtypes.boolean})
define_function_symbol('unlikely', {Attr{name='cond', type=primtypes.boolean}}, {primtypes.boolean})
define_function_symbol('panic', {Attr{name='message', type=primtypes.string}}, {}, {noreturn=true, sideeffect=true})
define_function_symbol('error', {Attr{name='message', type=primtypes.string}}, {}, {noreturn=true, sideeffect=true})
define_function_symbol('warn', {Attr{name='message', type=primtypes.string}}, {}, {sideeffect=true})
define_function_symbol('require', {Attr{name='modname', type=primtypes.string}}, {})
define_symbol('print')
define_symbol('check')
define_symbol('assert')
define_symbol('nilptr', primtypes.nilptr)
define_symbol('_G', primtypes.table)
define_symbol('_VERSION', primtypes.string, {comptime=true, value=version.NELUA_VERSION})

return symdefs
