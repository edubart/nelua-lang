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
  self.possible_returntypes = {}
  self.resolved_returntypes = {}
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
  if not symbol and node and config.strict then
    node:raisef("undeclarated symbol '%s'", name)
  end
  return symbol
end

function Scope:add_symbol(symbol)
  assert(class.is_a(symbol, Symbol), 'invalid symbol')
  local name = symbol.name
  local oldsymbol = self.symbols[name]
  if oldsymbol then
    symbol.node:assertraisef(not config.strict,
      "symbol '%s' shadows pre declarated symbol with the same name", name)

    -- symbol redeclaration, resolve old symbol type before replacing it
    oldsymbol:resolve_type()
    symbol.attr.shadowcount = (oldsymbol.attr.shadowcount or 1) + 1
  end
  self.symbols[name] = symbol
  return symbol
end

function Scope:resolve_symbols()
  local count = 0
  for _,symbol in pairs(self.symbols) do
    if symbol:resolve_type() then
      count = count + 1
    end
  end
  return count
end

function Scope:add_return_type(index, type)
  local returntypes = self.possible_returntypes[index]
  if not returntypes then
    returntypes = {}
    self.possible_returntypes[index] = returntypes
  elseif tabler.ifind(returntypes, type) then
    return
  end
  table.insert(returntypes, type)
end

function Scope:resolve_returntypes()
  local resolved_returntypes = {}
  for i,returntypes in pairs(self.possible_returntypes) do
    resolved_returntypes[i] = typedefs.find_common_type(returntypes) or typedefs.primtypes.any
  end
  self.resolved_returntypes = resolved_returntypes
  return resolved_returntypes
end

function Scope:resolve()
  local count = self:resolve_symbols()
  self:resolve_returntypes()
  return count
end

return Scope
