local class = require 'euluna.utils.class'
local errorer = require 'euluna.utils.errorer'
local tabler = require 'euluna.utils.tabler'
local metamagic = require 'euluna.utils.metamagic'
local ASTNode = require 'euluna.astnode'
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
  metamagic.setmetaindex(self.shapetypes, shapetypes)
end

function ASTBuilder:register(tag, shape)
  local klass = class(ASTNode)
  klass.tag = tag
  klass.nargs = #shape.shape
  self.shapetypes.node[tag] = get_astnode_shapetype(klass)
  self.shapes[tag] = shape
  self.nodes[tag] = klass
  return klass
end

function ASTBuilder:create(tag, ...)
  local klass = self.nodes[tag]
  errorer.assertf(klass, "AST with name '%s' is not registered", tag)
  local node = klass(...)
  local shape = self.shapes[tag]
  local ok, err = shape(node)
  errorer.assertf(ok, 'invalid shape while creating AST node "%s": %s', tag, err)
  return node
end

function ASTBuilder:clone()
  local clone = ASTBuilder()
  tabler.update(clone.nodes, self.nodes)
  tabler.update(clone.shapes, self.shapes)
  tabler.update(clone.shapetypes, self.shapetypes)
  return clone
end

function ASTBuilder:AST(tag, ...)
  return self:create(tag, ...)
end

function ASTBuilder:TAST(type, tag, ...)
  local node = self:create(tag, ...)
  node.type = type
  return node
end

return ASTBuilder
