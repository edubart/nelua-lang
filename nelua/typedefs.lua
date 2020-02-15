local types = require 'nelua.types'
local config = require 'nelua.configer'.get()
local shaper = require 'tableshape'.types

local primtypes = {}
local typedefs = {primtypes=primtypes}
types.set_typedefs(typedefs)

-- CPU word size in bytes (size of size_t)
local cpusize = math.floor(config.cpu_bits / 8)

-- C int is at least 2 bytes and max 4 bytes
local cintsize = math.max(math.min(cpusize, 4), 2)

-- C long is at least 4 bytes
local clongsize = math.max(cpusize, 4)

-- primitive types
primtypes.any         = types.AnyType('any', 2*cpusize) -- the type for anything
primtypes.void        = types.VoidType('void', 0) -- the type for nothing
primtypes.type        = types.TypeType('type', 0) -- the type for types
primtypes.auto        = types.AutoType('auto', 0)
primtypes.isize       = types.IntegralType('isize', cpusize)
primtypes.int8        = types.IntegralType('int8', 1)
primtypes.int16       = types.IntegralType('int16', 2)
primtypes.int32       = types.IntegralType('int32', 4)
primtypes.int64       = types.IntegralType('int64', 8)
primtypes.usize       = types.IntegralType('usize', cpusize, true)
primtypes.uint8       = types.IntegralType('uint8', 1, true)
primtypes.uint16      = types.IntegralType('uint16', 2, true)
primtypes.uint32      = types.IntegralType('uint32', 4, true)
primtypes.uint64      = types.IntegralType('uint64', 8, true)
primtypes.float32     = types.FloatType('float32', 4, 9)
primtypes.float64     = types.FloatType('float64', 8, 17)
primtypes.boolean     = types.BooleanType('boolean', 1)
primtypes.string      = types.StringType('string', cpusize*2)
primtypes.varanys     = types.VaranysType('varanys')
primtypes.table       = types.TableType('table')
primtypes.nilable     = types.NilableType('nilable')
primtypes.nilptr      = types.NilptrType('nilptr', cpusize)
primtypes.pointer     = types.PointerType(nil, primtypes.void)

-- for C compability
primtypes.cschar      = types.IntegralType('cschar', 1)
primtypes.cshort      = types.IntegralType('cshort', 2)
primtypes.cint        = types.IntegralType('cint', cintsize)
primtypes.clong       = types.IntegralType('clong', clongsize)
primtypes.clonglong   = types.IntegralType('clonglong', 8)
primtypes.cptrdiff    = types.IntegralType('cptrdiff', cpusize)
primtypes.cchar       = types.IntegralType('cchar', 1)
primtypes.cuchar      = types.IntegralType('cuchar', 1, true)
primtypes.cushort     = types.IntegralType('cushort', 2, true)
primtypes.cuint       = types.IntegralType('cuint', cintsize, true)
primtypes.culong      = types.IntegralType('culong', clongsize, true)
primtypes.culonglong  = types.IntegralType('culonglong', 8, true)
primtypes.csize       = types.IntegralType('csize', cpusize, true)
primtypes.clongdouble = types.FloatType('clongdouble', 16, 36)
primtypes.cstring     = types.PointerType(nil, primtypes.cchar)

-- type aliases
primtypes.integer  = primtypes.int64
primtypes.uinteger = primtypes.uint64
primtypes.number   = primtypes.float64
primtypes.byte     = primtypes.uint8
primtypes.cdouble  = primtypes.float64
primtypes.cfloat   = primtypes.float32
primtypes[_G.table]   = primtypes.table
primtypes[_G.string]  = primtypes.string
primtypes[_G.type]    = primtypes.type

-- signed types
typedefs.integral_signed_types = {
  primtypes.int8,
  primtypes.int16,
  primtypes.int32,
  primtypes.int64,
  primtypes.isize,
  primtypes.cschar,
  primtypes.cshort,
  primtypes.cint,
  primtypes.clong,
  primtypes.clonglong,
  primtypes.cptrdiff,
  primtypes.cchar
}

-- unsigned types
typedefs.unsigned_types = {
  primtypes.uint8,
  primtypes.uint16,
  primtypes.uint32,
  primtypes.uint64,
  primtypes.usize,
  primtypes.cuchar,
  primtypes.cushort,
  primtypes.cuint,
  primtypes.culong,
  primtypes.culonglong,
  primtypes.csize,
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

typedefs.promote_signed_types = {
  primtypes.int8,
  primtypes.int16,
  primtypes.int32,
  primtypes.int64
}

typedefs.call_pragmas = {
  cinclude = shaper.shape{n=shaper.number, shaper.string},
  cemit = shaper.shape{n=shaper.number, shaper.string + shaper.func, shaper.string:is_optional()},
  cdefine = shaper.shape{n=shaper.number, shaper.string},
  cflags = shaper.shape{n=shaper.number, shaper.string},
  ldflags = shaper.shape{n=shaper.number, shaper.string},
  linklib = shaper.shape{n=shaper.number, shaper.string},
  afterinfer = shaper.shape{n=shaper.number, shaper.func},
}

local common_annots = {
  cimport = shaper.shape{shaper.string:is_optional()},
  onestring = shaper.shape{shaper.string},
  oneinteger = shaper.shape{shaper.integer}
}

typedefs.function_annots = {
  cimport = common_annots.cimport,
  cinclude = common_annots.onestring,
  codename = common_annots.onestring,
  cqualifier = common_annots.onestring,
  cattribute = common_annots.onestring,
  inline = true,
  noreturn = true,
  noinline = true,
  volatile = true,
  nodecl = true,
  nosideeffect = true,
  entrypoint = true,
  hookmain = true,
  cexport = true,
}

typedefs.variable_annots = {
  cimport = common_annots.cimport,
  cinclude = common_annots.onestring,
  codename = common_annots.onestring,
  cqualifier = common_annots.onestring,
  cattribute = common_annots.onestring,
  aligned = common_annots.oneinteger,
  static = true,
  register = true,
  restrict = true,
  volatile = true,
  nodecl = true,
  noinit = true,
  cexport = true,
  comptime = true,
  const = true,
  autocast = true,
}

typedefs.type_annots = {
  aligned = common_annots.oneinteger,
  cimport = common_annots.cimport,
  cinclude = common_annots.onestring,
  codename = common_annots.onestring,
  nodecl = true,
  packed = true,
}

return typedefs
