require 'compat53'
local astnodes = {}
local class = require 'pl.class'
local ASTNode = class()

local astcreate_by_name = {}

function ASTNode:args()
  return table.unpack(self)
end

local ASTNode_mt = { __index = ASTNode }
astnodes.ASTNode = ASTNode

function astnodes.register(name)
  local klass_name = 'AST' .. name
  local klass = class(ASTNode)
  local klass_mt = { __index = klass }
  setmetatable(klass, ASTNode_mt)
  astnodes[klass_name] = klass
  klass.tag = name
  local function astcreate(...)
    local self = {...}
    setmetatable(self, klass_mt)
    return self
  end
  klass.create = astcreate
  astcreate_by_name[name] = astcreate
  return klass
end

function astnodes.create(tag, ...)
  local astcreate = astcreate_by_name[tag]
  if not astcreate then
    error(string.format("AST with name '%s' is not registered", tag))
  end
  return astcreate(...)
end

astnodes.register('Number')
astnodes.register('String')
astnodes.register('Boolean')
astnodes.register('Block')
astnodes.register('Return')

return astnodes
