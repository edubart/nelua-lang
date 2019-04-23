local iters = require 'euluna.utils.iterators'
local tabler = require 'euluna.utils.tabler'
local metamagic = require 'euluna.utils.metamagic'
local types = require 'euluna.types'
local bn = require 'euluna.utils.bn'
local shaper = require 'tableshape'.types
local Type = types.Type

local typedefs = {}

-- primitive types
local primtypes = {
  int       = Type('int'),
  int8      = Type('int8'),
  int16     = Type('int16'),
  int32     = Type('int32'),
  int64     = Type('int64'),
  uint      = Type('uint'),
  uint8     = Type('uint8'),
  uint16    = Type('uint16'),
  uint32    = Type('uint32'),
  uint64    = Type('uint64'),
  float32   = Type('float32'),
  float64   = Type('float64'),
  boolean   = Type('boolean'),
  string    = Type('string'),
  cstring   = Type('cstring'),
  char      = Type('char'),
  any       = Type('any'),
  void      = Type('void'),
  table     = Type('table'),
  Nil       = Type('nil'),
  type      = Type.type, -- the type of "Type"
}
primtypes.pointer = types.PointerType(nil, primtypes.void)
typedefs.primtypes = primtypes

-- type aliases
primtypes.integer  = primtypes.int64
primtypes.uinteger = primtypes.uint64
primtypes.number   = primtypes.float64
primtypes.byte     = primtypes.uint8

-- integral types
local integral_types = {
  primtypes.int, primtypes.int8, primtypes.int16, primtypes.int32, primtypes.int64,
  primtypes.uint, primtypes.uint8, primtypes.uint16, primtypes.uint32, primtypes.uint64,
}
do
  for itype in iters.ivalues(integral_types) do
    itype.integral = true
  end
end

-- integral ranges
typedefs.signed_ranges = {
  { type = primtypes.int8,   min = - bn.pow(2,  8) / 2, max = bn.pow(2,  8) / 2 - 1 },
  { type = primtypes.int16,  min = - bn.pow(2, 16) / 2, max = bn.pow(2, 16) / 2 - 1 },
  { type = primtypes.int32,  min = - bn.pow(2, 32) / 2, max = bn.pow(2, 32) / 2 - 1 },
  { type = primtypes.int64,  min = - bn.pow(2, 64) / 2, max = bn.pow(2, 64) / 2 - 1 },
  { type = primtypes.int,    min = - bn.pow(2, 64) / 2, max = bn.pow(2, 64) / 2 - 1 },
}
typedefs.unsigned_ranges = {
  { type = primtypes.uint8,  min = bn.new(0), max = bn.pow(2,  8) },
  { type = primtypes.uint16, min = bn.new(0), max = bn.pow(2, 16) },
  { type = primtypes.uint32, min = bn.new(0), max = bn.pow(2, 32) },
  { type = primtypes.uint64, min = bn.new(0), max = bn.pow(2, 64) },
  { type = primtypes.uint,   min = bn.new(0), max = bn.pow(2, 64) },
}

-- real types
primtypes.float32.float = true
primtypes.float64.float = true
primtypes.uint.unsigned = true
primtypes.uint8.unsigned = true
primtypes.uint16.unsigned = true
primtypes.uint32.unsigned = true
primtypes.uint64.unsigned = true

-- literal types
typedefs.number_literal_types = {
  _integer    = primtypes.integer,
  _uinteger   = primtypes.uinteger,
  _number     = primtypes.number,
  _b          = primtypes.byte,     _byte       = primtypes.byte,
  _c          = primtypes.char,     _char       = primtypes.char,
  _i          = primtypes.int,      _int        = primtypes.int,
  _i8         = primtypes.int8,     _int8       = primtypes.int8,
  _i16        = primtypes.int16,    _int16      = primtypes.int16,
  _i32        = primtypes.int32,    _int32      = primtypes.int32,
  _i64        = primtypes.int64,    _int64      = primtypes.int64,
  _u          = primtypes.uint,     _uint       = primtypes.uint,
  _u8         = primtypes.uint8,    _uint8      = primtypes.uint8,
  _u16        = primtypes.uint16,   _uint16     = primtypes.uint16,
  _u32        = primtypes.uint32,   _uint32     = primtypes.uint32,
  _u64        = primtypes.uint64,   _uint64     = primtypes.uint64,
  _f32        = primtypes.float32,  _float32    = primtypes.float32,
  _f64        = primtypes.float64,  _float64    = primtypes.float64,
  _pointer    = primtypes.pointer,
}

-- number types
-- NOTE: order here does matter when looking up for a common type between two different types
typedefs.numeric_types = {
  primtypes.int8, primtypes.int16, primtypes.int32, primtypes.int64,
  primtypes.uint8, primtypes.uint16, primtypes.uint32, primtypes.uint64,
  primtypes.float64,
  -- will never be choosen as a common type, but we need to list it
  primtypes.int,
  primtypes.uint,
  primtypes.float32
}

