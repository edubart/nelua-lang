local class = require 'nelua.utils.class'
local metamagic = require 'nelua.utils.metamagic'
local types = require 'nelua.types'
local typedefs = require 'nelua.typedefs'
local symdefs = require 'nelua.symdefs'
local tabler = require 'nelua.utils.tabler'
local stringer = require 'nelua.utils.stringer'

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

function Scope:get_symbol(name)
  local symbol = self.symbols[name]
  if not symbol then
    symbol = symdefs[name]
    if symbol then
      symbol = symbol:clone()
    end
  end
  return symbol
end

function Scope:add_symbol(symbol)
  local name = symbol.name
  assert(name)
  local oldsymbol = self.symbols[name]
  if oldsymbol and (not oldsymbol.node or oldsymbol.node ~= symbol.node) then
    if self.context.strict then
      return nil, stringer.pformat("symbol '%s' shadows pre declared symbol with the same name", name)
    end

    if rawget(self.symbols, name) == oldsymbol then
      -- symbol redeclaration in the same scope, resolve old symbol type before replacing it
      oldsymbol:resolve_type(self.context.anyinference)
    end

    symbol.shadowed = true
  end
  if self.context.modname then
    symbol.modname = self.context.modname
  end
  self.symbols[name] = symbol
  return true
end

function Scope:resolve_symbols()
  local count = 0
  local unknownlist = {}
  local anyfallback = self.context.anyinference
  -- first resolve any symbol with known possible types
  for _,symbol in pairs(self.symbols) do
    if not symbol.hasunknown then
      if symbol:resolve_type() then
        count = count + 1
      end
    elseif count == 0 then
      table.insert(unknownlist, symbol)
    end
    if anyfallback and symbol.type == nil then
      symbol.type = typedefs.primtypes.any
      symbol:clear_possible_types()
      count = count + 1
    end
  end
  -- if nothing was resolved previously then try resolve symbol with unknown possible types
  if not anyfallback and count == 0 and #unknownlist > 0 then
    -- [disabled] try to infer the type only for the first unknown symbol
    --table.sort(unknownlist, function(a,b) return a.node.pos < b.node.pos end)
    for _,symbol in ipairs(unknownlist) do
      if symbol:resolve_type() then
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
    resolved_returntypes[i] = types.find_common_type(returntypes) or typedefs.primtypes.any
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
