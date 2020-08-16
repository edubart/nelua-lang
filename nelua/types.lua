-- Types module
--
-- The types module define classes for all the primitive types in Nelua.
-- Also defines some utilities functions for working with types.
--
-- This module is always available in the preprocessor in the `types` variable.

local class = require 'nelua.utils.class'
local tabler = require 'nelua.utils.tabler'
local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local stringer = require 'nelua.utils.stringer'
local sstream = require 'nelua.utils.sstream'
local metamagic = require 'nelua.utils.metamagic'
local config = require 'nelua.configer'.get()
local bn = require 'nelua.utils.bn'
local except = require 'nelua.utils.except'
local shaper = require 'nelua.utils.shaper'
local typedefs, primtypes

local types = {}
local cpusize = config.cpu_bits // 8

--------------------------------------------------------------------------------
local Type = class()
types.Type = Type

-- Define the shape of all fields used in the type.
-- Use this as a reference to know all used fields in the Type class by the compiler.
Type.shape = shaper.shape {
  -- Unique identifier for the type, used when needed for runtime type information.
  id = shaper.integer,
  -- Size of the type at runtime in bytes.
  size = shaper.integer,
  -- Size of the type at runtime in bits.
  bitsize = shaper.integer,
  -- Alignment for the type in bytes.
  align = shaper.integer,
  -- Short name of the type, e.g. 'int64', 'record', 'enum' ...
  name = shaper.string,
  -- First identifier name defined in the sources for the type, not applicable to primitive types.
  -- It is used to generate a pretty name on code generation and to show name on type errors.
  nickname = shaper.string:is_optional(),
  -- The actual name of the type used in the code generator when emitting C code.
  codename = shaper.string,
  -- Symbol that defined the type, not applicable for primitive types.
  symbol = shaper.symbol:is_optional(),
  -- Node that defined the type.
  node = shaper.astnode:is_optional(),
  -- Compile time unary operators defined for the type.
  unary_operators = shaper.table,
  -- Compile time binary operators defined for the type.
  binary_operators = shaper.table,
  -- A generic type that the type can represent when used as generic.
  generic = shaper.type:is_optional(),
  -- Whether the code generator should omit the type declaration.
  nodecl = shaper.optional_boolean,
  -- Whether the code generator should is importing the type from C.
  cimport = shaper.optional_boolean,
  -- C header that the code generator should include C when using the type.
  cinclude = shaper.string:is_optional(),
  -- The value passed in <aligned(X)> annotation, this will change the computed align.
  aligned = shaper.integer:is_optional(),
  -- Whether the type is a primitive type, true for non user defined types.
  is_primitive = shaper.optional_boolean,
  -- Whether the type can turn represents a string, true for stringview, string and cstring.
  is_stringy = shaper.optional_boolean,
  -- Whether the type represents a contiguous buffer.
  -- True for arrays, span and vector defined in the lib.
  -- This is used to allow casting to/from span.
  is_contiguous = shaper.optional_boolean,
  -- Booleans for checking the underlying type.
  is_generic_pointer = shaper.optional_boolean,
  is_cstring = shaper.optional_boolean,
  is_float32 = shaper.optional_boolean,
  is_float64 = shaper.optional_boolean,
  is_float128 = shaper.optional_boolean,
  -- Booleans for checking the underlying type. (lib types)
  is_allocator = shaper.optional_boolean,
  is_resourcepool = shaper.optional_boolean,
  is_string = shaper.optional_boolean,
  is_span = shaper.optional_boolean,
  is_vector = shaper.optional_boolean,
  is_sequence = shaper.optional_boolean,
  is_filestream = shaper.optional_boolean,

  -- REMOVE:
  is_copyable = shaper.optional_boolean,
  is_destroyable = shaper.optional_boolean,

  -- TODO: rethink
  key = shaper.string:is_optional(),
}

Type._type = true
Type.unary_operators = {}
Type.binary_operators = {}

local idcounter = 0
local typeid_by_typecodename = {}
local function genid(codename)
  assert(codename)
  local id = typeid_by_typecodename[codename]
  if not id then
    id = idcounter
    idcounter = idcounter + 1
  end
  return id
end

function Type:set_codename(codename)
  self.codename = codename
  if self.id then
    typeid_by_typecodename[codename] = self.id
  else
    self.id = genid(codename)
  end
end

function Type:_init(name, size, node)
  assert(name)
  self.name = name
  self.node = node
  self.size = size or 0
  self.bitsize = self.size * 8
  self.align = self.size
  if not self.codename then
    self:set_codename('nl' .. self.name)
  end
  local mt = getmetatable(self)
  self.unary_operators = setmetatable({}, {__index = mt.unary_operators})
  self.binary_operators = setmetatable({}, {__index = mt.binary_operators})
end

function Type:suggest_nickname(nickname)
  if self.is_primitive or self.nickname then return false end
  self.nickname = nickname
  return true
end

function Type:typedesc()
  return self.name
end

local function get_operator_in_oplist(self, oplist, opname, arg1, arg2, arg3)
  local opret = oplist[opname]
  local type, value, err
  if traits.is_function(opret) then
    type, value, err = opret(self, arg1, arg2, arg3)
  else
    type, value = opret, nil
  end
  if not type and self.is_any then
    type, value = self, nil
  end
  return type, value, err
end

function Type:unary_operator(opname, attr)
  local type, value, err = get_operator_in_oplist(self, self.unary_operators, opname, attr)
  if not type and not err then
    err = stringer.pformat("invalid operation for type '%s'", self)
  end
  return type, value, err
end

function Type:binary_operator(opname, rtype, lattr, rattr)
  local type, value, err = get_operator_in_oplist(self, self.binary_operators, opname, rtype, lattr, rattr)
  if not type and not err then
    err = stringer.pformat("invalid operation between types '%s' and '%s'",
      self, rtype)
  end
  return type, value, err
end

-- Used to check conversion from `type` to `self`
function Type:is_convertible_from_type(type)
  if self == type then
    -- the type itself
    return self
  elseif type.is_any then
    -- anything can be converted to and from `any`
    return self
  else
    return false, stringer.pformat("no viable type conversion from `%s` to `%s`", type, self)
  end
end

