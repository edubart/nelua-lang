local iters = require 'euluna.utils.iterators'
local tabler = require 'euluna.utils.tabler'
local class = require 'euluna.utils.class'

local Symbol = class()

function Symbol:_init(name, node, mut, type, holding_type)
  assert(mut and (node or name))
  self.name = name
  self.node = node
  self.mut = mut
  self.type = type
  self.holding_type = holding_type
  self.noderefs = {}
  self.possibletypes = {}
  self.codename = name
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

local function update_node(self, node)
  node.mut = self.mut
  node.type = self.type
  node.codename = self.codename
  if self.mut == 'const' then
    node.const = true
  end
end

function Symbol:link_node(node)
  update_node(self, node)
  if tabler.ifind(self.noderefs, node) then return end
  table.insert(self.noderefs, node)
end

function Symbol:set_codename(name)
  self.codename = name
  self:update_noderefs()
end

function Symbol:set_type(type)
  if rawequal(self.type, type) then return end
  self.type = type
  self:update_noderefs()
end

function Symbol:update_noderefs()
  for node in iters.values(self.noderefs) do
    update_node(self, node)
  end
end

return Symbol
