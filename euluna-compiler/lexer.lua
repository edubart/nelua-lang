local lpeg = require "lpeglabel"
local re = require 'relabel'
local syntax_errors = require "euluna-compiler.syntax_errors"

local lexer = {}

-- setup grammer label errors
re.setlabels(syntax_errors.label_to_int)

-- shortcut for grammer function
local function G(pattern) return re.compile(pattern, lexer) end

-- spacing
lexer.SPACE         = G"%s"
lexer.SKIP          = G"%SPACE*"
lexer.LINEBREAK     = G"[%nl\r] / [\r%nl] / [%nl] / [\r]"

-- comments
lexer.LONGCOMMENT   = G[[
  longcomment <- open (contents close / %{UnclosedLongComment})
  contents    <- (!close .)*
  open        <- '--[' {:eq: '='*:} '['
  close       <- ']' =eq ']'
]]
lexer.SHORTCOMMENT  = G"'--' (!%LINEBREAK .)* %LINEBREAK?"
lexer.COMMENT       = G"%LONGCOMMENT / %SHORTCOMMENT"

-- numbers
function lexer.toHexadecimal(num) return {tag='number', type='hexdecimal', value=num} end
function lexer.toBinary(num)  return {tag='number', type='binary', value=num} end
function lexer.toExponential(num) return {tag='number', type='exponential', value=num} end
function lexer.toDecimal(num) return {tag='number', type='decimal', value=num} end
function lexer.toInteger(num) return {tag='number', type='integer', value=num} end
function lexer.toLiteral(node, literal) node.literal = literal return node end

lexer.INTEGER       = G"%d+"
lexer.BINARY        = G"'0' [bB] ([01]+ / %{MalformedNumber})"
lexer.HEXADECIMAL   = G"'0' [xX] (%x+ / %{MalformedNumber})"
lexer.DECIMAL       = G"%d+ '.' %d* / '.' %d+"
lexer.EXPONENTIAL   = G"(%DECIMAL / %INTEGER) [eE] ([+-]? %d+ / %{MalformedNumber})"
lexer.NUMBER = G[[
  number         <- (literal_number / normal_number)
  normal_number  <- %HEXADECIMAL -> toHexadecimal /
                    %BINARY -> toBinary /
                    %EXPONENTIAL -> toExponential /
                    %DECIMAL -> toDecimal /
                    %INTEGER -> toInteger
  literal_number <- (normal_number '_' {(%a %w* / %{MalformedNumber})}) -> toLiteral
]]

-- sequence escaping
function lexer.toChar(str) return string.char(tonumber(str)) end
function lexer.toCharFromHex(str) return string.char(tonumber(str, 16)) end
function lexer.toUnicodeFromHex(str) return (utf8 and utf8.char or string.char)(tonumber(str, 16)) end
function lexer.toBackslash(str)
  local Backslashes = {
    ["a"] = "\a", ["b"] = "\b", ["f"] = "\f",
    ["n"] = "\n", ["r"] = "\r",
    ["t"] = "\t", ["v"] = "\v",
    ["\\"] = "\\",
    ["'"] = "'", ['"'] = '"',
  }
  return Backslashes[str]
end
function lexer.toNewLine() return "\n" end

lexer.ESCAPESEQUENCE = G[[
  escape      <- '\' escapings
  escapings   <-
    [abfnrtv\'"] -> toBackslash /
    %LINEBREAK -> toNewLine /
    'z' %s* -> '' /
    (%d %d^-2) -> toChar /
    'x' %x+ -> toCharFromHex /
    ('u' '{' {%x+} '}') -> toUnicodeFromHex /
    %{MalformedEscapeSequence}
]]

-- strings
function lexer.toLongString(str) return {tag='string', type='longstring', value=str} end

lexer.LONGSTRING = G[[
  longstring  <- open (contents close / %{UnclosedLongString})
  contents    <- { (!close .)* } -> toLongString
  open        <- '[' {:eq: '='*:} '[' %LINEBREAK?
  close       <- ']' =eq ']'
]]

lexer.SHORTSTRING = G[[
  shortstring   <- open ({content*} close / %{UnclosedShortString})
  content       <- %ESCAPESEQUENCE / !(=de / %LINEBREAK) .
  open          <- {:de: ['"] :}
  close         <- =de
]]

lexer.STRING  = G"%SHORTSTRING / %LONGSTRING"

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
  "block", "switch", "try", "catch", "case"
}

local keyword_pattern = ''
for _,keyword in pairs(Keywords) do
  local idkeyword = keyword:upper()
  lexer[idkeyword] = G("'"..keyword.."' !%IDSUFFIX")
  keyword_pattern = keyword_pattern..'%'..idkeyword..' /'
end
keyword_pattern = keyword_pattern:sub(1,-3)

lexer.KEYWORD = G(keyword_pattern)

-- identifier
lexer.IDENTIFIER = G"!%KEYWORD %IDPREFIX %IDSUFFIX+"

-- symbols
lexer.ADD       = G"'+'"
lexer.SUB       = G"'-'"
lexer.MUL       = G"'*'"
lexer.MOD       = G"'%'"
lexer.DIV       = G"'/'"
lexer.IDIV      = G"'//'"
lexer.POW       = G"'^'"
lexer.LEN       = G"'#'"
lexer.BAND      = G"'&'"
lexer.BXOR      = G"'~'"
lexer.BOR       = G"'|'"
lexer.SHL       = G"'<<'"
lexer.SHR       = G"'>>'"
lexer.CONCAT    = G"'..'"
lexer.EQ        = G"'=='"
lexer.LT        = G"'<'"
lexer.GT        = G"'>'"
lexer.NE        = G"'~='"
lexer.LE        = G"'<='"
lexer.GE        = G"'>='"
lexer.ASSIGN    = G"'='"
lexer.LPAREN    = G"'('"
lexer.RPAREN    = G"')'"
lexer.LBRACKET  = G"'['"
lexer.RBRACKET  = G"']'"
lexer.LCURLY    = G"'{'"
lexer.RCURLY    = G"'}'"
lexer.SEMICOLON = G"';'"
lexer.COMMA     = G"','"
lexer.DOTS      = G"'...'"
lexer.DOT       = G"'.'"
lexer.DBLCOLON  = G"'::'"
-- Euluna
-- AT = '@'
-- DOLLAR = '$'
-- QUESTION = '?'
-- EXCLAMATION = '!',
lexer.COLON = G"':'"

return lexer
