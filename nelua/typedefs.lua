local tabler = require 'nelua.utils.tabler'
local types = require 'nelua.types'
local bn = require 'nelua.utils.bn'
local shaper = require 'tableshape'.types
local Type = types.Type

local typedefs = {}

-- primitive types
local primtypes = {
  isize     = Type('isize'),
  int8      = Type('int8'),
  int16     = Type('int16'),
  int32     = Type('int32'),
  int64     = Type('int64'),
  usize     = Type('usize'),
  uint8     = Type('uint8'),
  uint16    = Type('uint16'),
  uint32    = Type('uint32'),
  uint64    = Type('uint64'),
  float32   = Type('float32'),
  float64   = Type('float64'),
  boolean   = Type('boolean'),
  string    = Type('string'),
  varanys   = Type('varanys'),
  table     = Type('table'),
  Nil       = Type('nil'),
  Nilptr    = Type('nilptr'),
  any       = Type.any, -- the type for anything
  void      = Type.void, -- the type for nothing
  type      = Type.type, -- the type for types

  -- for C compability
  cschar      = Type('cschar'),
  cshort      = Type('cshort'),
  cint        = Type('cint'),
  clong       = Type('clong'),
  clonglong   = Type('clonglong'),
  cptrdiff    = Type('cptrdiff'),
  cchar       = Type('cchar'),
  cuchar      = Type('cuchar'),
  cushort     = Type('cushort'),
  cuint       = Type('cuint'),
  culong      = Type('culong'),
  culonglong  = Type('culonglong'),
  csize       = Type('csize'),
  clongdouble = Type('clongdouble'),
}

primtypes.pointer = types.PointerType(nil, primtypes.void)
primtypes.pointer.nodecl = true

primtypes.cstring = types.PointerType(nil, primtypes.cchar)

typedefs.primtypes = primtypes

-- type aliases
primtypes.integer  = primtypes.int64
primtypes.uinteger = primtypes.uint64
primtypes.number   = primtypes.float64
primtypes.byte     = primtypes.uint8
primtypes.cdouble  = primtypes.float64
primtypes.cfloat   = primtypes.float32

-- signed integral ranges
local i8min, i8max   = - bn.pow(2,  8) / 2, bn.pow(2,  8) / 2 - 1
local i16min, i16max = - bn.pow(2, 16) / 2, bn.pow(2, 16) / 2 - 1
local i32min, i32max = - bn.pow(2, 32) / 2, bn.pow(2, 32) / 2 - 1
local i64min, i64max = - bn.pow(2, 64) / 2, bn.pow(2, 64) / 2 - 1
local umin   = bn.new(0)
local u8max  = bn.pow(2,  8) - 1
local u16max = bn.pow(2, 16) - 1
local u32max = bn.pow(2, 32) - 1
local u64max = bn.pow(2, 64) - 1

typedefs.signed_ranges = {
  {type = primtypes.int8,      min = i8min,  max = i8max},
  {type = primtypes.int16,     min = i16min, max = i16max},
  {type = primtypes.int32,     min = i32min, max = i32max},
  {type = primtypes.int64,     min = i64min, max = i64max},
  {type = primtypes.isize,     min = i64min, max = i64max, strictmin = i32min, strictmax = i32max},

  -- C ranges are set to the most common ranges
  {type = primtypes.cschar,    min = i8min,  max = i8max },
  {type = primtypes.cshort,    min = i16min, max = i16max },
  -- do 16 bit CPUs is even used today?
  --{type = primtypes.cint,      min = i32min, max = i32max, strictmin = i16min, strictmax = i16max},
  {type = primtypes.cint,      min = i32min, max = i32max, strictmin = i32min, strictmax = i32max},
  {type = primtypes.clong,     min = i64min, max = i64max, strictmin = i32min, strictmax = i32max},
  {type = primtypes.clonglong, min = i64min, max = i64max },
  {type = primtypes.cptrdiff,  min = i64min, max = i64max, strictmin = i32min, strictmax = i32max},
  {type = primtypes.cchar,     min = i8min,  max = u8max,  strictmin = umin,   strictmax = i8max },
}

