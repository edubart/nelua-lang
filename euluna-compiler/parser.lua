local parser = {}

require 'euluna-compiler.global'
local lpeg = require "lpeglabel"
local re = require "relabel"
local ast = require "euluna-compiler.ast"
local lexer = require "euluna-compiler.lexer"
local syntax_errors = require "euluna-compiler.syntax_errors"
local inspect = require "inspect"
local tablex = require "pl.tablex"

re.setlabels(syntax_errors.label_to_int)

local defs = tablex.copy(lexer)

function defs.to_nil(pos) return {tag='nil', pos=pos} end
function defs.to_ellipsis(pos) return {tag='ellipsis', pos=pos} end

function defs.to_main_block(pos, block)
  block.tag = 'top_block'
  block.pos = pos
  return block
end

function defs.to_block(pos, block)
  block.tag = 'block'
  block.pos = pos
  return block
end

function defs.to_return_stat(pos, expr)
  return { tag='return_stat', pos=pos, expr=expr }
end

function defs.to_chain_binary_op(pos, matches)
  local lhs = matches[1]
  for i=2,#matches,2 do
    local opname = matches[i]
    local rhs = matches[i+1]
    lhs = {tag="binary_op", pos=pos, lhs=lhs, op=opname, rhs=rhs}
  end
  return lhs
end

function defs.to_binary_op(pos, lhs, opname, rhs)
  if rhs then
    return {tag="binary_op", pos=pos, lhs=lhs, op=opname, rhs=rhs}
  end
  return lhs
end

function defs.to_chain_unary_op(pos, opnames, expr)
  for i=#opnames,1,-1 do
    local opname = opnames[i]
    expr = {tag="unary_op", pos=pos, op=opname, expr=expr}
  end
  return expr
end

function defs.to_chain_index_or_call(pos, identifier, exprs)
  if exprs then
    local folded_expr = exprs[#exprs]
    for i=#exprs-1,1,-1 do
      local expr = matches[i]
      expr.expr = folded_expr
      folded_expr = expr
    end
    identifier.expr = folded_expr
  end
  return identifier
end

function defs.to_dot_index(pos, name)
  return {tag="dot_index", pos=pos, name=name}
end

function defs.to_array_index(pos, expr)
  return {tag="array_index", pos=pos, expr=expr}
end

function defs.to_method_call(pos, name, args)
  return {tag='method_call', pos=pos, name=name, args=args}
end

function defs.to_call(pos, name, args)
  return {tag='call', pos=pos, args=args}
end

local grammar = re.compile([==[
  code <-
    %SHEBANG? %SKIP
    ({} block) -> to_main_block
    (!. / %{ExpectedEOF})

  block <-
    ({} {| stat* return_stat? |}) ->  to_block

  stat <-
    %SEMICOLON
    -- funccall
    / (!blockend %{InvalidStatement})

  blockend <-
    %RETURN / !.

  return_stat <-
    ({} %RETURN expr? %SEMICOLON?) -> to_return_stat

  expr      <- expr1
  expr1     <- ({} {| expr2  (op_or       expr2 )* |})   -> to_chain_binary_op
  expr2     <- ({} {| expr3  (op_and      expr3 )* |})   -> to_chain_binary_op
  expr3     <- ({} {| expr4  (op_cmp      expr4 )* |})   -> to_chain_binary_op
  expr4     <- ({} {| expr5  (op_bor      expr5 )* |})   -> to_chain_binary_op
  expr5     <- ({} {| expr6  (op_xor      expr6 )* |})   -> to_chain_binary_op
  expr6     <- ({} {| expr7  (op_band     expr7 )* |})   -> to_chain_binary_op
  expr7     <- ({} {| expr8  (op_bshift   expr8 )* |})   -> to_chain_binary_op
  expr8     <- ({}    expr9  (op_concat   expr8 )?   )   -> to_binary_op
  expr9     <- ({} {| expr10 (op_add      expr10)* |})   -> to_chain_binary_op
  expr10    <- ({} {| expr11 (op_mul      expr11)* |})   -> to_chain_binary_op
  expr11    <- ({} {| op_unary* |} expr12)               -> to_chain_unary_op
  expr12    <- ({} simple_expr (op_pow expr11)?)         -> to_binary_op

  simple_expr <-
      (%NUMBER)
    / (%STRING)
    / (%BOOLEAN)
    / ({} %NIL)                                           -> to_nil
    / ({} %ELLIPSIS)                                      -> to_ellipsis
    -- function
    -- table
    / suffixed_expr
    / (%LPAREN expr %RPAREN)

  suffixed_expr <-
    ({}
      %IDENTIFIER
      (index_expr / call_expr)*
    )                                                -> to_chain_index_or_call

  index_expr <-
      ({} %DOT
        (%IDENTIFIER / %{ExpectedIdentifier})
      )                                              -> to_dot_index
    / ({}
        %LBRACKET
        expr
        (%RBRACKET / %{UnclosedBracket})
      )                                              -> to_array_index

  call_expr <-
      ({}
        %COLON
        (%IDENTIFIER / %{ExpectedMethodIdentifier})
        (call_args / %{ExpectedCall})
      )                                               -> to_method_call
    / ({} call_args )                                 -> to_call

  call_args <- %LPAREN expr_list (%RPAREN / %{UnclosedParenthesis})
  expr_list <- {| (expr (%COMMA expr)*)? |}

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
               %IDIV -> 'idiv' /
               %MOD -> 'mod'
  op_unary  <- %NOT -> 'not' /
               %LEN -> 'len' /
               %NEG -> 'neg' /
               %BNOT -> 'bnot'
  op_pow   <-  %POW -> 'pow'

]==], defs)

function parser.parse(input)
  local ast, errnum, suffix = grammar:match(input)
  if ast then
    return ast
  else
    if errnum and suffix then
      local pos = #input - #suffix + 1
      local line, col = re.calcline(input, pos)
      local label = syntax_errors.int_to_label[errnum]
      local msg = syntax_errors.int_to_msg[errnum]
      return false, { line=line, col=col, label=label, message=msg }
    else
      return false, "ast was nil"
    end
  end
end

return parser