-- automatic type conversion
primtypes.uint:add_conversible_types({primtypes.uint8, primtypes.uint16, primtypes.uint32})
primtypes.uint16:add_conversible_types({primtypes.uint8})
primtypes.uint32:add_conversible_types({primtypes.uint8, primtypes.uint16, primtypes.uint32})
primtypes.uint64:add_conversible_types({primtypes.uint, primtypes.uint8, primtypes.uint16, primtypes.uint32})
primtypes.int:add_conversible_types({
  primtypes.int8, primtypes.int16, primtypes.int32,
  primtypes.uint8, primtypes.uint16
})
primtypes.int16:add_conversible_types({
  primtypes.int8,
  primtypes.uint8
})
primtypes.int32:add_conversible_types({
  primtypes.int8, primtypes.int16,
  primtypes.uint8, primtypes.uint16
})
primtypes.int64:add_conversible_types({
  primtypes.int, primtypes.int8, primtypes.int16, primtypes.int32,
  primtypes.uint, primtypes.uint8, primtypes.uint16, primtypes.uint32
})
primtypes.float32:add_conversible_types({
  primtypes.int, primtypes.int8, primtypes.int16, primtypes.int32, primtypes.int64,
  primtypes.uint, primtypes.uint8, primtypes.uint16, primtypes.uint32, primtypes.uint64,
  primtypes.float64
})
primtypes.float64:add_conversible_types({
  primtypes.int, primtypes.int8, primtypes.int16, primtypes.int32, primtypes.int64,
  primtypes.uint, primtypes.uint8, primtypes.uint16, primtypes.uint32, primtypes.uint64,
  primtypes.float32
})
primtypes.cstring:add_conversible_types({
  primtypes.string
})

-- unary operator types
local bitwise_types = {
  primtypes.int, primtypes.int8, primtypes.int16, primtypes.int32, primtypes.int64,
  primtypes.uint, primtypes.uint8, primtypes.uint16, primtypes.uint32, primtypes.uint64
}
local unary_op_types = {
  ['neg']   = { primtypes.float32, primtypes.float64,
                primtypes.int, primtypes.int8, primtypes.int16, primtypes.int32, primtypes.int64},
  ['bnot']  = bitwise_types,
  ['len']   = { types.ArrayTableType, types.ArrayType, types.RecordType,
                result_type = primtypes.integer },
  ['not']   = { Type, primtypes.boolean },
  ['ref']   = { Type, result_type = function(type)
                  if not type:is_type() then
                    return types.PointerType(nil, type)
                  end
                end
              },
  --TODO: tostring
}

do
  for opname, optypes in pairs(unary_op_types) do
    for type in iters.ivalues(optypes) do
      type:add_unary_operator_type(opname, optypes.result_type or type)
    end
  end
end

-- binary operator types
local comparable_types = {
  primtypes.float32, primtypes.float64,
  primtypes.int, primtypes.int8, primtypes.int16, primtypes.int32, primtypes.int64,
  primtypes.uint, primtypes.uint8, primtypes.uint16, primtypes.uint32, primtypes.uint64,
  primtypes.char, primtypes.string,
  result_type = primtypes.boolean
}
local binary_op_types = {
  ['le']      = comparable_types,
  ['ge']      = comparable_types,
  ['lt']      = comparable_types,
  ['gt']      = comparable_types,
  ['bor']     = bitwise_types,
  ['bxor']    = bitwise_types,
  ['band']    = bitwise_types,
  ['shl']     = bitwise_types,
  ['shr']     = bitwise_types,
  ['add']     = typedefs.numeric_types,
  ['sub']     = typedefs.numeric_types,
  ['mul']     = typedefs.numeric_types,
  ['div']     = typedefs.numeric_types,
  ['mod']     = typedefs.numeric_types,
  ['idiv']    = typedefs.numeric_types,
  ['pow']     = typedefs.numeric_types,
  ['concat']  = { primtypes.string },
  ['ne']      = { Type, result_type = primtypes.boolean },
  ['eq']      = { Type, result_type = primtypes.boolean },
}

do
  for opname, optypes in pairs(binary_op_types) do
    for type in iters.ivalues(optypes) do
      type:add_binary_operator_type(opname, optypes.result_type or type)
    end
  end
end

-- 'or', 'and' is handled internally
typedefs.binary_conditional_ops = {
  ['or']  = true,
  ['and'] = true,
}

function typedefs.find_common_type(possibletypes)
  local len = #possibletypes
  if len == 0 then return nil end
  if len == 1 then return possibletypes[1] end

  -- check if all types are the same first
  local firsttype = possibletypes[1]
  if tabler.iall(possibletypes, function(ty)
    return ty == firsttype
  end) then
    return firsttype
  end

  -- numeric type promotion
  if tabler.iall(possibletypes, Type.is_numeric) then
    for numtype in iters.ivalues(typedefs.numeric_types) do
      if tabler.iall(possibletypes, function(ty)
        return numtype:is_coercible_from(ty) end
      ) then
        return numtype
      end
    end
  end
end

typedefs.mutabilities = {
  ['var'] = true,
  ['const'] = true,
}

typedefs.readonly_mutabilities = {
  ['const'] = true
}

typedefs.block_pragmas = {
  cinclude = shaper.shape{shaper.string},
  cemit = shaper.shape{shaper.string},
  cdefine = shaper.shape{shaper.string},
  cflags = shaper.shape{shaper.string},
  ldflags = shaper.shape{shaper.string},
  linklib = shaper.shape{shaper.string}
}

local common_pragmas = {
  cimport = shaper.shape{shaper.string:is_optional(), (shaper.boolean + shaper.string):is_optional()},
  codename = shaper.shape{shaper.string},
  volatile = true,
  nodecl = true,
}
typedefs.function_pragmas = {
  inline = true,
  noreturn = true,
  noinline = true,
}
typedefs.variable_pragmas = {
  aligned = shaper.shape{shaper.integer},
  register = true,
  restrict = true,
}
do
  metamagic.setmetaindex(typedefs.function_pragmas, common_pragmas)
  metamagic.setmetaindex(typedefs.variable_pragmas, common_pragmas)
end

return typedefs
