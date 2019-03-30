local typedefs = require 'euluna.analyzers.types.definitions'

local cdefs = {}

local types = typedefs.primitive_types

cdefs.types_printf_format = {
  [types.char]    = '%c',
  [types.float32] = '%f',
  [types.float64] = '%lf',
  [types.pointer] = '%p',
  [types.int]     = '%ti',
  [types.int8]    = '%hhi',
  [types.int16]   = '%hi',
  [types.int32]   = '%i',
  [types.int64]   = '%li',
  [types.uint]    = '%tu',
  [types.uint8]   = '%hhu',
  [types.uint16]  = '%hu',
  [types.uint32]  = '%u',
  [types.uint64]  = '%lu',
}

cdefs.primitive_ctypes = {
  [types.int]     = {name = 'intptr_t',         },
  [types.int8]    = {name = 'int8_t',           },
  [types.int16]   = {name = 'int16_t',          },
  [types.int32]   = {name = 'int32_t',          },
  [types.int64]   = {name = 'int64_t',          },
  [types.uint]    = {name = 'uintptr_t',        },
  [types.uint8]   = {name = 'uint8_t',          },
  [types.uint16]  = {name = 'uint16_t',         },
  [types.uint32]  = {name = 'uint32_t',         },
  [types.uint64]  = {name = 'uint64_t',         },
  [types.float32] = {name = 'float',            },
  [types.float64] = {name = 'double',           },
  [types.boolean] = {name = 'bool',             },
  [types.string]  = {name = 'euluna_string_t*', },
  [types.char]    = {name = 'char',             },
  [types.pointer] = {name = 'void*',            },
  [types.any]     = {name = 'euluna_any_t',     },
}

cdefs.unary_ops = {
  ['not'] = '!',
  ['neg'] = '-',
  ['bnot'] = '~',
  ['ref'] = '&',
  ['deref'] = '*',
  --TODO: len
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
  --TODO: idiv
  --TODO: pow
  --TODO: concat
}

return cdefs