-- Used to check conversion from `attr` type to `self` type
function Type:is_convertible_from_attr(attr, explicit)
  local type = attr.type

  -- check for comptime number conversions
  local value = attr.value
  if type and value and attr.comptime and
    self.is_arithmetic and type.is_arithmetic and not explicit then
    if self.is_integral then
      if not bn.isintegral(value) then
        return false, stringer.pformat(
          "constant value `%s` is fractional which is invalid for the type '%s'",
          value, self)
      elseif not self:is_inrange(value) then
        return false, stringer.pformat(
          "constant value `%s` for type `%s` is out of range, the minimum is `%s` and maximum is `%s`",
          value, self, self.min, self.max)
      else
        -- in range and integral, a valid constant conversion
        return self
      end
    end
  end

  return self:is_convertible_from_type(type, explicit)
end

function Type:is_convertible_from(what, explicit)
  if traits.is_astnode(what) then
    return self:is_convertible_from_attr(what.attr, explicit)
  elseif traits.is_type(what) then
    return self:is_convertible_from_type(what, explicit)
  else --luacov:disable
    assert(traits.is_attr(what))
    return self:is_convertible_from_attr(what, explicit)
  end --luacov:enable
end

function Type.normalize_value(_, value)
  return value
end

function Type:promote_type(type)
  if self == type then
    return self
  end
end

function Type.promote_type_for_value() return nil end

function Type:is_equal(type)
  return type.name == self.name and getmetatable(type) == getmetatable(self)
end

function Type:is_initializable_from_attr(attr)
  if attr and self == attr.type and attr.comptime then
    return true
  end
end

function Type:implict_deref_type()
  return self
end

function Type.is_pointer_of() return false end
function Type.is_array_of() return false end
function Type.has_pointer() return false end
function Type.has_destroyable() return false end
function Type.has_copyable() return false end
function Type:is_contiguous_of(type)
  if not self.is_contiguous then return false end
  if self:is_array_of(type) then
    return true
  elseif self.is_record then
    local mtatindex = self:get_metafield('__atindex')
    local mtlen = self:get_metafield('__len')
    if mtatindex and mtatindex.type:get_return_type(1):is_pointer_of(type) and
       mtlen and mtlen.type:get_return_type(1).is_integral then
      return true
    end
  end
end

function Type:__tostring()
  if self.nickname then
    return self.nickname
  else
    return self:typedesc()
  end
end

function Type:__eq(t)
  return type(t) == 'table' and t._type and self:is_equal(t)
end

local function promote_type_for_attrs(lattr, rattr)
  if not lattr.untyped and rattr.comptime and rattr.untyped then
    return lattr.type:promote_type_for_value(rattr.value)
  elseif not rattr.untyped and lattr.comptime and lattr.untyped then
    return rattr.type:promote_type_for_value(lattr.value)
  end
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
      return nil, nil, stringer.pformat('cannot reference not addressable type "%s"', ltype)
    end
  else
    return nil, nil, stringer.pformat('cannot reference compile time value of type "%s"', ltype)
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
  local retype = promote_type_for_attrs(lattr, rattr) or ltype:promote_type(rtype) or primtypes.any
  local lval, rval = lattr.value, rattr.value
  if retype.is_boolean and lval ~= nil and rval ~= nil then
    reval = not not (lval and rval)
  end
  return retype, reval
end

Type.binary_operators['or'] = function(ltype, rtype, lattr, rattr)
  local reval
  local retype = promote_type_for_attrs(lattr, rattr) or ltype:promote_type(rtype) or primtypes.any
  local lval, rval = lattr.value, rattr.value
  if retype.is_boolean and lval ~= nil and rval ~= nil then
    reval = lval or rval
  end
  return retype, reval
end

local uidcounter = 0
local function genkey(name, node)
  local uid
  local srcname
  if node then
    uid = node.uid
    srcname = node.src.name or ''
  else
    uidcounter = uidcounter + 1
    uid = uidcounter
    srcname = '__nonode__'
  end
  return string.format('%s%s%d', name, srcname, uid)
end

local function gencodename(self, name, node)
  self.key = genkey(name, node)
  local hash = stringer.hash(self.key, 16)
  return string.format('%s_%s', name, hash)
end

local function typeclass(base)
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

--------------------------------------------------------------------------------
local VoidType = typeclass()
types.VoidType = VoidType
VoidType.nodecl = true
VoidType.is_nolvalue = true
VoidType.is_comptime = true
VoidType.is_void = true
VoidType.is_primitive = true

function VoidType:_init(name)
  Type._init(self, name, 0)
end

--------------------------------------------------------------------------------
local AutoType = typeclass()
types.AutoType = AutoType
AutoType.is_auto = true
AutoType.nodecl = true
AutoType.is_comptime = true
AutoType.is_nilable = true
AutoType.is_primitive = true
AutoType.is_unpointable = true
AutoType.is_polymorphic = true

function AutoType:_init(name)
  Type._init(self, name, 0)
end

function AutoType.is_convertible_from_type(_, type)
  return type
end

--------------------------------------------------------------------------------
local TypeType = typeclass()
types.TypeType = TypeType
TypeType.is_type = true
TypeType.is_comptime = true
TypeType.nodecl = true
TypeType.is_unpointable = true
TypeType.is_polymorphic = true
TypeType.is_primitive = true

function TypeType:_init(name)
  Type._init(self, name, 0)
end

TypeType.unary_operators.len = function(_, lattr)
  local reval
  local lval = lattr.value
  if lval then
    assert(traits.is_type(lval))
    reval = bn.new(lval.size)
  end
  return primtypes.integer, reval
end

--------------------------------------------------------------------------------
local NiltypeType = typeclass()
types.NiltypeType = NiltypeType
NiltypeType.is_niltype = true
NiltypeType.is_nilable = true
NiltypeType.is_primitive = true
NiltypeType.is_unpointable = true

function NiltypeType:_init(name)
  Type._init(self, name, 0)
end

NiltypeType.unary_operators['not'] = function()
  return primtypes.boolean, true
end

--------------------------------------------------------------------------------
local NilptrType = typeclass()
types.NilptrType = NilptrType
NilptrType.is_nolvalue = true
NilptrType.is_nilptr = true
NilptrType.is_primitive = true
NilptrType.is_unpointable = true

