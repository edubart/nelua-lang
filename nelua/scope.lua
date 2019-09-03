local class = require 'nelua.utils.class'
local metamagic = require 'nelua.utils.metamagic'
local typedefs = require 'nelua.typedefs'
local symdefs = require 'nelua.symdefs'
local tabler = require 'nelua.utils.tabler'
local Symbol = require 'nelua.symbol'

local Scope = class()

function Scope:_init(parent, kind)
  self.kind = kind
  if kind == 'root' then
    self.context = parent
  else
    self.parent = parent
    self.context = parent.context
  end
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

function Scope:is_static_storage()
  if self:is_main() then return true end
  return self.staticstorage or (self.parent and self.parent.staticstorage)
end

function Scope:get_parent_of_kind(kind)
  local parent = self
  repeat
    parent = parent.parent
  until (not parent or parent.kind == kind)
  return parent
end

function Scope:get_symbol(name, node, required)
  local symbol = self.symbols[name]
  if not symbol and node then
    local symdef = symdefs[name]
    if symdef then
      symbol = Symbol(name, nil, symdef.type)
      tabler.update(symbol.attr, symdef)
      symbol.attr.const = true
      symbol.attr.builtin = true
      if symbol.attr.type:is_function() then
        symbol.attr.type.sideeffect = false
      end
    end
  end
  if not symbol and required and self.context.state.strict and not self.context.preprocessing then
    node:raisef("undeclared symbol '%s'", name)
  end
  return symbol
end

local function symbol_resolve_type(symbol)
  if symbol.attr.type or symbol.requnknown or symbol.resolvefail then
    return false
  end
  local type = typedefs.find_common_type(symbol.possibletypes)
  if type then
    symbol.attr.type = type
    return true
  else
    symbol.resolvefail = true
    return false
  end
end

function Scope:add_symbol(symbol)
  local name = symbol.name
  assert(name)
  local oldsymbol = self.symbols[name]
  if oldsymbol and (not oldsymbol.node or oldsymbol.node ~= symbol.node) then
    symbol.node:assertraisef(not self.context.state.strict,
      "symbol '%s' shadows pre declared symbol with the same name", name)

    if rawget(self.symbols, name) == oldsymbol then
      -- symbol redeclaration in the same scope, resolve old symbol type before replacing it
      symbol_resolve_type(oldsymbol)
    end

    symbol.attr.shadowed = true
  end
  if self.context.state.modname then
    symbol.attr.modname = self.context.state.modname
  end
  self.symbols[name] = symbol
  return symbol
end

function Scope:resolve_symbols()
  local count = 0
  local unknownlist = {}
  -- first resolve any symbol with known possible types
  for _,symbol in pairs(self.symbols) do
    if not symbol.hasunknown then
      if symbol_resolve_type(symbol) then
        count = count + 1
      end
    elseif count == 0 then
      table.insert(unknownlist, symbol)
    end
  end
  -- if nothing was resolved previously then try resolve symbol with unknown possible types
  if count == 0 and #unknownlist > 0 then
    -- [disabled] try to infer the type only for the first unknown symbol
    --table.sort(unknownlist, function(a,b) return a.node.pos < b.node.pos end)
    for _,symbol in ipairs(unknownlist) do
      if symbol_resolve_type(symbol) then
        count = count + 1
        --break
      end
    end
  end
  return count
end

function Scope:add_return_type(index, type)
  local returntypes = self.possible_returntypes[index]
  if not returntypes then
    returntypes = {}
    self.possible_returntypes[index] = returntypes
  elseif type and tabler.ifind(returntypes, type) then
    return
  end
  if type then
    table.insert(returntypes, type)
  else
    self.has_unknown_return = true
  end
end

function Scope:resolve_returntypes()
  local resolved_returntypes = {}
  for i,returntypes in pairs(self.possible_returntypes) do
    resolved_returntypes[i] = typedefs.find_common_type(returntypes) or typedefs.primtypes.any
  end
  resolved_returntypes.has_unknown = self.has_unknown_return
  self.resolved_returntypes = resolved_returntypes
  return resolved_returntypes
end

function Scope:resolve()
  local count = self:resolve_symbols()
  self:resolve_returntypes()
  return count
end

return Scope
