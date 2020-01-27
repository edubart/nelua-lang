local traits = require 'nelua.utils.traits'
local tabler = require 'nelua.utils.tabler'
local class = require 'nelua.utils.class'
local bn = require 'nelua.utils.bn'
local typedefs = require 'nelua.typedefs'
local Context = require 'nelua.context'
local Attr = require 'nelua.attr'

local PPContext = class(Context)

function PPContext:_init(visitors, context)
  Context._init(self, visitors)
  self.context = context
  self.registry = {}
  self.state = {}
end

function PPContext:push_state(scope, statnodes)
  self.state = {scope=scope, statnodes=statnodes, oldstate=self.state}
end

function PPContext:pop_state()
  self.state = self.state.oldstate
end

function PPContext:get_symbol(key)
  return self.state.scope.symbols[key]
end

function PPContext:make_hygienize(statnodes)
  return function(f)
    return function(...)
      self:push_state(self.context.scope, statnodes)
      local rets = tabler.pack(f(...))
      self:pop_state()
      return tabler.unpack(rets)
    end
  end
end

function PPContext:add_statnode(node)
  table.insert(self.state.statnodes, node)
  self.context:traverse(node)
end

function PPContext.toname(_, val, orignode)
  orignode:assertraisef(traits.is_string(val),
    'unable to convert preprocess value of type "%s" to a compile time name', type(val))
  return val
end

function PPContext:tovalue(val, orignode)
  local node
  local aster = self.context.astbuilder.aster
  local primtypes = require 'nelua.typedefs'.primtypes
  if val == table then
    val = primtypes.table
  elseif val == string then
    val = primtypes.string
  elseif val == type then
    val = primtypes.type
  end
  if traits.is_astnode(val) then
    node = val
  elseif traits.is_type(val) then
    node = aster.Type{'auto'}
    -- inject persistent parsed type
    local pattr = Attr({
      type = typedefs.primtypes.type,
      value = val,
      comptime = true
    })
    node.attr:merge(pattr)
    node.pattr = pattr
  elseif traits.is_string(val) then
    node = aster.String{val}
  elseif traits.is_symbol(val) then
    node = aster.Id{val.name}
  elseif traits.is_number(val) or traits.is_bignumber(val) then
    local num = bn.new(val)
    local neg = false
    if num:isneg() then
      num = num:abs()
      neg = true
    end
    if num:isintegral() then
      node = aster.Number{'dec', num:todec()}
    else
      local int, frac = num:todec():match('^(-?%d+).(%d+)$')
      node = aster.Number{'dec', int, frac}
    end
    if neg then
      node = aster.UnaryOp{'unm', node}
    end
  elseif traits.is_boolean(val) then
    node = aster.Boolean{val}
  --TODO: table, nil
  else
    orignode:raisef('unable to convert preprocess value of type "%s" to a const value', type(val))
  end
  node.srcname = orignode.srcname
  node.modname = orignode.modname
  node.src = orignode.src
  node.pos = orignode.pos
  return node
end

function PPContext:getregistryindex(what)
  local registry = self.registry
  local regindex = registry[what]
  if not regindex then
    table.insert(registry, what)
    regindex = #registry
    registry[what] = regindex
  end
  return regindex
end

return PPContext
