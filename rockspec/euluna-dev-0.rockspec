package = 'euluna'
version = 'dev-0'

source = {
  url = "git://github.com/edubart/euluna-lang",
  branch = "master"
}

description = {
  summary = 'The Euluna Programming Language.',
  detailed = 'An elegant efficient system and applications programming language statically typed compiled that can be mixed with C++ and Lua code.',
  maintainer = "Eduardo Bart <edub4rt@gmail.com>",
  homepage = 'https://github.com/edubart/euluna-lang',
  license = 'MIT <http://opensource.org/licenses/MIT>'
}

dependencies = {
  'penlight',
  'lpeglabel',
  'luaossl',
  'inspect',
  'argparse',
}

build = {
  type = 'builtin',
  modules = {
    ['euluna-compiler.cpp_builtin_functions'] = 'euluna-compiler/cpp_builtin_functions.lua',
    ['euluna-compiler.cpp_builtin_generator'] = 'euluna-compiler/cpp_builtin_generator.lua',
    ['euluna-compiler.cpp_compiler'] = 'euluna-compiler/cpp_compiler.lua',
    ['euluna-compiler.cpp_generator'] = 'euluna-compiler/cpp_generator.lua',
    ['euluna-compiler.global'] = 'euluna-compiler/global.lua',
    ['euluna-compiler.lexer'] = 'euluna-compiler/lexer.lua',
    ['euluna-compiler.parser'] = 'euluna-compiler/parser.lua',
    ['euluna-compiler.syntax_errors'] = 'euluna-compiler/syntax_errors.lua',
    ['euluna-compiler.util'] = 'euluna-compiler/util.lua',
  },
  install = {
    bin = {
      ['euluna'] = 'euluna.lua'
    }
  }
}