function NilptrType:_init(name, size)
  Type._init(self, name, size)
end

function NilptrType:promote_type(type)
  if type.is_pointer then return type end
  return Type.promote_type(self, type)
end

NilptrType.unary_operators['not'] = function()
  return primtypes.boolean, true
end

--------------------------------------------------------------------------------
local BooleanType = typeclass()
types.BooleanType = BooleanType
BooleanType.is_boolean = true
BooleanType.is_primitive = true

function BooleanType:_init(name, size)
  Type._init(self, name, size)
end

function BooleanType:is_convertible_from_type()
  return self
end

BooleanType.unary_operators['not'] = function(ltype, lattr)
  local lval = lattr.value
  local reval
  if lval ~= nil then
    reval = not lval
  end
  return ltype, reval
end

--------------------------------------------------------------------------------
local AnyType = typeclass()
types.AnyType = AnyType
AnyType.is_any = true
AnyType.is_nilable = true
AnyType.is_primitive = true

function AnyType:_init(name, size)
  Type._init(self, name, size)
end

function AnyType:is_convertible_from_type()
  return self
end

function AnyType.has_pointer() return true end

--------------------------------------------------------------------------------
local VaranysType = typeclass(AnyType)
types.VaranysType = VaranysType
VaranysType.is_varanys = true
VaranysType.is_nolvalue = true
VaranysType.is_primitive = true

function VaranysType:_init(name, size)
  Type._init(self, name, size)
end

--------------------------------------------------------------------------------
local ArithmeticType = typeclass()
types.ArithmeticType = ArithmeticType
ArithmeticType.is_arithmetic = true
ArithmeticType.is_primitive = true

function ArithmeticType:_init(name, size)
  Type._init(self, name, size)
end

ArithmeticType.is_convertible_from_type = Type.is_convertible_from_type

function ArithmeticType:is_initializable_from_attr(attr)
  if Type.is_initializable_from_attr(self, attr) then
    return true
  end
  if attr and attr.comptime and attr.untyped and attr.type and attr.type.is_arithmetic then
    return true
  end
end

ArithmeticType.unary_operators.unm = function(ltype, lattr)
  local reval
  local retype = ltype
  local lval = lattr.value
  if lval ~= nil then
    reval = -lval
    retype = ltype:promote_type_for_value(reval)
  end
  return retype, reval
end

ArithmeticType.binary_operators.eq = function(_, rtype, lattr, rattr)
  local reval
  if rtype.is_arithmetic then
    local lval, rval = lattr.value, rattr.value
    if lval and rval then
      reval = bn.eq(lval, rval)
    end
  else
    reval = false
  end
  return primtypes.boolean, reval
end

local function make_arithmetic_cmp_opfunc(cmpfunc)
  return function(_, rtype, lattr, rattr)
    if rtype.is_arithmetic then
      return primtypes.boolean, cmpfunc(lattr, rattr)
    end
  end
end

ArithmeticType.binary_operators.le = make_arithmetic_cmp_opfunc(function(a,b)
  -- floats can differs at runtime in case of NaNs
  if a == b and not a.type.is_float then
    return true
  end
  if a.value and b.value then
    return a.value <= b.value
  end
end)

ArithmeticType.binary_operators.ge = make_arithmetic_cmp_opfunc(function(a,b)
  -- floats can differs at runtime in case of NaNs
  if a == b and not a.type.is_float then
    return true
  end
  if a.value and b.value then
    return a.value >= b.value
  end
end)

ArithmeticType.binary_operators.lt = make_arithmetic_cmp_opfunc(function(a,b)
  if a.value and b.value then
    return a.value < b.value
  end
end)

ArithmeticType.binary_operators.gt = make_arithmetic_cmp_opfunc(function(a,b)
  if a.value and b.value then
    return a.value > b.value
  end
end)

--------------------------------------------------------------------------------
-- Integral Type
--
-- Integral type is used for unsigned and signed integer (whole numbers) types,
-- i.e. 'int64', 'uint64', ...
-- They have min and max values and cannot be fractional.

local IntegralType = typeclass(ArithmeticType)
types.IntegralType = IntegralType
IntegralType.is_integral = true

IntegralType.shape = shaper.fork_shape(Type.shape, {
  -- Minimum and maximum value that the integral type can store.
  min = shaper.arithmetic, max = shaper.arithmetic,
  -- Signess of the integral type.
  is_signed = shaper.optional_boolean, is_unsigned = shaper.optional_boolean,
  -- Boolean to know the exactly underlying integral type.
  is_uint64 = shaper.optional_boolean,
  is_uint32 = shaper.optional_boolean,
  is_uint16 = shaper.optional_boolean,
  is_uint8 = shaper.optional_boolean,
  is_int64 = shaper.optional_boolean,
  is_int32 = shaper.optional_boolean,
  is_int16 = shaper.optional_boolean,
  is_int8 = shaper.optional_boolean,
})

