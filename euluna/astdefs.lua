local ASTBuilder = require 'euluna.astbuilder'

local astbuilder = ASTBuilder()
local stypes = astbuilder.shapetypes
local ntypes = stypes.node

-- primitives
astbuilder:register('Number', stypes.shape {
  stypes.one_of{"dec", "bin", "hex"}, -- number base
  stypes.string:is_optional(), -- integer part
  stypes.string:is_optional(), -- fractional part
  stypes.string:is_optional(), -- exponential part
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
  stypes.array_of(ntypes.Node) -- pair or exprs
})
astbuilder:register('Pair', stypes.shape {
  ntypes.Node + stypes.string, -- field name (an expr or a string)
  ntypes.Node -- field value expr
})

-- identifier and types
astbuilder:register('Id', stypes.shape {
  stypes.string, -- name
})
astbuilder:register('IdDecl', stypes.shape {
  stypes.string, -- name
  stypes.one_of{"var", "var&", "var&&", "val"}:is_optional(), -- mutability
  ntypes.Node:is_optional(), -- typexpr
})
astbuilder:register('Paren', stypes.shape {
  ntypes.Node -- expr
})

-- types
astbuilder:register('Type', stypes.shape {
  stypes.string, -- type name
})
astbuilder:register('TypeInstance', stypes.shape {
  ntypes.Node, -- typexpr
})
astbuilder:register('FuncType', stypes.shape {
  stypes.array_of(ntypes.Node), -- arguments types
  stypes.array_of(ntypes.Node), -- returns types
})
astbuilder:register('RecordFieldType', stypes.shape {
  stypes.string, -- name
  ntypes.Node, -- typexpr
})
astbuilder:register('RecordType', stypes.shape {
  stypes.array_of(ntypes.RecordFieldType), -- field types
})
astbuilder:register('EnumFieldType', stypes.shape {
  stypes.string, -- name
  ntypes.Number:is_optional() -- numeric value
})
astbuilder:register('EnumType', stypes.shape {
  ntypes.Type:is_optional(), -- primitive type
  stypes.array_of(ntypes.EnumFieldType), -- field types
})
astbuilder:register('ArrayTableType', stypes.shape {
  ntypes.Node, -- subtype typexpr
})
astbuilder:register('ArrayType', stypes.shape {
  ntypes.Node, -- subtype typeexpt
  ntypes.Number, -- size
})
astbuilder:register('PointerType', stypes.shape {
  ntypes.Node:is_optional(), -- subtype typexpr
})

-- function
astbuilder:register('Function', stypes.shape {
  stypes.array_of(ntypes.IdDecl + ntypes.Varargs), -- typed arguments
  stypes.array_of(ntypes.Node), -- typed returns
  ntypes.Node -- block
})

-- indexing
astbuilder:register('DotIndex', stypes.shape {
  stypes.string, -- name
  ntypes.Node -- expr
})
astbuilder:register('ColonIndex', stypes.shape {
  stypes.string, -- name
  ntypes.Node -- expr
})
astbuilder:register('ArrayIndex', stypes.shape {
  ntypes.Node, -- index expr
  ntypes.Node -- expr
})

-- calls
astbuilder:register('Call', stypes.shape {
  stypes.array_of(ntypes.Node), -- args exprs
  ntypes.Node, -- caller expr
  stypes.boolean:is_optional(), -- is called from a block
})
astbuilder:register('CallMethod', stypes.shape {
  stypes.string, -- method name
  stypes.array_of(ntypes.Node), -- args exprs
  ntypes.Node, -- caller expr
  stypes.boolean:is_optional(), -- is called from a block
})

-- block
astbuilder:register('Block', stypes.shape {
  stypes.array_of(ntypes.Node) -- statements
})

-- statements
astbuilder:register('Return', stypes.shape {
  stypes.array_of(ntypes.Node) -- returned exprs
})
astbuilder:register('If', stypes.shape {
  stypes.array_of(stypes.shape{ntypes.Node, ntypes.Block}), -- if list {expr, block}
  ntypes.Block:is_optional() -- else block
})
astbuilder:register('Do', stypes.shape {
  ntypes.Block -- block
})
astbuilder:register('While', stypes.shape {
  ntypes.Node, -- expr
  ntypes.Block -- block
})
astbuilder:register('Repeat', stypes.shape {
  ntypes.Block, -- block
  ntypes.Node -- expr
})
astbuilder:register('ForNum', stypes.shape {
  ntypes.IdDecl, -- iterated var
  ntypes.Node, -- begin expr
  stypes.string, -- compare operator
  ntypes.Node, -- end expr
  ntypes.Node:is_optional(), -- increment expr
  ntypes.Block, -- block
})
astbuilder:register('ForIn', stypes.shape {
  stypes.array_of(ntypes.IdDecl), -- iterated vars
  stypes.array_of(ntypes.Node), -- in exprlist
  ntypes.Block -- block
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
  stypes.array_of(ntypes.IdDecl), -- var names with types
  stypes.array_of(ntypes.Node):is_optional(), -- expr list, initial assignments values
})
astbuilder:register('Assign', stypes.shape {
  stypes.array_of(ntypes.Node), -- expr list, assign variables
  stypes.array_of(ntypes.Node), -- expr list, assign values
})
astbuilder:register('FuncDef', stypes.shape {
  stypes.one_of{"local"}:is_optional(), -- scope
  ntypes.Id + ntypes.DotIndex + ntypes.ColonIndex, -- name
  stypes.array_of(ntypes.IdDecl + ntypes.Varargs), -- typed arguments
  stypes.array_of(ntypes.Node), -- typed returns
  ntypes.Block -- block
})

-- operations
astbuilder:register('UnaryOp', stypes.shape {
  stypes.string, -- type
  ntypes.Node -- right expr
})
astbuilder:register('BinaryOp', stypes.shape {
  stypes.string, -- type
  ntypes.Node, --- left expr
  ntypes.Node -- right expr
})

-- euluna extesions to lua
astbuilder:register('Switch', stypes.shape {
  ntypes.Node, -- switch expr
  stypes.array_of(stypes.shape{ntypes.Node, ntypes.Block}), -- case list {expr, block}
  ntypes.Block:is_optional() -- else block
})

astbuilder:register('Continue', stypes.shape {})

return astbuilder
