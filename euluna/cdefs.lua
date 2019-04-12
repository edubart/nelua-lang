local typedefs = require 'euluna.typedefs'
local metamagic = require 'euluna.utils.metamagic'

local cdefs = {}

local primtypes = typedefs.primtypes

cdefs.types_printf_format = {
  [primtypes.char]    = '%c',
  [primtypes.float32] = '%f',
  [primtypes.float64] = '%lf',
  [primtypes.pointer] = '%p',
  [primtypes.int]     = '%ti',
  [primtypes.int8]    = '%hhi',
  [primtypes.int16]   = '%hi',
  [primtypes.int32]   = '%i',
  [primtypes.int64]   = '%li',
  [primtypes.uint]    = '%tu',
  [primtypes.uint8]   = '%hhu',
  [primtypes.uint16]  = '%hu',
  [primtypes.uint32]  = '%u',
  [primtypes.uint64]  = '%lu',
}

cdefs.primitive_ctypes = {
  [primtypes.int]     = 'intptr_t',
  [primtypes.int8]    = 'int8_t',
  [primtypes.int16]   = 'int16_t',
  [primtypes.int32]   = 'int32_t',
  [primtypes.int64]   = 'int64_t',
  [primtypes.uint]    = 'uintptr_t',
  [primtypes.uint8]   = 'uint8_t',
  [primtypes.uint16]  = 'uint16_t',
  [primtypes.uint32]  = 'uint32_t',
  [primtypes.uint64]  = 'uint64_t',
  [primtypes.float32] = 'float',
  [primtypes.float64] = 'double',
  [primtypes.boolean] = 'bool',
  [primtypes.char]    = 'char',
  [primtypes.cstring] = 'char*',
  [primtypes.pointer] = 'void*',
  [primtypes.void]    = 'void',
}

cdefs.unary_ops = {
  ['not'] = '!',
  ['neg'] = '-',
  ['bnot'] = '~',
  ['ref'] = '&',
  ['deref'] = '*',
  -- builtins
  ['len'] = true,
  --TODO: tostring
}

cdefs.binary_ops = {
  ['or'] = '||',
  ['and'] = '&&',
  ['ne'] = '!=',
  ['eq'] = '==',
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
  ['div'] = '/',
  ['mod'] = '%',
  -- builtins
  ['idiv'] = true,
  ['pow'] = true,
  --TODO: concat
}

cdefs.runtime_files = {
  'euluna_core',
  'euluna_gc',
  'euluna_arrtab',
  'euluna_main',
  'euluna_math',
}

cdefs.compiler_base_flags = {
  cflags_base = "-pipe -std=c99 -pedantic -Wall -Wextra -fno-strict-aliasing -rdynamic",
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

for _,compiler_flags in pairs(cdefs.compilers_flags) do
  metamagic.setmetaindex(compiler_flags, cdefs.compiler_base_flags)
end

return cdefs