-- unsigned integral ranges
typedefs.unsigned_ranges = {
  {type = primtypes.uint8,      min = umin, max = u8max},
  {type = primtypes.uint16,     min = umin, max = u16max},
  {type = primtypes.uint32,     min = umin, max = u32max},
  {type = primtypes.uint64,     min = umin, max = u64max},
  {type = primtypes.usize,      min = umin, max = u64max, strictmax = u32max},

  {type = primtypes.cuchar,     min = umin, max = u8max },
  {type = primtypes.cushort,    min = umin, max = u16max},
  -- do 16 bit CPUs is even used today?
  --{type = primtypes.cuint,      min = umin, max = u32max, strictmin = umin, strictmax = u16max},
  {type = primtypes.cuint,      min = umin, max = u32max, strictmax = u32max},
  {type = primtypes.culong,     min = umin, max = u64max, strictmax = u32max},
  {type = primtypes.culonglong, min = umin, max = u64max, strictmax = u64max},
  {type = primtypes.csize,      min = umin, max = u64max, strictmax = u32max},
}

typedefs.integral_ranges = {}
do
  tabler.insertvalues(typedefs.integral_ranges, typedefs.signed_ranges)
  tabler.insertvalues(typedefs.integral_ranges, typedefs.unsigned_ranges)
end

-- float types
typedefs.float_types = {
  primtypes.float32,
  primtypes.float64,
  primtypes.clongdouble,
}

-- number types
typedefs.numeric_types = {}
typedefs.integral_types = {}
typedefs.signed_types = {}
typedefs.unsigned_types = {}

do
  for _,range in ipairs(typedefs.signed_ranges) do
    local itype = range.type
    itype.integral = true
    itype.range = range
    table.insert(typedefs.numeric_types, itype)
    table.insert(typedefs.integral_types, itype)
    table.insert(typedefs.signed_types, itype)
  end
  for _,range in ipairs(typedefs.unsigned_ranges) do
    local itype = range.type
    itype.integral = true
    itype.unsigned = true
    itype.range = range
    table.insert(typedefs.numeric_types, itype)
    table.insert(typedefs.integral_types, itype)
    table.insert(typedefs.unsigned_types, itype)
  end
  for _,ftype in ipairs(typedefs.float_types) do
    ftype.float = true
    table.insert(typedefs.numeric_types, ftype)
    table.insert(typedefs.signed_types, ftype)
  end
end

-- NOTE: order here does matter when looking up for a common type between two different types
typedefs.integer_coerce_types = {
  primtypes.int8, primtypes.int16, primtypes.int32, primtypes.int64,
  primtypes.uint8, primtypes.uint16, primtypes.uint32, primtypes.uint64,
}

-- literal suffixes types
typedefs.number_literal_types = {
  _i          = primtypes.integer,  _integer    = primtypes.integer,
  _u          = primtypes.uinteger, _uinteger   = primtypes.uinteger,
  _n          = primtypes.number,   _number     = primtypes.number,
  _b          = primtypes.byte,     _byte       = primtypes.byte,
  _is         = primtypes.isize,    _isize      = primtypes.isize,
  _i8         = primtypes.int8,     _int8       = primtypes.int8,
  _i16        = primtypes.int16,    _int16      = primtypes.int16,
  _i32        = primtypes.int32,    _int32      = primtypes.int32,
  _i64        = primtypes.int64,    _int64      = primtypes.int64,
  _us         = primtypes.usize,    _usize      = primtypes.usize,
  _u8         = primtypes.uint8,    _uint8      = primtypes.uint8,
  _u16        = primtypes.uint16,   _uint16     = primtypes.uint16,
  _u32        = primtypes.uint32,   _uint32     = primtypes.uint32,
  _u64        = primtypes.uint64,   _uint64     = primtypes.uint64,
  _f32        = primtypes.float32,  _float32    = primtypes.float32,
  _f64        = primtypes.float64,  _float64    = primtypes.float64,
  _pointer    = primtypes.pointer,

  _cchar       = primtypes.cchar,
  _cschar      = primtypes.cschar,
  _cshort      = primtypes.cshort,
  _cint        = primtypes.cint,
  _clong       = primtypes.clong,
  _clonglong   = primtypes.clonglong,
  _cptrdiff    = primtypes.cptrdiff,
  _cuchar      = primtypes.cuchar,
  _cushort     = primtypes.cushort,
  _cuint       = primtypes.cuint,
  _culong      = primtypes.culong,
  _culonglong  = primtypes.culonglong,
  _csize       = primtypes.csize,
  _clongdouble = primtypes.clongdouble,
}

