local re = require 'relabel'
local syntax_errors = require "euluna-compiler.syntax_errors"

local lexer = {}

-- setup grammer label errors
re.setlabels(syntax_errors.label_to_int)

-- shortcut for grammar
local function G(peg) return re.compile(peg, lexer) end

-- shortcut for token grammar
local function T(peg) return G(peg) * lexer.SKIP end

-- spacing
lexer.SPACE         = G"%s"
lexer.LINEBREAK     = G"[%nl]'\r' / '\r'[%nl] / [%nl] / '\r'"

-- shebang
lexer.SHEBANG       = G"'#!' (!%LINEBREAK .)*"

-- comments
lexer.LONGCOMMENT   = G[[
  longcomment <- open (contents close / %{UnclosedLongComment})
  contents    <- (!close .)*
  open        <- '--[' {:eq: '='*:} '['
  close       <- ']' =eq ']'
]]
lexer.SHORTCOMMENT  = G"'--' (!%LINEBREAK .)* %LINEBREAK?"
lexer.SKIP          = G"(%SPACE / %LONGCOMMENT / %SHORTCOMMENT)*"
lexer.COMMENT       = T"%LONGCOMMENT / %SHORTCOMMENT"

-- numbers
function lexer.to_hexadecimal(num) return {tag='number', type='hexadecimal', value=num} end
function lexer.to_binary(num)  return {tag='number', type='binary', value=num} end
function lexer.to_exponential(num) return {tag='number', type='exponential', value=num} end
function lexer.to_decimal(num) return {tag='number', type='decimal', value=num} end
function lexer.to_integer(num) return {tag='number', type='integer', value=num} end
function lexer.to_literal(node, literal) node.literal = literal return node end
function lexer.to_number(pos, node) node.pos=pos return node end

lexer.NUMBER = T[[
  number          <- ({} (literal_number / normal_number)) -> to_number
  normal_number   <- hexadecimal -> to_hexadecimal /
                     binary -> to_binary /
                     exponential -> to_exponential /
                     decimal -> to_decimal /
                     integer -> to_integer
  literal_number  <- (normal_number '_' {(%a %w* / %{MalformedLiteral})}) -> to_literal

  exponential     <- (decimal / integer) [eE] ([+-]? %d+ / %{MalformedNumber})
  decimal         <- %d+ '.' %d* / '.' %d+
  integer         <- %d+
  binary          <- '0' [bB] ([01]+ / %{MalformedNumber})
  hexadecimal     <- '0' [xX] (%x+ / %{MalformedNumber})
]]

-- sequence escaping
function lexer.to_char(str) return string.char(tonumber(str)) end
function lexer.to_char_from_hex(str) return string.char(tonumber(str, 16)) end
function lexer.to_unicode_from_hex(str) return (utf8 and utf8.char or string.char)(tonumber(str, 16)) end
function lexer.to_escaped_backslash(str)
  local Backslashes = {
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
  return Backslashes[str]
end
function lexer.to_new_line() return "\n" end

lexer.ESCAPESEQUENCE = G[[
  escape      <- {~ '\' -> '' escapings ~}
  escapings   <-
    [abfnrtv\'"] -> to_escaped_backslash /
    %LINEBREAK -> to_new_line /
    ('z' %s*) -> '' /
    (%d %d^-2) -> to_char /
    ('x' {%x+}) -> to_char_from_hex /
    ('u' '{' {%x+} '}') -> to_unicode_from_hex /
    %{MalformedEscapeSequence}
]]

-- strings
function lexer.to_string(pos, str, literal) return {tag='string', pos=pos, value=str, literal=literal} end

lexer.STRING  = T[[
  string          <- ({} (short_string / long_string) literal?) -> to_string
  literal         <- '_' {(%a %w* / %{MalformedLiteral})}

  long_string     <- long_open ({long_content*} long_close / %{UnclosedLongString})
  long_content    <- !long_close .
  long_open       <- '[' {:eq: '='*:} '[' %LINEBREAK?
  long_close      <- ']' =eq ']'

  short_string    <- short_open ({~ short_content* ~} short_close / %{UnclosedShortString})
  short_content   <- %ESCAPESEQUENCE / !(=de / %LINEBREAK) .
  short_open      <- {:de: ['"] :}
  short_close     <- =de
]]

-- identifier
lexer.IDPREFIX    = G"[_%a]"
lexer.IDSUFFIX    = G"[_%w]"

-- keywords
local Keywords = {
  -- Lua
  "and", "break", "do", "else", "elseif", "end", "for", "false",
  "function", "goto", "if", "in", "local", "nil", "not", "or",
  "repeat", "return", "then", "true", "until", "while",
  -- Euluna
  "export", "global", "continue", "var", "let", "ref", "const",
  "switch", "case", "try", "catch", "finally", "throw", "defer",
  "enum", "object", "as", "of", "discard"
}

local keyword_pattern = ''
for _,keyword in pairs(Keywords) do
  local idkeyword = keyword:upper()
  lexer[idkeyword] = T("'"..keyword.."' !%IDSUFFIX")
  keyword_pattern = keyword_pattern..'%'..idkeyword..' /'
end
keyword_pattern = keyword_pattern:sub(1,-3)

lexer.KEYWORD = T(keyword_pattern)

-- identifier
lexer.NAME    = T"!%KEYWORD {%IDPREFIX %IDSUFFIX*}"

-- boolean
function lexer.to_bool_false(pos) return {tag='boolean', pos=pos, value=false} end
function lexer.to_bool_true(pos) return {tag='boolean', pos=pos, value=true} end
lexer.BOOLEAN = T"({} %FALSE) -> to_bool_false / ({} %TRUE) -> to_bool_true"

-- symbols
lexer.ADD         = T"'+'"
lexer.SUB         = T"!'--' '-'"
lexer.NEG         = lexer.SUB
lexer.MUL         = T"'*'"
lexer.MOD         = T"'%'"
lexer.DIV         = T"'/'"
lexer.POW         = T"'^'"
lexer.LEN         = T"'#'"
lexer.TOSTRING    = T"'$'"

lexer.BAND        = T"'&'"
lexer.BOR         = T"'|'"
lexer.SHL         = T"'<<'"
lexer.SHR         = T"'>>'"

lexer.EQ          = T"'=='"
lexer.NE          = T"'~=' / '!='"
lexer.LE          = T"'<='"
lexer.GE          = T"'>='"
lexer.LT          = T"!%SHL !%LE '<'"
lexer.GT          = T"!%SHR !%GE '>'"

lexer.BXOR        = T"!%NE '~'"
lexer.BNOT        = lexer.BXOR
lexer.ASSIGN      = T"!%EQ '='"

lexer.LPAREN      = T"'('"
lexer.RPAREN      = T"')'"
lexer.LBRACKET    = T"!('[' '='* '[') '['"
lexer.RBRACKET    = T"']'"
lexer.LCURLY      = T"'{'"
lexer.RCURLY      = T"'}'"

lexer.SEMICOLON   = T"';'"
lexer.COMMA       = T"','"
lexer.SEPARATOR   = T"[,;]"
lexer.ELLIPSIS    = T"'...'"
lexer.CONCAT      = T"!%ELLIPSIS '..'"
lexer.DOT         = T"!%ELLIPSIS !%CONCAT !('.' %d) '.'"
lexer.DBLCOLON    = T"'::'"
lexer.COLON       = T"!%DBLCOLON ':'"

-- Euluna
--lexer.AT          = T"'@'"
--lexer.DOLLAR      = T"'$'"
--lexer.QUESTION    = T"'?'"
--lexer.EXCLAMATION = T"'!'"

return lexer