function IntegralType:_init(name, size, is_unsigned)
  ArithmeticType._init(self, name, size)

  -- compute the min and max values
  if is_unsigned then
    self.is_unsigned = true
    self['is_uint'..self.bitsize] = true
    self.min =  bn.zero()
    self.max =  (bn.one() << self.bitsize) - 1
  else -- signed
    self.is_signed = true
    self['is_int'..self.bitsize] = true
    self.min = -(bn.one() << self.bitsize) // 2
    self.max = ((bn.one() << self.bitsize) // 2) - 1
  end
end

function IntegralType:is_convertible_from_type(type, explicit)
  if type == self then
    return self
  elseif type.is_integral and self:is_type_inrange(type) then
    return self
  elseif type.is_arithmetic then
    -- implicit narrowing cast
    return self
  elseif explicit and type.is_pointer and self.size == cpusize then
    return self
  end
  return ArithmeticType.is_convertible_from_type(self, type, explicit)
end

function IntegralType:is_type_inrange(type)
  if type.is_integral and self:is_inrange(type.min) and self:is_inrange(type.max) then
    return true
  end
end

function IntegralType:normalize_value(value)
  if not bn.isintegral(value) then
    value = bn.trunc(value)
  end
  if not self:is_inrange(value) then
    if self.is_signed and value > self.max then
      value = -bn.bwrap(-value, self.bitsize)
    else
      value = bn.bwrap(value, self.bitsize)
    end
  end
  return value
end

function IntegralType:promote_type_for_value(value)
  if bn.isintegral(value) then
    if self:is_inrange(value) then
      -- this type already fits
      return self
    end

    -- try to use a type of same signess until fit the size
    local dtypes
    local fallbacktype
    if self.is_unsigned and not bn.isneg(value) then
      dtypes = typedefs.promote_unsigned_types
      fallbacktype =  primtypes.uint64
    else
      dtypes = typedefs.promote_signed_types
      fallbacktype =  primtypes.int64
    end

    for i=1,#dtypes do
      local dtype = dtypes[i]
      if dtype:is_inrange(value) and dtype.size >= self.size then
        -- both value and prev type fits
        return dtype
      end
    end

    return fallbacktype
  else
    return primtypes.number
  end
end

function IntegralType:promote_type(type)
  if type == self or type.is_float then
    return type
  elseif not type.is_integral then
    return nil
  end
  if self.is_unsigned == type.is_unsigned then
    -- promote to bigger of the same signess
    return type.size >= self.size and type or self
  else
    -- promote to signed version of largest type
    local maxbitsize = math.max(self.bitsize, type.bitsize)
    local rettype = primtypes[string.format('int%d', maxbitsize)]
    assert(rettype)
    return rettype
  end
end

function IntegralType:is_inrange(value)
  return value >= self.min and value <= self.max
end

local function integral_arithmetic_operation(ltype, rtype, lattr, rattr)
  if not rtype.is_arithmetic then
    return
  end
  return promote_type_for_attrs(lattr, rattr) or ltype:promote_type(rtype)
end

local function integral_fractional_operation(_, rtype)
  if rtype.is_float then
    return rtype
  else
    return primtypes.number
  end
end

local function integral_bitwise_operation(ltype, rtype, lattr, rattr)
  if not rtype.is_integral then
    return
  end
  local retype = promote_type_for_attrs(lattr, rattr)
  if not retype then
    retype = rtype.size > ltype.size and rtype or ltype
  end
  return retype
end

local function integral_shift_operation(ltype, rtype)
  if not rtype.is_integral then
    return
  end
  return ltype
end

local function make_integral_binary_opfunc(optypefunc, opvalfunc)
  return function(ltype, rtype, lattr, rattr)
    local retype, err = optypefunc(ltype, rtype, lattr, rattr)
    local lval, rval = lattr.value, rattr.value
    if retype and lval and rval then
      local reval
      reval, err = opvalfunc(lval, rval, retype)
      if reval then
        retype = retype:promote_type_for_value(reval)
        reval = retype:normalize_value(reval)
      end
      return retype, reval, err
    end
    return retype, nil, err
  end
end

IntegralType.unary_operators.bnot = function(ltype, lattr)
  local reval
  local lval = lattr.value
  if lval ~= nil then
    reval = ltype:normalize_value(~lval)
  end
  return ltype, reval
end

IntegralType.binary_operators.add = make_integral_binary_opfunc(integral_arithmetic_operation, function(a,b)
  return a + b
end)

IntegralType.binary_operators.sub = make_integral_binary_opfunc(integral_arithmetic_operation, function(a,b)
  return a - b
end)

IntegralType.binary_operators.mul = make_integral_binary_opfunc(integral_arithmetic_operation, function(a,b)
  return a * b
end)

IntegralType.binary_operators.div = make_integral_binary_opfunc(integral_fractional_operation, function(a,b)
  return bn.tonumber(a) / bn.tonumber(b)
end)

IntegralType.binary_operators.idiv = make_integral_binary_opfunc(function(ltype, rtype, lattr, rattr)
  if ltype.is_integral and rtype.is_integral and bn.iszero(rattr.value) then
    return nil, 'attempt to divide by zero'
  end
  return integral_arithmetic_operation(ltype, rtype, lattr, rattr)
end, function(a,b,t)
  if t.is_float then
    return bn.tonumber(a) // bn.tonumber(b)
  else
    return a // b
  end
end)

IntegralType.binary_operators.mod = make_integral_binary_opfunc(function(ltype, rtype, lattr, rattr)
  if ltype.is_integral and rtype.is_integral and bn.iszero(rattr.value) then
    return nil, 'attempt to perform mod zero'
  end
  return integral_arithmetic_operation(ltype, rtype, lattr, rattr)
end, function(a,b,t)
  if t.is_float then
    return bn.tonumber(a) % bn.tonumber(b)
  else
    return a % b
  end
end)

IntegralType.binary_operators.pow = make_integral_binary_opfunc(integral_fractional_operation, function(a,b)
  return a ^ b
end)

IntegralType.binary_operators.bor = make_integral_binary_opfunc(integral_bitwise_operation, function(a,b,t)
  return t:normalize_value(a | b)
end)

IntegralType.binary_operators.bxor = make_integral_binary_opfunc(integral_bitwise_operation, function(a,b,t)
  return t:normalize_value(a ~ b)
end)

IntegralType.binary_operators.band = make_integral_binary_opfunc(integral_bitwise_operation, function(a,b,t)
  return t:normalize_value(a & b)
end)

IntegralType.binary_operators.shl = make_integral_binary_opfunc(integral_shift_operation, function(a,b,t)
  return t:normalize_value(a << b)
end)

IntegralType.binary_operators.shr = make_integral_binary_opfunc(integral_shift_operation, function(a,b,t)
  if a < 0 then
    -- perform logical shift right
    local msb = (bn.one() << (t.bitsize - 1))
    a = bn.bwrap(a | msb, t.bitsize)
  end
  return t:normalize_value(a >> b)
end)

--------------------------------------------------------------------------------
local FloatType = typeclass(ArithmeticType)
types.FloatType = FloatType
FloatType.is_float = true
FloatType.is_signed = true

FloatType.shape = shaper.fork_shape(Type.shape, {
  -- Max decimal digits that this float can represent.
  maxdigits = shaper.integer,
  -- Boolean to know the exactly underlying float type.
  is_float32 = shaper.optional_boolean,
  is_float64 = shaper.optional_boolean,
  is_float128 = shaper.optional_boolean,
})

function FloatType:_init(name, size, maxdigits)
  ArithmeticType._init(self, name, size)
  self.maxdigits = maxdigits
  self['is_float'..self.bitsize] = true
end

function FloatType:is_convertible_from_type(type, explicit)
  if type.is_arithmetic then
    return self
  end
  return ArithmeticType.is_convertible_from_type(self, type, explicit)
end

function FloatType.is_inrange() return true end

function FloatType:promote_type_for_value()
  --assert(traits.isnumeric(value))
  return self
end

function FloatType:promote_type(type)
  if type == self or type.is_integral then
    return self
  elseif not type.is_float then
    return
  end
  if type.size > self.size then
    return type
  end
  return self
end

local function float_arithmetic_operation(ltype, rtype, lattr, rattr)
  if not rtype.is_arithmetic then
    return
  end
  if rtype.is_float32 and lattr.untyped then
    return rtype
  elseif ltype.is_float32 and rattr.untyped then
    return ltype
  end
  return ltype:promote_type(rtype)
end

local function make_float_binary_opfunc(optypefunc, opvalfunc)
  return function(ltype, rtype, lattr, rattr)
    local retype, err = optypefunc(ltype, rtype, lattr, rattr)
    local lval, rval = lattr.value, rattr.value
    if retype and lval and rval then
      local reval
      reval, err = opvalfunc(lval, rval, retype)
      return retype, reval, err
    end
    return retype, err
  end
end

FloatType.binary_operators.add = make_float_binary_opfunc(float_arithmetic_operation, function(a,b)
  return a + b
end)
FloatType.binary_operators.sub = make_float_binary_opfunc(float_arithmetic_operation, function(a,b)
  return a - b
end)
FloatType.binary_operators.mul = make_float_binary_opfunc(float_arithmetic_operation, function(a,b)
  return a * b
end)
FloatType.binary_operators.div = make_float_binary_opfunc(float_arithmetic_operation, function(a,b)
  return bn.tonumber(a) / bn.tonumber(b)
end)
FloatType.binary_operators.idiv = make_float_binary_opfunc(float_arithmetic_operation, function(a,b)
  return bn.tonumber(a) // bn.tonumber(b)
end)
FloatType.binary_operators.mod = make_float_binary_opfunc(float_arithmetic_operation, function(a,b)
  return bn.tonumber(a) % bn.tonumber(b)
end)
FloatType.binary_operators.pow = make_float_binary_opfunc(float_arithmetic_operation, function(a,b)
  return a ^ b
end)

--------------------------------------------------------------------------------
local TableType = typeclass()
types.TableType = TableType
TableType.is_primitive = true
TableType.is_table = true

function TableType:_init(name)
  Type._init(self, name, cpusize)
end

--[[
function TableType.unary_operator()
  return primtypes.any
end

function TableType.binary_operator()
  return primtypes.any
end
]]

--------------------------------------------------------------------------------
local ArrayType = typeclass()
types.ArrayType = ArrayType
ArrayType.is_array = true
ArrayType.is_contiguous = true

ArrayType.shape = shaper.fork_shape(Type.shape, {
  -- Fixed length for the array.
  length = shaper.integer,
  -- The sub type for the array.
  subtype = shaper.type,
})

function ArrayType:_init(subtype, length)
  local size = subtype.size * length
  self:set_codename(string.format('%s_arr%d', subtype.codename, length))
  Type._init(self, 'array', size)
  self.subtype = subtype
  self.length = length
  self.align = subtype.align
end

function ArrayType:is_equal(type)
  return self.subtype == type.subtype and self.length == type.length and type.is_array
end

function ArrayType:typedesc()
  return sstream(self.name, '(', self.subtype, ', ', self.length, ')'):tostring()
end

function ArrayType:is_convertible_from_type(type, explicit)
  if not explicit and type:is_pointer_of(self) then
    -- implicit automatic dereference
    return self
  end
  return Type.is_convertible_from_type(self, type, explicit)
end

function ArrayType:is_array_of(subtype)
  return self.subtype == subtype
end

function ArrayType:has_pointer()
  return self.subtype:has_pointer()
end

ArrayType.unary_operators.len = function(ltype)
  return primtypes.isize, bn.new(ltype.length)
end

--------------------------------------------------------------------------------
local EnumType = typeclass(IntegralType)
types.EnumType = EnumType
EnumType.is_enum = true
EnumType.is_primitive = false -- to allow using custom nicknames

EnumType.shape = shaper.fork_shape(IntegralType.shape, {
  -- Fixed length for the array.
  fields = shaper.array_of(shaper.shape{
    -- Name of the field.
    name = shaper.string,
    -- Index of the field in the enum, the first index is always 1 not 0.
    index = shaper.integer,
    -- The field value.
    value = shaper.integral,
  }),
  -- The integral sub type for the enum.
  subtype = shaper.type,
})

function EnumType:_init(subtype, fields)
  self:set_codename(gencodename(self, 'enum'))
  IntegralType._init(self, 'enum', subtype.size, subtype.is_unsigned)
  self.subtype = subtype
  self.fields = fields
  self:update_fields()
end

-- Update fields internal values when they are changed.
function EnumType:update_fields()
  local fields = self.fields
  for i=1,#fields do
    local field = fields[i]
    field.index = i
    fields[field.name] = field
  end
end

function EnumType:typedesc()
  local ss = sstream('enum(', self.subtype, '){')
  for i,field in ipairs(self.fields) do
    if i > 1 then ss:add(', ') end
    ss:add(field.name, '=', field.value)
  end
  ss:add('}')
  return ss:tostring()
end

--------------------------------------------------------------------------------
local FunctionType = typeclass()
types.FunctionType = FunctionType
FunctionType.is_function = true
FunctionType.is_procedure = true

FunctionType.shape = shaper.fork_shape(Type.shape, {
  -- List of arguments attrs, they contain the type with annotations.
  argattrs = shaper.array_of(shaper.attr),
  -- List of arguments types.
  argtypes = shaper.array_of(shaper.type),
  -- List of return types.
  rettypes = shaper.array_of(shaper.type),
  -- Whether this functions trigger side effects.
  -- A function trigger side effects when it throw errors or operate on global variables.
  sideeffect = shaper.optional_boolean,
})

function FunctionType:_init(argattrs, rettypes, node)
  self:set_codename(gencodename(self, 'function', node))
  Type._init(self, 'function', cpusize, node)
  self.argattrs = argattrs or {}
  local argtypes = {}
  for i=1,#argattrs do
    argtypes[i] = argattrs[i].type
  end
  self.argtypes = argtypes
  if rettypes then
    if #rettypes == 1 and rettypes[1].is_void then
      -- single void type means no returns
      self.rettypes = {}
    else
      self.rettypes = rettypes
      local lastindex = #rettypes
      local lastret = rettypes[lastindex]
      self.returnvaranys = lastret and lastret.is_varanys
    end
  else
    self.rettypes = {}
  end
end

function FunctionType:is_equal(type)
  return type.is_function and
         tabler.deepcompare(type.argtypes, self.argtypes) and
         tabler.deepcompare(type.rettypes, self.rettypes)
end

function FunctionType:has_destroyable_return()
  for i=1,#self.rettypes do
    if self.rettypes[i]:has_destroyable() then
      return true
    end
  end
end

function FunctionType:get_return_type(index)
  local rettypes = self.rettypes
  if self.returnvaranys and index > #rettypes then
    return primtypes.any
  end
  local rettype = rettypes[index]
  if rettype then
    return rettype
  elseif index == 1 then
    return primtypes.void
  end
end

function FunctionType:has_multiple_returns()
  return #self.rettypes > 1
end

function FunctionType:get_return_count()
  return #self.rettypes
end

function FunctionType:is_convertible_from_type(type, explicit)
  if type.is_nilptr then
    return self
  end
  if explicit and (type.is_generic_pointer or type.is_function) then
    return self
  end
  return Type.is_convertible_from_type(self, type, explicit)
end

function FunctionType:typedesc()
  local ss = sstream(self.name, '(', self.argtypes, ')')
  if self.rettypes and #self.rettypes > 0 then
    ss:add(': ')
    if #self.rettypes > 1 then
      ss:add('(', self.rettypes, ')')
    else
      ss:add(self.rettypes)
    end
  end
  return ss:tostring()
end

--------------------------------------------------------------------------------
local PolyFunctionType = typeclass()
types.PolyFunctionType = PolyFunctionType
PolyFunctionType.is_procedure = true
PolyFunctionType.is_polyfunction = true

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
})

