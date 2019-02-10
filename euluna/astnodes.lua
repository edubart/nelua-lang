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
    local ok, err = shape(self)
    if not ok then
      error(string.format('invalid shape while creating AST node "%s": %s', name, err))
    end
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

local astnodes_create = astnodes.create
function astnodes.to_astnode(pos, tag, ...)
  local ast = astnodes_create(tag, ...)
  ast.pos = pos
  return ast
end

local ast_types = {
  node = types.custom(function(val)
    if type(val) == 'table' and val.is_a and val:is_a(ASTNode) then
      return true
    end
    return nil, string.format('expected type "ASTNode", got "%s"', type(val))
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
astnodes.register('Nil', types.shape {})

-- varargs
astnodes.register('Varargs', types.shape {})

-- table
astnodes.register('Table', types.shape {
  types.array_of(ast_types.node) -- pair or exprs
})
astnodes.register('Pair', types.shape {
  ast_types.node + types.string, -- field name
  ast_types.node -- field value expr
})

astnodes.register('Function', types.shape {
  types.array_of(ast_types.node):is_optional(), -- typed arguments
  types.array_of(ast_types.node):is_optional(), -- typed returns
  ast_types.node -- block
})

-- variable/function/type names
astnodes.register('Id', types.shape {
  types.string, -- name
})
astnodes.register('Type', types.shape {
  types.string, -- type
})
astnodes.register('TypedId', types.shape {
  types.string, -- name
  ast_types.node:is_optional(), -- type
})

-- indexing
astnodes.register('DotIndex', types.shape {
  types.string, -- name
  ast_types.node -- expr
})
astnodes.register('ArrayIndex', types.shape {
  ast_types.node, -- index expr
  ast_types.node -- expr
})

-- calls
astnodes.register('Call', types.shape {
  types.array_of(ast_types.node), -- call types
  types.array_of(ast_types.node), -- args exprs
  ast_types.node, -- caller expr
})
astnodes.register('CallMethod', types.shape {
  types.string, -- method name
  types.array_of(ast_types.node), -- call types
  types.array_of(ast_types.node), -- args exprs
  ast_types.node, -- caller expr
})

-- general
astnodes.register('Block', types.shape {
  types.array_of(ast_types.node)
})

-- statements
astnodes.register('Stat_Return', types.shape {
  types.array_of(ast_types.node)
})

-- operations
astnodes.register('UnaryOp', types.shape {
  types.string, -- type
  ast_types.node -- right expr
})
astnodes.register('BinaryOp', types.shape {
  types.string, -- type
  ast_types.node, --- left expr
  ast_types.node -- right expr
})
astnodes.register('TernaryOp', types.shape {
  types.string, -- type
  ast_types.node, -- left expr
  ast_types.node, -- middle expr
  ast_types.node -- right expr
})

return astnodes
