local Aster = require 'euluna.aster'
local Parser = require 'euluna.parser'
local Grammar = require 'euluna.grammar'

--------------------------------------------------------------------------------
-- AST definition
--------------------------------------------------------------------------------

local aster = Aster()
local types = aster.types

-- primitives
aster:register('Number', types.shape {
  types.one_of{"int", "dec", "bin", "exp", "hex"}, -- type
  types.string + types.table, -- value, (table used in exp values)
  types.string:is_optional() -- literal
})
aster:register('String', types.shape {
  types.string, -- value
  types.string:is_optional() -- literal
})
aster:register('Boolean', types.shape {
  types.boolean, -- true or false
})
aster:register('Nil', types.shape {})
aster:register('Varargs', types.shape {})

-- table
aster:register('Table', types.shape {
  types.array_of(types.ast.Node) -- pair or exprs
})
aster:register('Pair', types.shape {
  types.ast.Node + types.string, -- field name (an expr or a string)
  types.ast.Node -- field value expr
})

-- identifier and types
aster:register('Id', types.shape {
  types.string, -- name
})
aster:register('Paren', types.shape {
  types.ast.Node -- expr
})
aster:register('Type', types.shape {
  types.string, -- type
})
aster:register('TypedId', types.shape {
  types.string, -- name
  types.ast.Type:is_optional(), -- type
})
aster:register('FuncArg', types.shape {
  types.string, -- name
  types.one_of{"var", "var&", "var&&", "let", "let&"}:is_optional(), -- mutability
  types.ast.Type:is_optional() -- type
})

-- function
aster:register('Function', types.shape {
  types.array_of(types.ast.FuncArg + types.ast.Varargs), -- typed arguments
  types.array_of(types.ast.Type), -- typed returns
  types.ast.Node -- block
})

-- indexing
aster:register('DotIndex', types.shape {
  types.string, -- name
  types.ast.Node -- expr
})
aster:register('ColonIndex', types.shape {
  types.string, -- name
  types.ast.Node -- expr
})
aster:register('ArrayIndex', types.shape {
  types.ast.Node, -- index expr
  types.ast.Node -- expr
})

-- calls
aster:register('Call', types.shape {
  types.array_of(types.ast.Type), -- call types
  types.array_of(types.ast.Node), -- args exprs
  types.ast.Node, -- caller expr
  types.boolean:is_optional(), -- is called from a block
})
aster:register('CallMethod', types.shape {
  types.string, -- method name
  types.array_of(types.ast.Type), -- call types
  types.array_of(types.ast.Node), -- args exprs
  types.ast.Node, -- caller expr
  types.boolean:is_optional(), -- is called from a block
})

-- block
aster:register('Block', types.shape {
  types.array_of(types.ast.Node) -- statements
})

-- statements
aster:register('Return', types.shape {
  types.array_of(types.ast.Node) -- returned exprs
})
aster:register('If', types.shape {
  types.array_of(types.shape{types.ast.Node, types.ast.Block}), -- if list {expr, block}
  types.ast.Block:is_optional() -- else block
})
aster:register('Do', types.shape {
  types.ast.Block -- block
})
aster:register('While', types.shape {
  types.ast.Node, -- expr
  types.ast.Block -- block
})
aster:register('Repeat', types.shape {
  types.ast.Block, -- block
  types.ast.Node -- expr
})
aster:register('ForNum', types.shape {
  types.ast.TypedId, -- iterated var
  types.ast.Node, -- begin expr
  types.string, -- compare operator
  types.ast.Node, -- end expr
  types.ast.Node:is_optional(), -- increment expr
  types.ast.Block, -- block
})
aster:register('ForIn', types.shape {
  types.array_of(types.ast.TypedId), -- iterated vars
  types.array_of(types.ast.Node), -- in exprlist
  types.ast.Block -- block
})
aster:register('Break', types.shape {})
aster:register('Label', types.shape {
  types.string -- label name
})
aster:register('Goto', types.shape {
  types.string -- label name
})
aster:register('VarDecl', types.shape {
  types.one_of{"local"}:is_optional(), -- scope
  types.one_of{"var"}, -- mutability
  types.array_of(types.ast.TypedId), -- var names with types
  types.array_of(types.ast.Node):is_optional(), -- expr list, initial assignments values
})
aster:register('Assign', types.shape {
  types.array_of(types.ast.Node), -- expr list, assign variables
  types.array_of(types.ast.Node), -- expr list, assign values
})
aster:register('FuncDef', types.shape {
  types.one_of{"local"}:is_optional(), -- scope
  types.ast.Id + types.ast.DotIndex + types.ast.ColonIndex, -- name
  types.array_of(types.ast.Node), -- typed arguments
  types.array_of(types.ast.Node), -- typed returns
  types.ast.Node -- block
})

