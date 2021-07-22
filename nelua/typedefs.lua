--[[
Typedefs module

The typedefs module defines all the primitive types,
literal suffixes, annotations and some type lists.
It uses the types module to create them.
]]

local types = require 'nelua.types'
local shaper = require 'nelua.utils.shaper'
local platform = require 'nelua.utils.platform'
local ccompiler = require 'nelua.ccompiler'
local version = require 'nelua.version'

-- Get C compiler defines.
local ccinfo = ccompiler.get_cc_info()

-- CPU word size in bytes (size of a pointer).
local ptrsize = ccinfo.sizeof_pointer or platform.cpu_bits // 8
-- C int is at least 2 bytes and max 4 bytes.
local cintsize = ccinfo.sizeof_int or math.max(math.min(ptrsize, 4), 2)
-- C short size is typically 2 bytes.
local cshortsize = ccinfo.sizeof_short or 2
-- C long is at least 4 bytes.
local clongsize = ccinfo.sizeof_long or math.max(ptrsize, 4)
-- C long long is at least 8 bytes.
local clonglongsize = ccinfo.sizeof_long_long or 8

-- Map containing all primitive types.
local primtypes = {}

-- The typedefs module.
local typedefs = {
  primtypes = primtypes,
  ptrsize = ptrsize,
  emptysize = ccinfo.is_cpp and 1 or 0,
}
types.set_typedefs(typedefs)

-- Basic types.
primtypes.niltype     = types.NiltypeType('niltype', typedefs.emptysize) -- must be defined first
primtypes.nilptr      = types.NilptrType('nilptr', ptrsize)
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
primtypes.int64       = types.IntegralType('int64', 8)
primtypes.int128      = types.IntegralType('int128', 16)
primtypes.isize       = types.IntegralType('isize', ptrsize)
primtypes.uint8       = types.IntegralType('uint8', 1, true)
primtypes.uint16      = types.IntegralType('uint16', 2, true)
primtypes.uint32      = types.IntegralType('uint32', 4, true)
primtypes.uint64      = types.IntegralType('uint64', 8, true)
primtypes.uint128     = types.IntegralType('uint128', 16, true)
primtypes.usize       = types.IntegralType('usize', ptrsize, true)
primtypes.float32     = types.FloatType('float32', 4, 9)
primtypes.float64     = types.FloatType('float64', 8, 17)
primtypes.float128    = types.FloatType('float128', 16, 36)
primtypes.byte        = primtypes.uint8

-- Types for C compatibility.
primtypes.cschar      = types.IntegralType('cschar', 1)
primtypes.cshort      = types.IntegralType('cshort', cshortsize)
primtypes.cint        = types.IntegralType('cint', cintsize)
primtypes.clong       = types.IntegralType('clong', clongsize)
primtypes.clonglong   = types.IntegralType('clonglong', clonglongsize)
primtypes.cptrdiff    = types.IntegralType('cptrdiff', ptrsize)
primtypes.cchar       = types.IntegralType('cchar', 1)
primtypes.cuchar      = types.IntegralType('cuchar', 1, true)
primtypes.cushort     = types.IntegralType('cushort', cshortsize, true)
primtypes.cuint       = types.IntegralType('cuint', cintsize, true)
primtypes.culong      = types.IntegralType('culong', clongsize, true)
primtypes.culonglong  = types.IntegralType('culonglong', clonglongsize, true)
primtypes.csize       = types.IntegralType('csize', ptrsize, true)
primtypes.clongdouble = types.FloatType('clongdouble', 16, 36)
primtypes.cstring     = types.PointerType(primtypes.cchar)
primtypes.cdouble     = primtypes.float64
primtypes.cfloat      = primtypes.float32
primtypes.cvarargs    = types.CVarargsType('cvarargs')
primtypes.cvalist     = types.CVaList('cvalist')

-- The following types are predefined aliases, but can be customized by the user.
primtypes.integer     = primtypes.int64
primtypes.uinteger    = primtypes.uint64
primtypes.number      = primtypes.float64

-- Complex types.
primtypes.string      = types.StringType('string')
primtypes.stringview  = primtypes.string -- deprecated
primtypes.any         = types.AnyType('any', 2*ptrsize)
primtypes.varanys     = types.VaranysType('varanys')
primtypes.varargs     = types.VarargsType('varargs')

-- Generic types.
primtypes.facultative = types.GenericType(types.facultative_concept)
primtypes.overload    = types.GenericType(types.overload_concept)
primtypes.decltype    = types.GenericType(types.decltype)

