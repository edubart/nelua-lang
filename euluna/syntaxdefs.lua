local PEGParser = require 'euluna.pegparser'
local PEGBuilder = require 'euluna.pegbuilder'
local astbuilder = require 'euluna.astdefs'
local memoize = require 'euluna.utils.memoize'

local function get_parser(std)
  local is_luacompat = std == 'luacompat'

  --------------------------------------------------------------------------------
  -- Lexer
  --------------------------------------------------------------------------------

  local parser = PEGParser()
  parser:set_astbuilder(astbuilder)

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

  if not is_luacompat then
    parser:add_keywords({
      -- euluna additional keywords
      "switch", "case", "continue", "var", "val"
    })
  end

  -- names and identifiers (names for variables, functions, etc)
  parser:set_token_peg('NAME', '&%IDPREFIX !%KEYWORD %IDFORMAT')
  parser:set_token_peg('cNAME', '&%IDPREFIX !%KEYWORD {%IDFORMAT}')
  parser:set_token_peg('cID', "({} &%IDPREFIX !%KEYWORD '' -> 'Id' {%IDFORMAT}) -> to_astnode")

  -- capture numbers (hexadecimal, binary, exponential, decimal or integer)
  parser:set_token_pegs([[
    %cNUMBER    <- ({} '' -> 'Number' number literal?) -> to_astnode
    number      <- '' -> 'hex' hexadecimal /
                   '' -> 'bin' binary /
                   '' -> 'dec' decimal
    literal     <- %cNAME
    hexadecimal <-  '0' [xX] ({hex} '.' ({hex} / '' -> '0') / '' -> '0' '.' {hex} / {hex} nil)
                    ([pP] {exp} / nil)
    binary      <-  '0' [bB] ({bin} '.' ({bin} / '' -> '0') / '' -> '0' '.' {bin} / {bin} nil)
                    ([pP] {exp} / nil)
    decimal     <-  ({dec} '.' ({dec} / '' -> '0') / '' -> '0' '.' {dec} / {dec} nil)
                    ([eE] {exp} / nil)
    dec         <- %d+
    bin         <- ([01]+ !%d / %{MalformedBinaryNumber})
    hex         <- (%x+ / %{MalformedHexadecimalNumber})
    exp         <- ([+-])? %d+ / %{MalformedExponentialNumber}
    nil         <- '' -> to_nil
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
  %TVAL         <- 'val'
  %TCONST       <- 'const'
  ]])

  --- capture varargs values
  parser:set_token_pegs([[
    %cVARARGS <- ({} %ELLIPSIS -> 'Varargs') -> to_astnode
  ]])

  --------------------------------------------------------------------------------
  -- Grammar
  --------------------------------------------------------------------------------

  local grammar = PEGBuilder()

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

  if not is_luacompat then
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
  end

  -- expressions
  grammar:set_pegs([[
    expr      <- expr1

    expr1  <- ({} ''->'BinaryOp'  {| expr2  (op_or       expr2 )* |})    -> to_chain_binary_op
    expr2  <- ({} ''->'BinaryOp'  {| expr3  (op_and      expr3 )* |})    -> to_chain_binary_op
    expr3  <- ({} ''->'BinaryOp'  {| expr4  (op_cmp      expr4 )* |})    -> to_chain_binary_op
    expr4  <- ({} ''->'BinaryOp'  {| expr5  (op_bor      expr5 )* |})    -> to_chain_binary_op
    expr5  <- ({} ''->'BinaryOp'  {| expr6  (op_xor      expr6 )* |})    -> to_chain_binary_op
    expr6  <- ({} ''->'BinaryOp'  {| expr7  (op_band     expr7 )* |})    -> to_chain_binary_op
    expr7  <- ({} ''->'BinaryOp'  {| expr8  (op_bshift   expr8 )* |})    -> to_chain_binary_op
    expr8  <- ({} ''->'BinaryOp'     expr9  (op_concat   expr8 )?   )    -> to_binary_op
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
        {| (typed_idlist (%COMMA %cVARARGS)? / %cVARARGS)? |}
      ) eRPAREN
      {| (%COLON etypexpr_list)? |}
        block
      eEND
    var_mutability <-
      %TVAR %BAND %BAND -> 'var&&' /
      %TVAR %BAND -> 'var&' /
      %TVAL %BAND -> 'val&' /
      %TVAR -> 'var' /
      %TVAL -> 'val'
    typed_idlist <- typed_id (%COMMA typed_id)*
    typed_id <- ({} '' -> 'IdDecl'
        %cNAME
        (var_mutability / '' -> 'var')
        (%COLON etypexpr)?
      ) -> to_astnode

    typexpr_list <- typexpr (%COMMA typexpr)*
    etypexpr_list <- etypexpr (%COMMA typexpr)*

    expr_list <- (expr (%COMMA expr)*)?
    eexpr_list <- eexpr (%COMMA expr)*

    var_scope <- %LOCAL -> 'local'

    cnil <- '' -> to_nil
    ctrue <- '' -> to_true

    typexpr <-
        func_type
      / composed_type
      / simple_type

    composed_type <- (
      {} '' -> 'ComposedType'
        %cNAME %LANGLE {| etypexpr_list |} eRANGLE
      ) -> to_astnode

    func_type <- (
      {} '' -> 'FuncType'
        %FUNCTION %LANGLE
        %LPAREN ({|
          (typexpr_list (%COMMA %cVARARGS)? / %cVARARGS)?
        |}) eRPAREN
        {| (%COLON etypexpr_list)? |}
        eRANGLE
      ) -> to_astnode

    simple_type   <- ({} '' -> 'Type' %cNAME) -> to_astnode
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

  if not is_luacompat then
    parser:add_syntax_errors({
      ExpectedCase = "expected `case` keyword"
    })
  end

  return {
    astbuilder = astbuilder,
    parser = parser,
    grammar = grammar
  }
end

return memoize(get_parser)
