local euluna_std_luacompat = require 'euluna.parsers.euluna_std_luacompat'

--------------------------------------------------------------------------------
-- AST definition
--------------------------------------------------------------------------------
local aster = euluna_std_luacompat.aster:clone()
local types = aster.types

aster:register('Switch', types.shape {
  types.ast.Node, -- switch expr
  types.array_of(types.shape{types.ast.Node, types.ast.Block}), -- case list {expr, block}
  types.ast.Block:is_optional() -- else block
})

aster:register('Continue', types.shape {})

aster:register('VarDecl', types.shape {
  types.one_of{"local"}:is_optional(), -- scope
  types.one_of{"var", "var&", "val", "val&"}, -- mutability
  types.array_of(types.ast.IdDecl), -- var names with types
  types.array_of(types.ast.Node):is_optional(), -- expr list, initial assignments values
})

--------------------------------------------------------------------------------
-- Lexer
--------------------------------------------------------------------------------
local parser = euluna_std_luacompat.parser:clone()
parser:set_aster(aster)
parser:add_keywords({
  -- euluna additional keywords
  "switch", "case", "continue", "var", "val"
})

--------------------------------------------------------------------------------
-- Grammar
--------------------------------------------------------------------------------

local grammar = euluna_std_luacompat.grammar:clone()
parser:set_peg('sourcecode', grammar:build())

grammar:add_group_peg('stat', 'vardecl', [[
  ({} '' -> 'VarDecl'
    ((var_scope (var_mutability / '' -> 'var')) / (cnil var_mutability))
    {| typed_idlist |}
    (%ASSIGN {| eexpr_list |})?
  ) -> to_astnode
]], nil, true)

grammar:add_group_peg('stat', 'switch', [[
  ({} %SWITCH -> 'Switch' eexpr
    {|(
      ({| %CASE eexpr eTHEN block |})+ / %{ExpectedCase})
    |}
    (%ELSE block)?
    eEND
  ) -> to_astnode
]])

grammar:add_group_peg('stat', 'continue', [[
  ({} %CONTINUE -> 'Continue') -> to_astnode
]])

parser:set_peg('sourcecode', grammar:build())

--------------------------------------------------------------------------------
-- Syntax Errors
--------------------------------------------------------------------------------

-- grammar errors
parser:add_syntax_errors({
  ExpectedCase = "expected `case` keyword"
})

return {
  aster = aster,
  parser = parser,
  grammar = grammar
}