function PolyFunctionType:_init(args, rettypes, node)
  self:set_codename(gencodename(self, 'polyfunction', node))
  Type._init(self, 'polyfunction', 0, node)
  self.args = args or {}
  local argtypes = {}
  for i=1,#args do
    argtypes[i] = args[i].type
  end
  self.argtypes = argtypes
  self.rettypes = rettypes or {}
  self.evals = {}
end

local function poly_args_matches(largs, rargs)
  for _,larg,rarg in iters.izip(largs, rargs) do
    local ltype = traits.is_attr(larg) and larg.type or larg
    local rtype = traits.is_attr(rarg) and rarg.type or rarg
    if ltype ~= rtype then
      return false
    elseif rtype.is_comptime and traits.is_attr(larg) then
      if larg.value ~= rarg.value or not traits.is_attr(rarg) then
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

function PolyFunctionType:eval_poly_for_args(args)
  local polyeval = self:get_poly_eval(args)
  if not polyeval then
    polyeval = { args = args }
    table.insert(self.evals, polyeval)
  end
  return polyeval
end

PolyFunctionType.is_equal = FunctionType.is_equal
PolyFunctionType.typedesc = FunctionType.typedesc

--------------------------------------------------------------------------------
-- Record Type
--
-- Record type is defined by a structure of fields, it really is the 'struct' under C.

