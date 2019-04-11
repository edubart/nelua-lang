local class = require 'euluna.utils.class'
local traits = require 'euluna.utils.traits'
local iters = require 'euluna.utils.iterators'
local Scope = require 'euluna.scope'

local Context = class()

local function traverser_default_visitor(self, node, ...)
  local nargs = traits.is_astnode(node) and node.nargs or #node
  for _,arg in iters.inpairs(node, nargs) do
    if traits.is_astnode(arg) then
      self:traverse(arg, ...)
    elseif traits.is_table(arg) then
      traverser_default_visitor(self, arg, ...)
    end
  end
end

function Context:_init(visitors, default_visitor)
  self.scope = Scope()
  self.visitors = visitors
  if default_visitor == true then
    self.default_visitor = traverser_default_visitor
  end
  self.nodes = {}
  self.builtins = {}
end

function Context:push_scope(kind)
  local scope = self.scope:fork(kind)
  self.scope = scope
  return scope
end

function Context:pop_scope()
  self.scope = self.scope.parent
end

function Context:push_node(node)
  table.insert(self.nodes, node)
end

function Context:pop_node()
  table.remove(self.nodes)
end

function Context:get_parent_node()
  return self.nodes[#self.nodes - 1]
end

function Context:iterate_parent_nodes()
  local i = #self.nodes
  return function(nodes)
    i = i - 1
    if i <= 0 then return nil end
    return nodes[i]
  end, self.nodes
end

function Context:get_parent_node_if(f)
  for node in self:iterate_parent_nodes() do
    if f(node) then return node end
  end
end

function Context:traverse_nodes(nodes, ...)
  assert(not traits.is_astnode(nodes) and traits.is_table(nodes), "must traverse a list")
  for _,node in ipairs(nodes) do
    self:traverse(node, ...)
  end
end

function Context:traverse_node(node, ...)
  assert(traits.is_astnode(node), "trying to traverse a non node value")
  local visitor_func = self.visitors[node.tag] or self.default_visitor
  node:assertf(visitor_func, "visitor for AST node '%s' does not exist", node.tag)
  self:push_node(node)
  local ret = visitor_func(self, node, ...)
  self:pop_node()
  return ret
end

function Context:traverse(node, ...)
  if traits.is_astnode(node) then
    return self:traverse_node(node, ...)
  end
  return self:traverse_nodes(node, ...)
end

function Context:add_runtime_builtin(name)
  if not name then return end
  self.builtins[name] = true
end

return Context
