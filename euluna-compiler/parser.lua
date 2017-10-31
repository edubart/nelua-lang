local parser = {}

require 'euluna-compiler.global'
local lpeg = require "lpeglabel"
local re = require "relabel"
local lexer = require "euluna-compiler.lexer"
local syntax_errors = require "euluna-compiler.syntax_errors"
local inspect = require "inspect"
local tablex = require "pl.tablex"

re.setlabels(syntax_errors.label_to_int)

local defs = tablex.copy(lexer)

function defs.to_nil(pos) return {tag='nil', pos=pos} end
function defs.to_ellipsis(pos) return {tag='ellipsis', pos=pos} end

function defs.to_identifier(pos, name)
  return {tag = 'identifier', pos=pos, name=name}
end

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
  return { tag='Return', pos=pos, expr=expr }
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

function defs.to_chain_index_or_call(pos, primary_expr, exprs)
  local last_expr = primary_expr
  if exprs then
    for _,expr in ipairs(exprs) do
      expr.what = last_expr
      last_expr = expr
    end
  end
  return last_expr
end

function defs.to_dot_index(pos, index)
  return {tag="dot_index", pos=pos, index=index}
end

function defs.to_array_index(pos, index)
  return {tag="array_index", pos=pos, index=index}
end

function defs.to_invoke(pos, name, args)
  return {tag='Invoke', pos=pos, name=name, args=args}
end

function defs.to_call(pos, args)
  return {tag='Call', pos=pos, args=args}
end

function defs.to_field_pair(pos, key, expr)
  return {tag='pair',pos=pos,key=key,expr=expr}
end

function defs.to_table(pos, fields)
  return {tag='table',pos=pos,fields=fields}
end

function defs.to_anonymous_function(pos, args, body)
  return {tag='anonymous_function',pos=pos,args=args,body=body}
end

local grammar = re.compile([==[
  code <-
    %SHEBANG? %SKIP
    ({} block) -> to_main_block
    (!. / %{ExpectedEOF})

  block <-
    ({} {| stat* return_stat? |}) ->  to_block

  stat <-
    -- if
    -- do
    -- while
    -- break
    -- label
    -- goto
      call_stat
    / assignment_stat
    / %SEMICOLON

  return_stat <-
    ({} %RETURN expr? %SEMICOLON?) -> to_return_stat

  call_stat <-
    ({}
      primary_expr
      {| ((index_expr+ & call_expr) / call_expr)+ |}
    )                                                 -> to_chain_index_or_call

  assignment_stat <-
    !. .

  simple_expr <-
      %NUMBER
    / %STRING
    / %BOOLEAN
    / nil
    / varargs
    / function
    / table
    / suffixed_expr
    / (%LPAREN expr %RPAREN)

  suffixed_expr <-
    ({}
      primary_expr
      {| (index_expr / call_expr)* |}
    )                                                 -> to_chain_index_or_call

  primary_expr <-
    identifier /
    %LPAREN expr (%RPAREN / %{UnclosedParenthesis})

  index_expr <-
      ({} %DOT
        (%NAME / %{ExpectedIdentifier})
      )                                               -> to_dot_index
    / ({}
        %LBRACKET
        expr
        (%RBRACKET / %{UnclosedBracket})
      )                                               -> to_array_index

  call_expr <-
      ({}
        %COLON
        (%NAME / %{ExpectedMethodIdentifier})
        (call_args / %{ExpectedCall})
      )                                               -> to_invoke
    / ({} call_args )                                 -> to_call

  call_args <- %LPAREN expr_list (%RPAREN / %{UnclosedParenthesis})
  expr_list <- {| (expr (%COMMA expr)*)? |}

  function <-
    ({} %FUNCTION
      (function_body / %{ExpectedFunctionBody})
    )                                                 -> to_anonymous_function

  function_body <-
    %LPAREN
      body_args_list
    (%RPAREN / %{UnclosedParenthesis})
      block
    (%END / %{UnclosedFunction})

  body_args_list <-
    {|
      (identifier (%COMMA identifier)* (%COMMA varargs)?
       / varargs)?
    |}

  table <-
    ({}
      %LCURLY
        table_field_list
      (%RCURLY / %{UnclosedCurly})
    )                                                 -> to_table

  table_field_list <-
    {| (table_field (%SEPARATOR table_field)* %SEPARATOR?)? |}

  table_field <- field_pair / expr

  field_pair <-
    ({}
      field_key
      %ASSIGN
      (expr / %{ExpectedExpression})
    )                                                 -> to_field_pair

  field_key <-
    (   %LBRACKET
          (expr / %{ExpectedExpression})
        (%RBRACKET / %{UnclosedBracket})
      / %NAME
    ) & %ASSIGN

  identifier <- ({} %NAME)                -> to_identifier
  varargs <- ({} %ELLIPSIS)               -> to_ellipsis
  nil <- ({} %NIL)                        -> to_nil

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

]==], defs)

function parser.parse(input)
  lpeg.setmaxstack(1000)
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
