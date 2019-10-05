local class = require 'nelua.utils.class'
local Scope = require 'nelua.scope'

local Context = class()

local function traverse_node(self, node, ...)
  local visitor_func = self.visitors[node.tag] or self.default_visitor
  if not visitor_func then --luacov:disable
    node:errorf("visitor for AST node '%s' does not exist", node.tag)
  end --luacov:enable
  table.insert(self.nodes, node) -- push node
  local ret = visitor_func(self, node, ...)
  table.remove(self.nodes) -- pop node
  return ret
end

local traverse
local function traverse_nodes(self, nodes, ...)
  for i=1,#nodes do
    traverse(self, nodes[i], ...)
  end
end

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

function Context:_init(visitors, default_visitor, parentcontext)
  if parentcontext then
    self.rootscope = parentcontext.rootscope
    self.builtins = parentcontext.builtins
    self.env = parentcontext.env
  else
    self.rootscope = Scope(self, 'root')
    self.builtins = {}
    self.env = {}
  end
  self.scope = self.rootscope
  self.visitors = visitors
  if default_visitor == true then
    self.default_visitor = traverser_default_visitor
  elseif default_visitor then
    self.default_visitor = default_visitor
  end
  self.strict = false
  self.nodes = {}
end

function Context:push_scope(kind)
  local scope = self.scope:fork(kind)
  self.scope = scope
  return scope
end

function Context:pop_scope()
  self.scope = self.scope.parent
end

function Context:get_top_node()
  return self.nodes[1]
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

function Context:traverse(node, ...)
  if node._astnode then
    return traverse_node(self, node, ...)
  else
    return traverse_nodes(self, node, ...)
  end
end
traverse = Context.traverse

function Context:repeat_scope_until_resolution(scope_kind, after_push)
  local scope
  repeat
    scope = self:push_scope(scope_kind)
    after_push(scope)
    local resolutions_count = scope:resolve()
    self:pop_scope()
  until resolutions_count == 0
  return scope
end

function Context:add_runtime_builtin(name)
  if not name then return end
  self.builtins[name] = true
end

return Context
