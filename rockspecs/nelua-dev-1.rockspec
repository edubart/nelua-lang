package = 'nelua'
version = 'dev-1'

source = {
  url = "git://github.com/edubart/nelua-lang",
  branch = "master"
}

description = {
  summary = 'Nelua Programming Language.',
  detailed = [[
Nelua is a minimal, simple, efficient, statically typed, compiled, meta programmable,
safe and extensible systems programming language with a Lua flavor.
It uses ahead of time compilation to compile to native code.
Nelua stands for Native Extensible Lua.
]],
  maintainer = "Eduardo Bart <edub4rt@gmail.com>",
  homepage = 'https://github.com/edubart/nelua-lang',
  license = 'MIT'
}

dependencies = {
  'lua >= 5.4',

  -- nelua originally depended on these, however they were bundled
  -- 'luafilesystem >= 1.8.0',
  -- 'lua-term >= 0.7',
  -- 'lpeglabel >= 1.6.0',
  -- 'hasher >= 0.1.0',
  -- 'chronos >= 0.2',

  -- dev dependencies only (used only for testing)
  --'luacheck >= 0.23.0',
  --'luacov >= 0.13.0',
  --'cluacov >= 0.1.1',
  --'dumper >= 0.1.1',
}

build = {
  type = 'builtin',
  modules = {
    -- Bundled C libraries
    lfs = {sources = {"src/lfs.c"}},
    sys = {sources = {"src/sys.c"}},
    hasher = {sources = {"src/hasher.c" }},
    lpeglabel = {sources = {
      "src/lpeglabel/lpcap.c",
      "src/lpeglabel/lpcode.c",
      "src/lpeglabel/lpprint.c",
      "src/lpeglabel/lptree.c",
      "src/lpeglabel/lpvm.c"
    }},

    -- Nelua compiler sources
    ['nelua.aster'] = 'nelua/aster.lua',
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
    ['nelua.version'] = 'nelua/version.lua',
    ['nelua.visitorcontext'] = 'nelua/visitorcontext.lua',
    ['nelua.thirdparty.argparse'] = 'nelua/thirdparty/argparse.lua',
    ['nelua.thirdparty.bint'] = 'nelua/thirdparty/bint.lua',
    ['nelua.thirdparty.inspect'] = 'nelua/thirdparty/inspect.lua',
    ['nelua.thirdparty.lester'] = 'nelua/thirdparty/lester.lua',
    ['nelua.thirdparty.lpegrex'] = 'nelua/thirdparty/lpegrex.lua',
    ['nelua.thirdparty.tableshape'] = 'nelua/thirdparty/tableshape.lua',
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
    ['nelua.utils.profiler'] = 'nelua/utils/profiler.lua',
    ['nelua.utils.shaper'] = 'nelua/utils/shaper.lua',
    ['nelua.utils.sstream'] = 'nelua/utils/sstream.lua',
    ['nelua.utils.stringer'] = 'nelua/utils/stringer.lua',
    ['nelua.utils.tabler'] = 'nelua/utils/tabler.lua',
    ['nelua.utils.tracker'] = 'nelua/utils/tracker.lua',
    ['nelua.utils.traits'] = 'nelua/utils/traits.lua',
  },
  install = {
    bin = {
      ['nelua'] = 'nelua.lua'
    },
    conf = {
      ['lib/allocators/default.nelua']      = 'lib/allocators/default.nelua',
      ['lib/allocators/interface.nelua']    = 'lib/allocators/interface.nelua',
      ['lib/allocators/general.nelua']      = 'lib/allocators/general.nelua',
      ['lib/allocators/gc.nelua']           = 'lib/allocators/gc.nelua',
      ['lib/allocators/arena.nelua']        = 'lib/allocators/arena.nelua',
      ['lib/allocators/stack.nelua']        = 'lib/allocators/stack.nelua',
      ['lib/allocators/heap.nelua']         = 'lib/allocators/heap.nelua',
      ['lib/allocators/pool.nelua']         = 'lib/allocators/pool.nelua',
      ['lib/arg.nelua']                     = 'lib/arg.nelua',
      ['lib/builtins.nelua']                = 'lib/builtins.nelua',
      ['lib/coroutine.nelua']               = 'lib/coroutine.nelua',
      ['lib/io.nelua']                      = 'lib/io.nelua',
      ['lib/iterators.nelua']               = 'lib/iterators.nelua',
      ['lib/list.nelua']                    = 'lib/list.nelua',
      ['lib/math.nelua']                    = 'lib/math.nelua',
      ['lib/memory.nelua']                  = 'lib/memory.nelua',
      ['lib/sequence.nelua']                = 'lib/sequence.nelua',
      ['lib/span.nelua']                    = 'lib/span.nelua',
      ['lib/vector.nelua']                  = 'lib/vector.nelua',
      ['lib/string.nelua']                  = 'lib/string.nelua',
      ['lib/patternmatcher.nelua']          = 'lib/patternmatcher.nelua',
      ['lib/stringbuilder.nelua']           = 'lib/stringbuilder.nelua',
      ['lib/resourcepool.nelua']            = 'lib/resourcepool.nelua',
      ['lib/filestream.nelua']              = 'lib/filestream.nelua',
      ['lib/hash.nelua']                    = 'lib/hash.nelua',
      ['lib/hashmap.nelua']                 = 'lib/hashmap.nelua',
      ['lib/table.nelua']                   = 'lib/table.nelua',
      ['lib/traits.nelua']                  = 'lib/traits.nelua',
      ['lib/os.nelua']                      = 'lib/os.nelua',
      ['lib/utf8.nelua']                    = 'lib/utf8.nelua',
      ['lib/C/init.nelua']                  = 'lib/C/init.nelua',
      ['lib/C/arg.nelua']                   = 'lib/C/arg.nelua',
      ['lib/C/ctype.nelua']                 = 'lib/C/ctype.nelua',
      ['lib/C/errno.nelua']                 = 'lib/C/errno.nelua',
      ['lib/C/locale.nelua']                = 'lib/C/locale.nelua',
      ['lib/C/math.nelua']                  = 'lib/C/math.nelua',
      ['lib/C/signal.nelua']                = 'lib/C/signal.nelua',
      ['lib/C/stdarg.nelua']                = 'lib/C/stdarg.nelua',
      ['lib/C/stdio.nelua']                 = 'lib/C/stdio.nelua',
      ['lib/C/stdlib.nelua']                = 'lib/C/stdlib.nelua',
      ['lib/C/string.nelua']                = 'lib/C/string.nelua',
      ['lib/C/time.nelua']                  = 'lib/C/time.nelua',
    }
  }
}
