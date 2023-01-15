--[[
Typedefs module

The typedefs module defines all the primitive types,
literal suffixes, annotations and some type lists.
It uses the types module to create them.
]]

local types = require 'nelua.types'
local shaper = require 'nelua.utils.shaper'
local ccompiler = require 'nelua.ccompiler'
local version = require 'nelua.version'

-- Get C compiler defines.
local ccinfo = ccompiler.get_cc_info()

-- CPU word size in bytes (size of a pointer).
local cptrsize = ccinfo.sizeof_pointer
-- Max primitive alignment.
local cmaxalign = ccinfo.biggest_alignment
-- Not all C compilers supports empty structs/arrays.
local cemptysize = ccinfo.is_empty_supported and 0 or 1

-- Map containing all primitive types.
local primtypes = {}

-- The typedefs module.
local typedefs = {
  primtypes = primtypes,
  ptrsize = cptrsize,
  maxalign = cmaxalign,
  emptysize = cemptysize
}
types.set_typedefs(typedefs)

-- Basic types.
primtypes.niltype     = types.NiltypeType('niltype', cemptysize) -- must be defined first
primtypes.nilptr      = types.NilptrType('nilptr', cptrsize)
primtypes.type        = types.TypeType('type', 0)
primtypes.typetype    = primtypes.type
primtypes.void        = types.VoidType('void', 0)
primtypes.auto        = types.AutoType('auto', 0)
primtypes.boolean     = types.BooleanType('boolean', 1)
primtypes.table       = types.TableType('table')
primtypes.pointer     = types.PointerType(primtypes.void)

-- Scalar types.
primtypes.int8        = types.IntegralType('int8', 1)
primtypes.int16       = types.IntegralType('int16', 2)
primtypes.int32       = types.IntegralType('int32', 4)
primtypes.int64       = types.IntegralType('int64', 8, false, ccinfo.alignof_long_long)
primtypes.int128      = types.IntegralType('int128', 16)
primtypes.isize       = types.IntegralType('isize', cptrsize)
primtypes.uint8       = types.IntegralType('uint8', 1, true)
primtypes.uint16      = types.IntegralType('uint16', 2, true)
primtypes.uint32      = types.IntegralType('uint32', 4, true)
primtypes.uint64      = types.IntegralType('uint64', 8, true, ccinfo.alignof_long_long)
primtypes.uint128     = types.IntegralType('uint128', 16, true)
primtypes.usize       = types.IntegralType('usize', cptrsize, true)
primtypes.float32     = types.FloatType('float32', ccinfo.sizeof_float, nil,
                                        ccinfo.flt_decimal_dig, ccinfo.flt_mant_dig)
primtypes.float64     = types.FloatType('float64', ccinfo.sizeof_double, ccinfo.alignof_double,
                                        ccinfo.dbl_decimal_dig, ccinfo.dbl_mant_dig)
primtypes.float128    = types.FloatType('float128', 16, nil,
                                        ccinfo.flt128_decimal_dig, ccinfo.flt128_mant_dig)
primtypes.byte        = primtypes.uint8

-- Types for C compatibility.
primtypes.cchar       = types.IntegralType('cchar', 1)
primtypes.cschar      = types.IntegralType('cschar', 1)
primtypes.cshort      = types.IntegralType('cshort', ccinfo.sizeof_short)
primtypes.cint        = types.IntegralType('cint', ccinfo.sizeof_int)
primtypes.clong       = types.IntegralType('clong', ccinfo.sizeof_long)
primtypes.clonglong   = types.IntegralType('clonglong', ccinfo.sizeof_long_long, false, ccinfo.alignof_long_long)
primtypes.cptrdiff    = types.IntegralType('cptrdiff', cptrsize)
primtypes.cuchar      = types.IntegralType('cuchar', 1, true)
primtypes.cushort     = types.IntegralType('cushort', ccinfo.sizeof_short, true)
primtypes.cuint       = types.IntegralType('cuint', ccinfo.sizeof_int, true)
primtypes.culong      = types.IntegralType('culong', ccinfo.sizeof_long, true)
primtypes.culonglong  = types.IntegralType('culonglong', ccinfo.sizeof_long_long, true, ccinfo.alignof_long_long)
primtypes.csize       = types.IntegralType('csize', cptrsize, true)
primtypes.clongdouble = types.FloatType('clongdouble', ccinfo.sizeof_long_double, ccinfo.alignof_long_double,
                                        ccinfo.ldbl_decimal_dig, ccinfo.ldbl_mant_dig)
