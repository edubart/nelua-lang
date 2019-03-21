local euluna_std_luacompat = require 'euluna.parsers.euluna_std_luacompat'

--------------------------------------------------------------------------------
-- AST definition
--------------------------------------------------------------------------------
local shaper = euluna_std_luacompat.shaper:clone()
local types = shaper.types

shaper:register('Switch', types.shape {
  types.ASTNode, -- switch expr
  types.array_of(types.shape{types.ASTNode, types.ASTBlock}), -- case list {expr, block}
  types.ASTBlock:is_optional() -- else block
})

shaper:register('Continue', types.shape {})

shaper:register('VarDecl', types.shape {
  types.one_of{"local"}:is_optional(), -- scope
  types.one_of{"var", "var&", "let", "let&", "const"}, -- mutability
  types.array_of(types.ASTTypedId), -- var names with types
  types.array_of(types.ASTNode):is_optional(), -- expr list, initial assignments values
})

--------------------------------------------------------------------------------
-- Lexer
--------------------------------------------------------------------------------
local parser = euluna_std_luacompat.parser:clone()
parser:set_shaper(shaper)
parser:add_keywords({
  -- euluna additional keywords
  "switch", "case", "continue", "var", "let", "const"
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

  var_mutability <-
    %TVAR %BAND -> 'var&' /
    %TVAR -> 'var' /
    %TLET %BAND -> 'let&' /
    %TLET -> 'let' /
    %TCONST -> 'const'
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
  shaper = shaper,
  parser = parser,
  grammar = grammar
}
