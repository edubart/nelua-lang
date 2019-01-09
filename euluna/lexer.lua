local ASTParser = require 'euluna.astparser'
local lexer = ASTParser()

--[[
# List of grammars defined in this Lexer

SPACE           spaces including new lines
LINEBREAK       all new lines formats CR CRLF LF LFCR
LONGCOMMENT     multiline comment
SHORTCOMMENT    single line comment
COMMENT         single or multiline comment
SKIP            skip any code not relevant (spaces, new lines and comments)
ESCAPESEQUENCE  escaped sequence conversion
IDPREFIX        letter or _ character
IDSUFFIX        alphanumeric or _ character
IDFORMAT        full identifier name

# List of tokens defined in this Lexer
KEYWORD         language keywords (for, if, while, ...)
cIDENTIFIER     identifier names, like variable and function names
cNUMBER         capture numbers (hexdecimal, binary, exponential, decimal or integer)
cSTRING         capture long or short strings
CBOOLEAN        capture boolean (true or false)
ADD             +
SUB             -
MUL             *
MOD             %
DIV             /
POW             ^
BAND            &
BOR             |
SHL             <<
SHR             >>
EQ              ==
NE              ~= or !=
LE              <=
GE              >=
LT              <
GT              >
BXOR            ~
ASSIGN          =
NEG             -
LEN             #
BNOT            ~
TOSTRING        $
LPAREN          (
RPAREN          )
LBRACKET        [
RBRACKET        ]
LCURLY          {
RCURLY          }
LANGLE          <
RANGLE          >
SEMICOLON       ;
COMMA           ,
SEPARATOR       , or ;
ELLIPSIS        ...
CONCAT          ..
DOT             .
DBLCOLON        ::
COLON           :
AT              @
DOLLAR          $

* tokens are grammars that automatically skips at the end

]]

-- space and new lines
lexer:add_grammars {
  SPACE = "%s",
  LINEBREAK = "[%nl]'\r' / '\r'[%nl] / [%nl] / '\r'",
}

-- shebang, e.g. "#!/usr/bin/euluna"
lexer:add_grammar('SHEBANG', "'#!' (!%LINEBREAK .)*")

-- comments
lexer:add_grammar('LONGCOMMENT', [[
  longcomment <- open (contents close / %{UnclosedLongComment})
  contents    <- (!close .)*
  open        <- '--[' {:eq: '='*:} '['
  close       <- ']' =eq ']'
]])
lexer:add_grammar('SHORTCOMMENT', "'--' (!%LINEBREAK .)* %LINEBREAK?")
lexer:add_grammar('COMMENT', "%LONGCOMMENT / %SHORTCOMMENT")

-- skip
lexer:add_grammar('SKIP', "(%SPACE / %COMMENT)*")

-- identifier parts
lexer:add_grammar('IDPREFIX', "[_%a]")
lexer:add_grammar('IDSUFFIX', "[_%w]")
lexer:add_grammar('IDFORMAT', "%IDPREFIX %IDSUFFIX*")

-- keywords
local KEYWORDS = {
  -- lua keywords
  "and", "break", "do", "else", "elseif", "end", "for", "false",
  "function", "goto", "if", "in", "local", "nil", "not", "or",
  "repeat", "return", "then", "true", "until", "while",
}

local keyword_names = {}
for i,keyword in ipairs(KEYWORDS) do
  local keyword_name = keyword:upper()
  keyword_names[i] = keyword_name
  lexer:add_token(keyword_name, string.format("'%s' !%%IDSUFFIX", keyword))
end
lexer:add_token('KEYWORD', string.format('%%%s', table.concat(keyword_names, '/%')))
lexer:add_token('cIDENTIFIER', '&%IDPREFIX !%KEYWORD {%IDFORMAT}')

-- number
lexer:add_token('cNUMBER', [[
  number          <- ({} '' -> 'Number' number_types literal?) -> to_astnode
  number_types    <- '' -> 'hex' hexadecimal /
                     '' -> 'bin' binary /
                     '' -> 'exp' exponential /
                     '' -> 'dec' decimal /
                     '' -> 'int' integer
  literal         <- %cIDENTIFIER
  exponential     <- (decimal / integer) [eE] ({[+-]? %d+} / %{MalformedExponentialNumber})
  decimal         <- {'-'? %d+ '.' %d* / '.' %d+}
  integer         <- {'-'? %d+}
  binary          <- '0' [bB] ({[01]+} !%d / %{MalformedBinaryNumber})
  hexadecimal     <- '0' [xX] ({%x+} / %{MalformedHexadecimalNumber})
]])

