local class = require 'euluna.utils.class'
local metamagic = require 'euluna.utils.metamagic'
local typedefs = require 'euluna.typedefs'
local tabler = require 'euluna.utils.tabler'
local config = require 'euluna.configer'.get()

local Scope = class()

function Scope:_init(parent, kind)
  self.kind = kind
  self.parent = parent
  self.symbols = {}
  self.returnstypes = {}
  if parent then
    metamagic.setmetaindex(self.symbols, parent.symbols)
  end
end

function Scope:fork(kind)
  return Scope(self, kind)
end

function Scope:is_top()
  return not self.parent
end

function Scope:is_main()
  return self.parent and not self.parent.parent
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
  local name = symbol.name
  if self.symbols[name] and config.strict then
    symbol.node:raisef("symbol '%s' shadows pre declarated symbol with the same name", name)
  end
  self.symbols[name] = symbol
  return symbol
end

local function resolve_symbol_type(symbol)
  if symbol.type then
    return false
  end
  if symbol.has_unknown_type then return false end
  local type = typedefs.find_common_type(symbol.possibletypes)
  symbol:set_type(type)
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
  local returntypes = self.returnstypes[index]
  if not returntypes then
    returntypes = {}
    self.returnstypes[index] = returntypes
  elseif tabler.find(returntypes, type) then
    return
  end
  table.insert(returntypes, type)
end

function Scope:resolve_returntypes()
  local resolved_types = {}
  for i,returntypes in pairs(self.returnstypes) do
    resolved_types[i] = typedefs.find_common_type(returntypes)
  end
  return resolved_types
end

return Scope
