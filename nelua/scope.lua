local class = require 'nelua.utils.class'
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
  self:clear_symbols()
end

function Scope:fork(kind, node)
  return Scope(self, kind, node)
end

function Scope:is_topscope()
  return self.parent and self.parent.kind == 'root'
end

local default_symbols_mt = {
  __index =  function(symbols, key)
    -- return predefined symbol definition if nothing is found
    local symbol = symdefs[key]
    if symbol then
      symbol = symbol:clone()
      symbols[key] = symbol
      return symbol
    end
  end
}

function Scope:clear_symbols()
  if self.parent then
    self.symbols = setmetatable({}, {__index = self.parent.symbols})
  else
    self.symbols = setmetatable({}, default_symbols_mt)
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
  if not self.checkpointstack then
    self.checkpointstack = {}
  end
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
  if not symbol.annonymous then
    key = symbol.name
  else
    key = symbol
  end
  local symbols = self.symbols
  local oldsymbol = symbols[key]
  if oldsymbol then
    if oldsymbol == symbol then
      return true
    end
    -- shadowing a symbol with the same name
    if oldsymbol == self.context.state.inlazydef then
      -- symbol definition of a lazy function
      key = symbol
    else
      -- shadowing an usual variable
      if rawget(symbols, key) == oldsymbol then
        -- this symbol will be overridden but we still need to list it for the resolution
        symbols[oldsymbol] = oldsymbol
      end
      symbol.shadows = true
    end
  end
  symbols[key] = symbol
  symbols[#symbols+1] = symbol
  return true
end

function Scope:delay_resolution()
  self.delay = true
end

function Scope:resolve_symbols()
  local count = 0
  local unknownlist = {}
  -- first resolve any symbol with known possible types
  local symbols = self.symbols
  for i=1,#symbols do
    local symbol = symbols[i]
    if symbol.type == nil then
      if symbol:resolve_type() then
        count = count + 1
      elseif count == 0 then
        unknownlist[#unknownlist+1] = symbol
      end
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
  if not type then
    self.has_unknown_return = true
  end
  local returntypes = self.possible_returntypes[index]
  if not returntypes then
    self.possible_returntypes[index] = {[1] = type}
  elseif type and not tabler.ifind(returntypes, type) then
    returntypes[#returntypes+1] = type
  end
end

function Scope:resolve_returntypes()
  if #self.possible_returntypes == 0 then return end
  local resolved_returntypes = self.resolved_returntypes
  resolved_returntypes.has_unknown = self.has_unknown_return
  for i,returntypes in ipairs(self.possible_returntypes) do
    resolved_returntypes[i] = types.find_common_type(returntypes) or typedefs.primtypes.any
  end
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
