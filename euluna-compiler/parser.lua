local parser = {}

require 'euluna-compiler.global'
local lpeg = require "lpeglabel"
local re = require "relabel"
local ast = require "euluna-compiler.ast"
local lexer = require "euluna-compiler.lexer"
local syntax_errors = require "euluna-compiler.syntax_errors"
local inspect = require "inspect"

re.setlabels(syntax_errors.label_to_int)

local defs = {
  opt = function(...)
    return {retparam = {...}}
  end,
  Stat_Block = function(...)
    return {block = {...} }
  end,
  Stat_Return = function(...)
    return {ret = {...}}
  end
}
local grammar = re.compile([[
  program       <- euluna

  euluna        <- SHEBANG^-1 SKIP block SKIP EOF

  block         <- ({} {| statement* return? |})    -> Stat_Block
  return        <- ({} RETURN (exp? -> opt))        -> Stat_Return
  exp           <- [a-z]+

  statement     <- "wont match" SKIP

  -- lexer
  RETURN        <- 'return' !IDREST SKIP
  IDREST        <- [_A-Za-z0-9]

  SKIP          <- (SPACE / COMMENT)*
  EOF           <- !. / %{EOFError}
  SPACE         <- %s
  COMMENT       <- LONG_COMMENT / SHORT_COMMENT
  SHORT_COMMENT <- '--' (!%nl .)*
  LONG_COMMENT  <- '--[[' (!"]%]" .)* "]%]"
  SHEBANG       <- '#!' (!%nl .)*
]], defs)

function parser.parse(input)
  local ast, errnum, suffix = grammar:match(input)
  dump(ast)
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
