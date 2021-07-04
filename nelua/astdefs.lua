--[[
This module defines all AST shapes.

It also servers as a documentation for AST nodes schemas.
These shapes are used for shape checking in tests
and when manually creating AST nodes.
]]

local aster = require 'nelua.aster'
local shaper = aster.shaper

-- Block containing a list of statements.
aster.register('Block', shaper.array_of(shaper.Node))

-- Number literal.
aster.register('Number', {
  shaper.string + shaper.number, -- value
  shaper.string + shaper.falsy, -- literal type
})

-- String literal.
aster.register('String', {
  shaper.string, -- value
  shaper.string + shaper.falsy, -- literal type
})

-- Boolean literal, (e.g `true` and `false`).
aster.register('Boolean', {
  shaper.boolean -- true or false
})

-- Nil literal, (e.g `nil`).
aster.register('Nil', {})

-- Variable arguments literal, (e.g `...`).
aster.register('Varargs', {})

-- List of statements that evaluates to an expression.
aster.register('DoExpr', {
  shaper.Block -- statements block
})

-- Preprocess code to be executed and removed.
aster.register('Preprocess', {
  shaper.string -- code
})

-- Preprocess expression to be replaced by an ASTNode containing an expression.
aster.register('PreprocessExpr', {
  shaper.string -- code
})

-- Preprocess expression to be replaced by a string containing a name.
aster.register('PreprocessName', {
  shaper.string -- code
})

local name = shaper.string + shaper.PreprocessName

-- Initializer list pair field.
aster.register('Pair', {
  shaper.Node + name, -- field name or expr
  shaper.Node, -- value expr
})

-- Initializer list (e.g `{}`), used for initialing tables, records and arrays.
aster.register('InitList', shaper.array_of(shaper.Pair + shaper.Node)) -- pair or exprs

-- Indexing with `.`.
aster.register('DotIndex', {
  name, -- name
  shaper.Node, -- expr
})

-- Indexing with `:`.
aster.register('ColonIndex', {
  name, -- name
  shaper.Node, -- expr
})

-- Indexing with brackets (e.g `[key]`).
aster.register('KeyIndex', {
  shaper.Node, -- key expr
  shaper.Node, -- expr
})

-- Annotation used in a variable, type or function declaration.
aster.register('Annotation', {
  name, -- name
  shaper.array_of(shaper.Node) + shaper.falsy, -- annotation arguments
})

-- Identifier.
aster.register('Id', {
  name -- name
})

-- Identifier declaration.
aster.register('IdDecl', {
  name + shaper.DotIndex, -- name
  shaper.Node + shaper.falsy, -- type expr
  shaper.array_of(shaper.Annotation) + shaper.falsy, -- annotations
})

-- Expression surround by parenthesis (e.g `(expr)`)
aster.register('Paren', {
  shaper.Node -- expr
})

-- Type expression (e.g `@typeexpr`).
aster.register('Type', {
  shaper.Node -- type expr
})

-- Variable arguments type, used in function declaration arguments only.
aster.register('VarargsType', {
  shaper.one_of{"varautos", "varanys", "cvarargs"} + shaper.falsy
})

-- Function type.
aster.register('FuncType', {
  shaper.array_of(shaper.Node), -- arguments types
  shaper.array_of(shaper.Node) + shaper.falsy, -- returns types
})

-- Record field.
aster.register('RecordField', {
  name, -- name
  shaper.Node, -- type expr
})

-- Record type.
aster.register('RecordType', shaper.array_of(shaper.RecordField)) -- fields

-- Union field.
aster.register('UnionField', {
  name + shaper.falsy, -- name
  shaper.Node, -- type expr
})

-- Union type.
aster.register('UnionType', shaper.array_of(shaper.UnionField)) -- fields

-- Variant type.
aster.register('VariantType', shaper.array_of(shaper.Node)) -- types exprs

-- Enum field.
aster.register('EnumField', {
  name, -- name
  shaper.Node + shaper.falsy, -- value expr
})

-- Enum type.
aster.register('EnumType', {
  shaper.Node + shaper.falsy, -- primitive type expr
  shaper.array_of(shaper.EnumField), -- field types
})

-- Array type.
aster.register('ArrayType', {
  shaper.Node, -- subtype type expr
  shaper.Node + shaper.falsy, -- size expr
})

-- Pointer type.
aster.register('PointerType', {
  shaper.Node + shaper.falsy, -- subtype type expr
})

