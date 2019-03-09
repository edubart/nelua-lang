local Shaper = require 'euluna.shaper'
local Parser = require 'euluna.parser'
local Grammar = require 'euluna.grammar'

--------------------------------------------------------------------------------
-- AST definition
--------------------------------------------------------------------------------

local shaper = Shaper()
local types = shaper.types

-- primitives
shaper:register('Number', types.shape {
  types.one_of{"int", "dec", "bin", "exp", "hex"}, -- type
  types.string + types.table, -- value, (table used in exp values)
  types.string:is_optional() -- literal
})
shaper:register('String', types.shape {
  types.string, -- value
  types.string:is_optional() -- literal
})
shaper:register('Boolean', types.shape {
  types.boolean, -- true or false
})
shaper:register('Nil', types.shape {})
shaper:register('Varargs', types.shape {})

-- table
shaper:register('Table', types.shape {
  types.array_of(types.ASTNode) -- pair or exprs
})
shaper:register('Pair', types.shape {
  types.ASTNode + types.string, -- field name (an expr or a string)
  types.ASTNode -- field value expr
})

-- function
shaper:register('Function', types.shape {
  types.array_of(types.ASTNode), -- typed arguments
  types.array_of(types.ASTNode), -- typed returns
  types.ASTNode -- block
})

-- identifier and types
shaper:register('Id', types.shape {
  types.string, -- name
})
shaper:register('Type', types.shape {
  types.string, -- type
})
shaper:register('TypedId', types.shape {
  types.string, -- name
  types.ASTType:is_optional(), -- type
})

-- indexing
shaper:register('DotIndex', types.shape {
  types.string, -- name
  types.ASTNode -- expr
})
shaper:register('ColonIndex', types.shape {
  types.string, -- name
  types.ASTNode -- expr
})
shaper:register('ArrayIndex', types.shape {
  types.ASTNode, -- index expr
  types.ASTNode -- expr
})

-- calls
shaper:register('Call', types.shape {
  types.array_of(types.ASTType), -- call types
  types.array_of(types.ASTNode), -- args exprs
  types.ASTNode, -- caller expr
  types.boolean:is_optional(), -- is called from a block
})
shaper:register('CallMethod', types.shape {
  types.string, -- method name
  types.array_of(types.ASTType), -- call types
  types.array_of(types.ASTNode), -- args exprs
  types.ASTNode, -- caller expr
  types.boolean:is_optional(), -- is called from a block
})

-- block
shaper:register('Block', types.shape {
  types.array_of(types.ASTNode) -- statements
})

-- statements
shaper:register('Return', types.shape {
  types.array_of(types.ASTNode) -- returned exprs
})
shaper:register('If', types.shape {
  types.array_of(types.shape{types.ASTNode, types.ASTBlock}), -- if list {expr, block}
  types.ASTBlock:is_optional() -- else block
})
shaper:register('Switch', types.shape {
  types.ASTNode, -- switch expr
  types.array_of(types.shape{types.ASTNode, types.ASTBlock}), -- case list {expr, block}
  types.ASTBlock:is_optional() -- else block
})
shaper:register('Do', types.shape {
  types.ASTBlock -- block
})
shaper:register('While', types.shape {
  types.ASTNode, -- expr
  types.ASTBlock -- block
})
shaper:register('Repeat', types.shape {
  types.ASTBlock, -- block
  types.ASTNode -- expr
})
shaper:register('ForNum', types.shape {
  types.ASTTypedId, -- iterated var
  types.ASTNode, -- begin expr
  types.string, -- compare operator
  types.ASTNode, -- end expr
  types.ASTNode:is_optional(), -- increment expr
  types.ASTBlock, -- block
})
shaper:register('ForIn', types.shape {
  types.array_of(types.ASTTypedId), -- iterated vars
  types.array_of(types.ASTNode), -- in exprlist
  types.ASTBlock -- block
})
shaper:register('Break', types.shape {})
shaper:register('Continue', types.shape {})
shaper:register('Label', types.shape {
  types.string -- label name
})
shaper:register('Goto', types.shape {
  types.string -- label name
})
shaper:register('VarDecl', types.shape {
  types.string:is_optional(), -- scope (local)
  types.string, -- mutability (var&/var/let&/let/const)
  types.array_of(types.ASTTypedId), -- var names with types
  types.array_of(types.ASTNode):is_optional(), -- expr list, initial assignments values
})
shaper:register('Assign', types.shape {
  types.array_of(types.ASTNode), -- expr list, assign variables
  types.array_of(types.ASTNode), -- expr list, assign values
})
shaper:register('FuncDef', types.shape {
  types.string:is_optional(), -- scope (local)
  types.ASTId + types.ASTDotIndex + types.ASTColonIndex, -- name
  types.array_of(types.ASTNode), -- typed arguments
  types.array_of(types.ASTNode), -- typed returns
  types.ASTNode -- block
})

