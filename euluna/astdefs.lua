local ASTBuilder = require 'euluna.astbuilder'

local astbuilder = ASTBuilder()
local stypes = astbuilder.shapetypes

-- primitives
astbuilder:register('Number', stypes.shape {
  stypes.one_of{"int", "dec", "bin", "exp", "hex"}, -- type
  stypes.string + stypes.table, -- value, (table used in exp values)
  stypes.string:is_optional() -- literal
})
astbuilder:register('String', stypes.shape {
  stypes.string, -- value
  stypes.string:is_optional() -- literal
})
astbuilder:register('Boolean', stypes.shape {
  stypes.boolean, -- true or false
})
astbuilder:register('Nil', stypes.shape {})
astbuilder:register('Varargs', stypes.shape {})

-- table
astbuilder:register('Table', stypes.shape {
  stypes.array_of(stypes.node.Node) -- pair or exprs
})
astbuilder:register('Pair', stypes.shape {
  stypes.node.Node + stypes.string, -- field name (an expr or a string)
  stypes.node.Node -- field value expr
})

-- identifier and types
astbuilder:register('Id', stypes.shape {
  stypes.string, -- name
})
astbuilder:register('Paren', stypes.shape {
  stypes.node.Node -- expr
})
astbuilder:register('Type', stypes.shape {
  stypes.string, -- type name
})
astbuilder:register('FuncType', stypes.shape {
  stypes.array_of(stypes.node.Node), -- arguments types
  stypes.array_of(stypes.node.Node), -- returns types
})
astbuilder:register('ComposedType', stypes.shape {
  stypes.string, -- type name
  stypes.array_of(stypes.node.Node), -- arguments types
})
astbuilder:register('IdDecl', stypes.shape {
  stypes.string, -- name
  stypes.one_of{"var", "var&", "var&&", "val"}:is_optional(), -- mutability
  stypes.node.Node:is_optional(), -- type
})

-- function
astbuilder:register('Function', stypes.shape {
  stypes.array_of(stypes.node.IdDecl + stypes.node.Varargs), -- typed arguments
  stypes.array_of(stypes.node.Node), -- typed returns
  stypes.node.Node -- block
})

-- indexing
astbuilder:register('DotIndex', stypes.shape {
  stypes.string, -- name
  stypes.node.Node -- expr
})
astbuilder:register('ColonIndex', stypes.shape {
  stypes.string, -- name
  stypes.node.Node -- expr
})
astbuilder:register('ArrayIndex', stypes.shape {
  stypes.node.Node, -- index expr
  stypes.node.Node -- expr
})

-- calls
astbuilder:register('Call', stypes.shape {
  stypes.array_of(stypes.node.Node), -- call types
  stypes.array_of(stypes.node.Node), -- args exprs
  stypes.node.Node, -- caller expr
  stypes.boolean:is_optional(), -- is called from a block
})
astbuilder:register('CallMethod', stypes.shape {
  stypes.string, -- method name
  stypes.array_of(stypes.node.Node), -- call types
  stypes.array_of(stypes.node.Node), -- args exprs
  stypes.node.Node, -- caller expr
  stypes.boolean:is_optional(), -- is called from a block
})

-- block
astbuilder:register('Block', stypes.shape {
  stypes.array_of(stypes.node.Node) -- statements
})

-- statements
astbuilder:register('Return', stypes.shape {
  stypes.array_of(stypes.node.Node) -- returned exprs
})
astbuilder:register('If', stypes.shape {
  stypes.array_of(stypes.shape{stypes.node.Node, stypes.node.Block}), -- if list {expr, block}
  stypes.node.Block:is_optional() -- else block
})
astbuilder:register('Do', stypes.shape {
  stypes.node.Block -- block
})
astbuilder:register('While', stypes.shape {
  stypes.node.Node, -- expr
  stypes.node.Block -- block
})
astbuilder:register('Repeat', stypes.shape {
  stypes.node.Block, -- block
  stypes.node.Node -- expr
})
astbuilder:register('ForNum', stypes.shape {
  stypes.node.IdDecl, -- iterated var
  stypes.node.Node, -- begin expr
  stypes.string, -- compare operator
  stypes.node.Node, -- end expr
  stypes.node.Node:is_optional(), -- increment expr
  stypes.node.Block, -- block
})
astbuilder:register('ForIn', stypes.shape {
  stypes.array_of(stypes.node.IdDecl), -- iterated vars
  stypes.array_of(stypes.node.Node), -- in exprlist
  stypes.node.Block -- block
})
astbuilder:register('Break', stypes.shape {})
astbuilder:register('Label', stypes.shape {
  stypes.string -- label name
})
astbuilder:register('Goto', stypes.shape {
  stypes.string -- label name
})
astbuilder:register('VarDecl', stypes.shape {
  stypes.one_of{"local"}:is_optional(), -- scope
  stypes.one_of{"var", "var&", "val", "val&"}, -- mutability
  stypes.array_of(stypes.node.IdDecl), -- var names with types
  stypes.array_of(stypes.node.Node):is_optional(), -- expr list, initial assignments values
})
astbuilder:register('Assign', stypes.shape {
  stypes.array_of(stypes.node.Node), -- expr list, assign variables
  stypes.array_of(stypes.node.Node), -- expr list, assign values
})
astbuilder:register('FuncDef', stypes.shape {
  stypes.one_of{"local"}:is_optional(), -- scope
  stypes.node.Id + stypes.node.DotIndex + stypes.node.ColonIndex, -- name
  stypes.array_of(stypes.node.IdDecl + stypes.node.Varargs), -- typed arguments
  stypes.array_of(stypes.node.Node), -- typed returns
  stypes.node.Block -- block
})

-- operations
astbuilder:register('UnaryOp', stypes.shape {
  stypes.string, -- type
  stypes.node.Node -- right expr
})
astbuilder:register('BinaryOp', stypes.shape {
  stypes.string, -- type
  stypes.node.Node, --- left expr
  stypes.node.Node -- right expr
})

-- euluna extesions to lua
astbuilder:register('Switch', stypes.shape {
  stypes.node.Node, -- switch expr
  stypes.array_of(stypes.shape{stypes.node.Node, stypes.node.Block}), -- case list {expr, block}
  stypes.node.Block:is_optional() -- else block
})

astbuilder:register('Continue', stypes.shape {})

return astbuilder
