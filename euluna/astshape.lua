local class = require 'pl.class'
local types = require 'tableshape'.types
local unpack = table.unpack or unpack

local ASTNode = class()

function ASTNode:args()
  return unpack(self)
end

local ASTShape = class()

function ASTShape:_init()
  self.nodes = {}
  self.creates = {}
end

function ASTShape:register(name, shape)
  local klass = class(ASTNode)
  self.nodes[name] = klass
  klass.tag = name
  local klass_mt = getmetatable(klass())
  local function node_create(...)
    local node = {...}
    setmetatable(node, klass_mt)
    local ok, err = shape(node)
    if not ok then
      error(string.format('invalid shape while creating AST node "%s": %s', name, err))
    end
    return node
  end
  klass.create = node_create
  self.creates[name] = node_create
  return klass
end

function ASTShape:create(tag, ...)
  local create = self.creates[tag]
  if not create then
    error(string.format("AST with name '%s' is not registered", tag))
  end
  return create(...)
end

ASTShape.types = {
  node = types.custom(function(val)
    if type(val) == 'table' and val.is_a and val:is_a(ASTNode) then
      return true
    end
    return nil, string.format('expected type "ASTNode", got "%s"', type(val))
  end)
}

return ASTShape
