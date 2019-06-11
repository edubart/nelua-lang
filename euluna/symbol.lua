local tabler = require 'euluna.utils.tabler'
local class = require 'euluna.utils.class'
local sstream = require 'euluna.utils.sstream'
local Symbol = class()

function Symbol:_init(name, node, mut, type)
  assert(name)
  local attr = node and node.attr or {}
  self.name = name
  self.node = node
  self.possibletypes = {}
  self.attr = attr
  if mut == 'const' then
    attr.const = true
  end
  attr.name = name
  attr.codename = name
  attr.mut = mut
  attr.type = type
end

function Symbol:add_possible_type(type, required)
  if self.attr.type then return end
  if not type and required then
    self.has_unknown_type = true
    return
  end
  if tabler.ifind(self.possibletypes, type) then return end
  table.insert(self.possibletypes, type)
end

function Symbol:link_node(node)
  if node.attr == self.attr then
    return
  end
  assert(next(node.attr) == nil, 'cannot link to a node with attributes')
  node.attr = self.attr
end

function Symbol:__tostring()
  local ss = sstream('symbol<')
  ss:add(self.attr.mut, ' ', self.name)
  if self.attr.type then
    ss:add(': ', tostring(self.attr.type))
  end
  if self.attr.value then
    ss:add(' = ', tostring(self.attr.value))
  end
  ss:add('>')
  return ss:tostring()
end

return Symbol
