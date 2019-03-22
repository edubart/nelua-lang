package = 'euluna'
version = 'dev-1'

source = {
  url = "git://github.com/edubart/euluna-lang",
  branch = "master"
}

description = {
  summary = 'The Euluna Programming Language.',
  detailed = [[
Euluna is a minimalistic, performant, safe, optionally typed, meta programmable,
systems programming language with syntax close to Lua language that works
either dynamically or staticaly by compiling to Lua or C.
]],
  maintainer = "Eduardo Bart <edub4rt@gmail.com>",
  homepage = 'https://github.com/edubart/euluna-lang',
  license = 'MIT'
}

dependencies = {
  'penlight >= 1.5.4',
  'lpeglabel >= 1.5.0',
  'tableshape >= 2.0.0',
  'inspect >= 3.1.1',
  'lua-term >= 0.7',
  'argparse >= 0.6.0',
  'sha1 >= 0.6.0',

  -- dev dependencies only
  'busted >= 2.0rc13',
  'luacheck >= 0.23.0',
  'luacov >= 0.13.0',
  'cluacov >= 0.1.1',
}

build = {
  type = 'builtin',
  modules = {
    ['euluna.configer'] = 'euluna/configer.lua',
    ['euluna.grammar'] = 'euluna/grammar.lua',
    ['euluna.parser'] = 'euluna/parser.lua',
    ['euluna.coder'] = 'euluna/coder.lua',
    ['euluna.runner'] = 'euluna/runner.lua',
    ['euluna.scope'] = 'euluna/scope.lua',
    ['euluna.aster'] = 'euluna/aster.lua',
    ['euluna.astnode'] = 'euluna/astnode.lua',
    ['euluna.traverser'] = 'euluna/traverser.lua',
    ['euluna.analyzers.type_analyzer'] = 'euluna/analyzers/type_analyzer.lua',
    ['euluna.compilers.lua_compiler'] = 'euluna/compilers/lua_compiler.lua',
    ['euluna.compilers.c_compiler'] = 'euluna/compilers/c_compiler.lua',
    ['euluna.generators.c_generator'] = 'euluna/generators/c_generator.lua',
    ['euluna.generators.lua_generator'] = 'euluna/generators/lua_generator.lua',
    ['euluna.parsers.euluna_std_default'] = 'euluna/parsers/euluna_std_default.lua',
    ['euluna.parsers.euluna_std_luacompat'] = 'euluna/parsers/euluna_std_luacompat.lua',
    ['euluna.utils.class'] = 'euluna/utils/class.lua',
    ['euluna.utils.errorer'] = 'euluna/utils/errorer.lua',
    ['euluna.utils.pegger'] = 'euluna/utils/pegger.lua',
    ['euluna.utils.tabler'] = 'euluna/utils/tabler.lua',
    ['euluna.utils.traits'] = 'euluna/utils/traits.lua',
  },
  install = {
    bin = {
      ['euluna'] = 'euluna.lua'
    }
  }
}
