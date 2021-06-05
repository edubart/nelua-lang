local traits = require 'nelua.utils.traits'
local class = require 'nelua.utils.class'
local aster = require 'nelua.aster'
local VisitorContext = require 'nelua.visitorcontext'

local PPContext = class(VisitorContext)

function PPContext:_init(visitors, context)
  VisitorContext._init(self, visitors)
  self.context = context
  self.registry = {}
  self.statnodes = nil
  self.statnodestack = {}
end

function PPContext:push_statnodes(statnodes)
  local statnodestack = self.statnodestack
  statnodestack[#statnodestack+1] = self.statnodes
  self.statnodes = statnodes
  return statnodes
end

function PPContext:pop_statnodes()
  local statnodestack = self.statnodestack
  local index = #statnodestack
  self.statnodes = statnodestack[index]
  statnodestack[index] = nil
end

function PPContext:add_statnode(node, noclone)
  if not noclone then
    node = node:clone()
  end
  local statnodes = self.statnodes
  if statnodes.addindex then
    local addindex = statnodes.addindex
    statnodes.addindex = addindex + 1
    table.insert(self.statnodes, addindex, node)
  else
    self.statnodes[#statnodes+1] = node
  end
  self.context:traverse_node(node)
end

function PPContext.toname(_, val, orignode)
  orignode:assertraisef(traits.is_string(val),
    'unable to convert preprocess value of type "%s" to a compile time name', type(val))
  return val
end

function PPContext.tonode(_, val, orignode)
  local node = aster.create_value(val, orignode)
  if not node then
    orignode:raisef('unable to convert preprocess value of lua type "%s" to a compile time value', type(val))
  end
  return node
end

function PPContext:inject_value(val, orignode, dest, destpos)
  if type(val) == 'table' and val._varargs then
    while #dest > destpos do -- clean old varargs
      dest[#dest] = nil
    end
    for i=1,#val do
      dest[destpos+i-1] = val[i]
    end
  else
    dest[destpos] = self:tonode(val, orignode)
  end
end

function PPContext:getregistryindex(what)
  local registry = self.registry
  local regindex = registry[what]
  if not regindex then
    regindex = #registry+1
    registry[regindex] = what
    registry[what] = regindex
  end
  return regindex
end

return PPContext