primtypes.cstring     = types.PointerType(primtypes.cchar)
primtypes.cdouble     = primtypes.float64; primtypes.cdouble.is_cdouble = true
primtypes.cfloat      = primtypes.float32; primtypes.cfloat.is_cfloat = true
primtypes.cvarargs    = types.CVarargsType('cvarargs')
primtypes.cvalist     = types.CVaList('cvalist')
primtypes.cclock_t    = types.IntegralType('cclock_t', ccinfo.sizeof_long)
primtypes.ctime_t     = types.IntegralType('ctime_t', cptrsize)
primtypes.cwchar_t    = types.IntegralType('cwchar_t', ccinfo.sizeof_wchar_t or 4, false)

-- The following types are predefined aliases, but can be customized by the user.
if cptrsize >= 4 then
  primtypes.integer   = primtypes.int64
  primtypes.uinteger  = primtypes.uint64
  primtypes.number    = primtypes.float64
else -- probably a 8bit microcontroller like AVR
  -- luacov:disable
  primtypes.integer   = primtypes.int32
  primtypes.uinteger  = primtypes.uint32
  primtypes.number    = primtypes.float32
  -- luacov:enable
end

-- Complex types.
primtypes.string      = types.StringType('string')
primtypes.stringview  = primtypes.string -- deprecated
primtypes.any         = types.AnyType('any', 2*cptrsize)
primtypes.varanys     = types.VaranysType('varanys')
primtypes.varargs     = types.VarargsType('varargs')

-- Generic types.
primtypes.facultative = types.GenericType(types.facultative_concept)
primtypes.overload    = types.GenericType(types.overload_concept)
primtypes.decltype    = types.GenericType(types.decltype)

-- Map of literal suffixes.
typedefs.number_literal_types = {
  _integer      = 'integer',      _i    = 'integer',
  _uinteger     = 'uinteger',     _u    = 'uinteger',
  _number       = 'number',       _n    = 'number',
  _byte         = 'byte',         _b    = 'byte',
  _isize        = 'isize',        _is   = 'isize',
  _int8         = 'int8',         _i8   = 'int8',
  _int16        = 'int16',        _i16  = 'int16',
  _int32        = 'int32',        _i32  = 'int32',
  _int64        = 'int64',        _i64  = 'int64',
  _int128       = 'int128',       _i128 = 'int128',
  _usize        = 'usize',        _us   = 'usize',
  _uint8        = 'uint8',        _u8   = 'uint8',
  _uint16       = 'uint16',       _u16  = 'uint16',
  _uint32       = 'uint32',       _u32  = 'uint32',
  _uint64       = 'uint64',       _u64  = 'uint64',
  _uint128      = 'uint128',      _u128 = 'uint128',
  _float32      = 'float32',      _f32  = 'float32',
  _float64      = 'float64',      _f64  = 'float64',
  _float128     = 'float128',     _f128 = 'float128',

  _cchar        = 'cchar',        _cc   = 'cchar',
  _cschar       = 'cschar',       _csc  = 'cschar',
  _cshort       = 'cshort',       _cs   = 'cshort',
  _cint         = 'cint',         _ci   = 'cint',
  _clong        = 'clong',        _cl   = 'clong',
  _clonglong    = 'clonglong',    _cll  = 'clonglong',
  _cptrdiff     = 'cptrdiff',     _cpd  = 'cptrdiff',
  _cuchar       = 'cuchar',       _cuc  = 'cuchar',
  _cushort      = 'cushort',      _cus  = 'cushort',
  _cuint        = 'cuint',        _cui  = 'cuint',
  _culong       = 'culong',       _cul  = 'culong',
  _culonglong   = 'culonglong',   _cull = 'culonglong',
  _csize        = 'csize',        _cz   = 'csize',
  _cfloat       = 'cfloat',       _cf   = 'cfloat',
  _cdouble      = 'cdouble',      _cd   = 'cdouble',
  _clongdouble  = 'clongdouble',  _cld  = 'clongdouble',
}

