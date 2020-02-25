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
local cpusize = math.floor(config.cpu_bits / 8)

--------------------------------------------------------------------------------
local Type = class()
types.Type = Type

Type._type = true
Type.unary_operators = {}
Type.binary_operators = {}

function Type:_init(name, size, node)
  assert(name)
  self.name = name
  self.node = node
  self.size = size or 0
  self.unary_operators = {}
  self.binary_operators = {}
  self.codename = string.format('nelua_%s', self.name)
  local mt = getmetatable(self)
  metamagic.setmetaindex(self.unary_operators, mt.unary_operators)
  metamagic.setmetaindex(self.binary_operators, mt.binary_operators)
end

function Type:suggest_nick(nick, codename)
  if self.is_primitive or self.nick then return end
  if codename then
    self.codename = codename
  else
    self.codename = self.codename:gsub(string.format('^%s_', self.name), nick .. '_')
  end
  self.nick = nick
end

function Type:prettyname()
  if self.nick then
    return self.nick
  end
  return tostring(self)
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
    err = stringer.pformat("invalid operation for type '%s'", self:prettyname())
  end
  return type, value, err
end

function Type:binary_operator(opname, rtype, lattr, rattr)
  local type, value, err = get_operator_in_oplist(self, self.binary_operators, opname, rtype, lattr, rattr)
  if not type and not err then
    err = stringer.pformat("invalid operation between types '%s' and '%s'",
      self:prettyname(), rtype:prettyname())
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
      type:prettyname(), self:prettyname())
  end
end

-- Used to check conversion from `attr` type to `self` type
function Type:is_convertible_from_attr(attr, explicit)
  local type = attr.type

  -- check for comptime number conversions
  if attr.type and attr.comptime and attr.value and
    self.is_arithmetic and type.is_arithmetic and not explicit then
    if self.is_integral then
      if not attr.value:isintegral() then
        return false, stringer.pformat(
          "constant value `%s` is fractional which is invalid for the type '%s'",
          attr.value:todec(), type:prettyname())
      elseif not self:is_inrange(attr.value) then
        return false, stringer.pformat(
          "constant value `%s` for type `%s` is out of range, the minimum is `%s` and maximum is `%s`",
          attr.value:todec(), self, self.min:todec(), self.max:todec())
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
  else
    assert(traits.is_attr(what))
    return self:is_convertible_from_attr(what, explicit)
  end
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
  if self.nick then return self.nick end
  return self.name
end

function Type:__eq(type)
  return rawequal(self, type) or (traits.is_type(type) and self:is_equal(type))
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
    srcname = node.srcname or ''
  else
    uidcounter = uidcounter + 1
    uid = uidcounter
    srcname = '__nonode__'
  end
  return string.format('%s%s%d', name, srcname, uid)
end

local function gencodename(self)
  self.key = genkey(self.name, self.node)
  local hash = stringer.hash(self.key, 16)
  return string.format('%s_%s', self.name, hash)
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
local NilableType = typeclass()
types.NilableType = NilableType
NilableType.is_nil = true
NilableType.is_nilable = true
NilableType.is_primitive = true
NilableType.is_unpointable = true

function NilableType:_init(name)
  Type._init(self, name, 0)
end

NilableType.unary_operators['not'] = function()
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
  if attr.type and attr.type.is_arithmetic and attr.comptime and attr.untyped then
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
      reval = lval == rval
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
  if a == b then return true end
  if a.value and b.value then
    return a.value <= b.value
  end
end)

