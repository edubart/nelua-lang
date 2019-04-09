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
  [primtypes.int]     = {name = 'intptr_t',         },
  [primtypes.int8]    = {name = 'int8_t',           },
  [primtypes.int16]   = {name = 'int16_t',          },
  [primtypes.int32]   = {name = 'int32_t',          },
  [primtypes.int64]   = {name = 'int64_t',          },
  [primtypes.uint]    = {name = 'uintptr_t',        },
  [primtypes.uint8]   = {name = 'uint8_t',          },
  [primtypes.uint16]  = {name = 'uint16_t',         },
  [primtypes.uint32]  = {name = 'uint32_t',         },
  [primtypes.uint64]  = {name = 'uint64_t',         },
  [primtypes.float32] = {name = 'float',            },
  [primtypes.float64] = {name = 'double',           },
  [primtypes.boolean] = {name = 'bool',             },
  [primtypes.string]  = {name = 'euluna_string_t*', },
  [primtypes.char]    = {name = 'char',             },
  [primtypes.pointer] = {name = 'void*',            },
  [primtypes.any]     = {name = 'euluna_any_t',     },
  [primtypes.void]    = {name = 'void',             },
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
