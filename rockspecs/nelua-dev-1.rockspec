package = 'nelua'
version = 'dev-1'

source = {
  url = "git://github.com/edubart/nelua-lang",
  branch = "master"
}

description = {
  summary = 'The Nelua Programming Language.',
  detailed = [[
Nelua is a minimalistic, performant, safe, optionally typed, compiled, meta programmable,
systems programming language with syntax and semantics similar to Lua
language that can work dynamically or statically depending on the code style and
compiles to C or Lua.
]],
  maintainer = "Eduardo Bart <edub4rt@gmail.com>",
  homepage = 'https://github.com/edubart/nelua-lang',
  license = 'MIT'
}

dependencies = {
  'lua >= 5.1',
  'penlight >= 1.5.4',
  'lpeglabel >= 1.5.0',
  'tableshape >= 2.0.0',
  'lua-term >= 0.7',
  'argparse >= 0.6.0',
  'hasher >= 0.1.0',
  'chronos >= 0.2',
  'lbc >= 20180729',

  -- dev dependencies only
  'busted >= 2.0rc13',
  'luacheck >= 0.23.0',
  'luacov >= 0.13.0',
  'cluacov >= 0.1.1',
  'dumper >= 0.1.0',
}

build = {
  type = 'builtin',
  modules = {
    ['nelua.astbuilder'] = 'nelua/astbuilder.lua',
    ['nelua.astdefs'] = 'nelua/astdefs.lua',
    ['nelua.astnode'] = 'nelua/astnode.lua',
    ['nelua.cbuiltins'] = 'nelua/cbuiltins.lua',
    ['nelua.ccompiler'] = 'nelua/ccompiler.lua',
    ['nelua.ccontext'] = 'nelua/ccontext.lua',
    ['nelua.cdefs'] = 'nelua/cdefs.lua',
    ['nelua.cgenerator'] = 'nelua/cgenerator.lua',
    ['nelua.configer'] = 'nelua/configer.lua',
    ['nelua.context'] = 'nelua/context.lua',
    ['nelua.cemitter'] = 'nelua/cemitter.lua',
    ['nelua.emitter'] = 'nelua/emitter.lua',
    ['nelua.luabuiltins'] = 'nelua/luabuiltins.lua',
    ['nelua.luacompiler'] = 'nelua/luacompiler.lua',
    ['nelua.luadefs'] = 'nelua/luadefs.lua',
    ['nelua.luagenerator'] = 'nelua/luagenerator.lua',
    ['nelua.pegbuilder'] = 'nelua/pegbuilder.lua',
    ['nelua.pegparser'] = 'nelua/pegparser.lua',
    ['nelua.runner'] = 'nelua/runner.lua',
    ['nelua.scope'] = 'nelua/scope.lua',
    ['nelua.symdefs'] = 'nelua/symdefs.lua',
    ['nelua.symbol'] = 'nelua/symbol.lua',
    ['nelua.syntaxdefs'] = 'nelua/syntaxdefs.lua',
    ['nelua.typechecker'] = 'nelua/typechecker.lua',
    ['nelua.preprocessor'] = 'nelua/preprocessor.lua',
    ['nelua.typedefs'] = 'nelua/typedefs.lua',
    ['nelua.types'] = 'nelua/types.lua',
    ['nelua.utils.bn'] = 'nelua/utils/bn.lua',
    ['nelua.utils.class'] = 'nelua/utils/class.lua',
    ['nelua.utils.console'] = 'nelua/utils/console.lua',
    ['nelua.utils.errorer'] = 'nelua/utils/errorer.lua',
    ['nelua.utils.except'] = 'nelua/utils/except.lua',
    ['nelua.utils.executor'] = 'nelua/utils/executor.lua',
    ['nelua.utils.fs'] = 'nelua/utils/fs.lua',
    ['nelua.utils.iterators'] = 'nelua/utils/iterators.lua',
    ['nelua.utils.nanotimer'] = 'nelua/utils/nanotimer.lua',
    ['nelua.utils.memoize'] = 'nelua/utils/memoize.lua',
    ['nelua.utils.metamagic'] = 'nelua/utils/metamagic.lua',
    ['nelua.utils.pegger'] = 'nelua/utils/pegger.lua',
    ['nelua.utils.sstream'] = 'nelua/utils/sstream.lua',
    ['nelua.utils.stringer'] = 'nelua/utils/stringer.lua',
    ['nelua.utils.tabler'] = 'nelua/utils/tabler.lua',
    ['nelua.utils.traits'] = 'nelua/utils/traits.lua',
  },
  install = {
    bin = {
      ['nelua'] = 'nelua.lua'
    },
    conf = {
      ['runtime/c/nelua_core.c']   = 'runtime/c/nelua_core.c',
      ['runtime/c/nelua_core.h']   = 'runtime/c/nelua_core.h',
      ['runtime/c/nelua_main.c']   = 'runtime/c/nelua_main.c',
      ['runtime/c/nelua_main.h']   = 'runtime/c/nelua_main.h',
      ['runtime/c/nelua_gc.c']     = 'runtime/c/nelua_gc.c',
      ['runtime/c/nelua_gc.h']     = 'runtime/c/nelua_gc.h',
      ['runtime/c/nelua_arrtab.c'] = 'runtime/c/nelua_arrtab.c',
      ['runtime/c/nelua_arrtab.h'] = 'runtime/c/nelua_arrtab.h',
      ['runtime/c/nelua_record.c'] = 'runtime/c/nelua_record.c',
      ['runtime/c/nelua_record.h'] = 'runtime/c/nelua_record.h',
    }
  }
}
