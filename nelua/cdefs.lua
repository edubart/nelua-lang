local metamagic = require 'nelua.utils.metamagic'

local cdefs = {}

cdefs.types_printf_format = {
  nelua_float32 = '"%.7g"',
  nelua_float64 = '"%.14g"',
  nelua_pointer = '"%p"',
  nelua_isize   = '"%" PRIiPTR',
  nelua_int8    = '"%" PRIi8',
  nelua_int16   = '"%" PRIi16',
  nelua_int32   = '"%" PRIi32',
  nelua_int64   = '"%" PRIi64',
  nelua_usize   = '"%" PRIuPTR',
  nelua_uint8   = '"%" PRIu8',
  nelua_uint16  = '"%" PRIu16',
  nelua_uint32  = '"%" PRIu32',
  nelua_uint64  = '"%" PRIu64',

  nelua_cchar       = '"%c"',
  nelua_cschar      = '"%c"',
  nelua_cshort      = '"%i"',
  nelua_cint        = '"%i"',
  nelua_clong       = '"%li"',
  nelua_clonglong   = '"%lli"',
  nelua_cptrdiff    = '"%" PRIiPTR',
  nelua_cuchar      = '"%u"',
  nelua_cushort     = '"%u"',
  nelua_cuint       = '"%u"',
  nelua_culong      = '"%lu"',
  nelua_culonglong  = '"%llu"',
  nelua_csize       = '"%lu"',
  nelua_clongdouble = '"%.19Lg"',
}

cdefs.primitive_ctypes = {
  nelua_isize   = 'intptr_t',
  nelua_int8    = 'int8_t',
  nelua_int16   = 'int16_t',
  nelua_int32   = 'int32_t',
  nelua_int64   = 'int64_t',
  nelua_usize   = 'uintptr_t',
  nelua_uint8   = 'uint8_t',
  nelua_uint16  = 'uint16_t',
  nelua_uint32  = 'uint32_t',
  nelua_uint64  = 'uint64_t',
  nelua_float32 = 'float',
  nelua_float64 = 'double',
  nelua_boolean = 'bool',
  nelua_cstring = 'char*',
  nelua_pointer = 'void*',
  nelua_nilptr  = 'void*',
  nelua_void    = 'void',

  nelua_cchar       = 'char',
  nelua_cschar      = 'signed char',
  nelua_cshort      = 'short',
  nelua_cint        = 'int',
  nelua_clong       = 'long',
  nelua_clonglong   = 'long long',
  nelua_cptrdiff    = 'ptrdiff_t',
  nelua_cuchar      = 'unsigned char',
  nelua_cushort     = 'unsigned short',
  nelua_cuint       = 'unsigned int',
  nelua_culong      = 'unsigned long',
  nelua_culonglong  = 'unsigned long long',
  nelua_csize       = 'size_t',
  nelua_clongdouble = 'long double',
}

cdefs.unary_ops = {
  ['not'] = '!',
  ['unm'] = '-',
  ['bnot'] = '~',
  ['ref'] = '&',
  ['deref'] = '*',
  -- builtins
  ['len'] = true
}

cdefs.compare_ops = {
  ['or'] = '||',
  ['and'] = '&&',
  ['le'] = '<=',
  ['ge'] = '>=',
  ['lt'] = '<',
  ['gt'] = '>',
  ['ne'] = '!=',
  ['eq'] = '=='
}

cdefs.binary_ops = {
  ['or'] = '||',
  ['and'] = '&&',
  ['bor'] = '|',
  ['bxor'] = '^',
  ['band'] = '&',
  ['add'] = '+',
  ['sub'] = '-',
  ['mul'] = '*',
  -- builtins
  ['le'] = true,
  ['ge'] = true,
  ['lt'] = true,
  ['gt'] = true,
  ['shl'] = true,
  ['shr'] = true,
  ['ne'] = true,
  ['eq'] = true,
  ['div'] = true,
  ['idiv'] = true,
  ['pow'] = true,
  ['mod'] = true,
  ['range'] = true,
  --TODO: concat
}

cdefs.compiler_base_flags = {
  cflags_base = "-Wall -lm",
  cflags_release = "-O3 -fno-plt",
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
    cflags_base = "-w -lm"
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
