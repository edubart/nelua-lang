local class = require 'euluna.utils.class'
local errorer = require 'euluna.utils.errorer'
local tabler = require 'euluna.utils.tabler'
local metamagic = require 'euluna.utils.metamagic'
local iters = require 'euluna.utils.iterators'
local ASTNode = require 'euluna.astnode'
local config = require 'euluna.configer'.get()
local shapetypes = require 'tableshape'.types

local ASTBuilder = class()

local function get_astnode_shapetype(nodeklass)
  return shapetypes.custom(function(val)
    if class.is_a(val, nodeklass) then return true end
    return nil, string.format('expected type "ASTNode", got "%s"', type(val))
  end)
end

function ASTBuilder:_init()
  self.nodes = { Node = ASTNode }
  self.shapetypes = { node = { Node = get_astnode_shapetype(ASTNode) } }
  self.shapes = { Node = shapetypes.shape {} }
  self.aster = {}
  metamagic.setmetaindex(self.shapetypes, shapetypes)
end

function ASTBuilder:register(tag, shape)
  shape.attr = shapetypes.table:is_optional()
  shape = shapetypes.shape(shape)
  local klass = class(ASTNode)
  klass.tag = tag
  klass.nargs = #shape.shape
  self.shapetypes.node[tag] = get_astnode_shapetype(klass)
  self.shapes[tag] = shape
  self.nodes[tag] = klass
  self.aster[tag] = function(params)
    local nargs = math.max(klass.nargs, #params)
    local node = self:create(tag, tabler.unpack(params, 1, nargs))
    for k,v in iters.spairs(params) do
      node[k] = v
    end
    return node
  end
  return klass
end

function ASTBuilder:create(tag, ...)
  local klass = self.nodes[tag]
  errorer.assertf(klass, "AST with name '%s' is not registered", tag)
  local node = klass(...)
  if config.check_ast_shape then
    local shape = self.shapes[tag]
    local ok, err = shape(node)
    errorer.assertf(ok, 'invalid shape while creating AST node "%s": %s', tag, err)
  end
  return node
end

function ASTBuilder:clone()
  local clone = ASTBuilder()
  tabler.update(clone.nodes, self.nodes)
  tabler.update(clone.shapes, self.shapes)
  tabler.update(clone.shapetypes, self.shapetypes)
  return clone
end

return ASTBuilder
