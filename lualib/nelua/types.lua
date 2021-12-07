--[[
Types module

The types module define classes for all the primitive types in Nelua.
Also defines some utilities functions for working with types.

This module is always available in the preprocessor in the `types` variable.
]]

local class = require 'nelua.utils.class'
local tabler = require 'nelua.utils.tabler'
local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local stringer = require 'nelua.utils.stringer'
local sstream = require 'nelua.utils.sstream'
local metamagic = require 'nelua.utils.metamagic'
local bn = require 'nelua.utils.bn'
local except = require 'nelua.utils.except'
local shaper = require 'nelua.utils.shaper'
local Attr = require 'nelua.attr'
local ASTNode = require 'nelua.astnode'

local types = {}

-- Counter that increment on every new defined type that are fundamentally different.
local typeid_counter = 0

-- Table of type's id by its codename.
local typeid_by_codename = {}

-- These are set by types.set_typedefs when typedefs file is loaded.
local typedefs, primtypes

--------------------------------------------------------------------------------
-- Type
--
-- Type is the base class that all other types are derived form.

local Type = class()
types.Type = Type

-- Define the shape of all fields used in the type.
-- Use this as a reference to know all used fields in the Type class by the compiler.
Type.shape = shaper.shape {
  -- Unique identifier for the type, used when needed for runtime type information.
  id = shaper.integer,
  -- Size of the type at runtime in bytes.
  size = shaper.integer:is_optional(),
  -- Size of the type at runtime in bits.
  bitsize = shaper.integer:is_optional(),
  -- Alignment for the type in bytes.
  align = shaper.integer:is_optional(),
  -- Short name of the type, e.g. 'int64', 'record', 'enum' ...
  name = shaper.string,
  -- Nickname for the type, usually it's the first identifier name that defined it in the sources.
  -- The nickname is used to generate pretty names for compile time type errors,
  -- also used to assist the compiler generating pretty code names in C.
  nickname = shaper.string:is_optional(),
  -- The actual name of the type used in the code generator when emitting C code.
  codename = shaper.string,
  -- Fixed custom codename used in <codename> annotation.
  fixedcodename = shaper.string:is_optional(),
  -- Symbol that defined the type, not applicable for primitive types.
  symbol = shaper.symbol:is_optional(),
  -- Node that defined the type.
  node = shaper.astnode:is_optional(),
  -- Unary operators defined for the type.
  unary_operators = shaper.table,
  -- Binary operators defined for the type.
  binary_operators = shaper.table,
  -- Table of meta fields (global methods/variables of the type).
  metafields = shaper.table:is_optional(),
  -- A generic type that the type can represent when used as generic.
  generic = shaper.type:is_optional(),
  -- Whether the code generator should omit the type declaration.
  nodecl = shaper.optional_boolean,
  -- Whether the compiler should never omit unused types.
  nodce = shaper.optional_boolean,
  -- Whether the code generator should import the type from C.
  cimport = shaper.optional_boolean,
  -- Whether the type was marked as incomplete imported struct/union.
  cincomplete = shaper.optional_boolean,
  -- Whether to emit typedef for a C imported structs.
  ctypedef = shaper.optional_boolean,
  -- Whether an empty type was referenced.
  emptyrefed = shaper.optional_boolean,
  -- Whether the scope is using fields from the type. (e.g. enum fields)
  using = shaper.optional_boolean,
  -- Whether the type can be copied, that is, passed by value.
  nocopy = shaper.optional_boolean,
  -- Marked when declaring a type without its definition.
  forwarddecl = shaper.optional_boolean,
  forwarddefn = shaper.optional_boolean,
  -- C header that the code generator should include when using the type.
  cinclude = shaper.string:is_optional(),
  -- The value passed in <aligned(X)> annotation, see also align.
  aligned = shaper.integer:is_optional(),
  -- Whether the type can have user defined nickname, true for user defined types.
  is_nameable = shaper.optional_boolean,
  -- Whether the type can be evaluated to false when casting to a boolean.
  is_falseable = shaper.optional_boolean,
  -- Whether the type can turn represents a string (e.g. string and cstring).
  is_stringy = shaper.optional_boolean,
  -- Whether the type represents a contiguous buffer (e.g. arrays, spans and vector in the lib).
  is_contiguous = shaper.optional_boolean,
  -- Whether the type represents a container buffer (e.g. arrays, spans, vector and list in the lib).
  is_container = shaper.optional_boolean,
  -- Whether the type uses 1-based indexing (e.g. sequence and table).
  is_oneindexing = shaper.optional_boolean,
  -- Whether the type is a compile time type (e.g concepts, generics)
  is_comptime = shaper.optional_boolean,
  -- Whether the type is used as a polymorphic argument in poly functions.
  is_polymorphic = shaper.optional_boolean,
  -- Whether the type cannot be a l-value.
  is_nolvalue = shaper.optional_boolean,
  -- Whether the type is a numeric scalar (e.g. float, integrals and enums).
  is_scalar = shaper.optional_boolean,
  -- Whether the type can perform arithmetic operations (e.g. sum, add, mul, ...).
  is_arithmetic = shaper.optional_boolean,
  -- Whether the type is a floating point number type (fractional numbers).
  is_float = shaper.optional_boolean,
  -- Whether the type is an integral type (whole numbers).
  is_integral = shaper.optional_boolean,
  -- Whether the type can have a negative sign (e.g. int64, float64, ...).
  is_signed = shaper.optional_boolean,
  -- Whether the type is a procedure (e.g. a function or a poly function).
  is_procedure = shaper.optional_boolean,
  -- Whether the type is not addressable in memory (e.g. type, concept, ...)
  is_unpointable = shaper.optional_boolean,
  -- Whether the type is composed by fields (record or union).
  is_composite = shaper.optional_boolean,
  -- Whether the type aggregates other types (record, union and arrays).
  is_aggregate = shaper.optional_boolean,
  -- Weather the runtype type does not store anything (empty records, union and arrays).
  is_empty = shaper.optional_boolean,
  -- Whether the type hold multiple arguments.
  is_multipleargs = shaper.optional_boolean,

  -- Booleans for checking the underlying type (scalar types),
  is_float32 = shaper.optional_boolean,
  is_float64 = shaper.optional_boolean,
  is_float128 = shaper.optional_boolean,
  is_int8 = shaper.optional_boolean,
  is_int16 = shaper.optional_boolean,
  is_int32 = shaper.optional_boolean,
  is_int64 = shaper.optional_boolean,
  is_int128 = shaper.optional_boolean,
  is_isize = shaper.optional_boolean,
  is_uint8 = shaper.optional_boolean,
  is_uint16 = shaper.optional_boolean,
  is_uint32 = shaper.optional_boolean,
  is_uint64 = shaper.optional_boolean,
  is_uint128 = shaper.optional_boolean,
  is_usize = shaper.optional_boolean,
  is_cschar = shaper.optional_boolean,
  is_cshort = shaper.optional_boolean,
  is_cint = shaper.optional_boolean,
  is_clong = shaper.optional_boolean,
  is_clonglong = shaper.optional_boolean,
  is_cptrdiff = shaper.optional_boolean,
  is_cchar = shaper.optional_boolean,
  is_cuchar = shaper.optional_boolean,
  is_cushort = shaper.optional_boolean,
  is_cuint = shaper.optional_boolean,
  is_culong = shaper.optional_boolean,
  is_culonglong = shaper.optional_boolean,
  is_csize = shaper.optional_boolean,
  is_cfloat = shaper.optional_boolean,
  is_cdouble = shaper.optional_boolean,
  is_clongdouble = shaper.optional_boolean,

  -- Booleans for checking the underlying type (primitive types).
  is_any = shaper.optional_boolean,
  is_array = shaper.optional_boolean,
  is_auto = shaper.optional_boolean,
  is_boolean = shaper.optional_boolean,
  is_concept = shaper.optional_boolean,
  is_overload = shaper.optional_boolean,
  is_facultative = shaper.optional_boolean,
  is_enum = shaper.optional_boolean,
  is_function = shaper.optional_boolean,
  is_generic = shaper.optional_boolean,
  is_nilable = shaper.optional_boolean,
  is_niltype = shaper.optional_boolean,
  is_pointer = shaper.optional_boolean,
  is_polyfunction = shaper.optional_boolean,
  is_record = shaper.optional_boolean,
  is_union = shaper.optional_boolean,
  is_stringview = shaper.optional_boolean, -- deprecated
  is_table = shaper.optional_boolean,
  is_type = shaper.optional_boolean,
  is_varanys = shaper.optional_boolean,
  is_varargs = shaper.optional_boolean,
  is_cvarargs = shaper.optional_boolean,
  is_void = shaper.optional_boolean,
  is_generic_pointer = shaper.optional_boolean,
  is_cstring = shaper.optional_boolean,
  is_acstring = shaper.optional_boolean,
  is_byte_pointer = shaper.optional_boolean,
  is_array_pointer = shaper.optional_boolean,
  is_bytearray_pointer = shaper.optional_boolean,
  is_unbounded_pointer = shaper.optional_boolean,
  is_unbounded_array = shaper.optional_boolean,
  is_cvalist = shaper.optional_boolean,

  -- Booleans for checking the underlying type (lib types).
  is_allocator = shaper.optional_boolean,
  is_string = shaper.optional_boolean,
  is_span = shaper.optional_boolean,
  is_vector = shaper.optional_boolean,
  is_sequence = shaper.optional_boolean,
  is_list = shaper.optional_boolean,
  is_hashmap = shaper.optional_boolean,
  is_filestream = shaper.optional_boolean,
  is_time_t = shaper.optional_boolean,
  is_clock_t = shaper.optional_boolean,
}

-- This is used to check if a table is a 'bn'.
Type._type = true

-- Lists of operators defined for all types.
Type.unary_operators = {}
Type.binary_operators = {}

function Type:_init(name, size)
  self.name = name
  if size == nil then
    self.size = 0
  elseif size then
    self.size = size
  end
  if self.size then
    self.bitsize = self.size * 8
  end

  -- set the default alignment for this type,
  -- usually the default alignment on primitive types is the primitive size itself
  if not self.align and self.size then
    self.align = self.size
  end
  if self.align then
    self.align = math.min(self.align, typedefs.maxalign)
  end

  -- generate a codename in case not set yet
  if not self.codename then
    self.codename = 'nl' .. self.name
  end

  -- generate an unique id for this type in case not generated yet for this codename
  local id = typeid_by_codename[self.codename]
  if not id then -- generate an id
    id = typeid_counter
    typeid_counter = typeid_counter + 1
    typeid_by_codename[self.codename] = id
  end
  self.id = id

  -- set unary and binary operators tables
  local mt = getmetatable(self)
  self.unary_operators = setmetatable({}, {__index = mt.unary_operators})
  self.binary_operators = setmetatable({}, {__index = mt.binary_operators})