-- Optional type.
aster.register('OptionalType', {
  shaper.Node -- subtype type expr
})

-- Generic type.
aster.register('GenericType', {
  shaper.Id + shaper.DotIndex, -- name
  shaper.array_of(shaper.Node), -- arguments (type expr or expr)
})

-- Anonymous function (function without a name).
aster.register('Function', {
  shaper.array_of(shaper.IdDecl + shaper.VarargsType), -- typed arguments
  shaper.array_of(shaper.Node) + shaper.falsy, -- typed returns
  shaper.array_of(shaper.Annotation) + shaper.falsy,
  shaper.Node, -- block
})

-- Call.
aster.register('Call', {
  shaper.array_of(shaper.Node), -- arguments exprs
  shaper.Node, -- caller expr
})

-- Call a method.
aster.register('CallMethod', {
  name, -- method name
  shaper.array_of(shaper.Node), -- arguments exprs
  shaper.Node, -- caller expr
})

-- Unary operator.
aster.register('UnaryOp', {
  shaper.one_of{"not", "unm", "len", "bnot", "ref", "deref"}, -- op name
  shaper.Node, -- right expr
})

-- Binary operator.
aster.register('BinaryOp', {
  shaper.Node, --- left expr
  shaper.one_of{"or", "and",
                "eq", "ne", "le", "lt", "ge", "gt",
                "bor", "bxor", "band", "shl", "shr", "asr",
                "concat",
                "add", "sub",
                "mul", "div", "idiv", "tdiv", "mod", "tmod",
                "pow"}, -- op name
  shaper.Node, -- right expr
})

-- Return statement.
aster.register('Return', shaper.array_of(shaper.Node)) -- returned exprs

-- If statement.
aster.register('If', {
  shaper.array_of(shaper.Node + shaper.Block), -- ifs (expr followed by block)
  shaper.Block + shaper.falsy, -- else block
})

-- Switch statement.
aster.register('Switch', {
  shaper.Node, -- switch expr
  shaper.array_of(shaper.array_of(shaper.Node) + shaper.Block), -- cases (exprs followed by block}
  shaper.Block + shaper.falsy, -- else block
})

-- Do statement.
aster.register('Do', {
  shaper.Block, -- statements block
})

-- Defer statement.
aster.register('Defer', {
  shaper.Block -- statements block
})

-- While statement.
aster.register('While', {
  shaper.Node, -- expr
  shaper.Block, -- statements block
})

-- Repeat statement.
aster.register('Repeat', {
  shaper.Block, -- statements block
  shaper.Node, -- expr
})

-- Numeric for statement.
aster.register('ForNum', {
  shaper.IdDecl, -- iterated var
  shaper.Node, -- begin expr
  shaper.one_of{"eq", "ne", "le", "lt", "ge", "gt"} + shaper.falsy, -- compare operator
  shaper.Node, -- end expr
  shaper.Node + shaper.falsy, -- increment expr
  shaper.Block, -- block
})

-- For in statement.
aster.register('ForIn', {
  shaper.array_of(shaper.IdDecl), -- iteration vars
  shaper.array_of(shaper.Node), -- in exprs
  shaper.Block, -- statements block
})

-- Break statement.
aster.register('Break', {})

-- Continue statement.
aster.register('Continue', {})

-- Label statement.
aster.register('Label', {
  name, -- label name
})

-- Goto statement.
aster.register('Goto', {
  name, -- label name
})

-- Variable declaration statement.
aster.register('VarDecl', {
  shaper.one_of{"local","global"}, -- scope
  shaper.array_of(shaper.IdDecl), -- var names with types
  shaper.array_of(shaper.Node) + shaper.falsy, -- exprs of initial values
})

-- Variable assignment statement.
aster.register('Assign', {
  shaper.array_of(shaper.Node), -- var exprs
  shaper.array_of(shaper.Node), -- values exprs
})

-- Function definition statement.
aster.register('FuncDef', {
  shaper.one_of{"local","global"} + shaper.falsy, -- scope
  shaper.IdDecl + shaper.Id + shaper.DotIndex + shaper.ColonIndex, -- name
  shaper.array_of(shaper.IdDecl + shaper.VarargsType), -- typed arguments
  shaper.array_of(shaper.Node) + shaper.falsy, -- typed returns
  shaper.array_of(shaper.Annotation) + shaper.falsy,
  shaper.Block, -- statements block
})

-- This is used only internally.
aster.register('Directive', {
  shaper.string, -- name
  shaper.table, -- arguments exprs
})
