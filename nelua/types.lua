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
local typedefs, primtypes

local types = {}
local cpusize = config.cpu_bits // 8

--------------------------------------------------------------------------------
local Type = class()
types.Type = Type

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
  if not self.codename then
    self:set_codename(string.format('nl%s', self.name))
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
    return false, stringer.pformat(
      "no viable type conversion from `%s` to `%s`",
      type, self)
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

function Type:auto_deref_type()
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
    return types.get_pointer_type(ltype)
  else
    return nil, nil, 'cannot reference compile time value'
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
AutoType.is_lazyable = true

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
TypeType.is_lazyable = true

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
  if type.is_pointer then
    return type
  end
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
  self.bitsize = size * 8
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
local IntegralType = typeclass(ArithmeticType)
types.IntegralType = IntegralType
IntegralType.is_integral = true

local function get_integral_range(bits, is_unsigned)
  local min, max
  if is_unsigned then
    min =  bn.zero()
    max =  (bn.one() << bits) - 1
  else -- signed
    min = -(bn.one() << bits) // 2
    max = ((bn.one() << bits) // 2) - 1
  end
  return min, max
end

function IntegralType:_init(name, size, is_unsigned)
  ArithmeticType._init(self, name, size)
  self.min, self.max = get_integral_range(self.bitsize, is_unsigned)
  self.is_unsigned = is_unsigned
  self.is_signed = not is_unsigned
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

    -- try to use signed version until fit the size
    local signedtypes = typedefs.promote_signed_types
    for i=1,#signedtypes do
      local dtype = signedtypes[i]
      if dtype:is_inrange(value) and dtype.size >= self.size then
        -- both value and prev type fits
        return dtype
      end
    end

    -- can only be int64 now
    return primtypes.int64
  else
    return primtypes.number
  end
end

function IntegralType:promote_type(type)
  if type == self or type.is_float then
    return type
  elseif not type.is_integral then
    return
  end
  if self.is_unsigned == type.is_unsigned then
    -- promote to bigger of the same signess
    return type.size >= self.size and type or self
  else
    -- promote to best signed type that fits both types
    local signedsize = self.is_signed and self.bitsize or type.bitsize
    local unsignedsize = self.is_unsigned and self.bitsize or type.bitsize
    if signedsize < unsignedsize * 2 then
      signedsize = math.min(unsignedsize * 2, 64)
    end
    return primtypes[string.format('int%d', signedsize)]
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

function FloatType:_init(name, size, maxdigits, fmtdigits)
  ArithmeticType._init(self, name, size)
  self.maxdigits = maxdigits
  self.fmtdigits = fmtdigits
  if self.bitsize == 32 then
    self.is_float32 = true
  elseif self.bitsize == 64 then
    self.is_float64 = true
  end
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

function ArrayType:_init(subtype, length)
  local size = subtype.size * length
  self:set_codename(string.format('%s_arr%d', subtype.codename, length))
  Type._init(self, 'array', size)
  self.subtype = subtype
  self.length = length
  self.align = subtype.align or subtype.size--math.min(subtype.size, cpusize)
end

function ArrayType:is_equal(type)
  return self.subtype == type.subtype and
         self.length == type.length and
         type.is_array
end

function ArrayType:typedesc()
  return sstream(self.name, '(', self.subtype, ', ', self.length, ')'):tostring()
end

function ArrayType:is_convertible_from_type(type, explicit)
  if not explicit and type:is_pointer_of(self) then
    -- automatic deref
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
EnumType.is_primitive = false

function EnumType:_init(subtype, fields)
  self:set_codename(gencodename(self, 'enum'))
  IntegralType._init(self, 'enum', subtype.size, subtype.is_unsigned)
  self.subtype = subtype
  for i=1,#fields do
    local field = fields[i]
    field.index = i
    fields[field.name] = field
  end
  self.fields = fields
end

function EnumType:get_field(name)
  return self.fields[name]
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

function FunctionType:_init(argattrs, returntypes, node)
  self:set_codename(gencodename(self, 'function', node))
  Type._init(self, 'function', cpusize, node)
  self.argattrs = argattrs or {}
  local argtypes = {}
  for i=1,#argattrs do
    argtypes[i] = argattrs[i].type
  end
  self.argtypes = argtypes
  if returntypes then
    if #returntypes == 1 and returntypes[1].is_void then
      -- single void type means no returns
      self.returntypes = {}
    else
      self.returntypes = returntypes
      local lastindex = #returntypes
      local lastret = returntypes[lastindex]
      self.returnvaranys = lastret and lastret.is_varanys
    end
  else
    self.returntypes = {}
  end
end

function FunctionType:is_equal(type)
  return type.is_function and
         tabler.deepcompare(type.argtypes, self.argtypes) and
         tabler.deepcompare(type.returntypes, self.returntypes)
end

function FunctionType:has_destroyable_return()
  for i=1,#self.returntypes do
    if self.returntypes[i]:has_destroyable() then
      return true
    end
  end
end

function FunctionType:get_return_type(index)
  local returntypes = self.returntypes
  if self.returnvaranys and index > #returntypes then
    return primtypes.any
  end
  local rettype = returntypes[index]
  if rettype then
    return rettype
  elseif index == 1 then
    return primtypes.void
  end
end

function FunctionType:has_multiple_returns()
  return #self.returntypes > 1
end

function FunctionType:has_enclosed_return()
  return self:has_multiple_returns()
end

function FunctionType:get_return_count()
  return #self.returntypes
end

function FunctionType:is_convertible_from_type(type, explicit)
  if type.is_nilptr then
    return self
  end
  return Type.is_convertible_from_type(self, type, explicit)
end

function FunctionType:typedesc()
  local ss = sstream(self.name, '(', self.argtypes, ')')
  if self.returntypes and #self.returntypes > 0 then
    ss:add(': ')
    if #self.returntypes > 1 then
      ss:add('(', self.returntypes, ')')
    else
      ss:add(self.returntypes)
    end
  end
  return ss:tostring()
end

--------------------------------------------------------------------------------
local LazyFunctionType = typeclass()
types.LazyFunctionType = LazyFunctionType
LazyFunctionType.is_procedure = true
LazyFunctionType.is_lazyfunction = true

function LazyFunctionType:_init(args, returntypes, node)
  self:set_codename(gencodename(self, 'lazyfunction', node))
  Type._init(self, 'lazyfunction', 0, node)
  self.args = args or {}
  local argtypes = {}
  for i=1,#args do
    argtypes[i] = args[i].type
  end
  self.argtypes = argtypes
  self.returntypes = returntypes or {}
  self.evals = {}
end

local function lazy_args_matches(largs, rargs)
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

function LazyFunctionType:get_lazy_eval(args)
  local lazyevals = self.evals
  for i=1,#lazyevals do
    local lazyeval = lazyevals[i]
    if lazy_args_matches(lazyeval.args, args) then
      return lazyeval
    end
  end
end

function LazyFunctionType:eval_lazy_for_args(args)
  local lazyeval = self:get_lazy_eval(args)
  if not lazyeval then
    lazyeval = { args = args }
    table.insert(self.evals, lazyeval)
  end
  return lazyeval
end

LazyFunctionType.is_equal = FunctionType.is_equal
LazyFunctionType.typedesc = FunctionType.typedesc

--------------------------------------------------------------------------------
local RecordType = typeclass()
types.RecordType = RecordType
RecordType.is_record = true

local function compute_record_size(fields, pack)
  local nfields = #fields
  local size = 0
  local align = 0
  if nfields == 0 then
    return size, align
  end
  local pad
  for i=1,#fields do
    local ftype = fields[i].type
    local fsize = ftype.size
    local falign = ftype.align or fsize --math.min(fsize, cpusize)
    align = math.max(align, falign)
    pad = 0
    if not pack and size % falign > 0 then
      pad = size % falign
    end
    size = size + pad + fsize
  end
  size = size - pad
  pad = 0
  if not pack and size % align > 0 then
    pad = align - (size % align)
  end
  size = size + pad
  return size, align
end

function RecordType:_init(fields, node)
  fields = fields or {}
  for i=1,#fields do
    local field = fields[i]
    field.index = i
    fields[field.name] = field
  end
  local size, align = compute_record_size(fields)
  if not self.codename then
    self:set_codename(gencodename(self, 'record', node))
  end
  Type._init(self, 'record', size, node)
  self.fields = fields
  self.metafields = {}
  self.align = align
end

function RecordType:add_field(name, type, index)
  local fields = self.fields
  local field = {name = name, type = type}
  if not index then
    index = #fields + 1
    fields[index] = field
  else
    table.insert(fields, index, field)
  end
  field.index = index
  self.fields[field.name] = field
  self.size, self.align = compute_record_size(fields)
end

function RecordType:get_field(name)
  return self.fields[name]
end

function RecordType:is_equal(type)
  return type.name == self.name and type.key == self.key
end

function RecordType:typedesc()
  local ss = sstream('record{')
  for i,field in ipairs(self.fields) do
    if i > 1 then ss:add(', ') end
    ss:add(field.name, ':', field.type)
  end
  ss:add('}')
  return ss:tostring()
end

function RecordType:get_metafield(name)
  return self.metafields[name]
end

function RecordType:set_metafield(name, symbol)
  if name == '__destroy' then
    self.is_destroyable = true
  elseif name == '__copy' then
    self.is_copyable = true
  end
  self.metafields[name] = symbol
end

function RecordType:is_convertible_from_type(type, explicit)
  if not explicit and type:is_pointer_of(self) then
    -- automatic deref
    return self
  end
  return Type.is_convertible_from_type(self, type, explicit)
end

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

--------------------------------------------------------------------------------
local PointerType = typeclass()
types.PointerType = PointerType
PointerType.is_pointer = true

function PointerType:_init(subtype)
  self.subtype = subtype
  if subtype.is_void then
    self.nodecl = true
    self.is_genericpointer = true
    self.is_primitive = true
  elseif subtype.name == 'cchar' then
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

function PointerType:is_convertible_from_attr(attr, explicit)
  local type = attr.type
  if not explicit and self.subtype == type and (type.is_record or type.is_array) then
    -- automatic ref
    if not attr.lvalue then
      return false, stringer.pformat(
        'cannot automatic reference rvalue of type "%s" to pointer type "%s"',
        type, self)
    end
    attr.autoref = true
    return self
  end
  return Type.is_convertible_from_attr(self, attr, explicit)
end

function PointerType:is_convertible_from_type(type, explicit)
  if type == self then
    return self
  elseif type.is_pointer then
    if explicit then
      return self
    elseif self.is_genericpointer then
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
      return self
    end
  end
  if type.is_stringview and (self.is_cstring or self:is_pointer_of(primtypes.byte)) then
    return self
  elseif type.is_nilptr then
    return self
  elseif explicit and type.is_integral and type.size == cpusize then
    -- conversion from pointer to integral
    return self
  end
  return Type.is_convertible_from_type(self, type, explicit)
end

function PointerType:promote_type(type)
  if type.is_nilptr then
    return self
  end
  return Type.promote_type(self, type)
end

function PointerType:is_equal(type)
  return type.subtype == self.subtype and type.is_pointer
end

function PointerType:is_pointer_of(subtype)
  return self.subtype == subtype
end

function PointerType:auto_deref_type()
  if self.subtype and self.subtype.is_record or self.subtype.is_array then
    return self.subtype
  end
  return self
end

function PointerType:typedesc()
  if not self.subtype.is_void then
    return sstream(self.name, '(', self.subtype, ')'):tostring()
  else
    return self.name
  end
end

function PointerType.has_pointer()
  return true
end

PointerType.unary_operators.len = function(_, lattr)
  if lattr.type.is_cstring then
    local lval = lattr.value
    local reval
    if lval then
      reval = bn.new(#lval)
    end
    return primtypes.isize, reval
  end
end

--------------------------------------------------------------------------------
local StringViewType = typeclass(RecordType)
types.StringViewType = StringViewType
StringViewType.is_stringview = true
StringViewType.is_stringy = true
StringViewType.is_primitive = true
StringViewType.align = cpusize

function StringViewType:_init(name, size)
  local fields = {
    {name = 'data', type = types.PointerType(types.ArrayType(primtypes.byte, 0)) },
    {name = 'size', type = primtypes.usize}
  }
  self:set_codename('nlstringview')
  RecordType._init(self, fields)
  self.name = 'stringview'
  self.nickname = 'stringview'
  self.metafields = {}
  Type._init(self, name, size)
end

function StringViewType:is_convertible_from_type(type, explicit)
  if type.is_cstring then
    -- implicit cast cstring to stringview
    return self
  end
  return Type.is_convertible_from_type(self, type, explicit)
end

StringViewType.unary_operators.len = function(_, lattr)
  local lval = lattr.value
  local reval
  if lval then
    reval = bn.new(#lval)
  end
  return primtypes.isize, reval
end

local function make_string_cmp_opfunc(cmpfunc)
  return function(_, rtype, lattr, rattr)
    if rtype.is_stringview then
      local reval
      local lval, rval = lattr.value, rattr.value
      if lval and rval then
        reval = cmpfunc(lval, rval)
      end
      return primtypes.boolean, reval
    end
  end
end

StringViewType.binary_operators.le = make_string_cmp_opfunc(function(a,b)
  return a<=b
end)
StringViewType.binary_operators.ge = make_string_cmp_opfunc(function(a,b)
  return a>=b
end)
StringViewType.binary_operators.lt = make_string_cmp_opfunc(function(a,b)
  return a<b
end)
StringViewType.binary_operators.gt = make_string_cmp_opfunc(function(a,b)
  return a>b
end)
StringViewType.binary_operators.concat = function(ltype, rtype, lattr, rattr)
  if rtype.is_stringview then
    local reval
    local lval, rval = lattr.value, rattr.value
    if lval and rval then
      reval = lval .. rval
    end
    return ltype, reval
  end
end

--------------------------------------------------------------------------------
local ConceptType = typeclass()
types.ConceptType = ConceptType
ConceptType.nodecl = true
ConceptType.is_nolvalue = true
ConceptType.is_comptime = true
ConceptType.is_unpointable = true
ConceptType.is_lazyable = true
ConceptType.is_nilable = true
ConceptType.is_concept = true

function ConceptType:_init(func)
  Type._init(self, 'concept', 0)
  self.func = func
end

function ConceptType:is_convertible_from_attr(attr, explicit)
  local type, err = self.func(attr, explicit)
  if type == true then
    assert(attr.type)
    type = attr.type
  elseif traits.is_symbol(type) then
    if type.type == primtypes.type and traits.is_type(type.value) then
      type = type.value
    else
      type = nil
      err = stringer.pformat("invalid return for concept '%s': cannot be non type symbol", self)
    end
  elseif traits.is_type(type) then
    if type.is_comptime then
      type = nil
      err = stringer.pformat("invalid return for concept '%s': cannot be of the type '%s'", self, type)
    end
  elseif not type and not err then
    type = nil
    err = stringer.pformat("type '%s' could not match concept '%s'", attr.type, self)
  elseif not (type == false or type == nil) then
    type = nil
    err = stringer.pformat("invalid return for concept '%s': must be a boolean or a type", self)
  end
  return type, err
end

--------------------------------------------------------------------------------
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

function GenericType:eval_type(params)
  local ok, ret = except.trycall(self.func, table.unpack(params))
  if not ok then
    return nil, ret
  end
  local err
  if traits.is_symbol(ret) then
    if not ret.type or not ret.type.is_type then
      ret = nil
      err = stringer.pformat("expected a symbol holding a type in generic return, but got something else")
    else
      ret = ret.value
    end
  elseif not traits.is_type(ret) then
    ret = nil
    err = stringer.pformat("expected a type or symbol in generic return, but got '%s'", type(ret))
  end
  return ret, err
end

--------------------------------------------------------------------------------
function types.set_typedefs(t)
  typedefs = t
  primtypes = t.primtypes
end

function types.get_pointer_type(subtype)
  if subtype == primtypes.cchar then
    return primtypes.cstring
  elseif not subtype.is_unpointable then
    return types.PointerType(subtype)
  end
end

function types.find_common_type(possibletypes)
  if not possibletypes then return end
  local commontype = possibletypes[1]
  for i=2,#possibletypes do
    commontype = commontype:promote_type(possibletypes[i])
    if not commontype then
      break
    end
  end
  return commontype
end

--TODO: refactor to use this function
--luacov:disable
function types.are_types_convertible(largs, rargs)
  for i,atype,btype in iters.izip(largs, rargs) do
    if atype and btype then
      local ok, err = btype:is_convertible_from(atype)
      if not ok then
        return nil, stringer.pformat("at index %d: %s", i, err)
      end
    elseif not atype then
      if not btype.is_nilable then
        return nil, stringer.format("at index %d: parameter of type '%s' is missing", i, atype)
      end
    else
      assert(not btype and atype)
      return nil, stringer.format("at index %d: extra parameter of type '%s':", i, atype)
    end
  end
  return true
end
--luacov:enable

return types
