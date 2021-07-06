--[[
Visitor context.

The visitor context is used to process an AST while traversing its nodes,
it visits a specialized function for each node tag.

It contains many utilities to push/pop nodes, states, pragmas and scopes
while traversing.
]]

local class = require 'nelua.utils.class'
local fs = require 'nelua.utils.fs'
local sstream = require 'nelua.utils.sstream'

-- The visitor context class.
local VisitorContext = class()

-- Used to quickly check whether a table is a context.
VisitorContext._context = true

-- Initializes a visitor context using `visitors` table to visit nodes while traversing.
function VisitorContext:_init(visitors, rootscope)
  self.context = self
  self.visitors = visitors
  -- scope
  self.rootscope = rootscope
  self.scope = rootscope
  self.scopestack = {}
  self.rootpragmas = {}
  -- pragmas
  self.pragmas = self.rootpragmas
  self.pragmastack = {}
  -- state
  self.rootstate = {}
  self.statestack = {}
  self.state = self.rootstate
  -- visiting nodes
  self.nodestack = {}
end

--[[
Promotes visitor context class to another context class `klass`.
Arguments `...` are forwarded to the `_init` function.
]]
function VisitorContext:promote(klass, ...)
  setmetatable(self, klass):_init(...)
  return klass
end

-- Pushes the state `state`, effectively overriding the current state.
function VisitorContext:push_state(state)
  local statestack, oldstate = self.statestack, self.state
  statestack[#statestack+1] = oldstate
  self.state = setmetatable(state, {__index = oldstate})
end

--[[
Pushes the new state `state` while forking from the current state.
Fork means that current state values are inherited.
]]
function VisitorContext:push_forked_state(state)
  self:push_state(setmetatable(state, {__index = self.state}))
end

-- Pops the current state, effectively restoring the previous state.
function VisitorContext:pop_state()
  local statestack = self.statestack
  local index = #statestack
  self.state = statestack[index]
  statestack[index] = nil
end

-- Pushes pragmas `pragmas`, effectively overriding the current pragmas.
function VisitorContext:push_pragmas(pragmas)
  local pragmastack = self.pragmastack
  local oldpragmas = self.pragmas
  pragmastack[#pragmastack+1] = oldpragmas
  self.pragmas = pragmas
end

--[[
Pushes the new pragmas `pragmas` while forking from the current pragmas.
Fork means that current pragmas values are inherited.
]]
function VisitorContext:push_forked_pragmas(pragmas)
  local oldpragmas = self.pragmas
  local mt = getmetatable(pragmas)
  if mt then -- reuse the forked pragmas
    assert(mt.__index == oldpragmas, 'broken pragmas chain, is a pragma pop missing?')
  else -- forking a new pragmas
    setmetatable(pragmas, {__index = oldpragmas})
  end
  self:push_pragmas(pragmas)
end

-- Pops current pragmas, effectively restoring the previous pragmas.
function VisitorContext:pop_pragmas()
  local pragmastack = self.pragmastack
  local index = #pragmastack
  self.pragmas = self.pragmastack[index]
  self.pragmastack[index] = nil
end

-- Pushes a node into the node visiting stack.
function VisitorContext:push_node(node)
  local nodestack = self.nodestack
  nodestack[#nodestack + 1] = node
end

-- Pops last node visiting node from the node visiting stack.
function VisitorContext:pop_node()
  local nodestack = self.nodestack
  nodestack[#nodestack] = nil
end

-- Pushes the scope `state`, effectively overriding the current scope.
function VisitorContext:push_scope(scope)
  local scopestack = self.scopestack
  scopestack[#scopestack+1] = self.scope
  self.scope = scope
end

--[[
Pushes a forked scope for node `node`, effectively overriding the current scope.
Fork means that current scope symbols are inherited.
]]
function VisitorContext:push_forked_scope(node)
  local scope = node.scope
  if scope then -- node already has a scope
    assert(scope.parent == self.scope and scope.node == node, 'broken scope chain')
  else -- node doesn't have a scope yet, create it
    scope = self.scope:fork(node)
    node.scope = scope
  end
  self:push_scope(scope)
  return scope
end

-- Pops the current scope, effectively restoring the previous scope.
function VisitorContext:pop_scope()
  local scopestack = self.scopestack
  local index = #scopestack
  self.scope = scopestack[index]
  scopestack[index] = nil
end

-- Traverses the node `node`, arguments `...` are forwarded to its visitor.
function VisitorContext:traverse_node(node, ...)
  local nodestack = self.nodestack
  local index = #nodestack+1
  nodestack[index] = node -- push node
  local visitors = self.visitors
  local visit = visitors[node.tag] or visitors.default_visitor
  local ret = visit(self, node, ...)
  nodestack[index] = nil -- pop node
  return ret
end

--[[
First transform `orignode` into `newnode`, then traverse `orignode`.
The transform function is used to replace a node with a different node
while reusing the original node reference.
]]
function VisitorContext:transform_and_traverse_node(orignode, newnode, ...)
  orignode:transform(newnode)
  return self:traverse_node(orignode, ...)
end

-- Traverses list of nodes `nodes`, arguments `...` are forwarded for each node visitor.
function VisitorContext:traverse_nodes(nodes, ...)
  for i=1,#nodes do
    self:traverse_node(nodes[i], ...)
  end
end

--[[
Gets a node from the node visiting stack at level `level`.
If level is omitted then `0` is used, thus the current node being visited is returned.
]]
function VisitorContext:get_visiting_node(level)
  local nodestack = self.nodestack
  return nodestack[#nodestack - (level or 0)]
end

-- Gets source directory for the current nodes being visited.
function VisitorContext:get_visiting_directory()
  local nodestack = self.nodestack
  for i=#nodestack,1,-1 do
    local node = nodestack[i]
    local filename = node.src and node.src.name
    if filename and not filename:match('^@') then
      local dirname = fs.dirname(filename)
      if dirname == '' then dirname = '.' end
      return dirname
    end
  end
end

--[[
Get tracebacks for the current nodes being visited up to level `level`.
If `level` is omitted then `0` is used, thus a full traceback is generated.
]]
function VisitorContext:get_visiting_traceback(level)
  local ss = sstream()
  -- consider polymorphic functions instantiations
  local polysrcnode = self.state.inpolyeval and self.state.inpolyeval.srcnode
  if polysrcnode then
    ss:add(polysrcnode:format_message('from', 'polymorphic function instantiation'))
  end
  -- show location for each node
  local nodestack = self.nodestack
  for i=1,#nodestack-(level or 0) do
    local node = nodestack[i]
    if node._astnode and node.tag ~= 'Block' then
      ss:add(node:format_message('from', 'AST node %s', node.tag))
    end
  end
  return ss:tostring()
end

-- DEPRECATED, use `get_visiting_node` instead.
function VisitorContext:get_parent_node(level) --luacov:disable
  return self:get_visiting_node(level or 1)
end --luacov:enable

return VisitorContext
