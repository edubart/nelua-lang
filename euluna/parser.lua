local parser = require 'euluna.lexer'

parser:add_grammars([==[
  %stat <-
    %SEMICOLON

  %return_stat <-
    ({} %RETURN -> 'Return' %SEMICOLON?) -> to_astnode

  %block <-
    ({} '' -> 'Block' {| %stat* %return_stat? |}) -> to_astnode

  %sourcecode <-
    %SHEBANG? %SKIP
    %block
    (!. / %{UnexpectedSyntaxAtEOF})
]==])

parser:add_syntax_errors({
  UnexpectedSyntaxAtEOF  = 'unexpected syntax, was expecting EOF'
})

return parser