local RecordType = typeclass()
types.RecordType = RecordType
RecordType.is_record = true

RecordType.shape = shaper.fork_shape(Type.shape, {
  -- Field in the record.
  fields = shaper.array_of(shaper.shape{
    -- Name of the field.
    name = shaper.string,
    -- Index of the field in the record, the first index is always 1 not 0.
    index = shaper.integer,
    -- Offset of the field in the record in bytes, always properly aligned.
    offset = shaper.integer,
    -- Type of the field.
    type = shaper.type,
  }),

  -- Meta fields in the record (methods and global variables declared for it).
  metafields = shaper.map_of(shaper.string, shaper.symbol),

  -- Function to determine which type to interpret when initializing the record from braces '{}'.
  -- This is used to allow initialization of custom vectors from braces.
  -- By default records interpret braces as fields initialization,
  -- but it can be changed to an array for example then it's handled in the __convert metamethod.
  choose_braces_type = shaper.func:is_optional(),

  -- Whether to pack the record.
  packed = shaper.optional_boolean,

  -- Use in the lib in generics like 'span', 'vector' to represent the subtype.
  subtype = shaper.type:is_optional(),
})

function RecordType:_init(fields, node)
  if not self.codename then
    self:set_codename(gencodename(self, 'record', node))
  end
  Type._init(self, 'record', 0, node)

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
  local offset, align = 0, 0
  if #fields > 0 then
    local packed, aligned = self.packed, self.aligned
    -- compute fields offset and record align
    for i=1,#fields do
      local field = fields[i]
      local fieldtype = field.type
      local fieldsize = fieldtype.size
      local fieldalign = fieldtype.align
      -- the record align is computed as the max field align
      align = math.max(align, fieldalign)
      if not packed then -- align the field
        offset = align_forward(offset, fieldalign)
      end
      field.offset = offset
      field.index = i
      fields[field.name] = field
      offset = offset + fieldsize
    end
    if not packed then -- align the record to the smallest field align
      offset = align_forward(offset, align)
    end
    if aligned then -- customized align by the user
      offset = align_forward(offset, aligned)
      align = math.max(aligned, align)
    end
  end
  self.size = offset
  self.bitsize = offset * 8
  self.align = align
end

-- Add a field to the record.
function RecordType:add_field(name, type, index)
  local fields = self.fields
  local field = {name = name, type = type}
  if not index then -- append a new field
    index = #fields + 1
    fields[index] = field
  else -- insert a new field at index
    table.insert(fields, index, field)
  end
  self:update_fields()
