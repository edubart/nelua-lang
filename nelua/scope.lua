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
  self.checkpointstack = {}
  self:clear_symbols()
end

function Scope:fork(kind)
  return Scope(self, kind)
end

function Scope:is_topscope()
  return self.parent and self.parent.kind == 'root'
end

function Scope:clear_symbols()
  self.symbols = {}
  if self.parent then
    metamagic.setmetaindex(self.symbols, self.parent.symbols)
  end
  self.possible_returntypes = {}
  self.resolved_returntypes = {}
  self.has_unknown_return = nil
end

--[[
function Scope:is_onheap()
  local scope = self
  while scope do
    if scope.kind == 'function' then
      if scope.parent and scope.parent.kind == 'root' then
        return true
      else
        -- nested function
        return false
      end
    elseif scope.kind == 'root' then
      return true
    else
      assert(scope.kind == 'block')
    end
    scope = scope.parent
  end
  return false
end
]]

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

function Scope:make_checkpoint()
  local checkpoint = {
    symbols = tabler.copy(self.symbols),
    possible_returntypes = tabler.copy(self.possible_returntypes),
    resolved_returntypes = tabler.copy(self.resolved_returntypes),
    has_unknown_return = self.has_unknown_return
  }
  if self.parent then
    checkpoint.parentcheck = self.parent:make_checkpoint()
  end
  return checkpoint
end

function Scope:set_checkpoint(checkpoint)
  tabler.clear(self.symbols)
  tabler.clear(self.possible_returntypes)
  tabler.clear(self.resolved_returntypes)
  tabler.update(self.symbols, checkpoint.symbols)
  tabler.update(self.possible_returntypes, checkpoint.possible_returntypes)
  tabler.update(self.resolved_returntypes, checkpoint.resolved_returntypes)
  self.has_unknown_return = checkpoint.has_unknown_return
  if checkpoint.parentcheck then
    self.parent:set_checkpoint(checkpoint.parentcheck)
  end
end

function Scope:merge_checkpoint(checkpoint)
  tabler.update(self.symbols, checkpoint.symbols)
  tabler.update(self.possible_returntypes, checkpoint.possible_returntypes)
  tabler.update(self.resolved_returntypes, checkpoint.resolved_returntypes)
  self.has_unknown_return = checkpoint.has_unknown_return
  if checkpoint.parentcheck then
    self.parent:merge_checkpoint(checkpoint.parentcheck)
  end
end

function Scope:push_checkpoint(checkpoint)
  table.insert(self.checkpointstack, self:make_checkpoint())
  self:set_checkpoint(checkpoint)
end

function Scope:pop_checkpoint()
  local oldcheckpoint = table.remove(self.checkpointstack)
  assert(oldcheckpoint)
  self:merge_checkpoint(oldcheckpoint)
end

function Scope:add_symbol(symbol)
  local key = symbol.name or symbol
  local oldsymbol = self.symbols[key]
  if oldsymbol == symbol then
    return true
  end
  if oldsymbol and oldsymbol == self.context.state.inlazydef then
    -- symbol definition of a lazy function
    key = symbol
    oldsymbol = nil
    symbol.shadows = true
  end
  if oldsymbol then
    if self.context.pragmas.strict then
      return nil, stringer.pformat("symbol '%s' shadows pre declared symbol with the same name", key)
    end

    if rawget(self.symbols, key) == oldsymbol then
      self.symbols[oldsymbol] = oldsymbol
    end
    symbol.shadows = true
  end
  if self.context.pragmas.modname then
    symbol.modname = self.context.pragmas.modname
  end
  self.symbols[key] = symbol
  return true
end

function Scope:resolve_symbols()
  local count = 0
  local unknownlist = {}
  -- first resolve any symbol with known possible types
  for _,symbol in pairs(self.symbols) do
    if symbol.delayresolution then
      count = count + 1
      symbol.delayresolution = false
    end
    if symbol:resolve_type() then
      count = count + 1
    elseif count == 0 then
      table.insert(unknownlist, symbol)
    end
    if self.context.state.anyphase and symbol.type == nil then
      symbol.type = typedefs.primtypes.any
      symbol:clear_possible_types()
      count = count + 1
    end
  end
  -- if nothing was resolved previously then try resolve symbol with unknown possible types
  if not self.context.state.anyphase and count == 0 and #unknownlist > 0 then
    -- [disabled] try to infer the type only for the first unknown symbol
    --table.sort(unknownlist, function(a,b) return a.node.pos < b.node.pos end)
    for _,symbol in ipairs(unknownlist) do
      if symbol:resolve_type(true) then
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
