local cdefs = {}

cdefs.PRINTF_TYPES_FORMAT = {
  integer = '%lli',
  number  = '%lf',
  byte    = '%hhi',
  char    = '%c',
  float64 = '%f',
  float32 = '%lf',
  pointer = '%p',
  int     = '%ti',
  int8    = '%hhi',
  int16   = '%hi',
  int32   = '%li',
  int64   = '%lli',
  uint    = '%tu',
  uint8   = '%hhu',
  uint16  = '%hu',
  uint32  = '%lu',
  uint64  = '%llu',
}

cdefs.PRIMIVE_TYPES = {
  integer = {ctype = 'int64_t',         include='<stdint.h>'      },
  number  = {ctype = 'double',                                    },
  byte    = {ctype = 'unsigned char',                             },
  char    = {ctype = 'char',                                      },
  float64 = {ctype = 'double',                                    },
  float32 = {ctype = 'float',                                     },
  pointer = {ctype = 'void*',                                     },
  int     = {ctype = 'intptr_t',        include='<stdint.h>'      },
  int8    = {ctype = 'int8_t',          include='<stdint.h>'      },
  int16   = {ctype = 'int16_t',         include='<stdint.h>'      },
  int32   = {ctype = 'int32_t',         include='<stdint.h>'      },
  int64   = {ctype = 'int64_t',         include='<stdint.h>'      },
  uint    = {ctype = 'uintptr_t',       include='<stdint.h>'      },
  uint8   = {ctype = 'uint8_t',         include='<stdint.h>'      },
  uint16  = {ctype = 'uint16_t',        include='<stdint.h>'      },
  uint32  = {ctype = 'uint32_t',        include='<stdint.h>'      },
  uint64  = {ctype = 'uint64_t',        include='<stdint.h>'      },
  boolean = {ctype = 'bool',            include='<stdbool.h>'     },
  bool    = {ctype = 'bool',            include='<stdbool.h>'     },
  string  = {ctype = 'euluna_string_t', builtin='euluna_string_t' },
}

cdefs.UNARY_OPS = {
  ['not'] = '!',
  ['neg'] = '-',
  ['bnot'] = '~',
  ['ref'] = '&',
  ['deref'] = '*',
  --TODO: len
  --TODO: tostring
}

cdefs.BINARY_OPS = {
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