end

-- Get a field from the record. (deprecated, use 'fields' directly)
function RecordType:get_field(name) --luacov:disable
  return self.fields[name]
end --luacov:enable

-- Check if this type equals to another type.
function RecordType:is_equal(type)
  return type.name == self.name and type.key == self.key
end

-- Get the symbol of a meta field for this record type.
function RecordType:get_metafield(name)
  return self.metafields[name]
end

-- Set a meta field for this record type to a symbol of a function or variable.
function RecordType:set_metafield(name, symbol)
  if name == '__destroy' then
    self.is_destroyable = true
  elseif name == '__copy' then
    self.is_copyable = true
  end
  self.metafields[name] = symbol
end

-- Check if this type is convertible from another type.
function RecordType:is_convertible_from_type(type, explicit)
  if not explicit and type:is_pointer_of(self) then
    -- perform implicit automatic dereference on a pointer to this record
    return self
  end
  return Type.is_convertible_from_type(self, type, explicit)
end

-- Check if this type can hold pointers, used by the garbage collector.
function RecordType:has_pointer()
  local fields = self.fields
  for i=1,#fields do
    if fields[i].type:has_pointer() then return true end
  end
  return false
end

function RecordType:has_destroyable()
  if self.is_destroyable then return true end
  local fields = self.fields
  for i=1,#fields do
    if fields[i].type:has_destroyable() then return true end
  end
  return false
end

function RecordType:has_copyable()
  if self.is_copyable then return true end
  local fields = self.fields
  for i=1,#fields do
    if fields[i].type:has_copyable() then return true end
  end
  return false
end

-- Return description of this type as a string.
function RecordType:typedesc()
  local ss = sstream('record{')
  for i,field in ipairs(self.fields) do
    if i > 1 then ss:add(', ') end
    ss:add(field.name, ':', field.type)
  end
  ss:add('}')
  return ss:tostring()
end

--------------------------------------------------------------------------------
local PointerType = typeclass()
types.PointerType = PointerType
PointerType.is_pointer = true

PointerType.shape = shaper.fork_shape(Type.shape, {
  -- The the the pointer is pointing to.
  subtype = shaper.type,
})

function PointerType:_init(subtype)
  self.subtype = subtype
  if subtype.is_void then -- generic pointer
    self.nodecl = true
    self.is_generic_pointer = true
    self.is_primitive = true
  elseif subtype.name == 'cchar' then -- cstring
    self.nodecl = true
    self.nickname = 'cstring'
    self.is_cstring = true
    self.is_stringy = true
    self.is_primitive = true
    self:set_codename('nlcstring')
  else
    self:set_codename(subtype.codename .. '_ptr')
  end
  Type._init(self, 'pointer', cpusize)
  self.unary_operators['deref'] = subtype
end

-- Check if this type is convertible from an attr.
function PointerType:is_convertible_from_attr(attr, explicit)
  local type = attr.type
  if not explicit and self.subtype == type and (type.is_record or type.is_array) then
    -- implicit automatic reference for records and arrays
    if not attr.lvalue then -- can only reference l-values
      return false, stringer.pformat(
        'cannot automatic reference rvalue of type "%s" to pointer type "%s"',
        type, self)
    end
    -- inform the code generation that the attr does an automatic reference
    attr.autoref = true
    return self
  end
  return Type.is_convertible_from_attr(self, attr, explicit)
end

-- Check if this type is convertible from another type.
function PointerType:is_convertible_from_type(type, explicit)
  if type == self then
    -- early check for the same type (optimization)
    return self
  elseif type.is_pointer then
    if explicit then
      -- explicit casting to any other pointer type
      return self
    elseif self.is_generic_pointer then
      -- implicit casting to a generic pointer
      return self
    elseif type.subtype:is_array_of(self.subtype) and type.subtype.length == 0 then
      -- implicit casting from unbounded arrays pointers to pointers
      return self
    elseif self.subtype:is_array_of(type.subtype) and self.subtype.length == 0 then
      -- implicit casting from pointers to unbounded arrays pointers
      return self
    elseif self.subtype.is_array and type.subtype.is_array and
           self.subtype.length == 0 and
           self.subtype.subtype == type.subtype.subtype then
      -- implicit casting from checked arrays pointers to unbounded arrays pointers
      return self
    elseif (self.is_cstring and type.subtype == primtypes.byte) or
           (type.is_cstring and self.subtype == primtypes.byte) then
      -- implicit casting between cstring and pointer to byte
      return self
    end
  elseif type.is_stringview and (self.is_cstring or self:is_pointer_of(primtypes.byte)) then
    -- implicit casting a stringview to a cstring or pointer to a byte
    return self
  elseif type.is_nilptr then
    -- implicit casting nilptr to a pointer
    return self
  elseif explicit then
    if type.is_function and self.is_generic_pointer then
      -- explicit casting a function to a generic pointer
      return self
    elseif type.is_integral and type.size >= cpusize then
      -- explicit casting a pointer to an integral that can fit a pointer
      return self
    end
  end
  return Type.is_convertible_from_type(self, type, explicit)
end

-- Check if this type equals to another type.
function PointerType:promote_type(type)
  if type.is_nilptr then
    return self
  end
  return Type.promote_type(self, type)
end

-- Check if this type equals to another type.
function PointerType:is_equal(type)
  return type.subtype == self.subtype and type.is_pointer
end

-- Check if this type is pointing to another type.
function PointerType:is_pointer_of(subtype)
  return self.subtype == subtype
end

-- Give the underlying type when implicit dereferencing the pointer.
function PointerType:implict_deref_type()
  -- implicit dereference is only allowed for records and arrays subtypes
  if self.subtype and self.subtype.is_record or self.subtype.is_array then
    return self.subtype
  end
  return self
end

-- Check if this type can hold pointers, used by the garbage collector.
function PointerType.has_pointer()
  return true
end

