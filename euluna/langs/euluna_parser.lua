require 'compat53'

local parser = require 'euluna.langs.euluna_lexer'
local grammar = require 'euluna.langs.euluna_grammar'

parser:set_grammar('sourcecode', grammar)

-- syntax errors
parser:add_syntax_errors({
  UnexpectedSyntaxAtEOF  = 'unexpected syntax, was expecting EOF'
})

return parser