-- operations
shaper:register('UnaryOp', types.shape {
  types.string, -- type
  types.ASTNode -- right expr
})
shaper:register('BinaryOp', types.shape {
  types.string, -- type
  types.ASTNode, --- left expr
  types.ASTNode -- right expr
})
shaper:register('TernaryOp', types.shape {
  types.string, -- type
  types.ASTNode, -- left expr
  types.ASTNode, -- middle expr
  types.ASTNode -- right expr
})


--------------------------------------------------------------------------------
-- Lexer
--------------------------------------------------------------------------------

local parser = Parser(shaper)

-- spaces including new lines
parser:set_peg("SPACE", "%s")

-- all new lines formats CR CRLF LF LFCR
parser:set_peg("LINEBREAK", "[%nl]'\r' / '\r'[%nl] / [%nl] / '\r'")

-- shebang, e.g. "#!/usr/bin/euluna"
parser:set_peg("SHEBANG", "'#!' (!%LINEBREAK .)*")

-- multiline and single line comments
parser:set_pegs([[
  %LONGCOMMENT  <- open (contents close / %{UnclosedLongComment})
  contents      <- (!close .)*
  open          <- '--[' {:eq: '='*:} '['
  close         <- ']' =eq ']'

  %SHORTCOMMENT <- '--' (!%LINEBREAK .)* %LINEBREAK?
  %COMMENT <- %LONGCOMMENT / %SHORTCOMMENT
]])

-- skip any code not relevant (spaces, new lines and comments), usually matched after any TOKEN
parser:set_peg('SKIP', "(%SPACE / %COMMENT)*")

-- identifier prefix, letter or _ character
parser:set_peg('IDPREFIX', '[_%a]')
-- identifier suffix, alphanumeric or _ character
parser:set_peg('IDSUFFIX', '[_%w]')
-- identifier full format (prefix + suffix)
parser:set_peg('IDFORMAT', '%IDPREFIX %IDSUFFIX*')

-- language keywords
parser:add_keywords({
  -- lua keywords
  "and", "break", "do", "else", "elseif", "end", "for", "false",
  "function", "goto", "if", "in", "local", "nil", "not", "or",
  "repeat", "return", "then", "true", "until", "while",

  -- euluna additional keywords
  "switch", "case", "continue", "var", "let", "const"
})

-- names and identifiers (names for variables, functions, etc)
parser:set_token_peg('NAME', '&%IDPREFIX !%KEYWORD %IDFORMAT')
parser:set_token_peg('cNAME', '&%IDPREFIX !%KEYWORD {%IDFORMAT}')
parser:set_token_peg('cID', "({} &%IDPREFIX !%KEYWORD '' -> 'Id' {%IDFORMAT}) -> to_astnode")

-- capture numbers (hexdecimal, binary, exponential, decimal or integer)
parser:set_token_pegs([[
  %cNUMBER        <- ({} '' -> 'Number' number_types literal?) -> to_astnode
  number_types    <- '' -> 'hex' hexadecimal /
                     '' -> 'bin' binary /
                     '' -> 'exp' exponential /
                     '' -> 'dec' decimal /
                     '' -> 'int' integer
  literal         <- %cNAME
  exponential     <- {| (decimal / integer) [eE] ({[+-]? %d+} / %{MalformedExponentialNumber}) |}
  decimal         <- {'-'? %d+ '.' %d* / '.' %d+}
  integer         <- {'-'? %d+}
  binary          <- '0' [bB] ({[01]+} !%d / %{MalformedBinaryNumber})
  hexadecimal     <- '0' [xX] ({%x+} / %{MalformedHexadecimalNumber})
]])

