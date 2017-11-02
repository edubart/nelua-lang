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
  block.tag = 'TopBlock'
  block.pos = pos
  return block
end

function defs.to_block(pos, block)
  block.tag = 'block'
  block.pos = pos
  return block
end

function defs.to_do(block)
  block.tag = 'Do'
  return block
end

function defs.to_while(pos, cond_expr, block)
  return {tag='While', pos=pos, cond_expr=cond_expr, block=block}
end

function defs.to_repeat(pos, block, cond_expr)
  return {tag='Repeat', pos=pos, cond_expr=cond_expr, block=block}
end

function defs.to_if_stat(pos, ifparts, elseblock)
  local ifs = {}
  for i=1,math.floor(#ifparts / 2) do
    ifs[i] = {cond=ifparts[i*2-1], block=ifparts[i*2]}
  end
  return {tag="If", pos=pos, ifs=ifs, elseblock=elseblock}
end

function defs.to_for_num(pos, identifier, begin_expr, cmp_op, end_expr, add_expr, block)
  return {tag="ForNum", pos=pos, id=identifier, block=block,
          begin_expr=begin_expr, end_expr=end_expr, add_expr=add_expr,
          cmp_op=cmp_op}
end

function defs.to_return_stat(pos, expr)
  return { tag='Return', pos=pos, expr=expr }
end

function defs.to_chain_binary_op(pos, matches)
  local lhs = matches[1]
  for i=2,#matches,2 do
    local opname = matches[i]
    local rhs = matches[i+1]
    lhs = {tag="BinaryOp", pos=pos, lhs=lhs, op=opname, rhs=rhs}
  end
  return lhs
end

function defs.to_binary_op(pos, lhs, opname, rhs)
  if rhs then
    return {tag="BinaryOp", pos=pos, lhs=lhs, op=opname, rhs=rhs}
  end
  return lhs
end

function defs.to_chain_unary_op(pos, opnames, expr)
  for i=#opnames,1,-1 do
    local opname = opnames[i]
    expr = {tag="UnaryOp", pos=pos, op=opname, expr=expr}
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
  return {tag="DotIndex", pos=pos, index=index}
end

function defs.to_array_index(pos, index)
  return {tag="ArrayIndex", pos=pos, index=index}
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
  return {tag='Table',pos=pos,fields=fields}
end

function defs.to_function(pos, args, body)
  return {tag='Function',pos=pos,args=args,body=body}
end

function defs.to_function_def(pos, identifier, args, body)
  return {tag='FunctionDef',pos=pos,name=identifier.name,args=args,body=body}
end

function defs.to_assign(pos, vars, exprs)
  return {tag='Assign', pos=pos, vars=vars, assigns=exprs}
end

function defs.to_assign_def(pos, vars, exprs)
  local vardecls = {}
  for i,var in ipairs(vars) do
    vardecls[i] = vars[i].name
  end
  return {tag='AssignDef', pos=pos, vars=vardecls, assigns=exprs}
end

function defs.to_decl(pos, vars)
  local vardecls = {}
  for i,var in ipairs(vars) do
    vardecls[i] = vars[i].name
  end
  return {tag='Decl', pos=pos, vars=vardecls}
end

function defs.to_local(node)
  node.varscope = 'local'
  return node
end

function defs.to_continue() return {tag='Continue'} end
function defs.to_break() return {tag='Break'} end

function defs.to_nothing() return nil end

function defs.assign_vartype(varscope, vartype, node)
  node.varscope = varscope
  node.vartype = vartype
  return node
end

function defs.assign_funcscope(varscope, node)
  node.varscope = varscope
  return node
end


local grammar = re.compile([==[
  code <-
    %SHEBANG? %SKIP
    ({} block) -> to_main_block
    (!. / %{ExpectedEOF})

  block <-
    ({} {| stat* return_stat? |}) -> to_block

  stat <-
      if_stat
    / do_stat
    / while_stat
    / repeat_stat
    / for_stat
    / break_stat
    / continue_stat
    / vars_stat
    / function_stat
    / call_stat
    / assignment_stat
    / %SEMICOLON

  if_stat <-
    ({}
      {|
      %IF (expr / %{ExpectedExpression}) (%THEN / %{ExpectedThen}) block
      (%ELSEIF (expr / %{ExpectedExpression}) (%THEN / %{ExpectedThen}) block)*
      |} (%ELSE block)?
      (%END / %{ExpectedEnd})
    ) -> to_if_stat

  do_stat <-
    (%DO block (%END / %{ExpectedEnd})) -> to_do

  while_stat <-
    ({}
      %WHILE (expr / %{ExpectedExpression}) (%DO / %{ExpectedDo})
      block
      (%END / %{ExpectedEnd})
    ) -> to_while

  repeat_stat <-
    ({}
      %REPEAT
      block
      %UNTIL (expr / %{ExpectedExpression})
    ) -> to_repeat

  break_stat <-
    %BREAK -> to_break

  continue_stat <-
    %CONTINUE -> to_continue

  for_stat <-
    %FOR (for_num / for_in / %{ExpectedForRange})

  for_num <-
    ({}
      identifier '='
        (expr / %{ExpectedExpression})
      %COMMA (op_cmp / '' -> 'le')
        (expr / %{ExpectedExpression})
      (%COMMA (expr / %{ExpectedExpression}) / capture_nil)
      (%DO / %{ExpectedDo})
        block
      (%END / %{ExpectedEnd})
    ) -> to_for_num

  for_in <- !. -- not implemented yet

  vars_stat <-
    ((var_scope (var_type / capture_nil) / capture_nil var_type)
      (vars_def / vars_decl)
    ) -> assign_vartype

  var_scope <-
    %LOCAL -> 'local' / %GLOBAL -> 'global'

  var_type <-
    %VAR -> 'var' / %REF -> 'ref' / %LET -> 'let'

  function_stat <-
    ((var_scope / capture_nil)
      function_def
    ) -> assign_funcscope

  function_def <-
    ({} %FUNCTION
        (identifier / %{ExpectedIdentifier})
        (function_body / %{ExpectedFunctionBody})
    ) -> to_function_def

  vars_def <-
    ({} {| identifier_list |}
        %ASSIGN
        (expr_list / %{ExpectedExpression})
    ) -> to_assign_def

  vars_decl <-
    ({} {| identifier_list |}
    ) -> to_decl

  return_stat <-
    ({} %RETURN expr? %SEMICOLON?
    ) -> to_return_stat

  call_stat <-
    ({} primary_expr
        {| ((index_expr+ & call_expr) / call_expr)+ |}
    ) -> to_chain_index_or_call

  assignment_stat <-
    ({} var_list
        %ASSIGN
        (expr_list / %{ExpectedExpression})
    ) -> to_assign

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
    / (%LPAREN expr %RPAREN)

  suffixed_expr <-
    ({}
      primary_expr
      {| (index_expr / call_expr)* |}
    ) -> to_chain_index_or_call

  primary_expr <-
    identifier /
    %LPAREN expr (%RPAREN / %{UnclosedParenthesis})

  index_expr <-
    ({} %DOT
        (%NAME / %{ExpectedIdentifier})
    ) -> to_dot_index
    /
    ({} %LBRACKET
        expr
        (%RBRACKET / %{UnclosedBracket})
    ) -> to_array_index

  call_expr <-
    ({} %COLON
        (%NAME / %{ExpectedMethodIdentifier})
        (call_args / %{ExpectedCall})
    ) -> to_invoke
    /
    ({} call_args ) -> to_call

  call_args <-
    %LPAREN
      expr_list
    (%RPAREN / %{UnclosedParenthesis})

  function <-
    ({} %FUNCTION
        (function_body / %{ExpectedFunctionBody})
    ) -> to_function

  function_body <-
    %LPAREN
      body_args_list
    (%RPAREN / %{UnclosedParenthesis})
      block
    (%END / %{UnclosedFunction})

  body_args_list <-
    {| (identifier_list (%COMMA varargs)? / varargs)? |}

  table <-
    ({} %LCURLY
          table_field_list
        (%RCURLY / %{UnclosedCurly})
    ) -> to_table

  table_field_list <-
    {| (table_field (%SEPARATOR table_field)* %SEPARATOR?)? |}

  table_field <- field_pair / expr

  field_pair <-
    ({} field_key
        %ASSIGN
        (expr / %{ExpectedExpression})
    ) -> to_field_pair

  field_key <-
    (   %LBRACKET
          (expr / %{ExpectedExpression})
        (%RBRACKET / %{UnclosedBracket})
      / %NAME
    ) & %ASSIGN

  identifier_list <- identifier (%COMMA identifier)*
  expr_list <- {| (expr (%COMMA expr)*)? |}
  identifier <- ({} %NAME) -> to_identifier
  varargs <- ({} %ELLIPSIS) -> to_ellipsis
  nil <- ({} %NIL) -> to_nil
  capture_nil <- '' -> to_nothing

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