-- operations
aster:register('UnaryOp', types.shape {
  types.string, -- type
  types.ast.Node -- right expr
})
aster:register('BinaryOp', types.shape {
  types.string, -- type
  types.ast.Node, --- left expr
  types.ast.Node -- right expr
})
aster:register('TernaryOp', types.shape {
  types.string, -- type
  types.ast.Node, -- left expr
  types.ast.Node, -- middle expr
  types.ast.Node -- right expr
})


--------------------------------------------------------------------------------
-- Lexer
--------------------------------------------------------------------------------

local parser = Parser()
parser:set_aster(aster)

-- spaces including new lines
parser:set_peg("SPACE", "%s")

-- all new lines formats CR CRLF LF LFCR
parser:set_peg("LINEBREAK", "[%nl]'\r' / '\r'[%nl] / [%nl] / '\r'")

-- shebang, e.g. "#!/usr/bin/euluna"
parser:set_peg("SHEBANG", "'#!' (!%LINEBREAK .)*")

-- multiline and single line comments
parser:set_pegs([[
  %LONGCOMMENT  <- (open (contents close / %{UnclosedLongComment})) -> 0
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
local utf8char = utf8 and utf8.char or string.char
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
    (%d %d^-1 !%d / [012] %d^2) -> num2char /
    ('x' {%x^2}) -> hex2char /
    ('u' '{' {%x^+1} '}') -> hex2unicode /
    %{MalformedEscapeSequence}
]], {
  num2char = function(s) return string.char(tonumber(s)) end,
  hex2char = function(s) return string.char(tonumber(s, 16)) end,
  hex2unicode = function(s) return utf8char(tonumber(s, 16)) end,
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
]])

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
%IDIV         <- '//'
%DIV          <- !%IDIV '/'
%POW          <- '^'
%BAND         <- '&'
%BOR          <- '|'
%SHL          <- '<<'
%SHR          <- '>>'
%EQ           <- '=='
%NE           <- '~='
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
%TOSTR        <- '$'
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

-- used by types
%TVAR         <- 'var'
%TLET         <- 'let'
%TCONST       <- 'const'
]])

--- capture varargs values
parser:set_token_pegs([[
  %cVARARGS <- ({} %ELLIPSIS -> 'Varargs') -> to_astnode
]])

--------------------------------------------------------------------------------
-- Grammar
--------------------------------------------------------------------------------

local grammar = Grammar()

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

grammar:add_group_peg('stat', 'label', [[
  ({} %DBLCOLON -> 'Label' ecNAME (%DBLCOLON / %{UnclosedLabel})) -> to_astnode
]])

grammar:add_group_peg('stat', 'goto', [[
  ({} %GOTO -> 'Goto' ecNAME) -> to_astnode
]])

grammar:add_group_peg('stat', 'vardecl', [[
  ({} '' -> 'VarDecl'
    var_scope '' -> 'var'
    {| typed_idlist |}
    (%ASSIGN {| eexpr_list |})?
  ) -> to_astnode
]])

grammar:add_group_peg('stat', 'funcdef', [[
  ({} '' -> 'FuncDef' (var_scope / cnil) %FUNCTION func_name function_body) -> to_astnode
  func_name <- (%cID {| (dot_index* colon_index / dot_index)* |}) -> to_chain_index_or_call
]])

grammar:add_group_peg('stat', 'assign', [[
  ({} '' -> 'Assign' {| assignable_var_list |} %ASSIGN {| eexpr_list |}) -> to_astnode

  assignable_var_list <- assignable_var (%COMMA assignable_var)*
  assignable_var <-
    (primary_expr {| ((call_expr+ &index_expr) / index_expr)+ |}) -> to_chain_index_or_call
    / %cID
]])

grammar:add_group_peg('stat', 'call', [[
  (primary_expr {| ((index_expr+ & call_expr) / call_expr)+ |} ctrue) -> to_chain_index_or_call
]])

