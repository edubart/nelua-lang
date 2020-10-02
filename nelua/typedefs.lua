-- Typedefs module
--
-- The typedefs module defines all the primitive types,
-- literal suffixes, annotations and some type lists.
-- It uses the types module to create them.

local types = require 'nelua.types'
local shaper = require 'nelua.utils.shaper'
local config = require 'nelua.configer'.get()

-- Map containing all primitive types.
local primtypes = {}

local typedefs = {primtypes=primtypes}
types.set_typedefs(typedefs)

-- CPU word size in bytes (size of size_t)
local cpusize = config.cpu_bits // 8
-- C int is at least 2 bytes and max 4 bytes
local cintsize = math.max(math.min(cpusize, 4), 2)
-- C long is at least 4 bytes
local clongsize = math.max(cpusize, 4)

-- Basic types.
primtypes.niltype     = types.NiltypeType('niltype') -- must be defined first, to have id 0
primtypes.nilptr      = types.NilptrType('nilptr', cpusize)
primtypes.type        = types.TypeType('type', 0)
primtypes.void        = types.VoidType('void', 0)
primtypes.auto        = types.AutoType('auto', 0)
primtypes.boolean     = types.BooleanType('boolean', 1)
primtypes.table       = types.TableType('table')
primtypes.pointer     = types.PointerType(primtypes.void)

-- Arithmetic types.
primtypes.int8        = types.IntegralType('int8', 1)
primtypes.int16       = types.IntegralType('int16', 2)
primtypes.int32       = types.IntegralType('int32', 4)
primtypes.int64       = types.IntegralType('int64', 8)
primtypes.int128      = types.IntegralType('int128', 16)
primtypes.isize       = types.IntegralType('isize', cpusize)
primtypes.uint8       = types.IntegralType('uint8', 1, true)
primtypes.uint16      = types.IntegralType('uint16', 2, true)
primtypes.uint32      = types.IntegralType('uint32', 4, true)
primtypes.uint64      = types.IntegralType('uint64', 8, true)
primtypes.uint128     = types.IntegralType('uint128', 16, true)
primtypes.usize       = types.IntegralType('usize', cpusize, true)
primtypes.float32     = types.FloatType('float32', 4, 9)
primtypes.float64     = types.FloatType('float64', 8, 17)
primtypes.float128    = types.FloatType('float128', 16, 36)
primtypes.byte        = primtypes.uint8

-- Types for C compatibility.
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
primtypes.cstring     = types.PointerType(primtypes.cchar)
primtypes.cdouble     = primtypes.float64
primtypes.cfloat      = primtypes.float32
primtypes.cvarargs    = types.CVarargsType('cvarargs')

-- The following types are predefined aliases, but can be customized by the user.
primtypes.integer     = primtypes.int64
primtypes.uinteger    = primtypes.uint64
primtypes.number      = primtypes.float64

-- Complex types.
primtypes.stringview  = types.StringViewType('stringview')
primtypes.any         = types.AnyType('any', 2*cpusize)
primtypes.varanys     = types.VaranysType('varanys')

-- Map of literal suffixes for arithmetic types.
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
  _i128       = primtypes.int128,   _int128     = primtypes.int128,
  _us         = primtypes.usize,    _usize      = primtypes.usize,
  _u8         = primtypes.uint8,    _uint8      = primtypes.uint8,
  _u16        = primtypes.uint16,   _uint16     = primtypes.uint16,
  _u32        = primtypes.uint32,   _uint32     = primtypes.uint32,
  _u64        = primtypes.uint64,   _uint64     = primtypes.uint64,
  _u128       = primtypes.uint128,  _uint128    = primtypes.uint128,
  _f32        = primtypes.float32,  _float32    = primtypes.float32,
  _f64        = primtypes.float64,  _float64    = primtypes.float64,
  _f128       = primtypes.float128, _float128   = primtypes.float128,

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

-- Map of literal suffixes for strings.
typedefs.string_literals_types = {
  _b           = primtypes.byte,    _byte       = primtypes.byte,
  _i8          = primtypes.int8,    _int8       = primtypes.int8,
  _u8          = primtypes.uint8,   _uint8      = primtypes.uint8,
  _cchar       = primtypes.cchar,
  _cuchar      = primtypes.cuchar,
  _cschar      = primtypes.cschar,
  _cstring     = primtypes.cstring,
}

-- Ordered list of signed types for performing type promotion.
typedefs.promote_signed_types = {
  primtypes.int8,
  primtypes.int16,
  primtypes.int32,
  primtypes.int64
}

-- Ordered list of unsigned types for performing type promotion.
typedefs.promote_unsigned_types = {
  primtypes.uint8,
  primtypes.uint16,
  primtypes.uint32,
  primtypes.uint64
}

typedefs.call_pragmas = {
  cinclude = shaper.shape{n=shaper.number, shaper.string},
  cemitdecl = shaper.shape{n=shaper.number, shaper.string + shaper.func},
  cemitdef = shaper.shape{n=shaper.number, shaper.string + shaper.func},
  cemit = shaper.shape{n=shaper.number, shaper.string + shaper.func},
  cdefine = shaper.shape{n=shaper.number, shaper.string},
  cflags = shaper.shape{n=shaper.number, shaper.string},
  ldflags = shaper.shape{n=shaper.number, shaper.string},
  linklib = shaper.shape{n=shaper.number, shaper.string}
}

