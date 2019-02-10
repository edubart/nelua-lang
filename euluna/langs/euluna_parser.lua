require 'compat53'

local parser = require 'euluna.langs.euluna_lexer'
local to_astnode = require 'euluna.astnodes'.to_astnode

-- statements
parser:add_statement('stat_break',[[
  ({} %BREAK -> 'Stat_Break') -> to_astnode
]])

-- expected closing characters
parser:set_pegs([[
  %eRPAREN    <- %RPAREN    / %{UnclosedParenthesis}
  %eRBRACKET  <- %RBRACKET  / %{UnclosedBracket}
  %ecNAME     <- %cNAME     / %{ExpectedName}
]])

-- expressions
parser:set_pegs([[
  %expr     <- expr0
  eexpr     <- expr / %{ExpectedExpression}

  expr0     <- ({} {| expr1  (%IF -> 'if' expr1 %ELSE expr1)* |}) -> to_chain_ternary_op
  expr1     <- ({} {| expr2  (op_or       expr2 )* |})            -> to_chain_binary_op
  expr2     <- ({} {| expr3  (op_and      expr3 )* |})            -> to_chain_binary_op
  expr3     <- ({} {| expr4  (op_cmp      expr4 )* |})            -> to_chain_binary_op
  expr4     <- ({} {| expr5  (op_bor      expr5 )* |})            -> to_chain_binary_op
  expr5     <- ({} {| expr6  (op_xor      expr6 )* |})            -> to_chain_binary_op
  expr6     <- ({} {| expr7  (op_band     expr7 )* |})            -> to_chain_binary_op
  expr7     <- ({} {| expr8  (op_bshift   expr8 )* |})            -> to_chain_binary_op
  expr8     <- ({}    expr9  (op_concat   expr8 )?   )            -> to_binary_op
  expr9     <- ({} {| expr10 (op_add      expr10)* |})            -> to_chain_binary_op
  expr10    <- ({} {| expr11 (op_mul      expr11)* |})            -> to_chain_binary_op
  expr11    <- ({} {| op_unary* |} expr12)                        -> to_chain_unary_op
  expr12    <- ({}    simple_expr (op_pow      expr11)?   )       -> to_binary_op

  simple_expr <-
      %cNUMBER
    / %cSTRING
    / %cBOOLEAN
    / %cNIL
    / %cVARARGS
    / suffixed_expr

  suffixed_expr <- (primary_expr {| index_expr* |}) -> to_chain_index

  primary_expr <-
    %cID /
    %LPAREN eexpr %eRPAREN

  index_expr <-
    {| {} %DOT -> 'DotIndex' %ecNAME |} /
    {| {} %LBRACKET -> 'ArrayIndex' eexpr %eRBRACKET |}

  op_or     <- %OR -> 'or'
  op_and    <- %AND -> 'and'
  op_cmp    <- %LT -> 'lt' /
               %NE -> 'ne' /
               %GT -> 'gt' /
               %LE -> 'le' /
               %GE -> 'ge' /
               %EQ -> 'eq'

  op_bor    <- %BOR -> 'bor'
  op_xor    <- %BXOR -> 'bxor'
  op_band   <- %BAND -> 'band'
  op_bshift <- %SHL -> 'shl' /
               %SHR -> 'shr'
  op_concat <- %CONCAT -> 'concat'
  op_add    <- %ADD -> 'add' /
               %SUB -> 'sub'
  op_mul    <- %MUL -> 'mul' /
               %DIV -> 'div' /
               %MOD -> 'mod'
  op_unary  <- %NOT -> 'not' /
               %LEN -> 'len' /
               %NEG -> 'neg' /
               %BNOT -> 'bnot' /
               %TOSTRING -> 'tostring'
  op_pow   <-  %POW -> 'pow'
]], {
  to_chain_unary_op = function(pos, opnames, expr)
    for i=#opnames,1,-1 do
      local opname = opnames[i]
      expr = to_astnode(pos, "UnaryOp", opname, expr)
    end
    return expr
  end,

  to_binary_op = function(pos, lhs, opname, rhs)
    if rhs then
      return to_astnode(pos, "BinaryOp", opname, lhs, rhs)
    end
    return lhs
  end,

  to_chain_binary_op = function(pos, matches)
    local lhs = matches[1]
    for i=2,#matches,2 do
      local opname, rhs = matches[i], matches[i+1]
      lhs = to_astnode(pos, "BinaryOp", opname, lhs, rhs)
    end
    return lhs
  end,

  to_chain_ternary_op = function(pos, matches)
    local lhs = matches[1]
    for i=2,#matches,3 do
      local opname, mid, rhs = matches[i], matches[i+1], matches[i+2]
      lhs = to_astnode(pos, "TernaryOp", opname, lhs, mid, rhs)
    end
    return lhs
  end,

  to_chain_index = function(primary_expr, exprs)
    local last_expr = primary_expr
    if exprs then
      for _,expr in ipairs(exprs) do
        table.insert(expr, last_expr)
        last_expr = to_astnode(table.unpack(expr))
      end
    end
    return last_expr
  end
})

-- source code body
parser:set_pegs([==[
  %stat_return <-
    ({} %RETURN -> 'Stat_Return' {| (%expr (%COMMA %expr)*)? |} %SEMICOLON?) -> to_astnode

  %block <-
    ({} '' -> 'Block' {| (%statement / %SEMICOLON)* %stat_return? |}) -> to_astnode

  %sourcecode <-
    %SHEBANG? %SKIP
    %block
    (!. / %{UnexpectedSyntaxAtEOF})
]==])

-- syntax errors
parser:add_syntax_errors({
  UnexpectedSyntaxAtEOF  = 'unexpected syntax, was expecting EOF'
})

return parser
