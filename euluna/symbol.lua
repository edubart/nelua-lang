local tabler = require 'euluna.utils.tabler'
local class = require 'euluna.utils.class'
local Symbol = class()

function Symbol:_init(name, node, mut, type)
  assert(name and node)
  local attr = node.attr
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

return Symbol