-- Map of literal suffixes.
typedefs.number_literal_types = {
  _i          = 'integer',  _integer    = 'integer',
  _u          = 'uinteger', _uinteger   = 'uinteger',
  _n          = 'number',   _number     = 'number',
  _b          = 'byte',     _byte       = 'byte',
  _is         = 'isize',    _isize      = 'isize',
  _i8         = 'int8',     _int8       = 'int8',
  _i16        = 'int16',    _int16      = 'int16',
  _i32        = 'int32',    _int32      = 'int32',
  _i64        = 'int64',    _int64      = 'int64',
  _i128       = 'int128',   _int128     = 'int128',
  _us         = 'usize',    _usize      = 'usize',
  _u8         = 'uint8',    _uint8      = 'uint8',
  _u16        = 'uint16',   _uint16     = 'uint16',
  _u32        = 'uint32',   _uint32     = 'uint32',
  _u64        = 'uint64',   _uint64     = 'uint64',
  _u128       = 'uint128',  _uint128    = 'uint128',
  _f32        = 'float32',  _float32    = 'float32',
  _f64        = 'float64',  _float64    = 'float64',
  _f128       = 'float128', _float128   = 'float128',

  _cchar       = 'cchar',
  _cschar      = 'cschar',
  _cshort      = 'cshort',
  _cint        = 'cint',
  _clong       = 'clong',
  _clonglong   = 'clonglong',
  _cptrdiff    = 'cptrdiff',
  _cuchar      = 'cuchar',
  _cushort     = 'cushort',
  _cuint       = 'cuint',
  _culong      = 'culong',
  _culonglong  = 'culonglong',
  _csize       = 'csize',
  _clongdouble = 'clongdouble',
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
  -- Whether the compiler should never omit unused variables.
  nodce = true,
  -- Whether to export the variable in C, declaring it with the 'extern' C qualifier.
  cexport = true,
  -- Whether the variable should be only available and used at compile time.
  comptime = true,
  -- Whether the variable should be closed by calling '__close' metamethod on scope termination.
  close = true,
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
  cinclude = shaper.shape{n=shaper.number, shaper.string},
  cemitdecl = shaper.shape{n=shaper.number, shaper.string + shaper.func},
  cemitdef = shaper.shape{n=shaper.number, shaper.string + shaper.func},
  cemit = shaper.shape{n=shaper.number, shaper.string + shaper.func},
  cdefine = shaper.shape{n=shaper.number, shaper.string},
  cflags = shaper.shape{n=shaper.number, shaper.string},
  cfile = shaper.shape{n=shaper.number, shaper.string},
  ldflags = shaper.shape{n=shaper.number, shaper.string},
  linklib = shaper.shape{n=shaper.number, shaper.string},
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
  expr_macro = true,
  require = true,
  -- DEPRECATED aliases
  inject_astnode = 'inject_statement',
  staticerror = 'static_error',
  staticassert = 'static_assert',
  exprmacro = 'expr_macro'
}

-- List of exported preprocessor variables that can change while preprocessing.
typedefs.pp_variables = {
  -- Visible symbols in the current scope.
  symbols = function(ppcontext) return ppcontext.context.scope.symbols end,
  -- Current scope.
  scope = function(ppcontext) return ppcontext.context.scope end,
  -- Current pragmas.
  pragmas = function(ppcontext) return ppcontext.context.pragmas end,
}

-- List of exported preprocessor constants that cannot change while preprocessing.
typedefs.pp_constants = {
  -- BN module.
  bn = function() return require 'nelua.utils.bn' end,
  -- Traits module.
  traits = function() return require 'nelua.utils.traits' end,
  -- Memoize function.
  memoize = function() return require 'nelua.utils.memoize' end,
  -- Aster module.
  aster = function() return require 'nelua.aster' end,
  -- Version module.
  version = function() return version end,
  -- Types module.
  types = function() return types end,
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
    type = types.FunctionType({{name='cond', type=primtypes.boolean}}, primtypes.boolean)},
  unlikely = {
    type = types.FunctionType({{name='cond', type=primtypes.boolean}}, primtypes.boolean)},
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
  require = {
    type = types.FunctionType({{name='modname', type=primtypes.string}})},
  print = {type = primtypes.any},
  _G = {type = primtypes.table},
  _VERSION = {type = primtypes.string, value = version.NELUA_VERSION, comptime = true},
}

-- List oSymbols declared in standard library, used to give suggestion on error messages.
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
  tocstring = 'string',
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