-- Support for compile time length operator on cstring (pointer to cchar).
PointerType.unary_operators.len = function(_, lattr)
  if lattr.type.is_cstring then
    local lval, reval = lattr.value, nil
    if lval then
      reval = bn.new(#lval)
    end
    return primtypes.isize, reval
  end
end

-- Return description of this type as a string.
function PointerType:typedesc()
  if not self.subtype.is_void then
    return sstream(self.name, '(', self.subtype, ')'):tostring()
  else
    return self.name
  end
end

--------------------------------------------------------------------------------
-- String View Type
--
-- String views are used to store and process immutable strings at compile time
-- and also to store string references at runtime. Internally it just holds a pointer
-- to a buffer and a size. It's buffer is always null terminated ('\0') by default
-- to have more compatibility with C.

local StringViewType = typeclass(RecordType)
types.StringViewType = StringViewType
StringViewType.is_stringview = true
StringViewType.is_stringy = true
StringViewType.is_primitive = true

function StringViewType:_init(name)
  self:set_codename('nlstringview')
  self.nickname = name
  RecordType._init(self, {
    {name = 'data', type = types.PointerType(types.ArrayType(primtypes.byte, 0)) },
    {name = 'size', type = primtypes.usize}
  })
  self.name = name
end

-- Check if this type is convertible from another type.
function StringViewType:is_convertible_from_type(type, explicit)
  if type.is_cstring then -- implicit cast cstring to stringview
    return self
  end
  return Type.is_convertible_from_type(self, type, explicit)
end

-- Compile time string view length.
StringViewType.unary_operators.len = function(_, lattr)
  local lval, reval = lattr.value, nil
  if lval then -- is a compile time stringview
    reval = bn.new(#lval)
  end
  return primtypes.isize, reval
end

-- Compile time string view concatenation.
StringViewType.binary_operators.concat = function(ltype, rtype, lattr, rattr)
  if ltype.is_stringview and rtype.is_stringview then
    local lval, rval, reval = lattr.value, rattr.value, nil
    if lval and rval then -- both are compile time strings
      reval = lval .. rval
    end
    return ltype, reval
  end
end

-- Utility to create the string view comparison functions at compile time.
local function make_string_cmp_opfunc(cmpfunc)
  return function(ltype, rtype, lattr, rattr)
    if ltype.is_stringview and rtype.is_stringview then -- comparing string views?
      local lval, rval, reval = lattr.value, rattr.value, nil
      if lval and rval then -- both are compile time strings
        reval = cmpfunc(lval, rval)
      end
      return primtypes.boolean, reval
    end
  end
end

-- Implement all the string view comparison functions.
StringViewType.binary_operators.le = make_string_cmp_opfunc(function(a,b) return a<=b end)
StringViewType.binary_operators.ge = make_string_cmp_opfunc(function(a,b) return a>=b end)
StringViewType.binary_operators.lt = make_string_cmp_opfunc(function(a,b) return a<b end)
StringViewType.binary_operators.gt = make_string_cmp_opfunc(function(a,b) return a>b end)

--------------------------------------------------------------------------------
-- Concept Type
--
-- Concept type is used to choose or match incoming types to function arguments at compile time.

local ConceptType = typeclass()
types.ConceptType = ConceptType
ConceptType.nodecl = true
ConceptType.is_nolvalue = true
ConceptType.is_comptime = true
ConceptType.is_unpointable = true
ConceptType.is_polymorphic = true
ConceptType.is_nilable = true
ConceptType.is_concept = true

-- Create a concept from a lua function defined in the preprocessor.
function ConceptType:_init(func)
  Type._init(self, 'concept', 0)
  self.func = func
end

-- Check if an attr can match a concept.
function ConceptType:is_convertible_from_attr(attr, _, argattrs)
  local type, err = self.func(attr, argattrs)
  if type == true then -- concept returned true, use the incoming type
    assert(attr.type)
    type = attr.type
  elseif traits.is_symbol(type) then -- concept returned a symbol
    if type.type == primtypes.type and traits.is_type(type.value) then
      type = type.value
    else -- the symbol is not holding a type
      type = nil
      err = stringer.pformat("invalid return for concept '%s': cannot be non type symbol", self)
    end
  elseif not type and not err then -- concept returned nothing
    type = nil
    err = stringer.pformat("type '%s' could not match concept '%s'", attr.type, self)
  elseif not (type == false or type == nil or traits.is_type(type)) then
    -- concept returned an invalid value
    type = nil
    err = stringer.pformat("invalid return for concept '%s': must be a boolean or a type", self)
  end
  if type then
    if type.is_comptime then -- concept cannot return compile time types
      type = nil
      err = stringer.pformat("invalid return for concept '%s': cannot be of the type '%s'", self, type)
    end
  end
  return type, err
end

--------------------------------------------------------------------------------
-- Generic Type
--
-- Generic type is used to create another type at compile time using the preprocessor.

local GenericType = typeclass()
types.GenericType = GenericType
GenericType.nodecl = true
GenericType.is_nolvalue = true
GenericType.is_comptime = true
GenericType.is_unpointable = true
GenericType.is_generic = true

function GenericType:_init(func)
  Type._init(self, 'generic', 0)
  self.func = func
end

-- Evaluate a generic to a type by calling it's function defined in the preprocessor.
function GenericType:eval_type(params)
  local ok, ret = except.trycall(self.func, table.unpack(params))
  if not ok then
    -- the generic creation failed due to a lua error in preprocessor function
    return nil, ret
  end
  local err
  if traits.is_symbol(ret) then -- generic returned a symbol
    if ret.type == primtypes.type then -- the symbol is holding a type
      ret = ret.value
    else -- invalid symbol
      ret = nil
      err = stringer.pformat("expected a symbol holding a type in generic return, but got something else")
    end
  elseif not traits.is_type(ret) then -- generic didn't return a type
    ret = nil
    err = stringer.pformat("expected a type or symbol in generic return, but got '%s'", type(ret))
  end
  return ret, err
end

-- Permits evaluating generics by directly calling it's symbol in the preprocessor.
function GenericType:__call(params)
  return self:eval_type({params})
end

--------------------------------------------------------------------------------
-- Utilities

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
    assert(nodeattr.type._type)
    typelist[i] = nodes[i].attr.value
  end
  return typelist
end

-- Used internally, set the typedefs and primtypes locals.
-- This exists because typedefs and types modules have recursive dependency on each other.
function types.set_typedefs(t)
  typedefs = t
  primtypes = t.primtypes
end

return types
