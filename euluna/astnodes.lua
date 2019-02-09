require 'compat53'
local astnodes = {}
local class = require 'pl.class'
local types = require("tableshape").types
local ASTNode = class()

local astcreate_by_name = {}

function ASTNode:args()
  return table.unpack(self)
end

astnodes.ASTNode = ASTNode

function astnodes.register(name, shape)
  local klass = class(ASTNode)
  astnodes[name] = klass
  klass.tag = name
  local klass_mt = getmetatable(klass())
  local function astcreate(...)
    local self = {...}
    setmetatable(self, klass_mt)
    assert(shape(self))
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

local ast_types = {
  node = types.custom(function(val)
    return type(val) == 'table' and val.is_a and val:is_a(ASTNode)
  end)
}

-- primitives
astnodes.register('Number', types.shape {
  types.one_of{"int", "dec", "bin", "exp", "hex"}, -- type
  types.string, -- value
  types.string:is_optional() -- literal
})
astnodes.register('String', types.shape {
  types.string, -- value
  types.string:is_optional() -- literal
})
astnodes.register('Boolean', types.shape {
  types.boolean, -- true or false
})

-- general
astnodes.register('Block', types.shape {
  types.array_of(ast_types.node)
})

-- statements
astnodes.register('Stat_Return', types.shape {
  ast_types.node:is_optional() -- expr
})

return astnodes