-- List of possible annotations for function types.
typedefs.function_annots = {
  -- Whether to import the function from C.
  -- If no name is supplied then the function identifier name is used in C,
  -- the function is declared unless 'nodecl' annotation is also used.
  cimport = shaper.shape{shaper.string:is_optional()},
  -- C file to include when using the function.
  cinclude = shaper.shape{shaper.string},
  -- Custom name used for the function when generating the C code.
  codename = shaper.shape{shaper.string},
  -- A C qualifier to use when declaring the function. (e.g. 'extern')
  cqualifier = shaper.shape{shaper.string},
  -- A C attribute to use when declaring the function, it uses '__attribute((...))' in C.
  cattribute = shaper.shape{shaper.string},
  -- Whether the function is deprecated, generating warnings when compiling.
  deprecated = true,
  -- Whether to inline the function.
  inline = true,
  -- Whether the function can return, it uses '__attribute__((noreturn))' in C.
  noreturn = true,
  -- Whether the function can't be inlined, it uses '__attribute__((noinline))' in C.
  noinline = true,
  -- Whether to prevent optimizing the function returns, it uses the 'volatile' qualifier in C.
  volatile = true,
  -- Whether to skip declaring the function in C.
  -- When using this the function must be declared somewhere else, like in a C include or macro.
  nodecl = true,
  -- Whether the function can't trigger side effects.
  -- A function triggers side effects when it can throw errors or manipulate external variables.
  -- The compiler uses this to know if it should use a strict evaluation order when calling it.
  nosideeffect = true,
  -- Whether to use the function as the entry point of the application (the C main),
  -- the entry point is called before evaluating any file and is responsible for calling nelua_main.
  entrypoint = true,
  -- Whether to export the function in C, declaring it with the 'extern' C qualifier.
  cexport = true,
  -- Force a function to be polymorphic so it can be declared on demand.
  polymorphic = true,
  -- Force a polymorphic function to always be evaluated.
  alwayseval = true,
}

-- List of possible annotations for variables.
typedefs.variable_annots = {
  -- Whether to import the variable from C,
  -- if no name is supplied then the same variable name is used in C,
  -- the variable is declared unless 'nodecl' annotations is also used.
  cimport = shaper.shape{shaper.string:is_optional()},
  -- C file to include when using the variable.
  cinclude = shaper.shape{shaper.string},
  -- Custom name used for the variable when generating the C code.
  codename = shaper.shape{shaper.string},
  -- A C qualifier to use when declaring the variable. (e.g. 'extern')
  cqualifier = shaper.shape{shaper.string},
  -- A C attribute to use when declaring the variable.
  cattribute = shaper.shape{shaper.string},
  -- Custom alignment to use with the variable.
  aligned = shaper.shape{shaper.integer},
  -- Whether the variable is deprecated, generating warnings when compiling.
  deprecated = true,
  -- Whether the variable is static, it uses the 'static' qualifier in C.
  -- Static variables are stored in the application static storage, not in the function stack frame.
  static = true,
  -- Whether the compiler should try to use the variable in a register,
  -- it uses the 'register' qualifier in C.
  register = true,
  -- Whether to use the '__restrict' qualifier in C.
  restrict = true,
  -- Whether to prevent optimizing the variable, it uses the 'volatile' qualifier in C.
  volatile = true,
  -- Whether to skip declaring the variable in C.
  -- When using this, the variable must be declared somewhere else, like in a C include.
  nodecl = true,
  -- Whether the compiler should skip zero initialization for the variable.
  noinit = true,
  -- Whether to export the variable in C, declaring it with the 'extern' C qualifier.
  cexport = true,
  -- Whether the variable should be only available and used at compile time.
  comptime = true,
  -- Whether the variable is immutable.
  const = true,
}

-- List of possible annotations for types.
typedefs.type_annots = {
  -- Custom alignment to use with the type.
  aligned = shaper.shape{shaper.integer},
  -- Whether to import the type from C.
  -- If no name is supplied then the same type name is used in C,
  -- the type is declared unless 'nodecl' annotations is also used.
  cimport = shaper.shape{shaper.string:is_optional()},
  -- C file to include when using the type.
  cinclude = shaper.shape{shaper.string},
  -- Change the nickname used in the compiler for the type.
  -- The nickname is used to generate pretty names for compile time type errors,
  -- also used to assist the compiler generating pretty code names in C.
  nickname = shaper.shape{shaper.string},
  -- Custom name used for the type when generating the C code.
  codename = shaper.shape{shaper.string},
  -- Whether to skip declaring the type in C.
  -- When using this, the type must be declared somewhere else, like in a C include.
  nodecl = true,
  -- Whether the compiler should pack a record type, removing padding between fields.
  -- It uses the '__attribute__((packed))' in C.
  packed = true,
}

return typedefs