end

-- Set a new codename for this type, storing it in the typeid table.
function Type:set_codename(codename)
  self.codename = codename
  typeid_by_codename[codename] = self.id
end

-- Set a nickname for this type if not set yet.
function Type:suggest_nickname(nickname)
  if nickname == 'T' then -- T is used for many generics, let's ignore it
    return false
  end
  if not self.nickname and self.is_nameable then
    self.nickname = nickname
    return true
  end
  return false
end

-- Return description for type as a string.
function Type:typedesc()
  return self.name
end

-- Helper to perform an operation returning the resulting type, compile time value and error.
local function perform_op_from_list(self, op, ...)
  local type, value, err
  if traits.is_function(op) then
    -- op is a function, get the results by running it
    type, value, err = op(...)
  else
    -- op must be fixed type or nil
    type, value = op, nil
  end
  if not type and self.is_any then
    -- operations on any values must always results in any too
    type, value = self, nil
  end
  return type, value, err
end

-- Perform an unary operation on attr returning the resulting type, compile time value and error.
function Type:unary_operator(opname, attr)
  local type, value, err = perform_op_from_list(self, self.unary_operators[opname], self, attr)
  if not type and not err then -- no resulting type, but no error, thus generate one
    err = string.format("invalid operation for type '%s'", self)
  end
  return type, value, err
end

-- Perform a binary operation on attrs returning the resulting type, compile time value and error.
function Type:binary_operator(opname, rtype, lattr, rattr)
  local type, value, err = perform_op_from_list(self, self.binary_operators[opname], self, rtype, lattr, rattr)
  if not type and not err then -- try binary operator on the right type
    type, value, err = perform_op_from_list(rtype, rtype.binary_operators[opname], self, rtype, lattr, rattr)
  end
  if not type and not err then -- no error, thus generate one
    err = string.format("invalid operation between types '%s' and '%s'", self, rtype)
  end
  return type, value, err
end

-- Get the desired type when converting this type from another type.
function Type:get_convertible_from_type(type)
  if self == type then
    -- the type itself
    return self
  elseif type.is_any then
    -- anything can be converted to and from `any`
    return self
  end
  local msg = string.format("no viable type conversion from '%s' to '%s'", type, self)
  if type.nickname and type.is_procedure then
    msg = msg..'\n\t'..string.format("where '%s' is also known as '%s'", type.nickname, type:typedesc())
  end
  if self.nickname and self.is_procedure then
    msg = msg..'\n\t'..string.format("where '%s' is also known as '%s'", self.nickname, self:typedesc())
  end
  return false, msg
end

-- Get the desired type when converting this type from an attr.
function Type:get_convertible_from_attr(attr, ...)
  return self:get_convertible_from_type(attr.type, ...)
end

-- Checks if this type is convertible from another type.
function Type:is_convertible_from_type(type, ...)
  local ok, err = self:get_convertible_from_type(type, ...)
  return not not ok, err
end

-- Checks if this type is convertible from an attr.
function Type:is_convertible_from_attr(attr, ...)
  local ok, err = self:get_convertible_from_attr(attr, ...)
  return not not ok, err
end

-- Checks if this type is convertible from a node, type or attr.
function Type:is_convertible_from(what, ...)
  if traits.is_astnode(what) then
    return self:is_convertible_from_attr(what.attr, ...)
  elseif traits.is_type(what) then
    return self:is_convertible_from_type(what, ...)
  else --luacov:disable
    assert(what._attr)
    return self:is_convertible_from_attr(what, ...)
  end --luacov:enable
end

-- Wrap a compile time value to be fitted on this type.
function Type.wrap_value(_, value)
  return value
end

-- Returns the resulting type when trying to fit a compile time value into this type.
-- Promoting to a larger type when required.
function Type.promote_type_for_value() return nil end

-- Returns the resulting type when mixing this type with another type.
function Type:promote_type(type)
  return self == type and self or nil
end

-- Checks if this type can initialize from the attr (succeeds only for compile time attrs).
function Type:is_initializable_from_attr(attr)
  return (attr.comptime and self == attr.type) or attr.ctopinit
end

-- Checks if this type equals to another type.
-- Usually this is overwritten by derived types, but this is a fallback implementation.
function Type:is_equal(type)
  return type.id == self.id
end

-- Give the underlying type when implicit dereferencing this type.
function Type:implicit_deref_type()
  return self
end

-- Checks if the type underlying structure is really defined (related to forwarddecl annotation).
function Type:is_defined()
  return not self.forwarddecl or self.forwarddefn
end

-- Checks if this type is pointing to the subtype.
function Type.is_pointer_of() return false end

-- Checks if this type is an array of the subtype.
function Type.is_array_of() return false end

-- Checks if this type has pointers, used by the garbage collector.
function Type.has_pointer() return false end

-- Checks if this type can be represented as a contiguous array of the subtype.
function Type.is_contiguous_of() return false end

-- Return a pretty string representing the type.
-- Usually returns the type's nickname when available or a verbose description otherwise.
function Type:__tostring()
  if self.nickname then
    -- use the nickname when available because it's compact and prettier
    return self.nickname
  else
    -- use the typedesc when no nickname is available
    -- however this can be too verbose for complex types
    return self:typedesc()
  end
end

-- Compare if two types are equal.
function Type.__eq(t1, t2)
  if getmetatable(t1) == getmetatable(t2) then
    if t1.id == t2.id then -- early check for same type (optimization)
      -- types with the same type id should always be the same
      return true
    end
    return t1:is_equal(t2)
  end
  return false
end

Type.unary_operators['not'] = function(_, attr)
  local reval
  if attr.value ~= nil then
    reval = false
  end
  return primtypes.boolean, reval
end

Type.unary_operators.ref = function(ltype, lattr)
  local lval = lattr.value
  if lval == nil then
    if not ltype.is_unpointable then
      return types.PointerType(ltype)
    else
      return nil, nil, string.format('cannot reference not addressable type "%s"', ltype)
    end
  else
    if ltype.is_aggregate then
      return types.PointerType(ltype)
    end
    return nil, nil, string.format('cannot reference compile time value of type "%s"', ltype)
  end
end

Type.binary_operators.eq = function(ltype, rtype, lattr, rattr)
  if ltype.is_comptime or rtype.is_comptime then
    return primtypes.boolean, ltype == rtype and lattr.value == rattr.value
  end
  local reval
  local lval, rval = lattr.value, rattr.value
  if lval ~= nil and rval ~= nil then
    reval = lval == rval
  end
  return primtypes.boolean, reval
end

Type.binary_operators.ne = function(ltype, rtype, lattr, rattr)
  local retype, reval = ltype:binary_operator('eq', rtype, lattr, rattr)
  if reval ~= nil then
    reval = not reval
  end
  return retype, reval
end

Type.binary_operators['and'] = function(ltype, rtype, lattr, rattr)
  local reval
  local retype = types.promote_type_for_attrs(lattr, rattr) or ltype:promote_type(rtype) or primtypes.any
  local lval, rval = lattr.value, rattr.value
  if retype.is_boolean and lval ~= nil and rval ~= nil then
    reval = not not (lval and rval)
  end
  return retype, reval
end

Type.binary_operators['or'] = function(ltype, rtype, lattr, rattr)
  local reval
  local retype = types.promote_type_for_attrs(lattr, rattr) or ltype:promote_type(rtype) or primtypes.any
  local lval, rval = lattr.value, rattr.value
  if retype.is_boolean and lval ~= nil and rval ~= nil then
    reval = lval or rval
  end
  return retype, reval
end

--------------------------------------------------------------------------------
-- Type utilities

-- Counter used to generate unique codenames.
local gencodename_uid = 0

-- Generate a unique codename based on the type name and a node position.
function types.gencodename(name, node)
  local uid
  local srcname
  if node then
    uid = node.uid
    srcname = node.src and node.src.name or ''
  else
    gencodename_uid = gencodename_uid + 1
    uid = gencodename_uid
    srcname = '__nonode__'
  end
  -- make a hash combining the type name, code source file and uid
  local key = string.format('%s%s%d', name, srcname, uid)
  -- take hash of the key
  local hash = stringer.hash(key, 12)
  -- combine the name and hash to generate our codename
  return string.format('%s_%s', name, hash)
end

-- Used internally, set the typedefs and primtypes locals.
-- This exists because typedefs and types modules have recursive dependency on each other.
function types.set_typedefs(t)
  typedefs = t
  primtypes = t.primtypes
end

-- Make a new type class derived from base type class.
-- Unary and binary operators are inherited.
function types.typeclass(base)
  if not base then
    base = Type
  end
  local klass = class(base)
  klass.unary_operators = {}
  klass.binary_operators = {}
  metamagic.setmetaindex(klass.unary_operators, base.unary_operators)
  metamagic.setmetaindex(klass.binary_operators, base.binary_operators)
  return klass
end

-- Promote all types from a list to a single common type.
-- Used on type resolution.
function types.find_common_type(possibletypes)
  if not possibletypes then return end
  local commontype = possibletypes[1]
  for i=2,#possibletypes do
    commontype = commontype:promote_type(possibletypes[i])
    if not commontype then -- no common type found
      return nil
    end
  end
  return commontype -- found the common type
end

-- Convert a list of nodes holding a type to a list of the holding types.
function types.typenodes_to_types(nodes)
  local typelist = {}
  for i=1,#nodes do
    local nodeattr = nodes[i].attr
    assert(nodeattr.type._type and nodeattr.value)
    typelist[i] = nodeattr.value
  end
  if #typelist == 1 and typelist[1].is_void then
    -- single void type means no returns
    typelist = {}
  end
  return typelist
end

