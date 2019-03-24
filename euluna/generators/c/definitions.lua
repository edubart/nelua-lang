local typedefs = require 'euluna.analyzers.types.definitions'

local cdefs = {}

local primitive_types = typedefs.primitive_types

cdefs.types_printf_format = {
  [primitive_types.char]    = '%c',
  [primitive_types.float64] = '%f',
  [primitive_types.float32] = '%lf',
  [primitive_types.pointer] = '%p',
  [primitive_types.int]     = '%ti',
  [primitive_types.int8]    = '%hhi',
  [primitive_types.int16]   = '%hi',
  [primitive_types.int32]   = '%li',
  [primitive_types.int64]   = '%lli',
  [primitive_types.uint]    = '%tu',
  [primitive_types.uint8]   = '%hhu',
  [primitive_types.uint16]  = '%hu',
  [primitive_types.uint32]  = '%lu',
  [primitive_types.uint64]  = '%llu',
}

cdefs.primitive_ctypes = {
  [primitive_types.char]    = {name = 'char',                                      },
  [primitive_types.float64] = {name = 'double',                                    },
  [primitive_types.float32] = {name = 'float',                                     },
  [primitive_types.pointer] = {name = 'void*',                                     },
  [primitive_types.int]     = {name = 'intptr_t',        include='<stdint.h>'      },
  [primitive_types.int8]    = {name = 'int8_t',          include='<stdint.h>'      },
  [primitive_types.int16]   = {name = 'int16_t',         include='<stdint.h>'      },
  [primitive_types.int32]   = {name = 'int32_t',         include='<stdint.h>'      },
  [primitive_types.int64]   = {name = 'int64_t',         include='<stdint.h>'      },
  [primitive_types.uint]    = {name = 'uintptr_t',       include='<stdint.h>'      },
  [primitive_types.uint8]   = {name = 'uint8_t',         include='<stdint.h>'      },
  [primitive_types.uint16]  = {name = 'uint16_t',        include='<stdint.h>'      },
  [primitive_types.uint32]  = {name = 'uint32_t',        include='<stdint.h>'      },
  [primitive_types.uint64]  = {name = 'uint64_t',        include='<stdint.h>'      },
  [primitive_types.boolean] = {name = 'bool',            include='<stdbool.h>'     },
  [primitive_types.string]  = {name = 'euluna_string_t', builtin='euluna_string_t' },
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
