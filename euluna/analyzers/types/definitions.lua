local iters = require 'euluna.utils.iterators'
local Type = require 'euluna.type'

local typedefs = {}

-- primitive types
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

-- literal types
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

-- default types for literals
typedefs.number_default_types = {
  int = types.int,
  dec = types.number,
  exp = types.number,
  hex = types.uint,
  bin = types.uint,
}

-- number types
-- NOTE: order here does matter when looking up for a common type between two different types
typedefs.number_types = {
  types.int8, types.int16, types.int32, types.int, types.int64,
  types.uint8, types.uint16, types.uint32, types.uint, types.uint64,
  types.float32, types.float64
}

-- automatic type conversion
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
  types.int, types.int8, types.int16,
  types.uint, types.uint8, types.uint16
})
types.float64:add_conversible_types({
  types.int, types.int8, types.int16, types.int32,
  types.uint, types.uint8, types.uint16, types.uint32,
  types.float32,
})

-- unary operator types
local bitwise_types = {
  types.int, types.int8, types.int16, types.int32, types.int64,
  types.uint, types.uint8, types.uint16, types.uint32, types.uint64
}
local unary_op_types = {
  -- 'not' is defined for everything in the code
  ['neg']   = { types.float32, types.float64,
                types.int, types.int8, types.int16, types.int32, types.int64},
  ['bnot']  = bitwise_types,
  --TODO: ref
  --TODO: deref
  --TODO: len
  --TODO: tostring
}

for opname, optypes in pairs(unary_op_types) do
  for type in iters.ivalues(optypes) do
    type:add_unary_operator_type(opname, optypes.result_type or type)
  end
end

-- binary operator types
local comparable_types = {
  types.char, types.string,
  types.float32, types.float64,
  types.int, types.int8, types.int16, types.int32, types.int64,
  types.uint, types.uint8, types.uint16, types.uint32,
  result_type = types.boolean
}
local binary_op_types = {
  -- 'or', 'and', `ne`, `eq` is defined for everything in the code
  ['le']      = comparable_types,
  ['ge']      = comparable_types,
  ['lt']      = comparable_types,
  ['gt']      = comparable_types,
  ['bor']     = bitwise_types,
  ['bxor']    = bitwise_types,
  ['band']    = bitwise_types,
  ['shl']     = bitwise_types,
  ['shr']     = bitwise_types,
  ['add']     = typedefs.number_types,
  ['sub']     = typedefs.number_types,
  ['mul']     = typedefs.number_types,
  ['div']     = typedefs.number_types,
  ['mod']     = typedefs.number_types,
  ['idiv']    = typedefs.number_types,
  ['pow']     = typedefs.number_types,
  ['concat']  = { types.string }
}

for opname, optypes in pairs(binary_op_types) do
  for type in iters.ivalues(optypes) do
    type:add_binary_operator_type(opname, optypes.result_type or type)
  end
end

typedefs.binary_equality_ops = {
  ['ne'] = true,
  ['eq'] = true,
}

typedefs.binary_conditional_ops = {
  ['or'] = true,
  ['and'] = true,
}

return typedefs
