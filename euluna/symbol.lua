local iters = require 'euluna.utils.iterators'
local tabler = require 'euluna.utils.tabler'
local class = require 'euluna.utils.class'

local Symbol = class()

function Symbol:_init(name, node, type, holding_type)
  self.name = name
  self.node = node
  self.type = type
  self.holding_type = holding_type
  self.noderefs = {}
  self.possibletypes = {}
end

function Symbol:add_possible_type(type, required)
  if self.type then return end
  if not type and required then
    self.has_unknown_type = true
    return
  end
  if tabler.ifind(self.possibletypes, type) then return end
  table.insert(self.possibletypes, type)
end

function Symbol:link_node_type(node)
  if self.type then
    node.type = self.type
  else
    if tabler.ifind(self.noderefs, node) then return end
    table.insert(self.noderefs, node)
  end
end

function Symbol:update_noderefs()
  for node in iters.values(self.noderefs) do
    node.type = self.type
  end
end

function Symbol:set_type(type)
  self.type = type
  self:update_noderefs()
end

return Symbol