-- Convert a list of argument nodes into a list of argument types.
-- This consider if last argument is a function call.
-- Returns nil if need to wait type resolution to complete.
function types.argtypes_from_argnodes(argnodes, wantedlen)
  local nargs = #argnodes
  local argtypes = {}
  for i=1,nargs do
    local argtype = argnodes[i].attr.type
    if not argtype then return end -- cannot complete evaluation yet
    argtypes[i] = argtype
  end
  if nargs > 0 and (not wantedlen or nargs < wantedlen) then
    local argnode = argnodes[nargs]
    local lastattr = argnode.attr
    if not lastattr.type then return end -- cannot complete evaluation yet
    local calleetype = lastattr.calleetype
    if calleetype and not argnode.is_Paren then
      if calleetype.is_any then --luacov:disable
        if wantedlen then
          for i=nargs,wantedlen do
            argtypes[i] = primtypes.any
          end
        end
        -- luacov:enable
      elseif calleetype.is_procedure then -- is a call
        local rettypes = calleetype.rettypes
        for i=2,#rettypes do
          argtypes[nargs+i-1] = calleetype.rettypes[i]
          if wantedlen and #argtypes >= wantedlen then -- has enough arguments
            break
          end
        end
      end
    end
  end
  return argtypes
end

-- Convert a list of attrs to a list of its types.
function types.attrs_to_types(attrs)
  local typelist = {}
  for i=1,#attrs do
    typelist[i] = attrs[i].type
  end
  return typelist
end

