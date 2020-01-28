local class = require 'nelua.utils.class'
local Scope = require 'nelua.scope'
local errorer = require 'nelua.utils.errorer'

local Context = class()

local function traverse_node(self, node, ...)
  local visitor_func = self.visitors[node.tag] or self.visitors.default_visitor
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

function Context:_init(visitors, parentcontext)
  if parentcontext then
    self.rootscope = parentcontext.rootscope
    self.usedbuiltins = parentcontext.usedbuiltins
    self.env = parentcontext.env
    self.requires = parentcontext.requires
    self.parentcontext = parentcontext
  else
    self.rootscope = Scope(self, 'root')
    self.usedbuiltins = {}
    self.env = {}
    self.requires = {}
    self.parentcontext = self
  end
  self:set_visitors(visitors)
  self.scope = self.rootscope
  self.scopestack = {}
  self.state = {}
  self.statestack = {}
  self.nodes = {}
end

function Context:set_visitors(visitors)
  self.visitors = visitors
  if visitors.default_visitor == nil then
    visitors.default_visitor = traverser_default_visitor
  end
end

--[[
function Context:push_state(state)
  table.insert(self.statestack, self.state)
  self.state = state
end

function Context:pop_state()
  self.state = table.remove(self.statestack)
  assert(self.state)
end
]]

function Context:push_scope(scope)
  table.insert(self.scopestack, self.scope)
  self.scope = scope
end

function Context:push_forked_scope(kind, node)
  local scope
  if node.scope then
    scope = node.scope
    assert(scope.kind == kind)
    --bdump(scope.kind)
    --dump('kind', scope.kind, scope.parent.kind, self.scope.kind)
    assert(scope.parent == self.scope)
    scope:clear_symbols()
  else
    scope = self.scope:fork(kind)
    node.scope = scope
  end
  self:push_scope(scope)
  return scope
end

function Context:pop_scope()
  self.scope = table.remove(self.scopestack)
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

function Context:repeat_scope_until_resolution(scope_kind, node, after_push)
  local scope
  repeat
    scope = self:push_forked_scope(scope_kind, node)
    after_push(scope)
    local resolutions_count = scope:resolve()
    self:pop_scope()
  until resolutions_count == 0
  return scope
end

function Context:ensure_runtime_builtin(name, p1, p2)
  if not (p1 or p2) and self.usedbuiltins[name] then return name end
  errorer.assertf(self.builtins[name], 'builtin "%s" not defined', name)
  local func = self.builtins[name]
  if func then
    local newname = func(self, p1, p2)
    if newname then
      name = newname
    end
  end
  self.usedbuiltins[name] = true
  return name
end

return Context
