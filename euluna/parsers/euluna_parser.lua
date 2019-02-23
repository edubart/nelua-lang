local ASTShape = require 'euluna.astshape'
local Parser = require 'euluna.parser'
local Grammar = require 'euluna.grammar'

--------------------------------------------------------------------------------
-- AST definition
--------------------------------------------------------------------------------

local astshape = ASTShape()
local types = astshape.types

-- primitives
astshape:register('Number', types.shape {
  types.one_of{"int", "dec", "bin", "exp", "hex"}, -- type
  types.string, -- value
  types.string:is_optional() -- literal
})
astshape:register('String', types.shape {
  types.string, -- value
  types.string:is_optional() -- literal
})
astshape:register('Boolean', types.shape {
  types.boolean, -- true or false
})
astshape:register('Nil', types.shape {})

-- varargs
astshape:register('Varargs', types.shape {})

-- table
astshape:register('Table', types.shape {
  types.array_of(types.ASTNode) -- pair or exprs
})
astshape:register('Pair', types.shape {
  types.ASTNode + types.string, -- field name (an expr or a string)
  types.ASTNode -- field value expr
})

astshape:register('Function', types.shape {
  types.array_of(types.ASTNode):is_optional(), -- typed arguments
  types.array_of(types.ASTNode):is_optional(), -- typed returns
  types.ASTNode -- block
})

-- variable/function/type names
astshape:register('Id', types.shape {
  types.string, -- name
})
astshape:register('Type', types.shape {
  types.string, -- type
})
astshape:register('TypedId', types.shape {
  types.string, -- name
  types.ASTType:is_optional(), -- type
})

-- indexing
astshape:register('DotIndex', types.shape {
  types.string, -- name
  types.ASTNode -- expr
})
astshape:register('ArrayIndex', types.shape {
  types.ASTNode, -- index expr
  types.ASTNode -- expr
})

-- calls
astshape:register('Call', types.shape {
  types.array_of(types.ASTType), -- call types
  types.array_of(types.ASTNode), -- args exprs
  types.ASTNode, -- caller expr
})
astshape:register('CallMethod', types.shape {
  types.string, -- method name
  types.array_of(types.ASTType), -- call types
  types.array_of(types.ASTNode), -- args exprs
  types.ASTNode, -- caller expr
})

-- general
astshape:register('Block', types.shape {
  types.array_of(types.ASTNode) -- statements
})

-- statements
astshape:register('StatReturn', types.shape {
  types.array_of(types.ASTNode) -- returned exprs
})

-- operations
astshape:register('UnaryOp', types.shape {
  types.string, -- type
  types.ASTNode -- right expr
})
astshape:register('BinaryOp', types.shape {
  types.string, -- type
  types.ASTNode, --- left expr
  types.ASTNode -- right expr
})
astshape:register('TernaryOp', types.shape {
  types.string, -- type
  types.ASTNode, -- left expr
  types.ASTNode, -- middle expr
  types.ASTNode -- right expr
})


--------------------------------------------------------------------------------
-- Lexer
--------------------------------------------------------------------------------

local parser = Parser(astshape)

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
  exponential     <- (decimal / integer) [eE] ({[+-]? %d+} / %{MalformedExponentialNumber})
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
    ({} %RETURN -> 'StatReturn' {| expr_list |} %SEMICOLON?) -> to_astnode
]==])

-- statements
grammar:add_group_peg('stat', 'break', [[
  ({} %BREAK -> 'StatBreak') -> to_astnode
]])

grammar:add_group_peg('stat', 'call', [[
  (primary_expr {| ((index_expr+ & call_expr) / call_expr)+ |}) -> to_chain_index_or_call
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

  index_expr <-
    {| {} %DOT -> 'DotIndex' ecNAME |} /
    {| {} %LBRACKET -> 'ArrayIndex' eexpr eRBRACKET |}

  call_expr <-
    {| {} %COLON -> 'CallMethod' ecNAME call_args |} /
    {| {} & (%LPAREN / %LANGLE typexpr_list %RANGLE %LPAREN) '' -> 'Call' call_args |}
  call_args <-
    {| (%LANGLE typexpr_list? eRANGLE)? |}
    eLPAREN {| expr_list |} eRPAREN

  table <- ({} '' -> 'Table' %LCURLY
      {| (table_row (%SEPARATOR table_row)* %SEPARATOR?)? |}
    eRCURLY) -> to_astnode
  table_row <- table_pair / expr
  table_pair <- ({} '' -> 'Pair' (%LBRACKET eexpr eRBRACKET / %cNAME) %ASSIGN eexpr) -> to_astnode

  function <- ({} %FUNCTION -> 'Function' function_body) -> to_astnode
  function_body <-
    eLPAREN (
      {| typed_idlist (%COMMA %cVARARGS)? / %cVARARGS |} /
      cnil
    ) eRPAREN
    (%COLON {| etypexpr_list |} / cnil)
      block
    eEND
  typed_idlist <- typed_id (%COMMA typed_id)*
  typed_id <- ({} '' -> 'TypedId' %cNAME (%COLON etypexpr)?) -> to_astnode

  typexpr <- ({} '' -> 'Type' %cNAME) -> to_astnode
  typexpr_list <- typexpr (%COMMA typexpr)*
  etypexpr_list <- etypexpr (%COMMA typexpr)*

  expr_list <- (expr (%COMMA expr)*)?

  cnil <- '' -> to_nil
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

  to_chain_index_or_call = function(primary_expr, exprs)
    local last_expr = primary_expr
    if exprs then
      for _,expr in ipairs(exprs) do
        table.insert(expr, last_expr)
        last_expr = to_astnode(unpack(expr))
      end
    end
    return last_expr
  end,

  to_nil = function() return nil end
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
               %TOSTRING -> 'tostring'
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
