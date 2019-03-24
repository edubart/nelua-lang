local Type = require 'euluna.type'

local typedefs = {}

local types = {
  char    = Type('char'),
  float64 = Type('float64'),
  float32 = Type('float32'),
  pointer = Type('pointer'),
  int     = Type('int'),
  int8    = Type('int8'),
  int16   = Type('int16'),
  int32   = Type('int32'),
  int64   = Type('int64'),
  uint    = Type('uint'),
  uint8   = Type('uint8'),
  uint16  = Type('uint16'),
  uint32  = Type('uint32'),
  uint64  = Type('uint64'),
  boolean = Type('boolean'),
  string  = Type('string'),
  any     = Type('any'),
  type    = Type.type, -- the type of "type"
}
typedefs.primitive_types = types

-- type aliases
types.integer = types.int64
types.number  = types.float64
types.byte    = types.uint8
types.bool    = types.boolean

typedefs.number_literal_types = {
  _integer    = types.integer,
  _number     = types.number,
  _b          = types.byte,     _byte       = types.byte,
  _c          = types.char,     _char       = types.char,
  _i          = types.int,      _int        = types.int,
  _i8         = types.int8,     _int8       = types.int8,
  _i16        = types.int16,    _int16      = types.int16,
  _i32        = types.int32,    _int32      = types.int32,
  _i64        = types.int64,    _int64      = types.int64,
  _u          = types.uint,     _uint       = types.uint,
  _u8         = types.uint8,    _uint8      = types.uint8,
  _u16        = types.uint16,   _uint16     = types.uint16,
  _u32        = types.uint32,   _uint32     = types.uint32,
  _u64        = types.uint64,   _uint64     = types.uint64,
  _f32        = types.float32,  _float32    = types.float32,
  _f64        = types.float64,  _float64    = types.float64,
  _pointer    = types.pointer,
}

typedefs.number_default_types = {
  int = types.int,
  dec = types.number,
  exp = types.number,
  hex = types.uint,
  bin = types.uint,
}

-- type compatibility
types.uint:add_conversible_types({types.uint8, types.uint16, types.uint32})
types.uint16:add_conversible_types({types.uint8})
types.uint32:add_conversible_types({types.uint8, types.uint16, types.uint32})
types.uint64:add_conversible_types({types.uint, types.uint8, types.uint16, types.uint32})

types.int:add_conversible_types({
  types.int8, types.int16, types.int32,
  types.uint8, types.uint16
})
types.int16:add_conversible_types({
  types.int8,
  types.uint8
})
types.int32:add_conversible_types({
  types.int8, types.int16,
  types.uint8, types.uint16
})
types.int64:add_conversible_types({
  types.int, types.int8, types.int16, types.int32,
  types.uint, types.uint8, types.uint16, types.uint32
})

types.float32:add_conversible_types({
  types.float64,
  types.int, types.int8, types.int16, types.int32, types.int64,
  types.uint, types.uint8, types.uint16, types.uint32, types.uint64
})
types.float64:add_conversible_types({
  types.float32,
  types.int, types.int8, types.int16, types.int32, types.int64,
  types.uint, types.uint8, types.uint16, types.uint32, types.uint64
})

return typedefs