-- Check and get last multiple arguments type from a list of attrs.
function types.get_multiple_argtype_from_attrs(attrs)
  local lastargattr = attrs[#attrs]
  if lastargattr then
    local lastargtype = lastargattr.type
    if lastargtype and lastargtype.is_multipleargs then
      return lastargtype
    end
  end
end

-- Checks if a list of types has no `auto` type.
function types.are_types_resolved(typelist)
  for i=1,#typelist do
    if typelist[i].is_auto then
      return false
    end
  end
  return true
end

-- Promote compile time attrs to a common type.
function types.promote_type_for_attrs(lattr, rattr)
  if not lattr.untyped and rattr.comptime and rattr.untyped then
    return lattr.type:promote_type_for_value(rattr.value)
  elseif not rattr.untyped and lattr.comptime and lattr.untyped then
    return rattr.type:promote_type_for_value(lattr.value)
  end
end

-- Check whether the type is a primitive type.
function types.is_primitive_type(type)
  return primtypes[type.nickname or type.name] == type
end

--------------------------------------------------------------------------------
-- Void type
--
-- Void type is more used internally to represent an empty type,
-- and also to represent the void type from C.

local VoidType = types.typeclass()
types.VoidType = VoidType
VoidType.nodecl = true
VoidType.is_nolvalue = true
VoidType.is_comptime = true
VoidType.is_void = true

function VoidType:_init(name)
  Type._init(self, name, 0)
end

--------------------------------------------------------------------------------
-- Auto Type
--
-- The auto type is a placeholder type to inform the compiler that the
-- type should be deduced right away from another symbol type.
-- It's commonly used in polymorphic functions arguments.

local AutoType = types.typeclass()
types.AutoType = AutoType
AutoType.is_auto = true
AutoType.nodecl = true
AutoType.is_comptime = true
AutoType.is_nilable = true
AutoType.is_unpointable = true
AutoType.is_polymorphic = true

function AutoType:_init(name)
  Type._init(self, name, 0)
end

-- Get the desired type when converting this type from another type.
function AutoType.get_convertible_from_type(_, type)
  -- the auto type can convert to anything
  return type
end

--------------------------------------------------------------------------------
-- Type Type
--
-- The 'type' type is the type of a type.

local TypeType = types.typeclass()
types.TypeType = TypeType
TypeType.is_type = true
TypeType.is_comptime = true
TypeType.is_unpointable = true
TypeType.is_polymorphic = true

function TypeType:_init(name)
  Type._init(self, name, 0)
end

-- Length operator for the type type, it returns the size of the type in bytes.
TypeType.unary_operators.len = function(_, attr)
  local reval
  local holdedtype = attr.value
  if holdedtype and holdedtype.size then
    reval = bn.new(holdedtype.size)
  end
  return primtypes.isize, reval
end

--------------------------------------------------------------------------------
-- Niltype Type
--
-- The niltype is the type of 'nil'.

local NiltypeType = types.typeclass()
types.NiltypeType = NiltypeType
NiltypeType.is_niltype = true
NiltypeType.is_nilable = true
NiltypeType.is_falseable = true
NiltypeType.is_unpointable = true
NiltypeType.is_empty = true

function NiltypeType:_init(name, size)
  Type._init(self, name, size)
end

-- Get the desired type when converting this type from another type.
function NiltypeType:get_convertible_from_type(type, explicit, autoref)
  if type.is_void then
    return true
  end
  return Type.get_convertible_from_type(self, type, explicit, autoref)
end

-- Negation operator for niltype type.
NiltypeType.unary_operators['not'] = function()
  return primtypes.boolean
end

--------------------------------------------------------------------------------
-- Nilptr Type
--
-- The nilptr is the type of 'nilptr'. Used when working with pointers.

local NilptrType = types.typeclass()
types.NilptrType = NilptrType
NilptrType.is_nolvalue = true
NilptrType.is_nilptr = true
NilptrType.is_falseable = true
NilptrType.is_unpointable = true

function NilptrType:_init(name, size)
  Type._init(self, name, size)
end

-- Returns the resulting type when mixing this type with another type.
function NilptrType:promote_type(type)
  if type.is_pointer or type.is_function then
    -- preserve pointer or function types
    return type
  end
  return Type.promote_type(self, type)
end

-- Negation operator for nilptr type.
NilptrType.unary_operators['not'] = function()
  return primtypes.boolean
end

--------------------------------------------------------------------------------
-- Boolean Type
--
-- The boolean type is the type for 'true' and 'false'.

local BooleanType = types.typeclass()
types.BooleanType = BooleanType
BooleanType.is_boolean = true
BooleanType.is_atomicable = true
BooleanType.is_falseable = true

function BooleanType:_init(name, size)
  Type._init(self, name, size)
end

function BooleanType:get_convertible_from_type()
  -- anything is convertible to a boolean
  return self
end

-- Negation operator for boolean type.
BooleanType.unary_operators['not'] = function(ltype, lattr)
  local lval = lattr.value
  local reval
  if lval ~= nil then -- compile time value
    reval = not lval
  end
  return ltype, reval
end

--------------------------------------------------------------------------------
-- Any Type
--
-- The any type is a special type that can store a runtime value of any type.

local AnyType = types.typeclass()
types.AnyType = AnyType
AnyType.is_any = true
AnyType.is_nilable = true
AnyType.is_falseable = true
AnyType.sideeffect = true

AnyType.shape = shaper.fork_shape(Type.shape, {
  sideeffect = shaper.optional_boolean,
})

function AnyType:_init(name, size)
  Type._init(self, name, size)
end

-- Get the desired type when converting this type from another type.
function AnyType:get_convertible_from_type()
  -- anything can convert to an any
  return self
end

-- Checks if this type has pointers, used by the garbage collector.
function AnyType.has_pointer() return true end

function AnyType.get_return_type() --luacov:disable
  return primtypes.any
end --luacov:enable

--------------------------------------------------------------------------------
-- Varanys Type
--
-- The varanys type is used only for the last return type of functions that
-- can return a variable number of anys at runtime.

local VaranysType = types.typeclass(AnyType)
types.VaranysType = VaranysType
VaranysType.is_varanys = true
VaranysType.is_multipleargs = true
VaranysType.is_nolvalue = true

function VaranysType:_init(name, size)
  Type._init(self, name, size)
end

--------------------------------------------------------------------------------
-- Varargs Type
--
-- The varargs type is used for the last argument type of polymorphic functions
-- that can have variable number of arguments.

local VarargsType = types.typeclass()
types.VarargsType = VarargsType
VarargsType.is_varargs = true
VarargsType.is_multipleargs = true
VarargsType.is_nolvalue = true
VarargsType.is_polymorphic = true

function VarargsType:_init(name, size)
  Type._init(self, name, size)
end

--------------------------------------------------------------------------------
-- CVarargs Type
--
-- The cvarargs type is used for the last argument type of C imported functions
-- that can have variable number of arguments.

local CVarargsType = types.typeclass()
types.CVarargsType = CVarargsType
CVarargsType.is_cvarargs = true
CVarargsType.is_multipleargs = true
CVarargsType.is_nolvalue = true

function CVarargsType:_init(name, size)
  Type._init(self, name, size)
end

--------------------------------------------------------------------------------
-- Scalar Type
--
-- The scalar type is used as a base type for creating the Integral and Float types.
-- Scalar types can perform arithmetic operations,
-- like addition, subtraction, multiplication, division, etc.

local ScalarType = types.typeclass()
types.ScalarType = ScalarType
ScalarType.is_arithmetic = true
ScalarType.is_scalar = true
ScalarType.is_atomicable = true
ScalarType.get_convertible_from_type = Type.get_convertible_from_type

function ScalarType:_init(name, size)
  Type._init(self, name, size)
end

-- Checks if this type can initialize from the attr (succeeds only for compile time attrs).
function ScalarType:is_initializable_from_attr(attr)
  if attr.comptime and attr.untyped and attr.type and attr.type.is_scalar then
    -- initializing from an untyped compile time scalar is always possible
    return true
  end
  return Type.is_initializable_from_attr(self, attr)
end

-- Negation operator for scalar types.
ScalarType.unary_operators.unm = function(ltype, lattr)
  local reval
  local retype = ltype
  local lval = lattr.value
  if lval then -- is compile time value
    reval = -lval
    retype = ltype:promote_type_for_value(reval)
  end
  return retype, reval
end

-- Equality operator from scalar types.
ScalarType.binary_operators.eq = function(ltype, rtype, lattr, rattr)
  local reval
  if lattr == rattr and not ltype.is_float then
    -- same symbol and not a float, we can optimize away and return always true
    -- floats are ignored because x == x is false when x is NaN
    return primtypes.boolean, true
  end
  if rtype.is_scalar then
    local lval, rval = lattr.value, rattr.value
    if lval and rval then -- both are compile time values
      reval = bn.eq(lval, rval)
    end
  else
    -- equality is always false when comparing another type
    reval = false
  end
  return primtypes.boolean, reval
end

-- Helper to create an comparison operation functions for scalar type.
local function make_arith_cmpop(cmpfunc)
  return function(ltype, rtype, lattr, rattr)
    if ltype.is_scalar and rtype.is_scalar then
      -- we can optimize away the operation when the attr is the same and not a float
      -- float are ignored because x <= x is false when x is NaN
      local same = lattr == rattr and not ltype.is_float
      local reval = cmpfunc(lattr.value, rattr.value, same)
      return primtypes.boolean, reval
    end
  end
end

-- Implement all the scalar comparison operations.
ScalarType.binary_operators.le = make_arith_cmpop(function(a,b,same)
  if same then
    return true
  elseif a and b then
    return a <= b
  end
end)
ScalarType.binary_operators.ge = make_arith_cmpop(function(a,b,same)
  if same then
    return true
  elseif a and b then
    return a >= b
  end
end)
ScalarType.binary_operators.lt = make_arith_cmpop(function(a,b,same)
  if same then
    return false
  elseif a and b then
    return a < b
  end
end)
ScalarType.binary_operators.gt = make_arith_cmpop(function(a,b,same)
  if same then
    return false
  elseif a and b then
    return a > b
  end
end)

--------------------------------------------------------------------------------
-- Integral Type
--
-- Integral type is used for unsigned and signed integer (whole numbers) types,
-- e.g. 'int64', 'uint64', ...
-- They have min and max values and cannot be fractional.

local IntegralType = types.typeclass(ScalarType)
types.IntegralType = IntegralType
IntegralType.is_integral = true

IntegralType.shape = shaper.fork_shape(Type.shape, {
  -- Minimum and maximum value that the integral type can store.
  min = shaper.scalar, max = shaper.scalar,
  -- Signess of the integral type.
  is_signed = shaper.optional_boolean, is_unsigned = shaper.optional_boolean,
})

function IntegralType:_init(name, size, is_unsigned, align)
  if align then
    self.align = align
  end
  ScalarType._init(self, name, size)

  -- compute the min and max values
  if is_unsigned then
    self.min =  bn.zero()
    self.max =  (bn.one() << self.bitsize) - 1
    self.is_unsigned = true
  else -- signed
    self.min = -(bn.one() << self.bitsize) // 2
    self.max = ((bn.one() << self.bitsize) // 2) - 1
    self.is_signed = true
  end

  self['is_'..self.name] = true
end

-- Return unsigned integral version of this type.
function IntegralType:unsigned_type()
  if self.is_unsigned then return self end
  local type = primtypes[typedefs.signed2unsigned[self.name]]
  return type or primtypes['uint'..self.bitsize]
end

-- Return signed integral version of this type.
function IntegralType:signed_type()
  if self.is_signed then return self end
  local type = primtypes[typedefs.unsigned2signed[self.name]]
  return type or primtypes['int'..self.bitsize]
end

-- Get the desired type when converting this type from an attr.
function IntegralType:get_convertible_from_attr(attr, explicit, autoref)
  if not explicit and attr.comptime and attr.type.is_scalar then
    -- implicit conversion between two compile time scalar types,
    -- we can convert only if the compiler time value does not overflow/underflow the type
    local value = bn.demotefloat(attr.value)
    if not traits.is_integral(value) then -- the value must be and integral
      return false, string.format(
        "constant value `%s` is fractional which is invalid for the type '%s'",
        value, self)
    elseif not self:is_inrange(value) then -- the value must be in our range
      return false, string.format(
        "constant value `%s` for type `%s` is out of range, the minimum is `%s` and maximum is `%s`",
        value, self, self.min, self.max)
    end
    -- in range and integral, thus a valid conversion
    return self
  end
  return ScalarType.get_convertible_from_attr(self, attr, explicit, autoref)
end

-- Get the desired type when converting this type from another type.
function IntegralType:get_convertible_from_type(type, explicit, autoref)
  if type.is_integral then
    if type.id == self.id then
      -- early return for the same type
      return self
    elseif self:is_type_inrange(type) then
      -- implicit conversion from another integral that fits this integral
      return self
    end
  end
  if type.is_scalar then
    -- implicit narrowing cast
    return self
  elseif explicit and type.is_pointer and self.size >= type.size then
    -- explicit cast from a pointer to an integral that can fit the pointer
    return self
  end
  return ScalarType.get_convertible_from_type(self, type, explicit, autoref)
end

-- Checks if this type scalar type can fit another scalar type.
-- To fit both min and max values of the other type must be in this type range.
function IntegralType:is_type_inrange(type)
  if type.is_integral and self:is_inrange(type.min) and self:is_inrange(type.max) then
    -- both min and max is in range
    return true
  end
  return false
end

-- Wrap a compile time value to be fitted on this integral type.
-- Float values are truncated, integer value wraps around in case of overflow/underflow.
function IntegralType:wrap_value(value)
  if traits.is_integral(value) then
    -- wrap around in case the value is not in range
    if not self:is_inrange(value) then
      if self.is_signed and value > self.max then
        -- special case for wrapping signed integers
        value = -bn.bwrap(-value, self.bitsize)
      else
        value = bn.bwrap(value, self.bitsize)
      end
    end
  else -- must be a float
    value = bn.trunc(value)
  end
  return value
end

-- Returns the resulting type when trying to fit a compile time value into this type.
-- Promoting to a larger type when required.
function IntegralType:promote_type_for_value(value)
  if traits.is_integral(value) then
    if self:is_inrange(value) then
      -- this type already fits
      return self
    end

    -- try to use a type of same signess until fit the size
    local promotetypes
    local fallbacktype
    if self.is_unsigned and not bn.isneg(value) then -- preserve unsigned when possible
      promotetypes = typedefs.promote_unsigned_types
      fallbacktype = primtypes.uint64
    else -- is signed
      promotetypes = typedefs.promote_signed_types
      fallbacktype = primtypes.int64
    end
    for i=1,#promotetypes do
      local type = promotetypes[i]
      if type.size >= self.size and type:is_inrange(value) then
        -- both value and prev type fits
        return type
      end
    end
    return fallbacktype
  else
    -- non integrals use the default number type
    return primtypes.number
  end
end

-- Returns the resulting type when mixing this type with another type.
-- Promoting to the largest type when required.
function IntegralType:promote_type(type)
  if type == self then -- is the same type
    return self
  elseif type.is_float then -- float always wins when mixing with integers
    return type
  elseif not type.is_integral then -- not a scalar
    return nil
  end
  if self.is_unsigned == type.is_unsigned then
    -- promote to largest type of the same signess
    return type.size >= self.size and type or self
  else
    -- promote to signed version of largest type
    local maxbitsize = math.max(self.bitsize, type.bitsize)
    return primtypes[string.format('int%d', maxbitsize)]
  end
end

-- Checks if the value can fit in this type min and max range.
function IntegralType:is_inrange(value)
  return value >= self.min and value <= self.max
end

-- Helper to determine the resulting type of an arithmetic operation on an integral.
local function integral_arith_op_type(ltype, rtype, lattr, rattr)
  if not rtype.is_scalar or not ltype.is_scalar then
    -- cannot do scalar operations for on a non scalar
    return nil
  end
  return types.promote_type_for_attrs(lattr, rattr) or ltype:promote_type(rtype)
end

-- Helper to determine the resulting type of division operation on an integral.
local function integral_arith_div_op_type(ltype, rtype, lattr, rattr)
  if ltype.is_integral and rtype.is_integral and bn.iszero(rattr.value) then
    -- division by zero is not allowed with integral types
    return nil, 'attempt to divide by zero'
  end
  return integral_arith_op_type(ltype, rtype, lattr, rattr)
end

-- Helper to determine the resulting type of an operation with an integral and a float.
local function integral_float_op_type(ltype, rtype)
  if ltype.is_float or rtype.is_float then -- preserve the same from other type
    return rtype
  else -- fallback to the default number type
    return primtypes.number
  end
end

-- Helper to determine the resulting type of a bitwise operation on integrals.
local function integral_bitwise_op_type(ltype, rtype, lattr, rattr)
  if not ltype.is_integral or not rtype.is_integral then
    return nil, string.format(
      "attempt to perform a bitwise operation with non integral type '%s' or '%s'", ltype, rtype)
  end
  local retype = types.promote_type_for_attrs(lattr, rattr)
  if not retype then
    if rtype.size > ltype.size then -- the largest type always wins
      retype = rtype
    else
      retype = ltype
    end
  end
  return retype
end

-- Helper to determine the resulting type of a shift operation on integrals.
local function integral_shift_op_type(ltype, rtype)
  if not ltype.is_integral or not rtype.is_integral then
    return nil, string.format(
      "attempt to perform a bitwise operation with non integral type '%s' or '%s'", ltype, rtype)
  end
  return ltype
end

-- Helper to create a binary operation function for integrals.
local function make_integral_binary_op(optypefunc, opvalfunc)
  return function(ltype, rtype, lattr, rattr)
    local retype, err = optypefunc(ltype, rtype, lattr, rattr)
    local lval, rval, reval = lattr.value, rattr.value, nil
    if retype and lval and rval then -- compile time operation
      if retype.is_float then -- promote both to floats before if the result is a float
        lval, rval = bn.tonumber(lval), bn.tonumber(rval)
      end
      reval, err = opvalfunc(lval, rval, retype)
      if reval then
        -- promote to a larger type if needed
        retype = retype:promote_type_for_value(reval)
        -- wrap the compile time value in case of overflow/underflow
        reval = retype:wrap_value(reval)
      end
    end
    return retype, reval, err
  end
end

-- Implement basic integral arithmetic operations.
IntegralType.binary_operators.add = make_integral_binary_op(integral_arith_op_type, function(a,b)
  return a + b
end)
IntegralType.binary_operators.sub = make_integral_binary_op(integral_arith_op_type, function(a,b)
  return a - b
end)
IntegralType.binary_operators.mul = make_integral_binary_op(integral_arith_op_type, function(a,b)
  return a * b
end)
IntegralType.binary_operators.idiv = make_integral_binary_op(integral_arith_div_op_type, function(a,b)
  return a // b
end)
IntegralType.binary_operators.tdiv = make_integral_binary_op(integral_arith_div_op_type, function(a,b,type)
  if bn.isintegral(a) and bn.isintegral(b) then
    if bn.eq(a, type.min) and bn.eq(b, -1) then
      return nil, 'divide overflow'
    end
  else -- mixed operation with float
    if bn.iszero(b) then -- division by zero
      return bn.tonumber(a) / 0
    end
  end
  return bn.tdiv(a, b)
end)
IntegralType.binary_operators.mod = make_integral_binary_op(integral_arith_div_op_type, function(a,b)
  return a % b
end)
IntegralType.binary_operators.tmod = make_integral_binary_op(integral_arith_div_op_type, function(a,b,type)
  if bn.isintegral(a) and bn.isintegral(b) then
    if bn.eq(a, type.min) and bn.eq(b, -1) then
      return nil, 'divide overflow'
    end
  else -- mixed operation with float
    if bn.iszero(b) then -- division by zero
      return bn.tonumber(a) % 0.0
    end
  end
  return bn.tmod(a, b)
end)
IntegralType.binary_operators.div = make_integral_binary_op(integral_float_op_type, function(a,b)
  return a / b
end)
IntegralType.binary_operators.pow = make_integral_binary_op(integral_float_op_type, function(a,b)
  return a ^ b
end)

-- Implement bitwise integral arithmetic operations.
-- All results are wrapped around beforehand.
IntegralType.binary_operators.bor = make_integral_binary_op(integral_bitwise_op_type, function(a,b,t)
  return t:wrap_value(a | b)
end)
IntegralType.binary_operators.bxor = make_integral_binary_op(integral_bitwise_op_type, function(a,b,t)
  return t:wrap_value(a ~ b)
end)
IntegralType.binary_operators.band = make_integral_binary_op(integral_bitwise_op_type, function(a,b,t)
  return t:wrap_value(a & b)
end)
IntegralType.binary_operators.shl = make_integral_binary_op(integral_shift_op_type, function(a,b,t)
  return t:wrap_value(a << b)
end)
IntegralType.binary_operators.shr = make_integral_binary_op(integral_shift_op_type, function(a,b,t)
  if bn.isneg(a) and bn.ispos(b) then
    -- operation is on negative integer, must perform logical shift right
    local msb = (bn.one() << (t.bitsize - 1))
    a = bn.bwrap(a | msb, t.bitsize)
  end
  return t:wrap_value(a >> b)
end)
IntegralType.binary_operators.asr = make_integral_binary_op(integral_shift_op_type, function(a,b,t)
  if bn.isneg(a) and b > t.bitsize then
    -- large arithmetic shift on negative integer, must return -1
    return t:wrap_value(-1)
  end
  return t:wrap_value(a >> b)
end)
IntegralType.unary_operators.bnot = function(ltype, lattr)
  local lval, reval = lattr.value, nil
  if lval then -- compile time value
    reval = ltype:wrap_value(~lval)
  end
  return ltype, reval
end

--------------------------------------------------------------------------------
-- Float Type
--
-- Float type is used for floating point numbers, that is, numbers that can have a fractional part.
-- Unlikely integral type it has no min and max values,
-- floats can sometimes be in NaN (not a number) or Inf (infinite) states when doing
-- invalid math operations, either at compile time or runtime.

local FloatType = types.typeclass(ScalarType)
types.FloatType = FloatType
FloatType.is_float = true
FloatType.is_signed = true

FloatType.shape = shaper.fork_shape(Type.shape, {
  -- Decimal digits, number of decimal to unique identify a float without loss in precision.
  decimaldigits = shaper.integer,
  -- Mantissa digits, precision of mantissa in bits.
  mantdigits = shaper.integer,
})

function FloatType:_init(name, size, align, decimaldigits, mantdigits)
  if align then
    self.align = align
  end
  ScalarType._init(self, name, size)
  self.decimaldigits = decimaldigits
  self.mantdigits = mantdigits
  self['is_'..self.name] = true
end

-- Get the desired type when converting this type from another type.
function FloatType:get_convertible_from_type(type, explicit, autoref)
  if type.is_scalar then
    -- any scalar can convert to a float
    return self
  end
  return ScalarType.get_convertible_from_type(self, type, explicit, autoref)
end

-- Checks if the value can fit in this type min and max range.
function FloatType.is_inrange(_, value)
  -- any scalar is in float range
  return traits.is_scalar(value)
end

-- Returns the resulting type when trying to fit a compile time value into this type.
-- Promoting to a larger type when required.
function FloatType:promote_type_for_value(value)
  if traits.is_scalar(value) then -- any scalar can turn into a float
    return self
  end
end

-- Returns the resulting type when mixing this type with another type.
-- Promoting to the largest type when required.
function FloatType:promote_type(type)
  if type == self or type.is_integral then
    -- when mixing floats and integrals, floats always wins
    return self
  elseif not type.is_float then
    -- the other type is not a scalar, fail
    return nil
  end
  -- return the largest float type
  if type.size > self.size then
    return type
  else
    return self
  end
end

-- Helper to get the resulting type in a binary operation with a float.
local function float_arith_op(ltype, rtype, lattr, rattr)
  if not ltype.is_scalar or not rtype.is_scalar then -- both must be scalar
    return nil
  end
  -- try to preserve float32 type when operating with untyped values
  if rtype.is_float32 and lattr.untyped then
    return rtype
  elseif ltype.is_float32 and rattr.untyped then
    return ltype
  end
  -- return the promotion between the two scalar types
  return ltype:promote_type(rtype)
end

-- Helper to create a binary operation function for floats.
local function make_float_binary_opfunc(optypefunc, opvalfunc)
  return function(ltype, rtype, lattr, rattr)
    local retype = optypefunc(ltype, rtype, lattr, rattr)
    if retype then -- we have a common type
      local lval, rval, reval = lattr.value, rattr.value, nil
      if lval and rval then -- both are compile time variables
        -- must convert both to a float before
        lval, rval = bn.tonumber(lval), bn.tonumber(rval)
        reval = opvalfunc(lval, rval, retype)
      end
      return retype, reval
    else -- operation between the types failed
      return nil
    end
  end
end

-- Implement the float binary operations.
FloatType.binary_operators.add = make_float_binary_opfunc(float_arith_op, function(a,b)
  return a + b
end)
FloatType.binary_operators.sub = make_float_binary_opfunc(float_arith_op, function(a,b)
  return a - b
end)
FloatType.binary_operators.mul = make_float_binary_opfunc(float_arith_op, function(a,b)
  return a * b
end)
FloatType.binary_operators.div = make_float_binary_opfunc(float_arith_op, function(a,b)
  return a / b
end)
FloatType.binary_operators.idiv = make_float_binary_opfunc(float_arith_op, function(a,b)
  return a // b
end)
FloatType.binary_operators.tdiv = make_float_binary_opfunc(float_arith_op, function(a,b)
  local q = a / b
  if q < 0 then
    q = math.ceil(q)
  else
    q = math.floor(q)
  end
  return q
end)
FloatType.binary_operators.mod = make_float_binary_opfunc(float_arith_op, function(a,b)
  return a % b
end)
FloatType.binary_operators.tmod = make_float_binary_opfunc(float_arith_op, function(a,b)
  local r = math.abs(a) % math.abs(b)
  if a < 0 then
    r = -r
  end
  return r
end)
FloatType.binary_operators.pow = make_float_binary_opfunc(float_arith_op, function(a,b)
  return a ^ b
end)

--------------------------------------------------------------------------------
-- Table type
--
-- The table type is he type used for lua style tables.

local TableType = types.typeclass()
types.TableType = TableType
TableType.is_table = true

function TableType:_init(name)
  Type._init(self, name, typedefs.ptrsize)
end

--------------------------------------------------------------------------------
-- Array Type
--
-- Arrays are contiguous lists where the size is fixed and known at compile time.

local ArrayType = types.typeclass()
types.ArrayType = ArrayType
ArrayType.is_array = true
ArrayType.is_aggregate = true
ArrayType.is_contiguous = true
ArrayType.is_container = true

ArrayType.shape = shaper.fork_shape(Type.shape, {
  -- Fixed length for the array.
  length = shaper.integer,
  -- The subtype for the array.
  subtype = shaper.type,
})

function ArrayType:_init(subtype, length, node)
  local size = false
  if subtype.size then
    size = subtype.size * length
  end
  self.codename = string.format('%s_arr%d', subtype.codename, length)
  self.node = node
  Type._init(self, 'array', size)
  self.subtype = subtype
  self.length = length
  self.align = subtype.align
  if length == 0 then
    self.is_unbounded_array = true
    self.is_empty = true
  end
  -- validated subtype
  if subtype.is_comptime then
    ASTNode.raisef(node, "in array type: subtype cannot be of compile-time type '%s'", subtype)
  elseif not subtype:is_defined() then
    ASTNode.raisef(node, "in array type: subtype cannot be of forward declared type '%s'", subtype)
  end
end

-- Checks if this type equals to another type.
function ArrayType:is_equal(type)
  return self.subtype == type.subtype and self.length == type.length and type.is_array
end

-- Checks if this type can be represented as a contiguous array of the subtype.
function ArrayType:is_contiguous_of(subtype)
  return self.subtype == subtype
end

-- Return description for type as a string.
function ArrayType:typedesc()
  local ss = sstream()
  ss:addmany(self.name, '(', self.subtype, ', ', self.length, ')')
  return ss:tostring()
end

-- Get the desired type when converting this type from another type.
function ArrayType:get_convertible_from_type(type, explicit, autoref)
  if not explicit and autoref and type:is_pointer_of(self) and not self.nocopy then
    -- implicit automatic dereference
    return self, true
  end
  return Type.get_convertible_from_type(self, type, explicit, autoref)
end

-- Checks if this type is an array of the subtype.
function ArrayType:is_array_of(subtype)
  return self.subtype == subtype
end

-- Checks if this type has pointers, used by the garbage collector.
function ArrayType:has_pointer()
  return self.subtype:has_pointer()
end

-- Length operator for arrays.
ArrayType.unary_operators.len = function(ltype)
  local size = bn.new(ltype.length)
  return primtypes.isize, size
end

--------------------------------------------------------------------------------
-- Enum Type
--
-- Enums are used to list constant compile time values in sequential order.

local EnumType = types.typeclass(IntegralType)
types.EnumType = EnumType
EnumType.is_enum = true
EnumType.is_nameable = true

EnumType.shape = shaper.fork_shape(IntegralType.shape, {
  -- Fixed length for the array.
  fields = shaper.array_of(shaper.shape{
    -- Name of the field.
    name = shaper.string,
    -- Index of the field in the enum, the first index is always 1.
    index = shaper.integer,
    -- The field value.
    value = shaper.integral,
  }),
  -- The integral subtype for the enum.
  subtype = shaper.type,
})

function EnumType:_init(subtype, fields, node)
  self.codename = types.gencodename('enum', node)
  self.node = node
  IntegralType._init(self, 'enum', subtype.size, subtype.is_unsigned, subtype.align)
  self.subtype = subtype
  self.fields = fields
  self.metafields = {}
  self:update_fields()
end

-- Update fields internal values, called when they are changed.
function EnumType:update_fields()
  local fields = self.fields
  for i=1,#fields do
    local field = fields[i]
    field.index = i
    fields[field.name] = field
  end
end

-- Return description for type as a string.
function EnumType:typedesc()
  local ss = sstream()
  ss:addmany('enum(', self.subtype, '){')
  for i,field in ipairs(self.fields) do
    if i > 1 then ss:add(', ') end
    ss:addmany(field.name, '=', field.value)
  end
  ss:add('}')
  return ss:tostring()
end

--------------------------------------------------------------------------------
-- Function Type
--
-- Function type is the type used for all runtime functions,
-- they are really pointers in C so they can be explicitly cast to/from pointers.

local FunctionType = types.typeclass()
types.FunctionType = FunctionType
FunctionType.is_nameable = true
FunctionType.is_function = true
FunctionType.is_atomicable = true
FunctionType.is_procedure = true
FunctionType.is_falseable = true

FunctionType.shape = shaper.fork_shape(Type.shape, {
  -- List of arguments attrs, they contain the type with annotations.
  argattrs = shaper.array_of(shaper.attr),
  -- List of arguments types.
  argtypes = shaper.array_of(shaper.type),
  -- List of return types.
  rettypes = shaper.array_of(shaper.type),
  -- Whether this functions trigger side effects.
  -- A function triggers side effects when it can throw errors or manipulate external variables.
  -- The compiler uses this to know if it should use a strict evaluation order when calling it.
  sideeffect = shaper.optional_boolean,
})

function FunctionType:_init(argattrs, rettypes, node, refonly)
  self.codename = types.gencodename('function', node)
  self.node = node
  Type._init(self, 'function', typedefs.ptrsize)

  if argattrs then -- set the arguments
    -- make sure each arg attr is really an Attr class
    for i=1,#argattrs do
      local argattr = argattrs[i]
      if not argattr._attr then
        setmetatable(argattr, Attr)
      end
    end
  end
  argattrs = argattrs or {}
  self.argattrs = argattrs

  -- generate argtypes list
  local argtypes = types.attrs_to_types(argattrs)
  self.argtypes = argtypes

  -- set the return types
  if rettypes then
    if rettypes._type then
      rettypes = {rettypes}
    end
  end
  self.rettypes = rettypes or {}

  -- validate arg types
  if not refonly then
    for i=1,#argtypes do
      local argtype = argtypes[i]
      if not argtype:is_defined() then
        ASTNode.raisef(node, "in function argument: argument #%d cannot be of forward declared type '%s'", i, argtype)
      end
    end
  end

  -- validate return types
  if rettypes then
    for i=1,#rettypes do
      local rettype = rettypes[i]
      if rettype.is_comptime and not rettype.is_type then
        ASTNode.raisef(node, "in function return: return #%d cannot be of compile-time type '%s'", i, rettype)
      elseif not refonly and not rettype:is_defined() then
        ASTNode.raisef(node, "in function return: return #%d cannot be of forward declared type '%s'", i, rettype)
      end
    end
  end
end

-- Checks if this type equals to another type.
function FunctionType:is_equal(type)
  return type.is_function and
         tabler.icompare(type.argtypes, self.argtypes) and
         tabler.icompare(type.rettypes, self.rettypes)
end

function FunctionType:get_multiple_argtype()
  local argtypes = self.argtypes
  local lasttype = argtypes[#argtypes]
  return (lasttype and lasttype.is_multipleargs) and lasttype or nil
end

-- Get the return type in the specified index.
-- For functions with no return the index 1 type returns 'void'.
function FunctionType:get_return_type(index)
  local rettypes = self.rettypes
  local numrets = #rettypes
  if index > numrets and rettypes[numrets] == primtypes.varanys then
    -- the function has runtime variable any returns
    return primtypes.any
  end
  local rettype = rettypes[index]
  if rettype then -- has a return type for that index
    return rettype
  elseif index == 1 then -- no returns
    return primtypes.void
  end
end

-- Get the desired type when converting this type from another type.
function FunctionType:get_convertible_from_type(type, explicit, autoref)
  if type.is_nilptr then
    -- allow setting a function to a nil pointer
    return self
  end
  if explicit then
    if type.is_generic_pointer then
      -- explicit casting from a generic pointer
      return self
    elseif type.is_function then
      -- explicit casting from another function type
      return self
    end
  end
  return Type.get_convertible_from_type(self, type, explicit, autoref)
end

-- Helper to emit a list of typed fields.
local function typedesc_addfields(ss, fields)
  for i=1,#fields do
    local field = fields[i]
    if i > 1 then ss:add(', ') end
    if field.name then
      ss:addmany(field.name, ': ', field.type)
    else
      ss:add(field.type)
    end
  end
end

-- Return description for type as a string.
function FunctionType:typedesc()
  local ss = sstream()
  ss:addmany(self.name, '(')
  typedesc_addfields(ss, self.argattrs or self.args)
  ss:add(')')
  local rettypes = self.rettypes
  local numrets = rettypes and #rettypes or 0
  ss:add(': ')
  if numrets > 1 then
    ss:addmany('(', rettypes, ')')
  elseif numrets == 1 then
    ss:add(rettypes[1])
  else
    ss:add('void')
  end
  return ss:tostring()
end

FunctionType.unary_operators.ref = function(ltype, lattr)
  if lattr.comptime then
    return ltype
  else
    return types.PointerType(ltype)
  end
end

--------------------------------------------------------------------------------
-- Poly Function Type
--
-- Polymorphic functions, or in short poly functions in the sources,
-- are functions which contains arguments that proprieties can
-- only be known when calling the function at compile time.
-- They are defined and processed lately when calling it for the first time.
-- The are used to specialize the function different arguments types.
-- They are memoized (only defined once for each kind of specialization).

local PolyFunctionType = types.typeclass()
types.PolyFunctionType = PolyFunctionType
PolyFunctionType.is_comptime = true
PolyFunctionType.is_nameable = true
PolyFunctionType.is_procedure = true
PolyFunctionType.is_polyfunction = true
PolyFunctionType.is_equal = FunctionType.is_equal
PolyFunctionType.get_multiple_argtype = FunctionType.get_multiple_argtype
PolyFunctionType.typedesc = FunctionType.typedesc

PolyFunctionType.shape = shaper.fork_shape(Type.shape, {
  -- List of arguments attrs, they contain the type with annotations.
  args = shaper.array_of(shaper.attr),
  -- List of arguments types.
  argtypes = shaper.array_of(shaper.type),
  -- List of return types.
  rettypes = shaper.array_of(shaper.type),
  -- List of functions evaluated by different argument types.
  evals = shaper.array_of(shaper.shape{
    -- List of arguments attrs for the evaluation.
    args = shaper.array_of(shaper.type),
    -- Node defining the evaluated function.
    node = shaper.astnode,
  }),
  -- Whether this functions trigger side effects.
  -- A function trigger side effects when it throw errors or operate on global variables.
  sideeffect = shaper.optional_boolean,
  -- Whether to always evaluate the polymorphic function.
  alwayspoly = shaper.optional_boolean,
})

function PolyFunctionType:_init(args, rettypes, node)
  self.codename = types.gencodename('polyfunction', node)
  self.node = node
  Type._init(self, 'polyfunction', 0)
  self.args = args or {}
  self.argtypes = types.attrs_to_types(args)
  self.rettypes = rettypes or {}
  self.evals = {}
end

local function poly_args_matches(largs, rargs)
  for _,larg,rarg in iters.izip2(largs, rargs) do
    local ltype = traits.is_attr(larg) and larg.type or larg
    local rtype = traits.is_attr(rarg) and rarg.type or rarg
    if ltype ~= rtype then
      return false
    elseif ltype.is_comptime and traits.is_attr(larg) then
      if larg.value ~= rarg.value or not traits.is_attr(rarg) then
        return false
      end
    elseif traits.is_attr(larg) and larg.comptime then
      if rarg.value ~= larg.value or not traits.is_attr(rarg) then
        return false
      end
    end
  end
  return true
end

function PolyFunctionType:get_poly_eval(args)
  local polyevals = self.evals
  for i=1,#polyevals do
    local polyeval = polyevals[i]
    if poly_args_matches(polyeval.args, args) then
      return polyeval
    end
  end
end

function PolyFunctionType:eval_poly(args, srcnode)
  local polyeval
  if not self.alwayspoly then
    polyeval = self:get_poly_eval(args)
  end
  if not polyeval then
    polyeval = { args = args, srcnode = srcnode}
    local evals = self.evals
    evals[#evals+1] = polyeval
  end
  return polyeval
end

function PolyFunctionType:has_varargs()
  local argtypes = self.argtypes
  local lasttype = argtypes[#argtypes]
  return lasttype and lasttype.is_varargs
end

--------------------------------------------------------------------------------
-- Record Type
--
-- Records are defined by a structure of fields, they really are structs from C.

local RecordType = types.typeclass()
types.RecordType = RecordType
RecordType.is_record = true
RecordType.is_nameable = true
RecordType.is_composite = true
RecordType.is_aggregate = true

RecordType.shape = shaper.fork_shape(Type.shape, {
  -- Field in the record.
  fields = shaper.array_of(shaper.shape{
    -- Name of the field.
    name = shaper.string,
    -- Index of the field in the record, the first index is always 1.
    index = shaper.integer,
    -- Offset of the field in the record in bytes, always properly aligned.
    offset = shaper.integer:is_optional(),
    -- Type of the field.
    type = shaper.type,
  }),
  -- Whether to pack the record.
  packed = shaper.optional_boolean,
  -- Use in the lib in generics like 'span', 'vector' to represent the subtype.
  subtype = shaper.type:is_optional(),
  K = shaper.type:is_optional(),
  V = shaper.type:is_optional(),
})

function RecordType:_init(fields, node)
  if not self.codename then
    self.codename = types.gencodename('record', node)
  end
  self.node = node
  Type._init(self, self.name or 'record', 0)

  -- compute this record size and align according to the fields
  self.fields = fields or {}
  self.metafields = {}
  self:update_fields()
end

-- Forward an offset to have a specified alignment.
local function align_forward(offset, align)
  if align <= 1 or offset == 0 then return offset end
  if offset % align == 0 then return offset end
  return offset + (align - (offset % align))
end

-- Update the record size, alignment and field offsets.
-- Called when changing any field at compile time.
function RecordType:update_fields()
  local fields = self.fields
  local offset, align = 0, 1
  local unknown = self.cincomplete
  if #fields > 0 then
    local packed, aligned = self.packed, self.aligned
    -- compute fields offset and record align
    for i=1,#fields do
      local field = fields[i]
      local fieldtype = field.type

      -- validate field
      if not fieldtype:is_defined() then
        ASTNode.raisef(self.node, "record field '%s' cannot be of forward declared type '%s'",
          field.name, fieldtype)
      elseif fieldtype.is_comptime then
        ASTNode.raisef(self.node, "record field '%s' cannot be of compile-time type '%s'",
          field.name, fieldtype)
      end
      field.index = i
      fields[field.name] = field

      local fieldsize = fieldtype.size
      local fieldalign = fieldtype.align
      if fieldsize and fieldalign then
        if not unknown then
          -- the record align is computed as the max field align
          if not packed then -- align the field
            align = math.max(align, fieldalign)
            offset = align_forward(offset, fieldalign)
          end
          field.offset = offset
          offset = offset + fieldsize
        end
      else
        unknown = true
      end
    end
    if not packed then -- align the record to the smallest field align
      offset = align_forward(offset, align)
    end
    if aligned then -- customized align by the user
      offset = align_forward(offset, aligned)
      align = math.max(aligned, align)
    end
  end
  if not unknown then
    if offset == 0 then
      self.is_empty = true
      offset = typedefs.emptysize
      align = offset
    else
      self.is_empty = nil
    end
    self.size = offset
    self.bitsize = offset * 8
    self.align = align
  else
    self.size = nil
    self.bitsize = nil
    self.align = nil
    self.is_empty = nil
  end
end

-- Add a field to the record.
function RecordType:add_field(name, type, index)
  local fields = self.fields
  local field = {name = name, type = type}
  local update = index ~= false
  if not index then -- append a new field
    index = #fields + 1
    fields[index] = field
  else -- insert a new field at index
    table.insert(fields, index, field)
  end
  if update then
    self:update_fields()
  end
end

-- DEPRECATED, use 'fields' directly.
function RecordType:get_field(name) --luacov:disable
  return self.fields[name]
end --luacov:enable

-- Checks if this type can be represented as a contiguous array of the subtype.
function RecordType:is_contiguous_of(subtype)
  if self.is_contiguous then
    local mt_atindex = self.metafields.__atindex
    local mt_len = self.metafields.__len
    if mt_atindex and mt_atindex.type:get_return_type(1):is_pointer_of(subtype) and
       mt_len and mt_len.type:get_return_type(1).is_integral then
      -- the __atindex method is a pointer to the subtype
      -- and the __len method returns an integral
      return true
    end
  end
  return false
end

-- Set a meta field for this type to a symbol of a function or variable.
function Type:set_metafield(name, symbol)
  local metafields = self.metafields
  if not metafields then
    metafields = {}
    self.metafields = metafields
  end
  metafields[name] = symbol
end

-- Get the desired type when converting this type from another type.
function RecordType:get_convertible_from_type(type, explicit, autoref)
  if not explicit and autoref and type:is_pointer_of(self) and not self.nocopy then
    -- perform implicit automatic dereference on a pointer to this record
    return self, true
  end
  return Type.get_convertible_from_type(self, type, explicit, autoref)
end

-- Checks if this type has pointers, used by the garbage collector.
function RecordType:has_pointer()
  local fields = self.fields
  for i=1,#fields do
    if fields[i].type:has_pointer() then return true end
  end
  return false
end

-- Return description for type as a string.
function RecordType:typedesc()
  local ss = sstream()
  ss:add('record{')
  typedesc_addfields(ss, self.fields)
  ss:add('}')
  return ss:tostring()
end

--------------------------------------------------------------------------------
-- Union Type
--
-- Union are defined by a structure of fields using the same address,
-- they really are unions from C.

local UnionType = types.typeclass()
types.UnionType = UnionType
UnionType.is_union = true
UnionType.is_nameable = true
UnionType.is_composite = true
UnionType.is_aggregate = true

UnionType.shape = shaper.fork_shape(Type.shape, {
  -- Field in the union.
  fields = shaper.array_of(shaper.shape{
    -- Name of the field.
    name = shaper.string,
    -- Index of the field in the union, the first index is always 1.
    index = shaper.integer,
    -- Type of the field.
    type = shaper.type,
  })
})

function UnionType:_init(fields, node)
  if not self.codename then
    self.codename = types.gencodename('union', node)
  end
  self.node = node
  Type._init(self, self.name or 'union', 0)

  -- compute this union size and align according to the fields
  self.fields = fields or {}
  self:update_fields()
end

-- Update the union size, alignment and field offsets.
-- Called when changing any field at compile time.
function UnionType:update_fields()
  local fields = self.fields
  local size, align = 0, 1
  local unknown = self.cincomplete
  if #fields > 0 then
    -- compute fields offset and union align
    for i=1,#fields do
      local field = fields[i]
      local fieldtype = field.type

      -- validate field
      if not fieldtype:is_defined() then
        ASTNode.raisef(self.node, "union field '%s' cannot be of forward declared type '%s'",
          field.name, fieldtype)
      elseif fieldtype.is_comptime then
        ASTNode.raisef(self.node, "union field '%s' cannot be of compile-time type '%s'",
          field.name, fieldtype)
      end

      field.index = i
      fields[field.name] = field
      if fieldtype.size and fieldtype.align then
        size = math.max(size, fieldtype.size)
        align = math.max(align, fieldtype.align)
      else
        unknown = true
      end
    end
  end
  if not unknown then
    if size == 0 then
      self.is_empty = true
      size = typedefs.emptysize
      align = size
    else
      self.is_empty = nil
    end
    self.size = size
    self.bitsize = size * 8
    self.align = align
  else
    self.size = nil
    self.bitsize = nil
    self.align = nil
    self.is_empty = nil
  end
end

-- Add a field to the union.
function UnionType:add_field(name, type, index)
  local fields = self.fields
  local field = {name = name, type = type}
  local update = index ~= false
  if not index then -- append a new field
    index = #fields + 1
    fields[index] = field
  else -- insert a new field at index
    table.insert(fields, index, field)
  end
  if update then
    self:update_fields()
  end
end

UnionType.has_pointer = RecordType.has_pointer

-- Return description for type as a string.
function UnionType:typedesc()
  local ss = sstream()
  ss:add('union{')
  typedesc_addfields(ss, self.fields)
  ss:add('}')
  return ss:tostring()
end

--------------------------------------------------------------------------------
-- Pointer Type
--
-- Pointers points to a region in memory of a specific type, like the C pointers.

local PointerType = types.typeclass()
types.PointerType = PointerType
PointerType.is_pointer = true
PointerType.is_atomicable = true
PointerType.is_falseable = true

PointerType.shape = shaper.fork_shape(Type.shape, {
  -- The the the pointer is pointing to.
  subtype = shaper.type,
})

function PointerType:_init(subtype)
  self.subtype = subtype
  if subtype.is_void then -- generic pointer
    self.nodecl = true
    self.nickname = 'pointer'
    self.codename = 'nlpointer'
    self.is_generic_pointer = true
  elseif subtype.is_cchar then -- cstring
    self.nodecl = true
    self.nickname = 'cstring'
    self.codename = 'nlcstring'
    self.is_cstring = true
    self.is_stringy = true
  elseif subtype.is_array and subtype.subtype.is_cchar then -- array cstring
    self.codename = subtype.codename .. '_ptr'
    self.is_acstring = true
    self.is_stringy = true
  else
    self.codename = subtype.codename .. '_ptr'
  end
  if subtype.is_array then
    local subsubtype = subtype.subtype
    if subsubtype.is_integral and subsubtype.size == 1 then
      self.is_bytearray_pointer = true
    end
    if subtype.length == 0 then
      self.is_unbounded_pointer = true
    end
    self.is_array_pointer = true
  elseif subtype.is_integral and subtype.size == 1 then
    self.is_byte_pointer = true
  end
  Type._init(self, 'pointer', typedefs.ptrsize)
  self.unary_operators['deref'] = subtype
end

-- Get the desired type when converting this type from an attr.
function PointerType:get_convertible_from_attr(attr, explicit, autoref)
  local type = attr.type
  if not explicit and autoref and self.subtype == type and type.is_aggregate then
    -- implicit automatic reference for records and arrays
    if not attr.lvalue then -- can only reference l-values
      return false, string.format(
        'cannot automatic reference rvalue of type "%s" to pointer type "%s"',
        type, self)
    end
    attr.refed = true
    return self, true
  end
  return Type.get_convertible_from_attr(self, attr, explicit, autoref)
end

local function is_pointer_subtype_convertible(ltype, rtype)
  if ltype == rtype then
    -- same type
    return true
  elseif ltype.is_integral and rtype.is_integral and ltype.bitsize == rtype.bitsize then
    -- integral with same size and (signess or 8 bitsize)
    return ltype.is_unsigned == rtype.is_unsigned or ltype.bitsize == 8
  end
  return false
end

-- Get the desired type when converting this type from another type.
function PointerType:get_convertible_from_type(type, explicit, autoref)
  if type.is_pointer then
    if type.subtype == self.subtype then
      -- early check for the same type (optimization)
      return self
    elseif explicit then
      -- explicit casting to any other pointer type
      return self
    elseif self.is_generic_pointer then
      -- implicit casting to a generic pointer
      return self
    else
      local selfsubtype = self.subtype
      local typesubtype = type.subtype
      if type.is_array_pointer and
         is_pointer_subtype_convertible(selfsubtype, typesubtype.subtype) then
        -- implicit casting from arrays pointers to pointers
        return self
      elseif self.is_array_pointer and
             is_pointer_subtype_convertible(selfsubtype.subtype, typesubtype) then
        -- implicit casting from pointers to arrays pointers
        return self
      elseif self.is_unbounded_pointer and typesubtype.is_array and
             is_pointer_subtype_convertible(selfsubtype.subtype, typesubtype.subtype) then
        -- implicit casting from bounded arrays pointers to unbounded arrays pointers
        return self
      elseif is_pointer_subtype_convertible(selfsubtype, typesubtype) then
        -- implicit casting between integral of same size and signess
        return self
      elseif selfsubtype.is_pointer and typesubtype.is_pointer and
             selfsubtype:get_convertible_from_type(typesubtype) then
        -- implicit casting for nested pointers
        return self
      end
    end
  elseif type.is_string then
    if self.is_array_pointer and
      is_pointer_subtype_convertible(self.subtype.subtype, primtypes.byte) then
      -- implicit casting from string to a pointer to a byte array
      return self
    elseif is_pointer_subtype_convertible(self.subtype, primtypes.byte) then
      -- implicit casting a string to a cstring or an 8bit integral
      return self
    end
  elseif type.is_nilptr then
    -- implicit casting nilptr to a pointer
    return self
  elseif explicit then
    if type.is_function then
      if self.is_generic_pointer then
        -- explicit casting a function to a generic pointer
        return self
      end
    elseif type.is_integral then
      if type.size >= typedefs.ptrsize then
        -- explicit casting a pointer to an integral that can fit a pointer
        return self
      end
    end
  end
  return Type.get_convertible_from_type(self, type, explicit, autoref)
end

-- Returns the resulting type when mixing this type with another type.
function PointerType:promote_type(type)
  if type.is_nilptr then -- nilptr can promote to any pointer
    return self
  end
  return Type.promote_type(self, type)
end

-- Checks if this type equals to another type.
function PointerType:is_equal(type)
  return type.subtype == self.subtype and type.is_pointer
end

-- Checks if this type is pointing to the subtype.
function PointerType:is_pointer_of(subtype)
  return self.subtype == subtype
end

-- Give the underlying type when implicit dereferencing this type.
function PointerType:implicit_deref_type()
  local subtype = self.subtype
  return subtype.is_aggregate and subtype or self
end

-- Checks if this type has pointers, used by the garbage collector.
function PointerType.has_pointer()
  return true
end

-- Support for compile time length operator on cstring (pointer to cchar).
PointerType.unary_operators.len = function(type, attr)
  if type.is_cstring then
    local lval, reval = attr.value, nil
    if lval then
      reval = bn.new(#lval)
    end
    return primtypes.isize, reval
  elseif type.subtype.is_array then
    return primtypes.isize, bn.new(type.subtype.length)
  end
end

-- Return description for type as a string.
function PointerType:typedesc()
  local ss = sstream()
  ss:addmany(self.name, '(', self.subtype, ')')
  return ss:tostring()
end

--------------------------------------------------------------------------------
-- String Type
--
-- String are used to store and process immutable strings at compile time
-- and also to store string references at runtime. Internally it just holds a pointer
-- to a buffer and a size. It's buffer is always null terminated ('\0') by default
-- to have more compatibility with C.

local StringType = types.typeclass(RecordType)
types.StringType = StringType
StringType.is_nameable = false
StringType.is_stringview = true -- deprecated
StringType.is_string = true
StringType.is_stringy = true
StringType.is_contiguous = true
StringType.is_container = true
StringType.is_oneindexing = true

function StringType:_init(name)
  self.codename = 'nlstring'
  self.subtype = primtypes.byte
  RecordType._init(self, {
    {name = 'data', type = types.PointerType(types.ArrayType(primtypes.byte, 0)) },
    {name = 'size', type = primtypes.usize}
  })
  self.name = name
  self.nickname = name
end

-- Get the desired type when converting this type from another type.
function StringType:get_convertible_from_type(type, explicit, autoref)
  if type.is_stringy then -- implicit cast cstring/acstring to string
    return self
  end
  return RecordType.get_convertible_from_type(self, type, explicit, autoref)
end

-- String length operator.
StringType.unary_operators.len = function(_, lattr)
  local lval, reval = lattr.value, nil
  if lval then -- is a compile time string
    reval = bn.new(#lval)
  end
  return primtypes.isize, reval
end

-- String concatenation operator.
StringType.binary_operators.concat = function(ltype, rtype, lattr, rattr)
  if ltype.is_string and rtype.is_string then
    local lval, rval = lattr.value, rattr.value
    if lval and rval then -- both are compile time strings
      local reval = lval .. rval
      return ltype, reval
    end
  end
end

-- Helper to create the string comparison operation function.
local function make_string_cmp_opfunc(cmpfunc)
  return function(ltype, rtype, lattr, rattr)
    if ltype.is_string and rtype.is_string then -- comparing strings?
      local lval, rval, reval = lattr.value, rattr.value, nil
      if lval and rval then -- both are compile time strings
        reval = cmpfunc(lval, rval)
      end
      return primtypes.boolean, reval
    end
  end
end

-- Implement all the string comparison operations.
StringType.binary_operators.le = make_string_cmp_opfunc(function(a,b) return a<=b end)
StringType.binary_operators.ge = make_string_cmp_opfunc(function(a,b) return a>=b end)
StringType.binary_operators.lt = make_string_cmp_opfunc(function(a,b) return a<b end)
StringType.binary_operators.gt = make_string_cmp_opfunc(function(a,b) return a>b end)

--------------------------------------------------------------------------------
-- CVaList Type
--
-- The cvarargs type is used for the last argument type of C imported functions
-- that can have variable number of arguments.

local CVaList = types.typeclass(RecordType)
types.CVaList = CVaList
CVaList.is_cvalist = true
CVaList.nodecl = true
CVaList.cimport = true
CVaList.cinclude = '<stdarg.h>'

function CVaList:_init(name)
  self.codename = 'nlcvalist'
  RecordType._init(self, {})
  self.size = nil -- the size is compiler dependent
  self.name = name
  self.nickname = name
end

--------------------------------------------------------------------------------
-- Concept Type
--
-- Concept type is used to choose or match incoming types to function arguments at compile time.

local ConceptType = types.typeclass()
types.ConceptType = ConceptType
ConceptType.nodecl = true
ConceptType.is_nameable = true
ConceptType.is_nolvalue = true
ConceptType.is_comptime = true
ConceptType.is_unpointable = true
ConceptType.is_polymorphic = true
ConceptType.is_nilable = true
ConceptType.is_concept = true

-- Create a concept from a lua function defined in the preprocessor.
function ConceptType:_init(func, desiredfunc)
  self.codename = types.gencodename('concept')
  Type._init(self, 'concept', 0)
  self.func = func
  self.desiredfunc = desiredfunc
end

-- Checks if this type is convertible from another type.
function ConceptType:get_convertible_from_type(type, explicit, autoref)
  local attr = Attr{type=type}
  return self:get_convertible_from_attr(attr, explicit, autoref, {attr})
end

-- Checks if an attr can match a concept.
function ConceptType:get_convertible_from_attr(attr, explicit, autoref, argattrs)
  local concept_eval_func = self.func -- alias to have better error messages
  local type, err = concept_eval_func(attr, explicit, autoref, argattrs)
  if type == true then -- concept returned true, use the incoming type
    assert(attr.type)
    type = attr.type
  elseif traits.is_symbol(type) then -- concept returned a symbol
    if type.type == primtypes.type and traits.is_type(type.value) then
      type = type.value
    else -- the symbol is not holding a type
      err = string.format("invalid return for concept '%s': cannot be non type symbol", self)
      type = nil
    end
  elseif not type and not err then -- concept returned nothing
    err = string.format("type '%s' could not match concept '%s'", attr.type, self)
    type = nil
  elseif not (type == false or type == nil or traits.is_type(type)) then
    -- concept returned an invalid value
    err = string.format("invalid return for concept '%s': must be a boolean or a type", self)
    type = nil
  end
  if type then
    if type.is_comptime then -- concept cannot return compile time types
      err = string.format("invalid return for concept '%s': cannot be of the type '%s'", self, type)
      type = nil
    end
  end
  return type, err
end

function ConceptType:get_desired_type_from_node(node)
  if self.desiredfunc then
    return self.desiredfunc(node)
  end
end

--[[
Creates a overload concept that matches passed types.
The arguments can be either a type or a symbol to a type.
They concept may try to convert types if no trivial match is found.
]]
function types.overload_concept(...)
  local acceptedtypes = {}
  for i=1,select('#', ...) do
    local type = select(i, ...)
    if not traits.is_type(type) then
      return nil, string.format("in overload concept definition argument #%d: invalid type", i)
    end
    acceptedtypes[i] = type
  end
  local type = types.ConceptType(function(x)
    local xtype = x.type
    -- try to match an exact type first
    if tabler.ifind(acceptedtypes, xtype) then
      return xtype
    end
    -- else try to convert one
    local errs = {}
    for i=1,#acceptedtypes do
      local type = acceptedtypes[i]
      local ok, err = type:is_convertible_from(xtype)
      if ok then
        return type
      end
      errs[#errs+1] = err
    end
    -- no match, return an error
    local ss = sstream()
    ss:add('cannot match overload concept:\n    ')
    ss:addlist(errs, '\n    ')
    return nil, ss:tostring()
  end, function(node)
    if node.is_InitList then
      -- try to infer to the first accepted table or record type
      for i=1,#acceptedtypes do
        local type = acceptedtypes[i]
        if type.is_table or type.is_record then
          return type
        end
      end
    end
  end)
  type.is_overload = true
  return type
end

-- Like `overload_concept`, but just for `x` and `niltype`.
function types.facultative_concept(x)
  local type, err = types.overload_concept(x, primtypes.niltype)
  if not type then return nil, err end
  type.is_facultative = true
  return type, err
end

--[[
Returns the type of `x`.
Where `x` can be an Attr, an ASTNode or a Type.
]]
function types.decltype(x)
  if not traits.is_table(x) then
    return nil, string.format("in decltype: invalid argument of lua type '%s'", type(x))
  end
  local type
  if x._astnode then -- node
    type = x.attr.type
  elseif x._attr then -- attr
    type = x.type
  elseif x._type then -- type
    type = primtypes.type
  end
  return type
end

--------------------------------------------------------------------------------
-- Generic Type
--
-- Generic type is used to create another type at compile time using the preprocessor.

local GenericType = types.typeclass()
types.GenericType = GenericType
GenericType.nodecl = true
GenericType.is_nameable = true
GenericType.is_nolvalue = true
GenericType.is_comptime = true
GenericType.is_unpointable = true
GenericType.is_generic = true

function GenericType:_init(func)
  self.codename = types.gencodename('generic')
  Type._init(self, 'generic', 0)
  self.func = func
end

-- Evaluate a generic to a type by calling it's function defined in the preprocessor.
function GenericType:eval_type(params)
  local generic_eval_func = self.func -- alias to have better error messages
  local ok, ret, err = except.trycall(generic_eval_func, table.unpack(params))
  if not ok then
    -- the generic creation failed due to a lua error in preprocessor function
    return nil, ret
  end
  if traits.is_symbol(ret) then -- generic returned a symbol
    if ret.type == primtypes.type then -- the symbol is holding a type
      return ret.value
    else -- invalid symbol
      return nil, string.format("expected a symbol holding a type in generic return, but got something else")
    end
  elseif traits.is_type(ret) then -- generic returned a type
    return ret
  elseif not ret and type(err) == 'string' then -- generic returned an error
    return nil, err
  end
  return nil, string.format("expected a type or symbol in generic return, but got '%s'", type(ret))
end

-- Permits evaluating generics by directly calling it's symbol in the preprocessor.
function GenericType:__call(...)
  local ret, err = self:eval_type({...})
  if err then
    except.reraise(err)
  end
  return ret
end

return types
