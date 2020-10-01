local class = require 'nelua.utils.class'
local tabler = require 'nelua.utils.tabler'

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
    if done == true then
      return
    elseif done then
      return done
    end
    -- bench_traverse(node)
  end
  local visitor_func = self.visitors[node.tag] or self.default_visitor
  if not visitor_func then --luacov:disable
    node:errorf("visitor for AST node '%s' does not exist", node.tag)
  end --luacov:enable
  local nodes = self.visiting_nodes
  local nodeindex = #nodes+1
  nodes[nodeindex] = node -- push node
  local ret = visitor_func(self, node, ...)
  nodes[nodeindex] = nil-- pop node
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
  self.default_visitor = visitors.default_visitor or traverser_default_visitor
end

function VisitorContext:push_node(node)
  local nodes = self.visiting_nodes
  nodes[#nodes + 1] = node
end

function VisitorContext:pop_node()
  local nodes = self.visiting_nodes
  nodes[#nodes] = nil
end

function VisitorContext:get_parent_node()
  local nodes = self.visiting_nodes
  return nodes[#nodes - 1]
end

function VisitorContext:get_current_node()
  local nodes = self.visiting_nodes
  return nodes[#nodes]
end

function VisitorContext:push_state()
  local statestack = self.statestack
  statestack[#statestack+1] = self.state
  local newstate = tabler.copy(self.state)
  self.state = newstate
  return newstate
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
