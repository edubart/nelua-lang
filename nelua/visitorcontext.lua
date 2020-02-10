local class = require 'nelua.utils.class'
local tabler = require 'nelua.utils.tabler'

local VisitorContext = class()

local function traverse_node(self, node, ...)
  local visitor_func = self.visitors[node.tag] or self.visitors.default_visitor
  if not visitor_func then --luacov:disable
    node:errorf("visitor for AST node '%s' does not exist", node.tag)
  end --luacov:enable
  table.insert(self.visiting_nodes, node) -- push node
  local ret = visitor_func(self, node, ...)
  table.remove(self.visiting_nodes) -- pop node
  return ret
end
VisitorContext.traverse_node = traverse_node

local function traverse_nodes(self, nodes, ...)
  for i=1,#nodes do
    traverse_node(self, nodes[i], ...)
  end
end
VisitorContext.traverse_nodes = traverse_nodes

local function traverser_default_visitor(self, node, ...)
  for i=1,node.nargs or #node do
    local arg = node[i]
    if arg and type(arg) == 'table' then
      if arg._astnode then
        traverse_node(self, arg, ...)
      else
        traverser_default_visitor(self, arg, ...)
      end
    end
  end
end

function VisitorContext:_init(visitors)
  self:set_visitors(visitors)
  self.visiting_nodes = {}
  self.state = {}
  self.statestack = {}
end

function VisitorContext:set_visitors(visitors)
  self.visitors = visitors
  if visitors.default_visitor == nil then
    visitors.default_visitor = traverser_default_visitor
  end
end

function VisitorContext:get_parent_node()
  return self.visiting_nodes[#self.visiting_nodes - 1]
end

function VisitorContext:get_current_node()
  return self.visiting_nodes[#self.visiting_nodes]
end

function VisitorContext:push_state()
  table.insert(self.statestack, self.state)
  local newstate = tabler.copy(self.state)
  self.state = newstate
  return newstate
end

function VisitorContext:pop_state()
  self.state = table.remove(self.statestack)
  assert(self.state)
end

return VisitorContext