-- automatic type conversion
do
  -- populate conversible types for integral numbers
  for _,drange in ipairs(typedefs.integral_ranges) do
    local dtype = drange.type
    local dmin, dmax = drange.strictmin or drange.min, drange.strictmax or drange.max
    for _,srange in ipairs(typedefs.integral_ranges) do
      local stype = srange.type
      local smin, smax = srange.strictmin or srange.min, srange.strictmax or srange.max
      if stype ~= dtype and smin >= dmin and smax <= dmax then
        dtype:add_conversible_types {stype}
      end
    end
  end
  -- populate conversible types for float numbers
  for _,dtype in ipairs(typedefs.float_types) do
    dtype:add_conversible_types(typedefs.integral_types)
    for _,stype in ipairs(typedefs.float_types) do
      if stype ~= dtype then
        dtype:add_conversible_types{stype}
      end
    end
  end
  primtypes.cstring:add_conversible_types({primtypes.string})
end

function typedefs.get_pointer_type(node, subtype)
  if subtype == primtypes.cstring.subtype then
    return primtypes.cstring
  elseif subtype == primtypes.pointer.subtype then
    return primtypes.pointer
  else
    return types.PointerType(node, subtype)
  end
end

-- unary operator types
local unary_op_types = {
  ['neg']   = typedefs.signed_types,
  ['bnot']  = typedefs.integral_types,
  ['len']   = { types.ArrayTableType, types.ArrayType, types.RecordType,
                result_type = primtypes.integer },
  ['not']   = { Type, primtypes.boolean },
  ['ref']   = { Type, result_type = function(type)
                  if not type:is_type() then
                    return typedefs.get_pointer_type(nil, type)
                  end
                end
              },
}

do
  for opname, optypes in pairs(unary_op_types) do
    for _,type in ipairs(optypes) do
      type:add_unary_operator_type(opname, optypes.result_type or type)
    end
  end
end

-- binary operator types
local comparable_types = {
  primtypes.string,
  result_type = primtypes.boolean
}
do
  tabler.insertvalues(comparable_types, typedefs.numeric_types)
end

local binary_op_types = {
  ['le']      = comparable_types,
  ['ge']      = comparable_types,
  ['lt']      = comparable_types,
  ['gt']      = comparable_types,
  ['bor']     = typedefs.integral_types,
  ['bxor']    = typedefs.integral_types,
  ['band']    = typedefs.integral_types,
  ['shl']     = typedefs.integral_types,
  ['shr']     = typedefs.integral_types,
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
    for _,type in ipairs(optypes) do
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
  local firsttype = possibletypes[1]
  if len == 1 then return firsttype end

  -- check if all types are the same first
  if tabler.iall(possibletypes, function(ty)
    return ty == firsttype
  end) then
    return firsttype
  end

  -- numeric type promotion
  if tabler.iall(possibletypes, Type.is_numeric) then
    for _,numtype in ipairs(typedefs.integer_coerce_types) do
      if tabler.iall(possibletypes, function(ty)
        return numtype:is_coercible_from_type(ty) end
      ) then
        return numtype
      end
    end

    -- try float32 if any of the types is float32
    if tabler.ifindif(possibletypes, Type.is_float32) then
      -- check if all types fit
      if not tabler.ifindif(possibletypes, Type.is_float64) then
        return primtypes.float32
      end
    end

    -- can only be float64 now
    return primtypes.float64
  end
end

typedefs.mutabilities = {
  ['compconst'] = true,
  ['const'] = true,
}

typedefs.block_pragmas = {
  cinclude = shaper.shape{shaper.string},
  cemit = shaper.shape{shaper.string},
  cdefine = shaper.shape{shaper.string},
  cflags = shaper.shape{shaper.string},
  ldflags = shaper.shape{shaper.string},
  linklib = shaper.shape{shaper.string},
  strict = true
}

local common_pragmas = {
  cimport = shaper.shape{shaper.string:is_optional(), (shaper.boolean + shaper.string):is_optional()},
  onestring = shaper.shape{shaper.string},
  oneinteger = shaper.shape{shaper.integer}
}
typedefs.function_pragmas = {
  cimport = common_pragmas.cimport,
  codename = common_pragmas.onestring,
  cqualifier = common_pragmas.onestring,
  cattribute = common_pragmas.onestring,
  inline = true,
  noreturn = true,
  noinline = true,
  volatile = true,
  nodecl = true,
  nosideeffect = true,
  entrypoint = true,
}
typedefs.variable_pragmas = {
  cimport = common_pragmas.cimport,
  codename = common_pragmas.onestring,
  cqualifier = common_pragmas.onestring,
  cattribute = common_pragmas.onestring,
  aligned = common_pragmas.oneinteger,
  static = true,
  register = true,
  restrict = true,
  volatile = true,
  nodecl = true,
}
typedefs.type_pragmas = {
  aligned = common_pragmas.oneinteger,
  cimport = common_pragmas.cimport,
  codename = common_pragmas.onestring,
  nodecl = true,
  packed = true,
}

return typedefs