-- escape sequence
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
lexer:add_grammar('cESCAPESEQUENCE', [[
  escapeseq   <- {~ '\' -> '' escapings ~}
  escapings   <-
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

-- string
lexer:add_token('cSTRING', [[
  string          <- ({} '' -> 'String' (short_string / long_string) literal?) -> to_astnode
  short_string    <- short_open ({~ short_content* ~} short_close / %{UnclosedShortString})
  short_content   <- %cESCAPESEQUENCE / !(=de / %LINEBREAK) .
  short_open      <- {:de: ['"] :}
  short_close     <- =de
  long_string     <- long_open ({long_content*} long_close / %{UnclosedLongString})
  long_content    <- !long_close .
  long_open       <- '[' {:eq: '='*:} '[' %LINEBREAK?
  long_close      <- ']' =eq ']'
  literal         <- %cIDENTIFIER
]])

-- boolean
lexer:add_token('cBOOLEAN', [[
  boolean <- ({} '' -> 'Boolean' ((%FALSE -> to_false) / (%TRUE -> to_true))) -> to_astnode
]], {
  to_false = function() return false end,
  to_true = function() return true end
})

-- binary operators
lexer:add_token('ADD',          "'+'")
lexer:add_token('SUB',          "!'--' '-'")
lexer:add_token('MUL',          "'*'")
lexer:add_token('MOD',          "'%'")
lexer:add_token('DIV',          "'/'")
lexer:add_token('POW',          "'^'")

lexer:add_token('BAND',         "'&'")
lexer:add_token('BOR',          "'|'")
lexer:add_token('SHL',          "'<<'")
lexer:add_token('SHR',          "'>>'")

lexer:add_token('EQ',           "'=='")
lexer:add_token('NE',           "'~=' / '!='")
lexer:add_token('LE',           "'<='")
lexer:add_token('GE',           "'>='")
lexer:add_token('LT',           "!%SHL !%LE '<'")
lexer:add_token('GT',           "!%SHR !%GE '>'")

lexer:add_token('BXOR',         "!%NE '~'")
lexer:add_token('ASSIGN',       "!%EQ '='")

-- unary operators
lexer:add_token('NEG',          "!'--' '-'")
lexer:add_token('LEN',          "'#'")
lexer:add_token('BNOT',         "!%NE '~'")
lexer:add_token('TOSTRING',     "'$'")

-- matching symbols
lexer:add_token('LPAREN',       "'('")
lexer:add_token('RPAREN',       "')'")
lexer:add_token('LBRACKET',     "!('[' '='* '[') '['")
lexer:add_token('RBRACKET',     "']'")
lexer:add_token('LCURLY',       "'{'")
lexer:add_token('RCURLY',       "'}'")
lexer:add_token('LANGLE',       "'<'")
lexer:add_token('RANGLE',       "'>'")

-- other symbols
lexer:add_token('SEMICOLON',    "';'")
lexer:add_token('COMMA',        "','")
lexer:add_token('SEPARATOR',    "[,;]")
lexer:add_token('ELLIPSIS',     "'...'")
lexer:add_token('CONCAT',       "!%ELLIPSIS '..'")
lexer:add_token('DOT',          "!%ELLIPSIS !%CONCAT !('.' %d) '.'")
lexer:add_token('DBLCOLON',     "'::'")
lexer:add_token('COLON',        "!%DBLCOLON ':'")
lexer:add_token('AT',           "'@'")
lexer:add_token('DOLLAR',       "'$'")

-- syntax errors
lexer:add_syntax_errors({
  MalformedExponentialNumber = 'malformed exponential number',
  MalformedBinaryNumber = 'malformed binary number',
  MalformedHexadecimalNumber = 'malformed hexadecimal number',
  UnclosedLongComment = 'unclosed long comment',
  UnclosedShortString = 'unclosed short string',
  UnclosedLongString = 'unclosed long string',
})

return lexer
