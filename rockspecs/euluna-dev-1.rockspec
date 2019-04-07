package = 'euluna'
version = 'dev-1'

source = {
  url = "git://github.com/edubart/euluna-lang",
  branch = "master"
}

description = {
  summary = 'The Euluna Programming Language.',
  detailed = [[
Euluna is a minimalistic, performant, safe, optionally typed, compiled, meta programmable,
systems programming language with syntax and semantics similar to Lua
language that can work dynamically or statically depending on the code style and
compiles to C or Lua.
]],
  maintainer = "Eduardo Bart <edub4rt@gmail.com>",
  homepage = 'https://github.com/edubart/euluna-lang',
  license = 'MIT'
}

dependencies = {
  'lua >= 5.1',
  'bit32',
  'penlight >= 1.5.4',
  'lpeglabel >= 1.5.0',
  'tableshape >= 2.0.0',
  'lua-term >= 0.7',
  'argparse >= 0.6.0',
  'sha1 >= 0.6.0',

  -- dev dependencies only
  'inspect >= 3.1.1',
  'busted >= 2.0rc13',
  'luacheck >= 0.23.0',
  'luacov >= 0.13.0',
  'cluacov >= 0.1.1',
  'chronos >= 0.2',
}

build = {
  type = 'builtin',
  modules = {
    ['euluna.astbuilder'] = 'euluna/astbuilder.lua',
    ['euluna.astdefs'] = 'euluna/astdefs.lua',
    ['euluna.astnode'] = 'euluna/astnode.lua',
    ['euluna.cbuiltins'] = 'euluna/cbuiltins.lua',
    ['euluna.ccompiler'] = 'euluna/ccompiler.lua',
    ['euluna.ccontext'] = 'euluna/ccontext.lua',
    ['euluna.cdefs'] = 'euluna/cdefs.lua',
    ['euluna.cgenerator'] = 'euluna/cgenerator.lua',
    ['euluna.configer'] = 'euluna/configer.lua',
    ['euluna.context'] = 'euluna/context.lua',
    ['euluna.emitter'] = 'euluna/emitter.lua',
    ['euluna.luacompiler'] = 'euluna/luacompiler.lua',
    ['euluna.luadefs'] = 'euluna/luadefs.lua',
    ['euluna.luagenerator'] = 'euluna/luagenerator.lua',
    ['euluna.pegbuilder'] = 'euluna/pegbuilder.lua',
    ['euluna.pegparser'] = 'euluna/pegparser.lua',
    ['euluna.runner'] = 'euluna/runner.lua',
    ['euluna.scope'] = 'euluna/scope.lua',
    ['euluna.symbol'] = 'euluna/symbol.lua',
    ['euluna.syntaxdefs'] = 'euluna/syntaxdefs.lua',
    ['euluna.typechecker'] = 'euluna/typechecker.lua',
    ['euluna.typedefs'] = 'euluna/typedefs.lua',
    ['euluna.types'] = 'euluna/types.lua',
    ['euluna.variable'] = 'euluna/variable.lua',
    ['euluna.utils.class'] = 'euluna/utils/class.lua',
    ['euluna.utils.errorer'] = 'euluna/utils/errorer.lua',
    ['euluna.utils.except'] = 'euluna/utils/except.lua',
    ['euluna.utils.executor'] = 'euluna/utils/executor.lua',
    ['euluna.utils.fs'] = 'euluna/utils/fs.lua',
    ['euluna.utils.iterators'] = 'euluna/utils/iterators.lua',
    ['euluna.utils.memoize'] = 'euluna/utils/memoize.lua',
    ['euluna.utils.metamagic'] = 'euluna/utils/metamagic.lua',
    ['euluna.utils.pegger'] = 'euluna/utils/pegger.lua',
    ['euluna.utils.stringer'] = 'euluna/utils/stringer.lua',
    ['euluna.utils.tabler'] = 'euluna/utils/tabler.lua',
    ['euluna.utils.traits'] = 'euluna/utils/traits.lua',
  },
  install = {
    bin = {
      ['euluna'] = 'euluna.lua'
    },
    conf = {
      ['runtime/c/euluna_core.c']   = 'runtime/c/euluna_core.c',
      ['runtime/c/euluna_core.h']   = 'runtime/c/euluna_core.h',
      ['runtime/c/euluna_main.c']   = 'runtime/c/euluna_main.c',
      ['runtime/c/euluna_main.h']   = 'runtime/c/euluna_main.h',
      ['runtime/c/euluna_gc.c']     = 'runtime/c/euluna_gc.c',
      ['runtime/c/euluna_gc.h']     = 'runtime/c/euluna_gc.h',
      ['runtime/c/euluna_arrtab.c'] = 'runtime/c/euluna_arrtab.c',
      ['runtime/c/euluna_arrtab.h'] = 'runtime/c/euluna_arrtab.h',
    }
  }
}
