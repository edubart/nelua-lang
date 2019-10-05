local PEGParser = require 'nelua.pegparser'
local PEGBuilder = require 'nelua.pegbuilder'
local astbuilder = require 'nelua.astdefs'
local memoize = require 'nelua.utils.memoize'

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

  -- shebang, e.g. "#!/usr/bin/nelua"
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

  -- identifier suffix, alphanumeric or _ character
  parser:set_peg('IDSUFFIX', '[\128-\255_%w]')

  -- language keywords
  parser:add_keywords({
    -- lua keywords
    "and", "break", "do", "else", "elseif", "end", "for", "false",
    "function", "goto", "if", "in", "local", "nil", "not", "or",
    "repeat", "return", "then", "true", "until", "while",
  })

  if not is_luacompat then
    parser:add_keywords({
      -- nelua additional keywords
      "switch", "case", "continue", "global"
    })
  end

  -- names and identifiers (names for variables, functions, etc)
  parser:set_token_pegs([[
    %cNAME <- &idprefix !%KEYWORD {~ idformat ~}
    idprefix <- ]] .. '[\128-\255_%a]' ..[[
    idformat <- ([_%w] / escape_utf8)+
    escape_utf8 <-
      ]]..'[\128-\255]+'..[[ -> char2hex
  ]], {
    char2hex = function(s)
      return 'u' .. s:gsub('.', function(c) return string.format('%02X', string.byte(c)) end)
    end
  })

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
  -- matching symbols
  %LPAREN       <- '('
  %RPAREN       <- ')'
  %LBRACKET     <- !('[' ('#'^+2 / '='*) '[') '['
  %RBRACKET     <- ']'
  %LCURLY       <- '{'
  %RCURLY       <- '}'
  %LANGLE       <- '<'
  %RANGLE       <- '>'
  %PPSHORT      <- '##'
  %PPEXPRL      <- '#['
  %PPNAMEL      <- '#('

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
  %UNM          <- !'--' '-'
  %LEN          <- !%PPSHORT !%PPEXPRL !%PPNAMEL '#'
  %BNOT         <- !%NE '~'
  %DEREF        <- '$'
  %REF          <- '&'

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
  %EXCL         <- '!'

  -- used by types
  %TRECORD      <- 'record'
  %TENUM        <- 'enum'
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
      ({} '' -> 'Block' {| (stat / %SEMICOLON)* stat_return? stat_preprocess* |}) -> to_astnode

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
    %FOR (for_num / for_in / %{ExpectedForParams}) / for_in_empty

    for_num <-
      ({} '' -> 'ForNum'
        typed_id %ASSIGN eexpr %COMMA (op_cmp / cnil) eexpr (%COMMA eexpr / cnil)
        eDO block eEND
      ) -> to_astnode

    for_in <-
      ({} '' -> 'ForIn' {| etyped_idlist |} %IN {| eexpr_list |} eDO block eEND) -> to_astnode

    for_in_empty <-
      ({} %IN -> 'ForIn' cnil {| eexpr_list |} eDO block eEND) -> to_astnode
  ]])

  grammar:add_group_peg('stat', 'break', [[
    ({} %BREAK -> 'Break') -> to_astnode
  ]])

  grammar:add_group_peg('stat', 'label', [[
    ({} %DBLCOLON -> 'Label' ename (%DBLCOLON / %{UnclosedLabel})) -> to_astnode
  ]])

  grammar:add_group_peg('stat', 'goto', [[
    ({} %GOTO -> 'Goto' ename) -> to_astnode
  ]])

  grammar:add_group_peg('stat', 'funcdef', [[
    ({} '' -> 'FuncDef' %LOCAL -> 'local' %FUNCTION func_iddecl function_body) -> to_astnode /
    ({} %FUNCTION -> 'FuncDef' cnil func_name function_body) -> to_astnode

    func_name <- (id {| (dot_index* colon_index / dot_index)* |}) -> to_chain_index_or_call
    func_iddecl <- ({} '' -> 'IdDecl' name) -> to_astnode
  ]])

  grammar:add_group_peg('stat', 'assign', [[
    ({} '' -> 'Assign' {| assignable_list |} %ASSIGN {| eexpr_list |}) -> to_astnode

    assignable_list <- assignable (%COMMA assignable)*
    assignable <-
      ({} ''->'UnaryOp' {| op_deref* |} assignable_suffix) -> to_chain_unary_op
    assignable_suffix <-
      (primary_expr {| ((call_expr+ &index_expr) / index_expr)+ |}) -> to_chain_index_or_call
      / id
  ]])

  grammar:add_group_peg('stat', 'call', [[
    callable
    callable <-
      ({} ''->'UnaryOp' {| op_deref* |} callable_suffix) -> to_chain_unary_op
    callable_suffix <-
      (primary_expr {| ((index_expr+ & call_expr) / call_expr)+ |} ctrue) -> to_chain_index_or_call
  ]])

  grammar:add_group_peg('stat', 'preprocess', [[
    ({} '' -> 'Preprocess' ppstring ) -> to_astnode
  ]])

  grammar:add_group_peg('stat', 'vardecl', [[
    ({} '' -> 'VarDecl'
      %LOCAL -> 'local' cnil
      {| etyped_idlist |}
      (%ASSIGN {| eexpr_list |})?
    ) -> to_astnode
  ]])

  if not is_luacompat then
    grammar:add_group_peg('stat', 'vardecl', [[
    ({} '' -> 'VarDecl'
      ( %LOCAL -> 'local'
        {| etyped_idlist |}
      / (%GLOBAL ->'global')
        {| eglobal_typed_idlist |}
      ) (%ASSIGN {| eexpr_list |})?
    ) -> to_astnode

    eglobal_typed_idlist <-
      (global_typed_id / %{ExpectedName}) (%COMMA global_typed_id)*
    global_typed_id <- ({} '' -> 'IdDecl'
        ((id {| dot_index+ |}) -> to_chain_index_or_call / name)
        (%COLON etypexpr / cnil)
        (&%EXCL {| var_attrib+ |})?
      ) -> to_astnode
    ]], nil, true)

    grammar:add_group_peg('stat', 'funcdef', [[
      ({} '' -> 'FuncDef' (%LOCAL -> 'local' / %GLOBAL -> 'global') %FUNCTION func_iddecl function_body) -> to_astnode /
      ({} %FUNCTION -> 'FuncDef' cnil func_name function_body) -> to_astnode

      func_name <- (id {| (dot_index* colon_index / dot_index)* |}) -> to_chain_index_or_call
      func_iddecl <- ({} '' -> 'IdDecl' name) -> to_astnode
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
    expr9  <- ({} ''->'BinaryOp'     expr10 (op_range    expr9 )?   )    -> to_binary_op
    expr10  <- ({} ''->'BinaryOp' {| expr11 (op_add      expr11)* |})    -> to_chain_binary_op
    expr11 <- ({} ''->'BinaryOp'  {| expr12 (op_mul      expr12)* |})    -> to_chain_binary_op
    expr12 <- ({} ''->'UnaryOp'   {| op_unary* |} expr13)                -> to_chain_unary_op
    expr13 <- ({} ''->'BinaryOp' simple_expr (op_pow      expr12)?   )   -> to_binary_op

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
      id /
      ppexpr /
      type_instance /
      ({} %LPAREN -> 'Paren' eexpr eRPAREN) -> to_astnode

    type_instance <-
      ({} %AT -> 'TypeInstance' etypexpr) -> to_astnode

    index_expr <- dot_index / array_index
    dot_index <- {| {} %DOT -> 'DotIndex' ename |}
    array_index <- {| {} %LBRACKET -> 'ArrayIndex' eexpr eRBRACKET |}
    colon_index <- {| {} %COLON -> 'ColonIndex' ename |}

    call_expr <-
      {| {} %COLON -> 'CallMethod' ename callargs |} /
      {| {} '' -> 'Call' callargs |}
    callargs <-
      {| (%LPAREN  expr_list eRPAREN / table / %cSTRING / ppexpr) |}

    table <- ({} '' -> 'Table' %LCURLY
        {| (table_row (%SEPARATOR table_row)* %SEPARATOR?)? |}
      eRCURLY) -> to_astnode
    table_row <- table_pair / expr
    table_pair <- ({} '' -> 'Pair' (%LBRACKET eexpr eRBRACKET / name) %ASSIGN eexpr) -> to_astnode

    function <- ({} %FUNCTION -> 'Function' function_body) -> to_astnode
    function_body <-
      eLPAREN (
        {| (typed_idlist (%COMMA %cVARARGS)? / %cVARARGS)? |}
      ) eRPAREN
      {| (%COLON etypexpr_list)? |} {| var_attrib* |}
        block
      eEND
    typed_idlist <- typed_id (%COMMA typed_id)*
    etyped_idlist <- (typed_id / %{ExpectedName}) (%COMMA typed_id)*
    typed_id <- ({} '' -> 'IdDecl'
        name
        (%COLON etypexpr / cnil)
        (&%EXCL {| var_attrib+ |})?
      ) -> to_astnode

    typexpr_list <- typexpr (%COMMA typexpr)*
    etypexpr_list <- etypexpr (%COMMA typexpr)*

    expr_list <- (expr (%COMMA expr)*)?
    eexpr_list <- eexpr (%COMMA expr)*

    var_attrib <- ({} %EXCL -> 'Attrib' eattrib_expr) -> to_astnode

    eattrib_expr <-
      ename {|(
        (%LPAREN attrib_arg (%COMMA attrib_arg)* eRPAREN) /
        %cSTRING
      )?|}
    attrib_arg <- %cNUMBER / %cSTRING / %cBOOLEAN

    cnil <- '' -> to_nil
    ctrue <- '' -> to_true
    cfalse <- '' -> to_false

    typexpr <- typexpr0
    typexpr0 <- ({} '' -> 'MultipleType' {| typexpr1 (%BOR typexpr1)* |}) -> to_list_astnode
    typexpr1 <- (simple_typexpr {| unary_typexpr_op* |}) -> to_chain_late_unary_op

    simple_typexpr <-
      func_type /
      record_type /
      enum_type /
      arraytable_type /
      array_type /
      span_type /
      range_type /
      pointer_type /
      primtype /
      ppexpr

    unary_typexpr_op <-
      {| {} %MUL -> 'PointerType' |}

    func_type <- (
      {} '' -> 'FuncType'
        %FUNCTION %LANGLE
        %LPAREN ({|
          (typexpr_list (%COMMA %cVARARGS)? / %cVARARGS)?
        |}) eRPAREN
        {| (%COLON etypexpr_list)? |}
        eRANGLE
      ) -> to_astnode

    typexpr_param_expr <-
      %cNUMBER /
      id /
      ppexpr /
      (%LPAREN eexpr eRPAREN) /
      %{ExpectedExpression}

    record_type <- ({} %TRECORD -> 'RecordType' eLCURLY
        {| (record_field (%SEPARATOR record_field)* %SEPARATOR?)? |}
      eRCURLY) -> to_astnode
    record_field <- ({} '' -> 'RecordFieldType'
       name eCOLON etypexpr
      ) -> to_astnode
    enum_type <- ({} %TENUM -> 'EnumType'
        ((%LPAREN eprimtype eRPAREN) / cnil) eLCURLY
        {| eenumfield (%SEPARATOR enumfield)* %SEPARATOR? |}
      eRCURLY) -> to_astnode
    enumfield <- ({} '' -> 'EnumFieldType'
        name (%ASSIGN eexpr)?
      ) -> to_astnode
    arraytable_type <- (
      {} 'arraytable' -> 'ArrayTableType'
        eLPAREN etypexpr eRPAREN
      ) -> to_astnode
    span_type <- (
      {} 'span' -> 'SpanType'
        eLPAREN etypexpr eRPAREN
      ) -> to_astnode
    range_type <- (
      {} 'range' -> 'RangeType'
        eLPAREN etypexpr eRPAREN
      ) -> to_astnode
    array_type <- (
      {} 'array' -> 'ArrayType'
        eLPAREN etypexpr eCOMMA typexpr_param_expr eRPAREN
      ) -> to_astnode
    pointer_type <- (
      {} 'pointer' -> 'PointerType'
        ((%LPAREN etypexpr eRPAREN) / %SKIP)
      ) -> to_astnode
    primtype   <- ({} '' -> 'Type' name) -> to_astnode

    ppexpr <- ({} %PPEXPRL -> 'PreprocessExpr' {expr -> 0} eRBRACKET) -> to_astnode
    ppname <- ({} %PPNAMEL -> 'PreprocessName' {expr -> 0} eRPAREN) -> to_astnode
    ppstring <- (ppshort_string / pplong_string) %SKIP
    ppshort_string    <- %PPSHORT {(!%LINEBREAK .)*} %LINEBREAK?
    pplong_string     <- pplong_open ({pplong_content*} pplong_close / %{UnclosedPreprocessBracket})
    pplong_content    <- !pplong_close .
    pplong_open       <- '[' {:eq: '#'^+2:} '[' %SKIP
    pplong_close      <- ']' =eq ']'

    name    <- %cNAME / ppname
    id      <- ({} '' -> 'Id' name) -> to_astnode
  ]])

  -- operators
  grammar:set_pegs([[
    op_or     <-  %OR -> 'or'
    op_and    <-  %AND -> 'and'
    op_cmp    <-  %LT -> 'lt' /
                  %NE -> 'ne' /
                  %GT -> 'gt' /
                  %LE -> 'le' /
                  %GE -> 'ge' /
                  %EQ -> 'eq'
    op_bor    <-  %BOR -> 'bor'
    op_xor    <-  %BXOR -> 'bxor'
    op_band   <-  %BAND -> 'band'
    op_bshift <-  %SHL -> 'shl' /
                  %SHR -> 'shr'
    op_concat <-  %CONCAT -> 'concat'
    op_add    <-  %ADD -> 'add' /
                  %SUB -> 'sub'
    op_mul    <-  %MUL -> 'mul' /
                  %IDIV -> 'idiv' /
                  %DIV -> 'div' /
                  %MOD -> 'mod'
    op_unary  <-  %NOT -> 'not' /
                  %LEN -> 'len' /
                  %UNM -> 'unm' /
                  %BNOT -> 'bnot' /
                  %REF -> 'ref' /
                  op_deref
    op_deref  <-  %DEREF -> 'deref'
    op_pow    <-  %POW -> 'pow'
    op_range  <-  %COLON -> 'range' ![({"']
  ]])

  -- syntax expected captures with errors
  grammar:set_pegs([[
    eRPAREN         <- %RPAREN        / %{UnclosedParenthesis}
    eRBRACKET       <- %RBRACKET      / %{UnclosedBracket}
    eRCURLY         <- %RCURLY        / %{UnclosedCurly}
    eRANGLE         <- %RANGLE        / %{UnclosedAngle}
    eLPAREN         <- %LPAREN        / %{ExpectedParenthesis}
    eLCURLY         <- %LCURLY        / %{ExpectedCurly}
    eLANGLE         <- %LANGLE        / %{ExpectedAngle}
    eLBRACKET       <- %LBRACKET      / %{ExpectedBracket}
    eCOLON          <- %COLON         / %{ExpectedColon}
    eCOMMA          <- %COMMA         / %{ExpectedComma}
    eEND            <- %END           / %{ExpectedEnd}
    eTHEN           <- %THEN          / %{ExpectedThen}
    eUNTIL          <- %UNTIL         / %{ExpectedUntil}
    eDO             <- %DO            / %{ExpectedDo}
    ename           <- name           / %{ExpectedName}
    eexpr           <- expr           / %{ExpectedExpression}
    etypexpr        <- typexpr        / %{ExpectedTypeExpression}
    ecallargs       <- callargs       / %{ExpectedCall}
    eenumfield      <- enumfield      / %{ExpectedEnumFieldType}
    eprimtype       <- primtype       / %{ExpectedPrimitiveTypeExpression}
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
    UnexpectedSyntaxAtEOF  = 'unexpected syntax',
    UnclosedParenthesis = "unclosed parenthesis, did you forget a `)`?",
    UnclosedBracket = "unclosed square bracket, did you forget a `]`?",
    UnclosedCurly = "unclosed curly brace, did you forget a `}`?",
    UnclosedAngleBracket = "unclosed angle bracket, did you forget a `>`?",
    UnclosedPreprocessBracket = "unclosed preprocess bracket, did your forget a ']##]'?",
    UnclosedLabel = "unclosed label, did you forget `::`?",
    ExpectedParenthesis = "expected parenthesis `(`",
    ExpectedCurly = "expected curly brace `{`",
    ExpectedAngle = "expected angle bracket `<`",
    ExpectedBracket = "expected square bracket `[`",
    ExpectedColon = "expected colon `:`",
    ExpectedComma = "expected comma `,`",
    ExpectedEnd = "expected `end` keyword",
    ExpectedThen = "expected `then` keyword",
    ExpectedUntil = "expected `until` keyword",
    ExpectedDo = "expected `do` keyword",
    ExpectedName = "expected an identifier name",
    ExpectedNumber = "expected a number expression",
    ExpectedExpression = "expected an expression",
    ExpectedTypeExpression = "expected a type expression",
    ExpectedCall = "expected call",
    ExpectedEnumFieldType = "expected at least one enum field",
    ExpectedPrimitiveTypeExpression = "expected a primitive type expression",
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
