local metamagic = require 'nelua.utils.metamagic'

local cdefs = {}

cdefs.types_printf_format = {
  nlfloat32 = '"%.7g"',
  nlfloat64 = '"%.14g"',
  nlpointer = '"%p"',
  nlisize   = '"%" PRIiPTR',
  nlint8    = '"%" PRIi8',
  nlint16   = '"%" PRIi16',
  nlint32   = '"%" PRIi32',
  nlint64   = '"%" PRIi64',
  nlusize   = '"%" PRIuPTR',
  nluint8   = '"%" PRIu8',
  nluint16  = '"%" PRIu16',
  nluint32  = '"%" PRIu32',
  nluint64  = '"%" PRIu64',

  nlcstring     = '"%s"',
  nlcchar       = '"%c"',
  nlcschar      = '"%c"',
  nlcshort      = '"%i"',
  nlcint        = '"%i"',
  nlclong       = '"%li"',
  nlclonglong   = '"%lli"',
  nlcptrdiff    = '"%" PRIiPTR',
  nlcuchar      = '"%u"',
  nlcushort     = '"%u"',
  nlcuint       = '"%u"',
  nlculong      = '"%lu"',
  nlculonglong  = '"%llu"',
  nlcsize       = '"%lu"',
  nlclongdouble = '"%.19Lg"',
}

cdefs.primitive_typenames = {
  nlisize   = {'intptr_t', '<stdint.h>'},
  nlint8    = {'int8_t', '<stdint.h>'},
  nlint16   = {'int16_t', '<stdint.h>'},
  nlint32   = {'int32_t', '<stdint.h>'},
  nlint64   = {'int64_t', '<stdint.h>'},
  nlint128  = '__int128',
  nlusize   = {'uintptr_t', '<stdint.h>'},
  nluint8   = {'uint8_t', '<stdint.h>'},
  nluint16  = {'uint16_t', '<stdint.h>'},
  nluint32  = {'uint32_t', '<stdint.h>'},
  nluint64  = {'uint64_t', '<stdint.h>'},
  nluint128 = 'unsigned __int128',
  nlfloat32 = 'float',
  nlfloat64 = 'double',
  nlfloat128 = '_Float128',
  nlboolean = {'bool', '<stdbool.h>'},
  nlcstring = 'char*',
  nlpointer = 'void*',
  nlnilptr  = 'void*',
  nlvoid    = 'void',
  nlcvalist = {'va_list', '<stdarg.h>'},
  nlcvarargs = '...',

  nlcchar       = 'char',
  nlcschar      = 'signed char',
  nlcshort      = 'short',
  nlcint        = 'int',
  nlclong       = 'long',
  nlclonglong   = 'long long',
  nlcptrdiff    = {'ptrdiff_t', '<stddef.h>'},
  nlcuchar      = 'unsigned char',
  nlcushort     = 'unsigned short',
  nlcuint       = 'unsigned int',
  nlculong      = 'unsigned long',
  nlculonglong  = 'unsigned long long',
  nlcsize       = {'size_t', '<stddef.h>'},
  nlclongdouble = 'long double',
}

cdefs.unary_ops = {
  ['not'] = true,
  ['ref'] = true,
  ['deref'] = true,
  ['len'] = true,
  ['unm'] = true,
  ['bnot'] = true,
}

cdefs.for_compare_ops = {
  ['le'] = '<=',
  ['ge'] = '>=',
  ['lt'] = '<',
  ['gt'] = '>',
  ['ne'] = '!=',
  ['eq'] = '==',
}

cdefs.binary_ops = {
  ['or'] = true,
  ['and'] = true,
  ['bor'] = true,
  ['bxor'] = true,
  ['band'] = true,
  ['add'] = true,
  ['sub'] = true,
  ['mul'] = true,
  ['le'] = true,
  ['ge'] = true,
  ['lt'] = true,
  ['gt'] = true,
  ['shl'] = true,
  ['shr'] = true,
  ['asr'] = true,
  ['ne'] = true,
  ['eq'] = true,
  ['div'] = true,
  ['idiv'] = true,
  ['tdiv'] = true,
  ['mod'] = true,
  ['tmod'] = true,
  ['pow'] = true,
}

cdefs.compiler_base_flags = {
  cflags_base = "-Wall -fwrapv",
  cflags_release = "-O2 -fno-plt",
  cflags_maximum_performance = "-Ofast -fno-plt -flto -march=native -DNDEBUG",
  cflags_debug = "-g"
}

cdefs.search_compilers = {
  'gcc', 'clang',
  'x86_64-w64-mingw32-gcc', 'x86_64-w64-mingw32-clang',
  'i686-w64-mingw32-gcc', 'i686-w64-mingw32-clang',
  'cc'
}

cdefs.compilers_flags = {
  tcc = {
    cflags_base = "-w"
  }
}

do
  for _,compiler_flags in pairs(cdefs.compilers_flags) do
    metamagic.setmetaindex(compiler_flags, cdefs.compiler_base_flags)
  end
end

cdefs.reserverd_keywords = {
  -- C syntax keywrods
  ['auto'] = true,
  ['break'] = true,
  ['case'] = true,
  ['char'] = true,
  ['const'] = true,
  ['continue'] = true,
  ['default'] = true,
  ['do'] = true,
  ['double'] = true,
  ['else'] = true,
  ['enum'] = true,
  ['extern'] = true,
  ['float'] = true,
  ['for'] = true,
  ['goto'] = true,
  ['if'] = true,
  ['int'] = true,
  ['long'] = true,
  ['register'] = true,
  ['return'] = true,
  ['short'] = true,
  ['signed'] = true,
  ['sizeof'] = true,
  ['static'] = true,
  ['struct'] = true,
  ['switch'] = true,
  ['typedef'] = true,
  ['union'] = true,
  ['unsigned'] = true,
  ['void'] = true,
  ['volatile'] = true,
  ['while'] = true,
  ['inline'] = true,
  ['restrict'] = true,
  ['asm'] = true,
  ['fortran'] = true,

  -- C macros aliases
  ['alignas'] = true,
  ['alignof'] = true,
  ['offsetof'] = true,
  ['bool'] = true,
  ['complex'] = true,
  ['imaginary'] = true,
  ['noreturn'] = true,
  ['static_assert'] = true,
  ['thread_local'] = true,

  -- C operator aliases
  ['and'] = true,
  ['and_eq'] = true,
  ['bitand'] = true,
  ['bitor'] = true,
  ['compl'] = true,
  ['not'] = true,
  ['not_eq'] = true,
  ['or'] = true,
  ['or_eq'] = true,
  ['xor'] = true,
  ['xor_eq'] = true,

  -- C macros used internally by compilers
  ['NULL'] = true,
  ['NAN'] = true,
  ['EOF'] = true,
  ['INFINITY'] = true,
  ['BUFSIZ'] = true,

  ['errno'] = true,
  ['stderr'] = true,
  ['stdin'] = true,
  ['stdout'] = true,
  ['assert'] = true,

  -- C arch defines
  ['i386'] = true,
  ['linux'] = true,
  ['mips'] = true,
  ['near'] = true,
  ['powerpc'] = true,
  ['unix'] = true,
}

function cdefs.quotename(name)
  if cdefs.reserverd_keywords[name] then
    return name .. '_'
  end
  return name
end

return cdefs
