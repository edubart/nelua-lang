local class = require 'pl.class'
local types = require 'tableshape'.types
local unpack = table.unpack or unpack

local ASTNode = class()
ASTNode.tag = 'Node'

function ASTNode:args()
  return unpack(self)
end

local Shaper = class()

local function get_astnode_shapetype(self, name)
  local nodeklass = self.nodes[name]
  return types.custom(function(val)
    if type(val) == 'table' and val.is_a and val:is_a(nodeklass) then
      return true
    end
    return nil, string.format('expected type "ASTNode", got "%s"', type(val))
  end)
end

function Shaper:_init()
  self.nodes = {
    node = ASTNode
  }
  self.creates = {}
  self.types = {
    ASTNode = get_astnode_shapetype(self)
  }
  setmetatable(self.types, {
    __index = types
  })
end

function Shaper:register(name, shape)
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
  self.types['AST' .. name] = get_astnode_shapetype(self, name)
  return klass
end

function Shaper:create(tag, ...)
  local create = self.creates[tag]
  if not create then
    error(string.format("AST with name '%s' is not registered", tag))
  end
  return create(...)
end

return Shaper