-- Map for converting signed and unsigned types.
typedefs.signed2unsigned = {
  int8        = 'uint8',
  int16       = 'uint16',
  int32       = 'uint32',
  int64       = 'uint64',
  int128      = 'uint128',
  isize       = 'uisize',
  cchar       = 'cuchar',
  cschar      = 'cuchar',
  cshort      = 'cushort',
  cint        = 'cuint',
  clong       = 'culong',
  clonglong   = 'culonglong',
  cptrdiff    = 'csize',
}

-- Map for converting unsigned and signed types.
typedefs.unsigned2signed = {
  uint8       = 'int8',
  uint16      = 'int16',
  uint32      = 'int32',
  uint64      = 'int64',
  uint128     = 'int128',
  usize       = 'isize',
  cuchar      = 'cchar',
  cushort     = 'cshort',
  cuint       = 'cint',
  culong      = 'clong',
  culonglong  = 'clonglong',
  csize       = 'cptrdiff',
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

-- List of compile pragmas.
typedefs.pragmas = {
  --[[
  Changes the prefix of generated C functions for the current source unit (current source file).
  When unset the source relative path will be used as prefix.
  When set to an empty string, then no prefix will be used,
  however this may increase the chances of name clashing in the C generated code.
  This pragma is useful to control function names when generating C libraries.
  ]]
  unitname = shaper.string,
  --[[
  Changes abort semantics, abort happens on failed assertions or runtime errors.
  This pragma can be one of the following values:
  * `'exit'`: the application with call system's `exit(-1)`
  * `'hooked'`: will call abort handler defined by the application, then you must define
  `function nelua_abort(): void`
  * `'trap'`: the application will call an invalid instruction and crash.
  * `'abort'` or unset, the application will call system's `abort()` (this is the default).
  ]]
  abort = shaper.one_of{'exit', 'trap', 'abort'}:is_optional(),
  --[[
  Changes how messages are written to stderr when a runtime error occur (panic, assert, check, etc).
  This pragma can be one of the following values:
  * `'none'`: the application with call system's `exit(-1)`
  * `'hooked'`: will call error message handler defined by the application, then you must define
  `function nelua_write_stderr(msg: cstring, len: usize, flush: boolean): void`
  * `'stdout'`: messages will be printed to stdout
  * `'stderr': messages will be printed to stderr (this is the default)
  ]]
  writestderr = shaper.one_of{'none', 'hooked', 'stdout', 'stderr'}:is_optional(),
  --[[
  Disables the main entry point generation.
  When set, the function `nelua_main` that initializes global variables and run code from top scope
  will still be defined, however it won't be called.
  You will need import it with `<cimport>` and call it manually from another entry point.
  You may not want to use this pragma, maybe you want to mark another function as the main
  entry point instead by using the annotation `<entrypoint>` on it.
  ]]
  noentrypoint = shaper.optional_boolean,
  --[[
  Disables the garbage collector.
  When this is enabled you will need to manage and deallocate memory manually.
  ]]
  nogc = shaper.optional_boolean,
  --[[
  Disable entry point generation for the GC.
  When set, the user will be responsible for initializing the GC in his own entry point.
  ]]
  nogcentry = shaper.optional_boolean,
  --[[
  Disables use of builtin character classes.
  When set, the standard library will use lib C APIs to check character classes,
  (like `islower`, `isdigit`, etc) and the system's current locale will affect some functions
  string methods in standard library.
  ]]
  nobuiltincharclass = shaper.optional_boolean,
  --[[
  Disable code generation of runtime checks.
  When set, the following checks will be disabled:
  * Numeric narrowing casts checks.
  * Null pointer dereference.
  * Out of bounds access.
  * Division by 0.
  * All `check()` functions will be converted to no-op.
  out of bounds access, null pointer deference, etc).
  ]]
  nochecks = shaper.optional_boolean,
  --[[
  Disables dead code elimination.
  With this enabled unused functions and variables will always be generated.
  ]]
  nodce = shaper.optional_boolean,
  --[[
  Disable initialization of variables to zeros by default (create for GLSL codegen).
  Please care changing this, as it will change the semantics of many code.
  ]]
  noinit = shaper.optional_boolean,
  -- Disable showing the source location in runtime asserts (created to minify the output binary).
  noassertloc = shaper.optional_boolean,
  -- Disable configuration warning in the C code generation (created to minify the C codegen).
  nocwarnpragmas = shaper.optional_boolean,
  --[[
  Disables use of static asserts in the C code generation (created to minify the C codegen).
  It's recommended to not change this, because whenever there is a disagreement
  of primitive types sizes you will get a compile error instead of possibly broken code.
  Such situation can happen when using exotic compilers, architectures or compiler flags.
  ]]
  nocstaticassert = shaper.optional_boolean,
  --[[
  Disables initial setup of API features in the C code generator (created to minify the C codegen).
  It's recommend to not change this, because more functions from POSIX, OS and lib C extensions
  will be available for use in the standard library, improving its quality.
  ]]
  nocfeaturessetup = shaper.optional_boolean,
  -- Disable use of `static` functions and variable in the C code generator (created for GLSL codegen).
  nocstatic = shaper.optional_boolean,
  -- Disable use of float suffixes in the C code generator (created for GLSL codegen).
  nocfloatsuffix = shaper.optional_boolean,
  -- Disable use of inline functions in the C code generation (created for GLSL codegen).
  nocinlines = shaper.optional_boolean,
  -- Disable use typedefs in the C code generation (created for GLSL codegen).
  noctypedefs = shaper.optional_boolean,
  -- Mark all variables declarations as volatile.
  volatile = shaper.optional_boolean,
}

-- List of possible annotations for function types.
typedefs.function_annots = {
  -- Whether to import the function from C.
  -- If no name is supplied then the function identifier name is used in C,
  -- the function is declared unless 'nodecl' annotation is also used.
  cimport = shaper.shape{shaper.string:is_optional()},
  -- Whether to export the function in C, declaring it with the 'extern' C qualifier.
  -- If no name is supplied then compiler will automatically generate a symbol name
  -- based on the file and function name.
  cexport = shaper.shape{shaper.string:is_optional()},
  -- C file to include when using the function.
  cinclude = shaper.shape{shaper.string},
  -- Custom name used for the function when generating the C code (implicitly sets `nodce`).
  codename = shaper.shape{shaper.string},
  -- A C qualifier to use when declaring the function. (e.g. 'extern')
  cqualifier = shaper.shape{shaper.string},
  -- A C qualifier to use when declaring the variable (placed just after C type specifier). (e.g. 'const')
  cpostqualifier = shaper.shape{shaper.string},
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
  -- Whether the compiler should never omit unused functions.
  nodce = true,
  -- Whether the function can't trigger side effects.
  -- A function triggers side effects when it can throw errors or manipulate external variables.
  -- The compiler uses this to know if it should use a strict evaluation order when calling it.
  nosideeffect = true,
  -- Whether to use the function as the entry point of the application (the C main),
  -- the entry point is called before evaluating any file and is responsible for calling `nelua_main`.
  entrypoint = true,
  -- Force a function to be polymorphic so it can be declared on demand.
  polymorphic = true,
  -- Force a function to always be polymorphic (evaluate a new function for each call).
  alwayspoly = true,
  -- Mark a function for forward declaration.
  -- This allows to call a function before defining it.
  forwarddecl = true,
}

-- List of possible annotations for variables.
typedefs.variable_annots = {
  -- Whether to import the variable from C,
  -- if no name is supplied then the same variable name is used in C,
  -- the variable is declared unless 'nodecl' annotations is also used.
  cimport = shaper.shape{shaper.string:is_optional()},
  -- Whether to export the variable in C, declaring it with the 'extern' C qualifier.
  -- If no name is supplied then the compiler will automatically generate a symbol name
  -- based on the file and variable name.
  cexport = shaper.shape{shaper.string:is_optional()},
  -- C file to include when using the variable.
  cinclude = shaper.shape{shaper.string},
  -- Custom name used for the variable when generating the C code (implicitly sets `nodce`).
  codename = shaper.shape{shaper.string},
  -- A C qualifier to use when declaring the variable (placed just before C type specifier). (e.g. 'volatile')
  cqualifier = shaper.shape{shaper.string},
  -- A C qualifier to use when declaring the variable (placed just after C type specifier). (e.g. 'const')
  cpostqualifier = shaper.shape{shaper.string},
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
  -- Whether to perform atomic operations on the variable (requires C11).
  atomic = true,
  -- Whether to declare variable per thread (requires C11 or C compiler support).
  threadlocal = true,
  -- Whether to prevent optimizing the variable, it uses the 'volatile' qualifier in C.
  volatile = true,
  -- Whether to skip declaring the variable in C.
  -- When using this, the variable must be declared somewhere else, like in a C include.
  nodecl = true,
  -- Whether the compiler should skip zero initialization for the variable.
  noinit = true,
  -- Whether the compiler should never omit unused variables.
  nodce = true,
  -- Weather the GC should not scan the variable for registers even if it contains pointers.
  nogcscan = true,
  -- Whether the variable should be only available and used at compile time.
  comptime = true,
  -- Whether the variable should be closed by calling '__close' metamethod on scope termination.
  close = true,
  -- Whether the variable is immutable.
  const = true,
  -- Force a variable to be initialized in the C top scope, even if it contains runtime expressions.
  -- This is only useful when making some low level OS specific code.
  ctopinit = true,
}

-- List of possible annotations for types.
typedefs.type_annots = {
  -- Custom alignment to use with the type.
  aligned = shaper.shape{shaper.integer},
  -- Whether to import the type from C.
  -- If no name is supplied then the same type name is used in C,
  -- the type is declared unless 'nodecl' annotations is also used.
  cimport = shaper.shape{shaper.string:is_optional()},
  -- C file to include when using the type,
  -- this annotation implicitly sets `nodecl` when combined with `cimport`.
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
  -- Whether to emit typedef for a C imported structs.
  ctypedef = shaper.shape{shaper.string:is_optional()},
  -- Whether the type is not fully defined.
  -- This makes size and align unknown at compile-time.
  cincomplete = true,
  -- Whether the compiler should pack a record type, removing padding between fields.
  -- It uses the '__attribute__((packed))' in C.
  packed = true,
  -- Mark a record type for forward declaration.
  -- This allows to use pointers to a record before defining it.
  forwarddecl = true,
  -- Whether to use enum fields in the declared scope.
  using = true,
  -- Whether the type can be copied, that is, passed by value (experimental).
  nocopy = true,
}

--[[
List of preprocessor directives.
They inject the AST node 'Directive' when called from the preprocessor.
]]
typedefs.pp_directives = {
  cinclude = shaper.shape{n=shaper.number, shaper.string + shaper.func},
  cemitdecl = shaper.shape{n=shaper.number, shaper.string + shaper.func},
  cemitdefn = shaper.shape{n=shaper.number, shaper.string + shaper.func},
  cemit = shaper.shape{n=shaper.number, shaper.string + shaper.func},
  cdefine = shaper.shape{n=shaper.number, shaper.string},
  cflags = shaper.shape{n=shaper.number, shaper.string},
  cfile = shaper.shape{n=shaper.number, shaper.string},
  cincdir = shaper.shape{n=shaper.number, shaper.string},
  linkdir = shaper.shape{n=shaper.number, shaper.string},
  linklib = shaper.shape{n=shaper.number, shaper.string},
  ldflags = shaper.shape{n=shaper.number, shaper.string},
  stripflags = shaper.shape{n=shaper.number, shaper.string},
  pragmapush = shaper.shape{n=shaper.number, shaper.table},
  pragmapop = shaper.shape{n=shaper.number},
}

--[[
List of exported preprocessor methods to use while meta programming.
These functions are documented in `PPContext`.
]]
typedefs.pp_methods = {
  inject_statement = true,
  generic = true,
  concept = true,
  hygienize = true,
  memoize = true,
  generalize = true,
  static_error = true,
  static_assert = true,
  after_analyze = true,
  after_inference = true,
  require = true,
  -- DEPRECATED aliases
  inject_astnode = 'inject_statement',
  staticerror = 'static_error',
  staticassert = 'static_assert',
}

-- List of exported preprocessor variables that can change while preprocessing.
typedefs.pp_variables = {
  -- Visible symbols in the current scope.
  symbols = function(ppcontext) return ppcontext.context.scope.symbols end,
  -- Current scope.
  scope = function(ppcontext) return ppcontext.context.scope end,
  -- Current pragmas.
  pragmas = function(ppcontext) return ppcontext.context.pragmas end,
  --[[
  Source location where the current polymorphic function was instantiated.
  It is a table source origin information (like fields  `srcname` and `lineno`).
  ]]
  polysrcloc = function(ppcontext) return ppcontext.context:get_polyeval_location() end,
  --Source location for the current preprocess node (a table with `srcname` and `lineno` fields).
  srcloc = function(ppcontext) return ppcontext:get_preprocess_location() end,
}

-- List of exported preprocessor constants that cannot change while preprocessing.
typedefs.pp_constants = {
  -- BN module.
  bn = function() return require 'nelua.utils.bn' end,
  -- Traits module.
  traits = function() return require 'nelua.utils.traits' end,
  -- Executor module.
  executor = function() return require 'nelua.utils.executor' end,
  -- Memoize function.
  memoize = function() return require 'nelua.utils.memoize' end,
  -- Aster module.
  aster = function() return require 'nelua.aster' end,
  -- Version module.
  version = function() return version end,
  -- Types module.
  types = function() return types end,
  -- Typedefs module.
  typedefs = function() return typedefs end,
  -- Global configuration.
  config = function() return require 'nelua.configer'.get() end,
  -- List of primitive types.
  primtypes = function() return primtypes end,
  -- Table with some C compiler information.
  ccinfo = function() return ccinfo end,
  -- Current analyzer context.
  context = function(ppcontext) return ppcontext.context end,
  -- AST of the file being compiled (the very first file parsed).
  ast = function(ppcontext) return ppcontext.context.ast end,
  -- Current preprocessing context.
  ppcontext = function(ppcontext) return ppcontext end,
  -- Current preprocessing registry (used internally).
  ppregistry = function(ppcontext) return ppcontext.registry end,
}

-- List of builtins (converted to a symbol on first usage).
typedefs.builtin_attrs = {
  likely = {
    type = types.FunctionType({{name='cond', type=primtypes.boolean}}, primtypes.boolean),
    noerror = true,
  },
  unlikely = {
    type = types.FunctionType({{name='cond', type=primtypes.boolean}}, primtypes.boolean),
    noerror = true,
  },
  panic = {
    type = types.FunctionType({{name='message', type=primtypes.string}}),
    noreturn = true, sideeffect = true},
  error = {
    type = types.FunctionType({{name='message', type=primtypes.string}}),
    noreturn = true, sideeffect = true},
  warn = {
    type = types.FunctionType({{name='message', type=primtypes.string}}),
    sideeffect = true},
  check = {type = primtypes.any},
  assert = {type = primtypes.any},
  require = {type = types.FunctionType({{name='modname', type=primtypes.string}})},
  print = {type = primtypes.any},
  _G = {type = primtypes.table},
  _VERSION = {type = primtypes.string, value = version.NELUA_VERSION, comptime = true},
}

-- List of symbols declared in standard library, used to give suggestion on error messages.
typedefs.symbol_modules = {
  arg = 'arg',
  coroutine = 'coroutine',
  filestream = 'filestream',
  hash = 'hash',
  hashmap = 'hashmap',
  io = 'io',
  vector = 'vector',
  list = 'list',
  math = 'math',
  memory = 'memory',
  os = 'os',
  sequence = 'sequence',
  span = 'span',
  stringbuilder = 'stringbuilder',
  traits = 'traits',
  utf8 = 'utf8',
  C = 'C',
  -- globals in traits
  type = 'traits',
  -- globals in string
  tostring = 'string',
  tonumber = 'string',
  tointeger = 'string',
  -- globals in iterators
  next = 'iterators', mnext = 'iterators',
  ipairs = 'iterators', mipairs = 'iterators',
  pairs = 'iterators', mpairs = 'iterators',
  -- default allocator
  DefaultAllocator = 'allocators.default',
  default_allocator = 'allocators.default',
  new = 'allocators.default',
  delete = 'allocators.default',
  -- gc allocator
  GCAllocator = 'allocators.gc',
  gc_allocator = 'allocators.gc',
  GC = 'allocators.gc',
  gc = 'allocators.gc',
  collectgarbage = 'allocators.gc',
  -- general allocator
  GeneralAllocator = 'allocators.general',
  general_allocator = 'allocators.general',
  -- other allocators
  ArenaAllocator = 'allocators.arena',
  StackAllocator = 'allocators.stack',
  PoolAllocator = 'allocators.pool',
  HeapAllocator = 'allocators.heap',
}
return typedefs
