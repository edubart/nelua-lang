local class = require 'nelua.utils.class'
local metamagic = require 'nelua.utils.metamagic'
local types = require 'nelua.types'
local typedefs = require 'nelua.typedefs'
local symdefs = require 'nelua.symdefs'
local tabler = require 'nelua.utils.tabler'

local Scope = class()

function Scope:_init(parent, kind, node)
  self.kind = kind
  self.node = node
  if kind == 'root' then
    self.context = parent
  else
    self.parent = parent
    self.context = parent.context
    table.insert(parent.children, self)
  end
  self.children = {}
  self.checkpointstack = {}
  self:clear_symbols()
end

function Scope:fork(kind, node)
  return Scope(self, kind, node)
end

function Scope:is_topscope()
  return self.parent and self.parent.kind == 'root'
end

function Scope:clear_symbols()
  self.symbols = {}
  if self.parent then
    metamagic.setmetaindex(self.symbols, self.parent.symbols)
  else
    metamagic.setmetaindex(self.symbols, function(symbols, key)
      local symbol = symdefs[key]
      if symbol then
        symbol = symbol:clone()
        symbols[key] = symbol
        return symbol
      end
    end)
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
  return self.symbols[name]
end

function Scope:make_checkpoint()
  local checkpoint = {
    symbols = tabler.copy(self.symbols),
    possible_returntypes = tabler.copy(self.possible_returntypes),
    resolved_returntypes = tabler.copy(self.resolved_returntypes),
    has_unknown_return = self.has_unknown_return
  }
  if self.parent and self.parent.kind ~= 'root' then
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
  local key
  if symbol.annonymous then
    key = symbol
  else
    key = symbol.name
  end
  local oldsymbol = self.symbols[key]
  if oldsymbol == symbol then
    return true
  end
  if oldsymbol then
    if oldsymbol == self.context.state.inlazydef then
      -- symbol definition of a lazy function
      key = symbol
      symbol.shadows = true
    else
      if rawget(self.symbols, key) == oldsymbol then
        self.symbols[oldsymbol] = oldsymbol
      end
      symbol.shadows = true
    end
  end
  self.symbols[key] = symbol
  table.insert(self.symbols, symbol)
  return true
end

function Scope:delay_resolution()
  self.delay = true
end

function Scope:resolve_symbols()
  local count = 0
  local unknownlist = {}
  -- first resolve any symbol with known possible types
  for i=1,#self.symbols do
    local symbol = self.symbols[i]
    if symbol:resolve_type() then
      count = count + 1
    elseif count == 0 and symbol.type == nil then
      table.insert(unknownlist, symbol)
    end
  end
  -- if nothing was resolved previously then try resolve symbol with unknown possible types
  if count == 0 and #unknownlist > 0 and not self.context.rootscope.delay then
    -- [disabled] try to infer the type only for the first unknown symbol
    --table.sort(unknownlist, function(a,b) return a.node.pos < b.node.pos end)
    for i=1,#unknownlist do
      local symbol = unknownlist[i]
      if symbol:resolve_type(true) then
        count = count + 1
      elseif self.context.state.anyphase then
        symbol.type = typedefs.primtypes.any
        symbol:clear_possible_types()
        count = count + 1
      end
      --break
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
  if self.delay then
    count = count + 1
    self.delay = nil
  end
  return count
end

return Scope
