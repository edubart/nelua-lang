local typedefs = require 'nelua.typedefs'
local metamagic = require 'nelua.utils.metamagic'

local cdefs = {}

local primtypes = typedefs.primtypes

cdefs.types_printf_format = {
  [primtypes.float32] = '%f',
  [primtypes.float64] = '%lf',
  [primtypes.pointer] = '%p',
  [primtypes.isize]   = '%ti',
  [primtypes.int8]    = '%hhi',
  [primtypes.int16]   = '%hi',
  [primtypes.int32]   = '%i',
  [primtypes.int64]   = '%li',
  [primtypes.usize]   = '%tu',
  [primtypes.uint8]   = '%hhu',
  [primtypes.uint16]  = '%hu',
  [primtypes.uint32]  = '%u',
  [primtypes.uint64]  = '%lu',

  [primtypes.cchar]       = '%c',
  [primtypes.cschar]      = '%c',
  [primtypes.cshort]      = '%hi',
  [primtypes.cint]        = '%i',
  [primtypes.clong]       = '%li',
  [primtypes.clonglong]   = '%lli',
  [primtypes.cptrdiff]    = '%li',
  [primtypes.cuchar]      = '%c',
  [primtypes.cushort]     = '%hu',
  [primtypes.cuint]       = '%u',
  [primtypes.culong]      = '%lu',
  [primtypes.culonglong]  = '%llu',
  [primtypes.csize]       = '%lu',
  [primtypes.clongdouble] = '%llf',
}

cdefs.primitive_ctypes = {
  [primtypes.isize]   = 'intptr_t',
  [primtypes.int8]    = 'int8_t',
  [primtypes.int16]   = 'int16_t',
  [primtypes.int32]   = 'int32_t',
  [primtypes.int64]   = 'int64_t',
  [primtypes.usize]   = 'uintptr_t',
  [primtypes.uint8]   = 'uint8_t',
  [primtypes.uint16]  = 'uint16_t',
  [primtypes.uint32]  = 'uint32_t',
  [primtypes.uint64]  = 'uint64_t',
  [primtypes.float32] = 'float',
  [primtypes.float64] = 'double',
  [primtypes.boolean] = 'bool',
  [primtypes.cstring] = 'char*',
  [primtypes.pointer] = 'void*',
  [primtypes.Nilptr]  = 'void*',
  [primtypes.void]    = 'void',

  [primtypes.cchar]       = 'char',
  [primtypes.cschar]      = 'signed char',
  [primtypes.cshort]      = 'short',
  [primtypes.cint]        = 'int',
  [primtypes.clong]       = 'long',
  [primtypes.clonglong]   = 'long long',
  [primtypes.cptrdiff]    = 'ptrdiff_t',
  [primtypes.cuchar]      = 'unsigned char',
  [primtypes.cushort]     = 'unsigned short',
  [primtypes.cuint]       = 'unsigned int',
  [primtypes.culong]      = 'unsigned long',
  [primtypes.culonglong]  = 'unsigned long long',
  [primtypes.csize]       = 'size_t',
  [primtypes.clongdouble] = 'long double',
}

cdefs.unary_ops = {
  ['not'] = '!',
  ['unm'] = '-',
  ['bnot'] = '~',
  ['ref'] = '&',
  ['deref'] = '*',
  -- builtins
  ['len'] = true,
  --TODO: tostring
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
  ['le'] = '<=',
  ['ge'] = '>=',
  ['lt'] = '<',
  ['gt'] = '>',
  ['bor'] = '|',
  ['bxor'] = '^',
  ['band'] = '&',
  ['shl'] = '<<',
  ['shr'] = '>>',
  ['add'] = '+',
  ['sub'] = '-',
  ['mul'] = '*',
  -- builtins
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
  cflags_warn = {
    "-Wall",
    "-Wextra",
    --"-Wno-incompatible-pointer-types", -- importing C functions can cause this warn
    --"-Wno-missing-field-initializers", -- records without all fields explicity initialized
    "-Wno-unused-parameter", -- functions with unused parameters
    "-Wno-unused-const-variable", -- consts can be left unused
    "-Wno-unused-function", -- local functions can be left unused
  },
  cflags_base = "-pipe -rdynamic -lm",
  cflags_release = "-O2",
  cflags_debug = "-g"
}

cdefs.compilers_flags = {
  gcc = {
    cflags_release = "-O2 -fno-plt -flto -Wl,-O1,--sort-common,-z,relro,-z,now"
  },
  clang = {
    cflags_release = "-O2 -fno-plt -Wl,-O1,--sort-common,-z,relro,-z,now"
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
