local class = require 'nelua.utils.class'
local errorer = require 'nelua.utils.errorer'
local tabler = require 'nelua.utils.tabler'
local metamagic = require 'nelua.utils.metamagic'
local iters = require 'nelua.utils.iterators'
local Attr = require 'nelua.attr'
local ASTNode = require 'nelua.astnode'
local config = require 'nelua.configer'.get()
local shapetypes = require 'nelua.thirdparty.tableshape'.types
local traits = require 'nelua.utils.traits'
local bn = require 'nelua.utils.bn'

local ASTBuilder = class()

local function get_astnode_shapetype(nodeklass)
  return shapetypes.custom(function(val)
    if class.is(val, nodeklass) then return true end
    return nil, string.format('expected type "ASTNode", got "%s"', type(val))
  end)
end

function ASTBuilder:_init()
  self.nodes = { Node = ASTNode }
  self.shapetypes = { node = { Node = get_astnode_shapetype(ASTNode) } }
  self.shapes = { Node = shapetypes.shape {} }
  self.aster = {}
  self.aster.value = function(...) return self:create_value(...) end
  metamagic.setmetaindex(self.shapetypes, shapetypes)
end

-- Create an AST node from an Lua value.
function ASTBuilder:create_value(val, srcnode)
  local node
  local aster = self.aster
  if traits.is_astnode(val) then
    node = val
  elseif traits.is_type(val) then
    local typedefs = require 'nelua.typedefs'
    node = aster.Type{'auto', pattr={
      type = typedefs.primtypes.type,
      value = val
    }}
  elseif traits.is_string(val) then
    node = aster.String{val}
  elseif traits.is_symbol(val) then
    node = aster.Id{val.name, pattr={
      forcesymbol = val
    }}
  elseif bn.isnumeric(val) then
    local num = bn.parse(val)
    local neg = false
    if bn.isneg(num) then
      num = bn.abs(num)
      neg = true
    end
    if bn.isintegral(num) then
      node = aster.Number{'dec', bn.todec(num)}
    else
      local snum = bn.todecsci(num)
      local int, frac, exp = bn.splitdecsci(snum)
      node = aster.Number{'dec', int, frac, exp}
    end
    if neg then
      node = aster.UnaryOp{'unm', node}
    end
  elseif traits.is_boolean(val) then
    node = aster.Boolean{val}
  --TODO: table, nil
  end
  if node and srcnode then
    node.src = srcnode.src
    node.pos = srcnode.pos
    node.endpos = srcnode.endpos
  end
  return node
end

function ASTBuilder:register(tag, shape)
  shape.attr = shapetypes.table:is_optional()
  shape.uid = shapetypes.number:is_optional()
  shape = shapetypes.shape(shape)
  local klass = class(ASTNode)
  klass.tag = tag
  klass.nargs = #shape.shape
  self.shapetypes.node[tag] = get_astnode_shapetype(klass)
  self.shapes[tag] = shape
  self.nodes[tag] = klass
  self.aster[tag] = function(params)
    local nargs = math.max(klass.nargs, #params)
    local node = self:create(tag, table.unpack(params, 1, nargs))
    for k,v in iters.spairs(params) do
      node[k] = v
    end
    if params.pattr then
      node.attr:merge(params.pattr)
    end
    return node
  end
  return klass
end

function ASTBuilder:create(tag, ...)
  local klass = self.nodes[tag]
  if not klass then
    errorer.errorf("AST with name '%s' is not registered", tag)
  end
  local node = klass(...)
  if config.check_ast_shape then
    local shape = self.shapes[tag]
    local ok, err = shape(node)
    errorer.assertf(ok, 'invalid shape while creating AST node "%s": %s', tag, err)
  end
  return node
end

local genuid = ASTNode.genuid

function ASTBuilder:_create(tag, src, pos, ...)
  local n = select('#', ...)
  local endpos = select(n, ...)
  local node = {
    src = src,
    pos = pos,
    endpos = endpos,
    uid = genuid(),
    attr = setmetatable({}, Attr),
  }
  for i=1,n-1 do
    node[i] = select(i, ...)
  end
  return setmetatable(node, self.nodes[tag])
end

function ASTBuilder:clone()
  local clone = ASTBuilder()
  tabler.update(clone.nodes, self.nodes)
  tabler.update(clone.shapes, self.shapes)
  tabler.update(clone.shapetypes, self.shapetypes)
  return clone
end

return ASTBuilder