ArithmeticType.binary_operators.ge = make_arithmetic_cmp_opfunc(function(a,b)
  if a == b then return true end
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
    min =  bn.new(0)
    max =  bn.pow(2, bits) - 1
  else -- signed
    min = -bn.pow(2, bits) / 2
    max =  bn.pow(2, bits) / 2 - 1
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
  elseif type.is_integral and self:is_inrange(type.min) and self:is_inrange(type.max) then
    return self
  elseif explicit then
    if type.is_arithmetic then
      return self
    elseif type.is_pointer and self.size == cpusize then
      return self
    end
  end
  return ArithmeticType.is_convertible_from_type(self, type, explicit)
end

function IntegralType:normalize_value(value)
  if not value:isintegral() then
    value = value:trunc()
  end
  if not self:is_inrange(value) then
    if self.is_signed and value > self.max then
      value = -bn.bnorm(-value, self.bitsize)
    else
      value = bn.bnorm(value, self.bitsize)
    end
  end
  return value
end

function IntegralType:promote_type_for_value(value)
  if value:isintegral() then
    if self:is_inrange(value) then
      -- this type already fits
      return self
    end

    -- try to use signed version until fit the size
    for _,dtype in ipairs(typedefs.promote_signed_types) do
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
    return primtypes['int' .. signedsize]
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

local function integral_range_operation(ltype, rtype, lattr, rattr)
  local subtype = integral_arithmetic_operation(ltype, rtype, lattr, rattr)
  return types.RangeType(nil, subtype)
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
    reval = ltype:normalize_value(bn.bnot(lval,ltype.bitsize))
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

IntegralType.binary_operators.div = make_integral_binary_opfunc(function(ltype, rtype, lattr, rattr)
  local rval = rattr.value
  if rval and rval:iszero() then
    return nil, 'division by zero is not allowed'
  end
  return integral_fractional_operation(ltype, rtype, lattr, rattr)
end, function(a,b)
  return a / b
end)

IntegralType.binary_operators.idiv = make_integral_binary_opfunc(function(ltype, rtype, lattr, rattr)
  local rval = rattr.value
  if rval and rval:iszero() then
    return nil, 'division by zero is not allowed'
  end
  return integral_arithmetic_operation(ltype, rtype, lattr, rattr)
end, function(a,b)
  return (a / b):floor()
end)

IntegralType.binary_operators.mod = make_integral_binary_opfunc(function(ltype, rtype, lattr, rattr)
  local rval = rattr.value
  if rval and rval:iszero() then
    return nil, 'division by zero is not allowed'
  end
  return integral_arithmetic_operation(ltype, rtype, lattr, rattr)
end, function(a,b)
  local r = a % b
  if (a * b):isneg() then
    r = r + b
  end
  return r
end)

IntegralType.binary_operators.pow = make_integral_binary_opfunc(integral_fractional_operation, function(a,b)
  return a ^ b
end)

IntegralType.binary_operators.bor = make_integral_binary_opfunc(integral_bitwise_operation, function(a,b,t)
  return t:normalize_value(bn.bor(a,b,t.bitsize))
end)

IntegralType.binary_operators.bxor = make_integral_binary_opfunc(integral_bitwise_operation, function(a,b,t)
  return t:normalize_value(bn.bxor(a,b,t.bitsize))
end)

IntegralType.binary_operators.band = make_integral_binary_opfunc(integral_bitwise_operation, function(a,b,t)
  return t:normalize_value(bn.band(a,b,t.bitsize))
end)

IntegralType.binary_operators.shl = make_integral_binary_opfunc(integral_shift_operation, function(a,b,t)
  return t:normalize_value(bn.lshift(a,b,t.bitsize))
end)

IntegralType.binary_operators.shr = make_integral_binary_opfunc(integral_shift_operation, function(a,b,t)
  return t:normalize_value(bn.rshift(a,b,t.bitsize))
end)

IntegralType.binary_operators.range = integral_range_operation

--------------------------------------------------------------------------------
local FloatType = typeclass(ArithmeticType)
types.FloatType = FloatType
FloatType.is_float = true
FloatType.is_signed = true

function FloatType:_init(name, size, maxdigits)
  ArithmeticType._init(self, name, size)
  self.maxdigits = maxdigits
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
  --assert(traits.is_bignumber(value))
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
  return a / b
end)
FloatType.binary_operators.idiv = make_float_binary_opfunc(float_arithmetic_operation, function(a,b)
  return (a / b):floor()
end)
FloatType.binary_operators.mod = make_float_binary_opfunc(float_arithmetic_operation, function(a,b)
  local r = a % b
  if (a * b):isneg() then
    r = r + b
  end
  return r
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

function ArrayType:_init(node, subtype, length)
  local size = subtype.size * length
  Type._init(self, 'array', size, node)
  self.subtype = subtype
  self.length = length
  self.maxfieldsize = subtype.size
  self.codename = string.format('%s_arr%d', subtype.codename, length)
end

function ArrayType:is_equal(type)
  return type.name == self.name and
         getmetatable(type) == getmetatable(self) and
         self.subtype == type.subtype and
         self.length == type.length
end

function ArrayType:__tostring()
  if self.nick then return self.nick end
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

function EnumType:_init(node, subtype, fields)
  IntegralType._init(self, 'enum', subtype.size, subtype.is_unsigned)
  self.node = node
  self.subtype = subtype
  self.fields = fields
  self.codename = gencodename(self)
end

function EnumType:get_field(name)
  return tabler.ifindif(self.fields, function(f)
    return f.name == name
  end)
end

function EnumType:__tostring()
  if self.nick then return self.nick end
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

function FunctionType:_init(node, argattrs, returntypes)
  Type._init(self, 'function', cpusize, node)
  self.argattrs = argattrs or {}
  self.argtypes = tabler.imap(self.argattrs, function(arg) return arg.type end)
  self.returntypes = returntypes or {}
  self.codename = gencodename(self)
end

function FunctionType:is_equal(type)
  return type.name == self.name and
         getmetatable(type) == getmetatable(self) and
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
  local lastindex = #returntypes
  local lastret = returntypes[lastindex]
  if lastret and lastret.is_varanys and index > lastindex then
    return primtypes.any
  end
  local rettype = returntypes[index]
  if not rettype and index == 1 then
    return primtypes.void
  end
  return rettype
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

function FunctionType:__tostring()
  if self.nick then return self.nick end
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
LazyFunctionType.is_function = true
LazyFunctionType.is_lazyfunction = true

function LazyFunctionType:_init(node, args, returntypes)
  Type._init(self, 'lazyfunction', 0, node)
  self.args = args or {}
  self.argtypes = tabler.imap(self.args, function(arg) return arg.type end)
  self.returntypes = returntypes or {}
  self.evals = {}
  self.codename = gencodename(self)
end

local function lazy_args_matches(largs, rargs)
  for _,larg,rarg in iters.izip(largs, rargs) do
    local ltype = traits.is_attr(larg) and larg.type or larg
    local rtype = traits.is_attr(rarg) and rarg.type or rarg
    if ltype ~= rtype then
      return false
    elseif traits.is_attr(larg) and rtype.is_comptime then
      if not traits.is_attr(rarg) or larg.value ~= rarg.value then
        return false
      end
    end
  end
  return true
end

function LazyFunctionType:get_lazy_eval(args)
  for _,lazyeval in ipairs(self.evals) do
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
LazyFunctionType.__tostring = FunctionType.__tostring

--------------------------------------------------------------------------------
local MetaType = typeclass()
types.MetaType = MetaType
MetaType.is_metatype = true

function MetaType:_init(node, fields)
  self.fields = fields or {}
  Type._init(self, 'metatype', 0, node)
  self.codename = gencodename(self)
end

function MetaType:get_field(name)
  return self.fields[name]
end

function MetaType:set_field(name, symbol)
  self.fields[name] = symbol
end

function MetaType:__tostring()
  local ss = sstream('metatype{')
  local first = true
  for name,sym in iters.opairs(self.fields) do
    if not first then
      ss:add(', ')
    else
      first = false
    end
    ss:add(name, ': ', sym.type)
  end
  ss:add('}')
  return ss:tostring()
end

--------------------------------------------------------------------------------
local RecordType = typeclass()
types.RecordType = RecordType
RecordType.is_record = true

local function compute_record_size(fields, pack)
  local nfields = #fields
  local size = 0
  local maxfieldsize = 0
  if nfields == 0 then
    return size, maxfieldsize
  end
  for i=1,#fields do
    local ftype = fields[i].type
    local fsize = ftype.size
    local mfsize = ftype.maxfieldsize or fsize
    maxfieldsize = math.max(maxfieldsize, mfsize)
    local pad = 0
    if not pack and size % mfsize > 0 then
      pad = fsize - (size % mfsize)
    end
    size = size + pad + fsize
  end
  local pad = 0
  if not pack and size % maxfieldsize > 0 then
    pad = maxfieldsize - (size % maxfieldsize)
  end
  size = size + pad
  return size, maxfieldsize
end

function RecordType:_init(node, fields)
  fields = fields or {}
  local size, maxfieldsize = compute_record_size(fields)
  Type._init(self, 'record', size, node)
  self.fields = fields
  self.codename = gencodename(self)
  self.metatype = MetaType()
  self.maxfieldsize = maxfieldsize
end

function RecordType:add_field(name, type, pos)
  if not pos then
    pos = #self.fields + 1
  end
  table.insert(self.fields, pos, {name = name, type = type})
  self.size, self.maxfieldsize = compute_record_size(self.fields)
end

function RecordType:get_field(name)
  return tabler.ifindif(self.fields, function(f)
    return f.name == name
  end)
end

function RecordType:is_equal(type)
  return type.name == self.name and type.key == self.key
end

function RecordType:__tostring()
  if self.nick then return self.nick end
  local ss = sstream('record{')
  for i,field in ipairs(self.fields) do
    if i > 1 then ss:add(', ') end
    ss:add(field.name, ':', field.type)
  end
  ss:add('}')
  return ss:tostring()
end

function RecordType:get_metafield(name)
  return self.metatype:get_field(name)
end

function RecordType:set_metafield(name, symbol)
  if name == '__destroy' then
    self.is_destroyable = true
  elseif name == '__copy' then
    self.is_copyable = true
  end
  return self.metatype:set_field(name, symbol)
end

function RecordType:is_convertible_from_type(type, explicit)
  if not explicit and type:is_pointer_of(self) then
    -- automatic deref
    return self
  end
  return Type.is_convertible_from_type(self, type, explicit)
end

function RecordType:has_pointer()
  return tabler.ifindif(self.fields, function(f)
    return f.type:has_pointer()
  end) ~= nil
end

function RecordType:has_destroyable()
  if self.is_destroyable then return true end
  return tabler.ifindif(self.fields, function(f)
    return f.type:has_destroyable()
  end) ~= nil
end

function RecordType:has_copyable()
  if self.is_copyable then return true end
  return tabler.ifindif(self.fields, function(f)
    return f.type:has_copyable()
  end) ~= nil
end

--------------------------------------------------------------------------------
local PointerType = typeclass()
types.PointerType = PointerType
PointerType.is_pointer = true

function PointerType:_init(node, subtype)
  Type._init(self, 'pointer', cpusize, node)
  self.subtype = subtype
  if subtype.is_void then
    self.nodecl = true
    self.is_genericpointer = true
    self.is_primitive = true
  elseif subtype.name == 'cchar' then
    self.nodecl = true
    self.is_cstring = true
    self.is_primitive = true
    self.codename = 'nelua_cstring'
  else
    self.codename = subtype.codename .. '_ptr'
  end
  self.unary_operators['deref'] = subtype
end

function PointerType:is_convertible_from_attr(attr, explicit)
  local type = attr.type
  if not explicit and self.subtype == type and (type.is_record or type.is_array) then
    -- automatic ref
    if not attr.lvalue then
      return false, stringer.pformat(
        'cannot automatic reference rvalue of type "%s" to pointer type "%s"',
        attr.type:prettyname(), self)
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
    end
  end
  if type.is_stringview then
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
  return type.name == self.name and
         getmetatable(type) == getmetatable(self) and
         type.subtype == self.subtype
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

function PointerType:__tostring()
  if self.nick then return self.nick end
  if not self.subtype.is_void then
    local subtypenick = self.subtype.nick or self.subtype.name
    return sstream(self.name, '(', subtypenick, ')'):tostring()
  else
    return self.name
  end
end

function PointerType.has_pointer()
  return true
end

--------------------------------------------------------------------------------
local StringViewType = typeclass(RecordType)
types.StringViewType = StringViewType
StringViewType.is_stringview = true
StringViewType.is_primitive = true
StringViewType.maxfieldsize = cpusize

function StringViewType:_init(name, size)
  local fields = {
    {name = 'data', type = primtypes.cstring},
    {name = 'size', type = primtypes.usize}
  }
  RecordType._init(self, nil, fields)
  self.name = 'stringview'
  self.nick = 'stringview'
  self.codename = 'nelua_stringview'
  self.metatype = MetaType()
  Type._init(self, name, size)
end

function StringViewType:is_convertible_from_type(type, explicit)
  if explicit and self.is_stringview and type.is_cstring then
    -- explicit cstring to string cast
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
local RangeType = typeclass(RecordType)
types.RangeType = RangeType
RangeType.is_range = true

function RangeType:_init(node, subtype)
  local fields = {
    {name = 'low', type = subtype},
    {name = 'high', type = subtype}
  }
  RecordType._init(self, node, fields)
  self.name = 'range'
  self.codename = subtype.codename .. '_range'
  self.metatype = MetaType()
  self.subtype = subtype
end

function RangeType:is_equal(type)
  return type.name == self.name and
         getmetatable(type) == getmetatable(self) and
         type.subtype == self.subtype
end

function RangeType:__tostring()
  if self.nick then return self.nick end
  return sstream(self.name, '(', self.subtype, ')'):tostring()
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
  if not type and not err then
    err = stringer.pformat("could not match concept '%s'", self:prettyname())
  end
  if type == true then
    assert(attr.type)
    type = attr.type
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
  local ret
  local ok, err = except.trycall(function()
    ret = self.func(tabler.unpack(params))
  end)
  if err then
    return nil, err
  end
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
    return types.PointerType(nil, subtype)
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
