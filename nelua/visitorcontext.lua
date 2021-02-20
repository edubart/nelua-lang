local class = require 'nelua.utils.class'

local VisitorContext = class()

VisitorContext._context = true

--[[
local nodetravs = {}
local numretravs = {}
local numtravs = {}
local function bench_traverse(node)
  if node._astnode then
    local tag = node.tag
    numtravs[tag] = (numtravs[tag] or 0) + 1
    if nodetravs[node] then
      numretravs[tag] = (numretravs[tag] or 0) + 1
    end
    nodetravs[node] = true
  end
end
]]

local function traverse_node(self, node, ...)
  if self.analyzing then
    local done = node.done
    if done then
      return done ~= true and done or nil
    end
    -- bench_traverse(node)
  end
  local nodes = self.nodes
  local index = #nodes+1
  nodes[index] = node -- push node
  local visitors = self.visitors
  local visit = visitors[node.tag] or visitors.default_visitor
  local ret = visit(self, node, ...)
  nodes[index] = nil -- pop node
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
  self.nodes = {}
  self.state = {}
  self.statestack = {}
  self.context = self
end

function VisitorContext:set_visitors(visitors)
  self.visitors = visitors
  if visitors.default_visitor == nil then
    visitors.default_visitor = traverser_default_visitor
  end
end

function VisitorContext:push_node(node)
  local nodes = self.nodes
  nodes[#nodes + 1] = node
end

function VisitorContext:pop_node()
  local nodes = self.nodes
  nodes[#nodes] = nil
end

function VisitorContext:get_parent_node(level)
  local nodes = self.nodes
  return nodes[#nodes - (level or 1)]
end

function VisitorContext:get_current_node()
  local nodes = self.nodes
  return nodes[#nodes]
end

function VisitorContext:push_state(newstate)
  local statestack, oldstate = self.statestack, self.state
  statestack[#statestack+1] = oldstate
  self.state = setmetatable(newstate, {__index=oldstate})
end

function VisitorContext:pop_state()
  local statestack = self.statestack
  local index = #statestack
  self.state = statestack[index]
  assert(self.state)
  statestack[index] = nil

  --[[
  if #self.statestack == 0 then
    print '============================report'
    for k,v in pairs(numretravs) do
      print(v,k, string.format('%.2f', v*100/numtravs[k]))
    end
  end
  ]]
end

return VisitorContext
