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

function defs.to_chain_binary_op(pos, matches)
  local lhs = matches[1]
  for i=2,#matches,2 do
    local opname = matches[i]
    local rhs = matches[i+1]
    lhs = {tag="BinaryOp", pos=pos, opname, lhs, rhs}
  end
  return lhs
end

function defs.to_binary_op(pos, lhs, opname, rhs)
  if rhs then
    return {tag="BinaryOp", pos=pos, opname, lhs, rhs}
  end
  return lhs
end

function defs.to_chain_unary_op(pos, opnames, expr)
  for i=#opnames,1,-1 do
    local opname = opnames[i]
    expr = {tag="UnaryOp", pos=pos, opname, expr}
  end
  return expr
end

function defs.to_chain_index_or_call(pos, primary_expr, exprs)
  local last_expr = primary_expr
  if exprs then
    for _,expr in ipairs(exprs) do
      table.insert(expr, 1, last_expr)
      last_expr = expr
    end
  end
  return last_expr
end

function defs.to_tag(pos, tag, ...)
  return {tag=tag, pos=pos, ...}
end

function defs.to_retag(pos, tag, node)
  node.pos = pos
  node.tag = tag
  return node
end

function defs.to_nil() return nil end

local grammar = re.compile([==[
  code <-
    %SHEBANG? %SKIP
    ({} '' -> 'TopBlock' block ) -> to_retag
    (!. / %{ExpectedEOF})

  block <-
    ({} '' -> 'block' {| stat* return_stat? |}) -> to_retag

  stat <-
      if_stat
    / switch_stat
    / try_stat
    / throw_stat
    / do_stat
    / while_stat
    / repeat_stat
    / for_stat
    / break_stat
    / continue_stat
    / defer_stat
    / label_stat
    / goto_stat
    / vardecl_stat
    / functiondef_stat
    / call_stat
    / assignment_stat
    / %SEMICOLON

  return_stat <-
    ({} %RETURN -> 'Return' expr? %SEMICOLON?) -> to_tag

  if_stat <-
    ({} %IF -> 'If'
      {|
      {| expr_expected THEN_expected block |}
      ({| %ELSEIF expr_expected THEN_expected block |})*
      |} (%ELSE block)?
      END_expected
    ) -> to_tag

  switch_stat <-
    ({} %SWITCH -> 'Switch'
      expr_expected
      {|(
        ({| %CASE expr_expected THEN_expected
             block
        |})+ / %{ExpectedCase})
      |}
      (%ELSE block)?
      END_expected
    ) -> to_tag

  try_stat <-
    ({} %TRY -> 'Try'
        block
      {| (%CATCH
        %LPAREN
          NAME_expected
        RPAREN_expected
        block)* |}
      ((%CATCH block) / capture_nil)
      (%FINALLY block)?
    ) -> to_tag

  throw_stat <-
    ({} %THROW -> 'Throw' expr_expected) -> to_tag

  do_stat <-
    ({} %DO -> 'Do' block END_expected) -> to_retag

  while_stat <-
    ({} %WHILE -> 'While'
      expr_expected (%DO / %{ExpectedDo})
      block
      END_expected
    ) -> to_tag

  repeat_stat <-
    ({} %REPEAT -> 'Repeat'
      block
      %UNTIL expr_expected
    ) -> to_tag

  for_stat <-
    %FOR (for_num / for_in / %{ExpectedForRange})

  for_num <-
    ({} '' -> 'ForNum'
      %NAME '='
        expr_expected
      %COMMA (op_cmp / '' -> 'le')
        expr_expected
      (%COMMA expr_expected / capture_nil)
      (%DO / %{ExpectedDo})
        block
      END_expected
    ) -> to_tag

  for_in <- !. -- not implemented yet

  break_stat <-
    ({} %BREAK -> 'Break') -> to_tag

  continue_stat <-
    ({} %CONTINUE -> 'Continue') -> to_tag

  defer_stat <-
    ({} %DEFER -> 'Defer' block END_expected) -> to_retag

  label_stat <-
    ({} %DBLCOLON -> 'Label'
      NAME_expected
      (%DBLCOLON / %{UnclosedLabel})
    ) -> to_tag

  goto_stat <-
    ({} %GOTO -> 'Goto' NAME_expected ) -> to_tag

  vardecl_stat <-
    ({} '' -> 'VarDecl'
      {| (var_scope? var_type) / var_scope '' -> 'var' |}
      {| name_list |}
      (%ASSIGN (expr_list / %{ExpectedExpression}))?
    ) -> to_tag

  var_scope <-
    %LOCAL -> 'local' / %GLOBAL -> 'global' / %EXPORT -> 'export'

  var_type <-
    %VAR -> 'var' / %REF -> 'ref' / %LET -> 'let'

  functiondef_stat <-
    ({} '' -> 'FunctionDef' (var_scope / capture_nil)
      %FUNCTION
      NAME_expected
      (function_body / %{ExpectedFunctionBody})
    ) -> to_tag

  call_stat <-
    ({} primary_expr
        {| ((index_expr+ & call_expr) / call_expr)+ |}
    ) -> to_chain_index_or_call

  assignment_stat <-
    ({} '' -> 'Assign'
        var_list
        %ASSIGN
        (expr_list / %{ExpectedExpression})
    ) -> to_tag

  var_list <- {| (var (%COMMA var)*)? |}

  var <-
    ({}
      primary_expr
      {| ((call_expr+ & index_expr) / index_expr)+ |}
    ) -> to_chain_index_or_call
    / identifier

  simple_expr <-
      %NUMBER
    / %STRING
    / %BOOLEAN
    / nil
    / varargs
    / function
    / table
    / suffixed_expr
    / (%LPAREN expr RPAREN_expected)

  suffixed_expr <-
    ({}
      primary_expr
      {| (index_expr / call_expr)* |}
    ) -> to_chain_index_or_call

  primary_expr <-
    identifier /
    %LPAREN expr RPAREN_expected

  index_expr <-
    ({} %DOT -> 'DotIndex'
        NAME_expected
    ) -> to_tag
    /
    ({} %LBRACKET -> 'ArrayIndex'
        expr_expected
        (%RBRACKET / %{UnclosedBracket})
    ) -> to_tag

  call_expr <-
    ({} %COLON -> 'Invoke'
        NAME_expected
        (call_args / %{ExpectedCall})
    ) -> to_tag
    /
    ({} & %LPAREN '' -> 'Call' call_args ) -> to_tag

  call_args <-
    %LPAREN
      expr_list
    RPAREN_expected

  function <-
    ({} %FUNCTION -> 'Function'
        (function_body / %{ExpectedFunctionBody})
    ) -> to_tag

  function_body <-
    %LPAREN
      {| (name_list (%COMMA varargs)? / varargs)? |}
    RPAREN_expected
      block
    END_expected

  table <-
    ({} %LCURLY -> 'Table'
          table_field_list
        (%RCURLY / %{UnclosedCurly})
    ) -> to_tag

  table_field_list <-
    (table_field (%SEPARATOR table_field)* %SEPARATOR?)?

  table_field <- field_pair / expr

  field_pair <-
    ({} '' -> 'Pair' field_key
        %ASSIGN
        expr_expected
    ) -> to_tag

  field_key <-
    (   %LBRACKET
          expr_expected
        (%RBRACKET / %{UnclosedBracket})
      / %NAME
    ) & %ASSIGN

  identifier <- ({} '' -> 'Id' %NAME) -> to_tag
  name_list <- %NAME (%COMMA %NAME)*
  expr_list <- {| (expr (%COMMA expr)*)? |}
  varargs <- ({} %ELLIPSIS -> 'Ellipsis') -> to_tag
  nil <- ({} %NIL -> 'Nil') -> to_tag
  capture_nil <- '' -> to_nil
  expr_expected <- expr / %{ExpectedExpression}

  THEN_expected <- %THEN / %{ExpectedThen}
  END_expected <- %END / %{ExpectedEnd}
  NAME_expected <- %NAME / %{ExpectedName}
  RPAREN_expected <- %RPAREN / %{UnclosedParenthesis}

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
    local pos = #input - #suffix + 1
    local line, col = re.calcline(input, pos)
    local label = syntax_errors.int_to_label[errnum]
    local msg = syntax_errors.int_to_msg[errnum]
    return false, { line=line, col=col, label=label, message=msg }
  end
end

return parser
