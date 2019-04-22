local tabler = require 'euluna.utils.tabler'
local class = require 'euluna.utils.class'
local metamagic = require 'euluna.utils.metamagic'
local Symbol = class()

function Symbol:_init(name, node, mut, type, holding_type)
  assert(mut and (node or name))
  self.name = name
  self.node = node
  self.possibletypes = {}
  local attr
  if node then
    -- try to get attr from a previus symbol associated with the ast
    attr = metamagic.getmetaindex(node.attr)
    if not attr then
      attr = {}
      metamagic.setmetaindex(node.attr, attr)
    end
  else
    attr = {}
  end
  self.attr = attr
  if mut == 'const' then
    attr.const = true
  end
  attr.name = name
  attr.mut = mut
  attr.type = type
  attr.codename = name
  attr.holding_type = holding_type
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
  assert(self.node)
  metamagic.setmetaindex(node.attr, self.attr)
end

return Symbol
