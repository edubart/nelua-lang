local parser = require 'euluna.langs.euluna_lexer'

parser:set_pegs([==[
  %stat <-
    %SEMICOLON

  %stat_return <-
    ({} %RETURN -> 'Stat_Return' %SEMICOLON?) -> to_astnode

  %block <-
    ({} '' -> 'Block' {| %stat* %stat_return? |}) -> to_astnode

  %sourcecode <-
    %SHEBANG? %SKIP
    %block
    (!. / %{UnexpectedSyntaxAtEOF})
]==])

parser:add_syntax_errors({
  UnexpectedSyntaxAtEOF  = 'unexpected syntax, was expecting EOF'
})

return parser
