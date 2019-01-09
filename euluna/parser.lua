local parser = require 'euluna.lexer'

--TODO: actually combine all grammars into a single one but with flexibility
--TODO: test live grammar change!

parser:add_grammar('stat', [==[
  stat <-
    %SEMICOLON
]==])

parser:add_grammar('return_stat', [==[
  return_stat <-
    ({} %RETURN -> 'Return' %SEMICOLON?) -> to_astnode
]==])

parser:add_grammar('block', [==[
  block <-
    ({} '' -> 'Block' {| %stat* %return_stat? |}) -> to_astnode
]==])

parser:add_grammar('sourcecode', [==[
  sourcecode <-
    %SHEBANG? %SKIP
    %block
    (!. / %{UnexpectedSyntaxAtEOF})
]==])

parser:add_syntax_errors({
  UnexpectedSyntaxAtEOF  = 'unexpected syntax, was expecting EOF'
})

return parser