-- escape sequence conversion
local BACKLASHES_SPECIFIERS = {
  ["a"] = "\a", -- audible bell
  ["b"] = "\b", -- back feed
  ["f"] = "\f", -- form feed
  ["n"] = "\n", -- new line
  ["r"] = "\r", -- carriege return
  ["t"] = "\t", -- horizontal tab
  ["v"] = "\v", -- vertical tab
  ["\\"] = "\\", -- backslash
  ["'"] = "'", -- single quote
  ['"'] = '"', -- double quote
}
parser:set_pegs([[
  %cESCAPESEQUENCE   <- {~ '\' -> '' escapings ~}
  escapings         <-
    [abfnrtv\'"] -> specifier2char /
    %LINEBREAK -> ln2ln /
    ('z' %s*) -> '' /
    (%d %d^-2) -> num2char /
    ('x' {%x+}) -> hex2char /
    ('u' '{' {%x+} '}') -> hex2unicode /
    %{MalformedEscapeSequence}
]], {
  num2char = function(s) return string.char(tonumber(s)) end,
  hex2char = function(s) return string.char(tonumber(s, 16)) end,
  hex2unicode = function(s) return (utf8 and utf8.char or string.char)(tonumber(s, 16)) end,
  specifier2char = function(s) return BACKLASHES_SPECIFIERS[s] end,
  ln2ln = function() return "\n" end,
})

-- capture long or short strings
parser:set_token_pegs([[
  %cSTRING        <- ({} '' -> 'String' (short_string / long_string) literal?) -> to_astnode
  short_string    <- short_open ({~ short_content* ~} short_close / %{UnclosedShortString})
  short_content   <- %cESCAPESEQUENCE / !(=de / %LINEBREAK) .
  short_open      <- {:de: ['"] :}
  short_close     <- =de
  long_string     <- long_open ({long_content*} long_close / %{UnclosedLongString})
  long_content    <- !long_close .
  long_open       <- '[' {:eq: '='*:} '[' %LINEBREAK?
  long_close      <- ']' =eq ']'
  literal         <- %cNAME
]])

-- capture boolean (true or false)
parser:set_token_pegs([[
  %cBOOLEAN <- ({} '' -> 'Boolean' ((%FALSE -> to_false) / (%TRUE -> to_true))) -> to_astnode
]], {
  to_false = function() return false end,
  to_true = function() return true end
})

--- capture nil values
parser:set_token_pegs([[
  %cNIL <- ({} %NIL -> 'Nil') -> to_astnode
]])

-- tokened symbols
parser:set_token_pegs([[
-- binary operators
%ADD          <- '+'
%SUB          <- !'--' '-'
%MUL          <- '*'
%MOD          <- '%'
%DIV          <- '/'
%POW          <- '^'
%BAND         <- '&'
%BOR          <- '|'
%SHL          <- '<<'
%SHR          <- '>>'
%EQ           <- '=='
%NE           <- '~=' / '!='
%LE           <- '<='
%GE           <- '>='
%LT           <- !%SHL !%LE '<'
%GT           <- !%SHR !%GE '>'
%BXOR         <- !%NE '~'
%ASSIGN       <- !%EQ '='

-- unary operators
%NEG          <- !'--' '-'
%LEN          <- '#'
%BNOT         <- !%NE '~'
%TOSTRING     <- '$'
%REF          <- '&'
%DEREF        <- '*'

-- matching symbols
%LPAREN       <- '('
%RPAREN       <- ')'
%LBRACKET     <- !('[' '='* '[') '['
%RBRACKET     <- ']'
%LCURLY       <- '{'
%RCURLY       <- '}'
%LANGLE       <- '<'
%RANGLE       <- '>'

-- other symbols
%SEMICOLON    <- ';'
%COMMA        <- ','
%SEPARATOR    <- [,;]
%ELLIPSIS     <- '...'
%CONCAT       <- !%ELLIPSIS '..'
%DOT          <- !%ELLIPSIS !%CONCAT !('.' %d) '.'
%DBLCOLON     <- '::'
%COLON        <- !%DBLCOLON ':'
%AT           <- '@'
%DOLLAR       <- '$'
%QUESTION     <- '?'
]])

--- capture varargs values
parser:set_token_pegs([[
  %cVARARGS <- ({} %ELLIPSIS -> 'Varargs') -> to_astnode
]])

-- syntax errors
parser:add_syntax_errors({
  MalformedExponentialNumber = 'malformed exponential number',
  MalformedBinaryNumber = 'malformed binary number',
  MalformedHexadecimalNumber = 'malformed hexadecimal number',
  UnclosedLongComment = 'unclosed long comment',
  UnclosedShortString = 'unclosed short string',
  UnclosedLongString = 'unclosed long string',
})

--------------------------------------------------------------------------------
-- Grammar
--------------------------------------------------------------------------------

local grammar = Grammar()
local to_astnode = parser.to_astnode
local unpack = table.unpack or unpack

-- source code body
grammar:set_pegs([==[
  sourcecode <-
    %SHEBANG? %SKIP
    block
    (!. / %{UnexpectedSyntaxAtEOF})

  block <-
    ({} '' -> 'Block' {| (stat / %SEMICOLON)* stat_return? |}) -> to_astnode

  stat_return <-
    ({} %RETURN -> 'Return' {| expr_list |} %SEMICOLON?) -> to_astnode
]==])

-- statements
grammar:add_group_peg('stat', 'if', [[
  ({} %IF -> 'If'
    {|
      {| eexpr eTHEN block |}
      ({| %ELSEIF eexpr eTHEN block |})*
    |}
    (%ELSE block)?
  eEND) -> to_astnode
]])

grammar:add_group_peg('stat', 'switch', [[
  ({} %SWITCH -> 'Switch' eexpr
      {|(
        ({| %CASE eexpr eTHEN block |})+ / %{ExpectedCase})
      |}
      (%ELSE block)?
      eEND
  ) -> to_astnode
]])

grammar:add_group_peg('stat', 'do', [[
  ({} %DO -> 'Do' block eEND) -> to_astnode
]])

grammar:add_group_peg('stat', 'while', [[
  ({} %WHILE -> 'While' eexpr eDO block eEND) -> to_astnode
]])

grammar:add_group_peg('stat', 'repeat', [[
  ({} %REPEAT -> 'Repeat' block eUNTIL eexpr) -> to_astnode
]])

grammar:add_group_peg('stat', 'for', [[
  %FOR (for_num / for_in / %{ExpectedForParams})

  for_num <-
    ({} '' -> 'ForNum'
      typed_id %ASSIGN eexpr %COMMA (op_cmp / '' -> 'le') eexpr (%COMMA eexpr / cnil)
      eDO block eEND
    ) -> to_astnode

  for_in <-
    ({} '' -> 'ForIn' {| typed_idlist |} %IN {| eexpr_list |} eDO block eEND) -> to_astnode
]])

grammar:add_group_peg('stat', 'break', [[
  ({} %BREAK -> 'Break') -> to_astnode
]])

grammar:add_group_peg('stat', 'continue', [[
  ({} %CONTINUE -> 'Continue') -> to_astnode
]])

grammar:add_group_peg('stat', 'label', [[
  ({} %DBLCOLON -> 'Label' ecNAME eDBLCOLON) -> to_astnode
]])

grammar:add_group_peg('stat', 'goto', [[
  ({} %GOTO -> 'Goto' ecNAME) -> to_astnode
]])

grammar:add_group_peg('stat', 'vardecl', [[
  ({} '' -> 'VarDecl'
    ((var_scope (var_mutability / '' -> 'var')) / (cnil var_mutability))
    {| typed_idlist |}
    (%ASSIGN {| eexpr_list |})?
  ) -> to_astnode
]])

grammar:add_group_peg('stat', 'funcdef', [[
  ({} '' -> 'FuncDef' (var_scope / cnil) %FUNCTION func_name function_body) -> to_astnode
  func_name <- (%cID {| (dot_index* colon_index / dot_index)* |}) -> to_chain_index_or_call
]])

grammar:add_group_peg('stat', 'call', [[
  (primary_expr {| ((index_expr+ & call_expr) / call_expr)+ |} ctrue) -> to_chain_index_or_call
]])

grammar:add_group_peg('stat', 'assign', [[
  ({} '' -> 'Assign' {| assignable_var_list |} %ASSIGN {| eexpr_list |}) -> to_astnode

  assignable_var_list <- assignable_var (%COMMA assignable_var)*
  assignable_var <-
    (primary_expr {| ((call_expr+ & index_expr) / index_expr)+ |}) -> to_chain_index_or_call
    / %cID
]])

-- expressions
grammar:set_pegs([[
  expr      <- expr0

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
    / function
    / table
    / suffixed_expr

  suffixed_expr <- (primary_expr {| (index_expr / call_expr)* |}) -> to_chain_index_or_call

  primary_expr <-
    %cID /
    %LPAREN eexpr eRPAREN

  index_expr <- dot_index / array_index
  dot_index <- {| {} %DOT -> 'DotIndex' ecNAME |}
  array_index <- {| {} %LBRACKET -> 'ArrayIndex' eexpr eRBRACKET |}
  colon_index <- {| {} %COLON -> 'ColonIndex' ecNAME |}

  call_expr <-
    {| {} %COLON -> 'CallMethod' ecNAME call_args |} /
    {| {} & (
      %LPAREN /
      %LCURLY /
      %cSTRING /
      %LANGLE typexpr_list %RANGLE %LPAREN
    ) '' -> 'Call' call_args |}
  call_args <-
    {| (%LANGLE typexpr_list? eRANGLE)? |}
    {| (%LPAREN  expr_list eRPAREN / table / %cSTRING) |}

  table <- ({} '' -> 'Table' %LCURLY
      {| (table_row (%SEPARATOR table_row)* %SEPARATOR?)? |}
    eRCURLY) -> to_astnode
  table_row <- table_pair / expr
  table_pair <- ({} '' -> 'Pair' (%LBRACKET eexpr eRBRACKET / %cNAME) %ASSIGN eexpr) -> to_astnode

  function <- ({} %FUNCTION -> 'Function' function_body) -> to_astnode
  function_body <-
    eLPAREN (
      {| (typed_idlist (%COMMA %cVARARGS)? / %cVARARGS)? |}
    ) eRPAREN
    {| (%COLON etypexpr_list)? |}
      block
    eEND
  typed_idlist <- typed_id (%COMMA typed_id)*
  typed_id <- ({} '' -> 'TypedId' %cNAME (%COLON etypexpr)?) -> to_astnode

  typexpr <- ({} '' -> 'Type' %cNAME) -> to_astnode
  typexpr_list <- typexpr (%COMMA typexpr)*
  etypexpr_list <- etypexpr (%COMMA typexpr)*

  expr_list <- (expr (%COMMA expr)*)?
  eexpr_list <- eexpr (%COMMA expr)*

  var_scope <- %LOCAL -> 'local'
  var_mutability <- %VAR %BAND -> 'var&' / %VAR -> 'var' / %LET %BAND -> 'let&' / %LET -> 'let' / %CONST -> 'const'

  cnil <- '' -> to_nil
  ctrue <- '' -> to_true
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

  to_chain_index_or_call = function(primary_expr, exprs, inblock)
    local last_expr = primary_expr
    if exprs then
      for _,expr in ipairs(exprs) do
        table.insert(expr, last_expr)
        last_expr = to_astnode(unpack(expr))
      end
    end
    if inblock then
      table.insert(last_expr, true)
    end
    return last_expr
  end,

  to_nil = function() return nil end,
  to_true = function() return true end
})

-- operators
grammar:set_pegs([[
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
               %TOSTRING -> 'tostring' /
               %REF -> 'ref' /
               %DEREF -> 'deref'
  op_pow   <-  %POW -> 'pow'
]])

-- syntax expected captures with errors
grammar:set_pegs([[
  eRPAREN    <- %RPAREN    / %{UnclosedParenthesis}
  eRBRACKET  <- %RBRACKET  / %{UnclosedBracket}
  eRCURLY    <- %RCURLY    / %{UnclosedCurly}
  eRANGLE    <- %RANGLE    / %{UnclosedAngle}
  eLPAREN    <- %LPAREN    / %{ExpectedParenthesis}
  eEND       <- %END       / %{ExpectedEnd}
  eTHEN      <- %THEN      / %{ExpectedThen}
  eUNTIL     <- %UNTIL     / %{ExpectedUntil}
  eDO        <- %DO        / %{ExpectedDo}
  eDBLCOLON  <- %DBLCOLON  / %{ExpectedDoubleColumn}
  ecNAME     <- %cNAME     / %{ExpectedName}
  eexpr      <- expr       / %{ExpectedExpression}
  etypexpr   <- typexpr    / %{ExpectedTypeExpression}
  ecall_args <- call_args  / %{ExpectedCall}
]])

-- compile whole grammar
parser:set_peg('sourcecode', grammar:build())
parser.grammar = grammar


--------------------------------------------------------------------------------
-- Syntax Errors
--------------------------------------------------------------------------------

parser:add_syntax_errors({
  UnexpectedSyntaxAtEOF  = 'unexpected syntax, was expecting EOF'
})

return parser
