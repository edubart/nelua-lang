package = 'nelua'
version = 'dev-1'

source = {
  url = "git://github.com/edubart/nelua-lang",
  branch = "master"
}

description = {
  summary = 'The Nelua Programming Language.',
  detailed = [[
Nelua is a minimalistic, efficient, optionally typed, ahead of time compiled,
meta programmable, systems programming language with syntax and semantics similar to Lua.
It can work statically or dynamically depending on the code style and compiles to native machine code.
]],
  maintainer = "Eduardo Bart <edub4rt@gmail.com>",
  homepage = 'https://github.com/edubart/nelua-lang',
  license = 'MIT'
}

dependencies = {
  'lua >= 5.3',
  'penlight >= 1.7.0',
  'lpeglabel >= 1.6.0',
  'hasher >= 0.1.0',
  'chronos >= 0.2',
  'lbc >= 20180729',

  -- dev dependencies only
  --'busted >= 2.0.0',
  --'luacheck >= 0.23.0',
  --'luacov >= 0.13.0',
  --'cluacov >= 0.1.1',
  --'dumper >= 0.1.1',
}

build = {
  type = 'builtin',
  modules = {
    ['nelua.astbuilder'] = 'nelua/astbuilder.lua',
    ['nelua.astdefs'] = 'nelua/astdefs.lua',
    ['nelua.astnode'] = 'nelua/astnode.lua',
    ['nelua.builtins'] = 'nelua/builtins.lua',
    ['nelua.cbuiltins'] = 'nelua/cbuiltins.lua',
    ['nelua.ccompiler'] = 'nelua/ccompiler.lua',
    ['nelua.ccontext'] = 'nelua/ccontext.lua',
    ['nelua.cdefs'] = 'nelua/cdefs.lua',
    ['nelua.cgenerator'] = 'nelua/cgenerator.lua',
    ['nelua.configer'] = 'nelua/configer.lua',
    ['nelua.analyzercontext'] = 'nelua/analyzercontext.lua',
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
    ['nelua.attr'] = 'nelua/attr.lua',
    ['nelua.syntaxdefs'] = 'nelua/syntaxdefs.lua',
    ['nelua.analyzer'] = 'nelua/analyzer.lua',
    ['nelua.preprocessor'] = 'nelua/preprocessor.lua',
    ['nelua.ppcontext'] = 'nelua/ppcontext.lua',
    ['nelua.typedefs'] = 'nelua/typedefs.lua',
    ['nelua.types'] = 'nelua/types.lua',
    ['nelua.visitorcontext'] = 'nelua/visitorcontext.lua',
    ['nelua.thirdparty.argparse'] = 'nelua/thirdparty/argparse.lua',
    ['nelua.thirdparty.inspect'] = 'nelua/thirdparty/inspect.lua',
    ['nelua.thirdparty.tableshape'] = 'nelua/thirdparty/tableshape.lua',
    ['nelua.thirdparty.term'] = 'nelua/thirdparty/term.lua',
    ['nelua.utils.bn'] = 'nelua/utils/bn.lua',
    ['nelua.utils.class'] = 'nelua/utils/class.lua',
    ['nelua.utils.console'] = 'nelua/utils/console.lua',
    ['nelua.utils.errorer'] = 'nelua/utils/errorer.lua',
    ['nelua.utils.except'] = 'nelua/utils/except.lua',
    ['nelua.utils.executor'] = 'nelua/utils/executor.lua',
    ['nelua.utils.fs'] = 'nelua/utils/fs.lua',
    ['nelua.utils.iterators'] = 'nelua/utils/iterators.lua',
    ['nelua.utils.nanotimer'] = 'nelua/utils/nanotimer.lua',
    ['nelua.utils.luaver'] = 'nelua/utils/luaver.lua',
    ['nelua.utils.memoize'] = 'nelua/utils/memoize.lua',
    ['nelua.utils.metamagic'] = 'nelua/utils/metamagic.lua',
    ['nelua.utils.pegger'] = 'nelua/utils/pegger.lua',
    ['nelua.utils.platform'] = 'nelua/utils/platform.lua',
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
      ['lib/allocators/interface.nelua'] = 'lib/allocators/interface.nelua',
      ['lib/allocators/generic.nelua']   = 'lib/allocators/generic.nelua',
      ['lib/allocators/gc.nelua']        = 'lib/allocators/gc.nelua',
      ['lib/core.nelua']           = 'lib/core.nelua',
      ['lib/io.nelua']             = 'lib/io.nelua',
      ['lib/math.nelua']           = 'lib/math.nelua',
      ['lib/memory.nelua']         = 'lib/memory.nelua',
      ['lib/sequence.nelua']       = 'lib/sequence.nelua',
      ['lib/span.nelua']           = 'lib/span.nelua',
      ['lib/vector.nelua']         = 'lib/vector.nelua',
      ['lib/string.nelua']         = 'lib/string.nelua',
      ['lib/table.nelua']          = 'lib/table.nelua',
      ['lib/traits.nelua']         = 'lib/traits.nelua',
      ['lib/os.nelua']             = 'lib/os.nelua',
      ['lib/utf8.nelua']           = 'lib/utf8.nelua',
      ['lib/C/ctype.nelua']        = 'lib/C/ctype.nelua',
      ['lib/C/errno.nelua']        = 'lib/C/errno.nelua',
      ['lib/C/locale.nelua']       = 'lib/C/locale.nelua',
      ['lib/C/math.nelua']         = 'lib/C/math.nelua',
      ['lib/C/signal.nelua']       = 'lib/C/signal.nelua',
      ['lib/C/stdio.nelua']        = 'lib/C/stdio.nelua',
      ['lib/C/stdlib.nelua']       = 'lib/C/stdlib.nelua',
      ['lib/C/string.nelua']       = 'lib/C/string.nelua',
      ['lib/C/time.nelua']         = 'lib/C/time.nelua',
    }
  }
}
