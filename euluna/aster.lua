local class = require 'euluna.utils.class'
local shapetypes = require 'tableshape'.types
local utils = require 'euluna.utils.errorer'
local tabler = require 'euluna.utils.tabler'
local assertf = utils.assertf
local ASTNode = require 'euluna.astnode'

local Aster = class()

local function get_astnode_shapetype(nodeklass)
  return shapetypes.custom(function(val)
    if class.is_a(val, nodeklass) then return true end
    return nil, string.format('expected type "ASTNode", got "%s"', type(val))
  end)
end

function Aster:_init()
  self.nodes = { Node = ASTNode }
  self.types = { ast = { Node = get_astnode_shapetype(ASTNode) } }
  self.shapes = { Node = shapetypes.shape {} }
  tabler.setmetaindex(self.types, shapetypes)
end

function Aster:register(tag, shape)
  local klass = class(ASTNode)
  klass.tag = tag
  klass.nargs = #shape.shape
  self.types.ast[tag] = get_astnode_shapetype(klass)
  self.shapes[tag] = shape
  self.nodes[tag] = klass
  return klass
end

function Aster:create(tag, ...)
  local klass = self.nodes[tag]
  assertf(klass, "AST with name '%s' is not registered", tag)
  local node = klass(...)
  local shape = self.shapes[tag]
  local ok, err = shape(node)
  assertf(ok, 'invalid shape while creating AST node "%s": %s', tag, err)
  return node
end

function Aster:clone()
  local clone = Aster()
  tabler.update(clone.nodes, self.nodes)
  tabler.update(clone.shapes, self.shapes)
  tabler.update(clone.types, self.types)
  return clone
end

function Aster:AST(tag, ...)
  return self:create(tag, ...)
end

function Aster:TAST(type, tag, ...)
  local node = self:create(tag, ...)
  node.type = type
  return node
end

return Aster
