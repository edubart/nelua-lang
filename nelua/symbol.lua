local tabler = require 'nelua.utils.tabler'
local class = require 'nelua.utils.class'
local sstream = require 'nelua.utils.sstream'
local traits = require 'nelua.utils.traits'
local console = require 'nelua.utils.console'
local types = require 'nelua.types'
local Attr = require 'nelua.attr'
local Symbol = class(Attr)
local config = require 'nelua.configer'.get()

Symbol._symbol = true

function Symbol:init(name, node)
  self.node = node
  self.name = name
end

function Symbol.promote_attr(attr, name, node)
  attr.node = node
  attr.name = name
  return setmetatable(attr, Symbol)
end

function Symbol:clear_possible_types()
  self.possibletypes = nil
  self.unknownrefs = nil
end

function Symbol:add_possible_type(type, refnode)
  if self.type then return end
  local unknownrefs = self.unknownrefs
  if not type then
    assert(refnode)
    if not unknownrefs then
      self.unknownrefs = {[refnode] = true}
    else
      unknownrefs[refnode] = true
    end
    return
  elseif unknownrefs and unknownrefs[refnode] then
    unknownrefs[refnode] = nil
    if #unknownrefs == 0 then
      self.unknownrefs = nil
    end
  end
  if not self.possibletypes then
    self.possibletypes = {[1] = type}
  elseif not tabler.ifind(self.possibletypes, type) then
    table.insert(self.possibletypes, type)
  else
    return
  end
end

function Symbol:resolve_type(force)
  if self.type or (not force and self.unknownrefs) then
    return false
  end
  local resolvetype = types.find_common_type(self.possibletypes)
  if resolvetype then
    self.type = resolvetype
    self:clear_possible_types()
  elseif traits.is_type(force) then
    self.type = force
  else
    return false
  end
  if config.debug_resolve then
    console.info(self.node:format_message('info', "symbol '%s' resolved to type '%s'", self.name, self.type))
  end
  return true
end

function Symbol:link_node(node)
  if node.attr ~= self then
    if next(node.attr) == nil then
      node.attr = self
    else
      node.attr = self:merge(node.attr)
    end
  end
end

function Symbol:__tostring()
  local ss = sstream(self.name or '<annonymous>')
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