-- expressions
grammar:set_pegs([[
  expr      <- expr0

  expr0  <- ({} ''->'TernaryOp' {| expr1  (%IF -> 'if' expr1 %ELSE expr1)* |}) -> to_chain_ternary_op
  expr1  <- ({} ''->'BinaryOp'  {| expr2  (op_or       expr2 )* |})    -> to_chain_binary_op
  expr2  <- ({} ''->'BinaryOp'  {| expr3  (op_and      expr3 )* |})    -> to_chain_binary_op
  expr3  <- ({} ''->'BinaryOp'  {| expr4  (op_cmp      expr4 )* |})    -> to_chain_binary_op
  expr4  <- ({} ''->'BinaryOp'  {| expr5  (op_bor      expr5 )* |})    -> to_chain_binary_op
  expr5  <- ({} ''->'BinaryOp'  {| expr6  (op_xor      expr6 )* |})    -> to_chain_binary_op
  expr6  <- ({} ''->'BinaryOp'  {| expr7  (op_band     expr7 )* |})    -> to_chain_binary_op
  expr7  <- ({} ''->'BinaryOp'  {| expr8  (op_bshift   expr8 )* |})    -> to_chain_binary_op
  expr8  <- ({} ''->'BinaryOp'    expr9  (op_concat   expr8 )?   )     -> to_binary_op
  expr9  <- ({} ''->'BinaryOp'  {| expr10 (op_add      expr10)* |})    -> to_chain_binary_op
  expr10 <- ({} ''->'BinaryOp'  {| expr11 (op_mul      expr11)* |})    -> to_chain_binary_op
  expr11 <- ({} ''->'UnaryOp'   {| op_unary* |} expr12)                -> to_chain_unary_op
  expr12 <- ({} ''->'BinaryOp' simple_expr (op_pow      expr11)?   )   -> to_binary_op

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
    ({} %LPAREN -> 'Paren' eexpr eRPAREN) -> to_astnode

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
      {| (func_args (%COMMA %cVARARGS)? / %cVARARGS)? |}
    ) eRPAREN
    {| (%COLON etypexpr_list)? |}
      block
    eEND
  func_args <- func_arg (%COMMA func_arg)*
  func_arg <- ({} '' -> 'FuncArg' %cNAME
    (%COLON (func_var_mutability (typexpr / cnil) / cnil etypexpr))?) -> to_astnode
  func_var_mutability <-
    %TVAR %BAND %BAND -> 'var&&' /
    %TVAR %BAND -> 'var&' /
    %TVAR -> 'var' /
    %TLET %BAND -> 'let&' /
    %TLET -> 'let'
  typed_idlist <- typed_id (%COMMA typed_id)*
  typed_id <- ({} '' -> 'TypedId' %cNAME (%COLON etypexpr)?) -> to_astnode

  typexpr <- ({} '' -> 'Type' %cNAME) -> to_astnode
  typexpr_list <- typexpr (%COMMA typexpr)*
  etypexpr_list <- etypexpr (%COMMA typexpr)*

  expr_list <- (expr (%COMMA expr)*)?
  eexpr_list <- eexpr (%COMMA expr)*

  var_scope <- %LOCAL -> 'local'

  cnil <- '' -> to_nil
  ctrue <- '' -> to_true
]])

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
               %IDIV -> 'idiv' /
               %DIV -> 'div' /
               %MOD -> 'mod'
  op_unary  <- %NOT -> 'not' /
               %LEN -> 'len' /
               %NEG -> 'neg' /
               %BNOT -> 'bnot' /
               %TOSTR -> 'tostring' /
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
  ecNAME     <- %cNAME     / %{ExpectedName}
  eexpr      <- expr       / %{ExpectedExpression}
  etypexpr   <- typexpr    / %{ExpectedTypeExpression}
  ecall_args <- call_args  / %{ExpectedCall}
]])

-- compile whole grammar
parser:set_peg('sourcecode', grammar:build())

--------------------------------------------------------------------------------
-- Syntax Errors
--------------------------------------------------------------------------------

-- lexer errors
parser:add_syntax_errors({
  MalformedExponentialNumber = 'malformed exponential number',
  MalformedBinaryNumber = 'malformed binary number',
  MalformedHexadecimalNumber = 'malformed hexadecimal number',
  MalformedEscapeSequence = 'malformed escape sequence',
  UnclosedLongComment = 'unclosed long comment',
  UnclosedShortString = 'unclosed short string',
  UnclosedLongString = 'unclosed long string',

})

-- grammar errors
parser:add_syntax_errors({
  UnexpectedSyntaxAtEOF  = 'unexpected syntax, was expecting EOF',
  UnclosedParenthesis = "unclosed parenthesis, did you forget a `)`?",
  UnclosedBracket = "unclosed bracket, did you forget a `]`?",
  UnclosedCurly = "unclosed curly brace, did you forget a `}`?",
  UnclosedAngleBracket = "unclosed angle bracket, did you forget a `>`",
  UnclosedLabel = "unclosed label, did you forget `::`?",
  ExpectedParenthesis = "expected parenthesis `(`",
  ExpectedEnd = "expected `end` keyword",
  ExpectedThen = "expected `then` keyword",
  ExpectedUntil = "expected `until` keyword",
  ExpectedDo = "expected `do` keyword",
  ExpectedName = "expected an identifier name",
  ExpectedExpression = "expected an expression",
  ExpectedTypeExpression = "expected a type expression",
  ExpectedCall = "expected call"
})

return {
  aster = aster,
  parser = parser,
  grammar = grammar
}
