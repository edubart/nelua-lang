local tabler = require 'nelua.utils.tabler'
local class = require 'nelua.utils.class'
local sstream = require 'nelua.utils.sstream'
local types = require 'nelua.types'
local Attr = require 'nelua.attr'
local Symbol = class(Attr)

Symbol._symbol = true

function Symbol:init(name, node)
  if node then
    self.node = node
  end
  if name then
    self.name = name
    self.codename = name
  end
  self:clear_possible_types()
end

function Symbol.promote_attr(attr, name, node)
  local self = setmetatable(attr, Symbol)
  self:init(name, node)
  return self
end

function Symbol:clear_possible_types()
  self.possibletypes = nil
  self.requnknown = nil
  self.hasunknown = nil
  self.resolvefail = nil
end

function Symbol:add_possible_type(type, required)
  if not self.possibletypes then
    self.possibletypes = {}
  end
  if self.type then return end
  if not type then
    if required then
      self.requnknown = true
    else
      self.hasunknown = true
    end
    return
  end
  if tabler.ifind(self.possibletypes, type) then return end
  table.insert(self.possibletypes, type)
end

function Symbol:resolve_type()
  if self.type or self.requnknown or self.resolvefail then
    return false
  end
  local resolvetype = types.find_common_type(self.possibletypes)
  if resolvetype then
    self.type = resolvetype
    return true
  else
    self.resolvefail = true
    return false
  end
end

function Symbol:link_node(node)
  if node.attr == self then
    return
  end
  if node.attr:is_empty() then
    node.attr = self
  else
    node.attr = self:merge(node.attr)
  end
end

function Symbol:__tostring()
  local ss = sstream(self.name)
  if self.type then
    ss:add(': ', self.type)
  end
  if self.comptime then
    ss:add(' <comptime>')
  elseif self.const then
    ss:add(' <const>')
  end
  if self.value then
    ss:add(' = ', self.value)
  end
  return ss:tostring()
end

return Symbol
