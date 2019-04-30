local class = require 'euluna.utils.class'
local metamagic = require 'euluna.utils.metamagic'
local typedefs = require 'euluna.typedefs'
local tabler = require 'euluna.utils.tabler'
local config = require 'euluna.configer'.get()
local Symbol = require 'euluna.symbol'

local Scope = class()

function Scope:_init(parent, kind)
  self.kind = kind
  self.parent = parent
  self.symbols = {}
  self.possible_return_types = {}
  self.resolved_return_types = {}
  if parent then
    metamagic.setmetaindex(self.symbols, parent.symbols)
  end
end

function Scope:fork(kind)
  return Scope(self, kind)
end

function Scope:is_main()
  return self.main or (self.parent and self.parent.main)
end

function Scope:get_parent_of_kind(kind)
  local parent = self
  repeat
    parent = parent.parent
  until (not parent or parent.kind == kind)
  return parent
end

function Scope:get_symbol(name, node)
  local symbol = self.symbols[name]
  if not symbol and config.strict then
    node:raisef("undeclarated symbol '%s'", name)
  end
  return symbol
end

function Scope:add_symbol(symbol)
  assert(class.is_a(symbol, Symbol), 'invalid symbol')
  local name = symbol.name
  if self.symbols[name] and config.strict then
    symbol.node:raisef("symbol '%s' shadows pre declarated symbol with the same name", name)
  end
  self.symbols[name] = symbol
  return symbol
end

local function resolve_symbol_type(symbol)
  if symbol.attr.type then
    return false
  end
  if symbol.has_unknown_type then return false end
  local type = typedefs.find_common_type(symbol.possibletypes)
  symbol.attr.type = type
  return true
end

function Scope:resolve_symbols_types()
  local count = 0
  for _,symbol in pairs(self.symbols) do
    if resolve_symbol_type(symbol) then
      count = count + 1
    end
  end
  return count
end

function Scope:add_return_type(index, type)
  local returntypes = self.possible_return_types[index]
  if not returntypes then
    returntypes = {}
    self.possible_return_types[index] = returntypes
  elseif tabler.ifind(returntypes, type) then
    return
  end
  table.insert(returntypes, type)
end

function Scope:resolve_returntypes()
  local resolved_return_types = {}
  for i,returntypes in pairs(self.possible_return_types) do
    resolved_return_types[i] = typedefs.find_common_type(returntypes) or typedefs.primtypes.any
  end
  self.resolved_return_types = resolved_return_types
  return resolved_return_types
end

return Scope
