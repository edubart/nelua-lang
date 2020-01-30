local class = require 'nelua.utils.class'
local tabler = require 'nelua.utils.tabler'
local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local stringer = require 'nelua.utils.stringer'
local sstream = require 'nelua.utils.sstream'
local metamagic = require 'nelua.utils.metamagic'
local config = require 'nelua.configer'.get()
local bn = require 'nelua.utils.bn'
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

function Type:suggest_nick(nick, usehash)
  if self.nick then return end
  if usehash then
    self.codename = self.codename:gsub(string.format('^%s_', self.name), nick .. '_')
  else
    self.codename = nick
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
  elseif traits.is_string(opret) then
    type, value = primtypes[opret], nil
  else
    type, value = opret, nil
  end
  if not type and self:is_any() then
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
    return true
  elseif type:is_any() then
    -- anything can be converted to and from `any`
    return true
  elseif type:is_pointer_of(self) then
    -- automatic deref
    return true
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
    self:is_arithmetic() and type:is_arithmetic() and not explicit then
    if self:is_integral() then
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
        return true
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
  return type and (
    rawequal(type, self) or
    (type.name == self.name and getmetatable(type) == getmetatable(self)))
end

function Type:is_initializable_from_attr(attr)
  if attr and self == attr.type and attr.comptime then
    return true
  end
end

function Type:is_comptime() return self.comptime end
function Type:is_primitive() return self.primitive end
function Type:is_auto() return self.auto end
function Type:is_arithmetic() return self.arithmetic end
function Type:is_float32() return self.float32 end
function Type:is_float64() return self.float64 end
function Type:is_float() return self.float end
function Type:is_any() return self.any end
function Type:is_varanys() return self.varanys end
function Type:is_nil() return self.Nil end
function Type:is_nilable() return self.nilable end
function Type:is_nilptr() return self.nilptr end
function Type:is_type() return self.typetype end
function Type:is_string() return self.string end
function Type:is_cstring() return self.cstring end
function Type:is_record() return self.record end
function Type:is_function() return self.Function end
function Type:is_lazyfunction() return self.lazyfunction end
function Type:is_boolean() return self.boolean end
function Type:is_table() return self.table end
function Type:is_array() return self.array end
function Type:is_enum() return self.enum end
function Type:is_void() return self.void end
function Type:is_arraytable() return self.arraytable end
function Type:is_pointer() return self.pointer end
function Type:is_span() return self.span end
function Type:is_range() return self.range end
function Type:is_integral() return self.integral end
function Type:is_unsigned() return self.unsigned end
function Type:is_signed() return self.arithmetic and not self.unsigned end
function Type:is_generic_pointer() return self.genericpointer end
function Type.is_pointer_of() return false end

function Type:__tostring()
  return self.name
end

function Type:__eq(type)
  return self:is_equal(type) and type:is_equal(self)
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
  if ltype:is_comptime() or rtype:is_comptime() then
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
  if retype:is_boolean() and lval ~= nil and rval ~= nil then
    reval = not not (lval and rval)
  end
  return retype, reval
end

Type.binary_operators['or'] = function(ltype, rtype, lattr, rattr)
  local reval
  local retype = promote_type_for_attrs(lattr, rattr) or ltype:promote_type(rtype) or primtypes.any
  local lval, rval = lattr.value, rattr.value
  if retype:is_boolean() and lval ~= nil and rval ~= nil then
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
VoidType.comptime = true
VoidType.void = true
VoidType.primitive = true

function VoidType:_init(name)
  Type._init(self, name, 0)
end

--------------------------------------------------------------------------------
local AutoType = typeclass()
types.AutoType = AutoType
AutoType.auto = true
AutoType.nodecl = true
AutoType.comptime = true
AutoType.nilable = true
AutoType.primitive = true
AutoType.unpointable = true
AutoType.lazyable = true

function AutoType:_init(name)
  Type._init(self, name, 0)
end

function AutoType.is_convertible_from_type()
  return true
end

--------------------------------------------------------------------------------
local TypeType = typeclass()
types.TypeType = TypeType
TypeType.typetype = true
TypeType.comptime = true
TypeType.nodecl = true
TypeType.unpointable = true
TypeType.lazyable = true

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
NilableType.Nil = true
NilableType.nilable = true
NilableType.primitive = true
NilableType.unpointable = true

function NilableType:_init(name)
  Type._init(self, name, 0)
end

NilableType.unary_operators['not'] = function()
  return primtypes.boolean, true
end

--------------------------------------------------------------------------------
local NilptrType = typeclass()
types.NilptrType = NilptrType
NilptrType.nilptr = true
NilptrType.primitive = true
NilptrType.unpointable = true

function NilptrType:_init(name, size)
  Type._init(self, name, size)
end

function NilptrType:promote_type(type)
  if type:is_pointer() then
    return type
  end
  return Type.promote_type(self, type)
end

NilptrType.unary_operators['not'] = function()
  return primtypes.boolean, true
end

--------------------------------------------------------------------------------
local StringType = typeclass()
types.StringType = StringType
StringType.string = true
StringType.primitive = true

function StringType:_init(name, size)
  Type._init(self, name, size)
end

function StringType:is_convertible_from_type(type, explicit)
  if self:is_string() and type:is_cstring() and explicit then
    -- explicit cstring to string cast
    return true
  end
  return Type.is_convertible_from_type(self, type, explicit)
end

StringType.unary_operators.len = function(_, lattr)
  local lval = lattr.value
  local reval
  if lval then
    reval = bn.new(#lval)
  end
  return primtypes.integer, reval
end

local function make_string_cmp_opfunc(cmpfunc)
  return function(_, rtype, lattr, rattr)
    if rtype:is_string() then
      local reval
      local lval, rval = lattr.value, rattr.value
      if lval and rval then
        reval = cmpfunc(lval, rval)
      end
      return primtypes.boolean, reval
    end
  end
end

StringType.binary_operators.le = make_string_cmp_opfunc(function(a,b)
  return a<=b
end)
StringType.binary_operators.ge = make_string_cmp_opfunc(function(a,b)
  return a>=b
end)
StringType.binary_operators.lt = make_string_cmp_opfunc(function(a,b)
  return a<b
end)
StringType.binary_operators.gt = make_string_cmp_opfunc(function(a,b)
  return a>b
end)
StringType.binary_operators.concat = function(ltype, rtype, lattr, rattr)
  if rtype:is_string() then
    local reval
    local lval, rval = lattr.value, rattr.value
    if lval and rval then
      reval = lval .. rval
    end
    return ltype, reval
  end
end

--------------------------------------------------------------------------------
local BooleanType = typeclass()
types.BooleanType = BooleanType
BooleanType.boolean = true
BooleanType.primitive = true

function BooleanType:_init(name, size)
  Type._init(self, name, size)
end

function BooleanType.is_convertible_from_type()
  return true
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
AnyType.any = true
AnyType.nilable = true
AnyType.primitive = true

function AnyType:_init(name, size)
  Type._init(self, name, size)
end

function AnyType.is_convertible_from_type()
  return true
end

--------------------------------------------------------------------------------
local VaranysType = typeclass(AnyType)
types.VaranysType = VaranysType
VaranysType.varanys = true

function VaranysType:_init(name, size)
  Type._init(self, name, size)
end

--------------------------------------------------------------------------------
local ArithmeticType = typeclass()
types.ArithmeticType = ArithmeticType
ArithmeticType.arithmetic = true
ArithmeticType.primitive = true

function ArithmeticType:_init(name, size)
  Type._init(self, name, size)
  self.bitsize = size * 8
end

function ArithmeticType:is_convertible_from_type(type, explicit)
  return Type.is_convertible_from_type(self, type, explicit)
end

function ArithmeticType:is_initializable_from_attr(attr)
  if Type.is_initializable_from_attr(self, attr) then
    return true
  end
  if attr.type and attr.type:is_arithmetic() and attr.comptime and attr.untyped then
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
  if rtype:is_arithmetic() then
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
    if rtype:is_arithmetic() then
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
IntegralType.integral = true

local function get_integral_range(bits, unsigned)
  local min, max
  if unsigned then
    min =  bn.new(0)
    max =  bn.pow(2, bits) - 1
  else -- signed
    min = -bn.pow(2, bits) / 2
    max =  bn.pow(2, bits) / 2 - 1
  end
  return min, max
end

function IntegralType:_init(name, size, unsigned)
  ArithmeticType._init(self, name, size)
  self.min, self.max = get_integral_range(self.bitsize, unsigned)
  self.unsigned = unsigned
end

function IntegralType:is_convertible_from_type(type, explicit)
  if type:is_integral() and self:is_inrange(type.min) and self:is_inrange(type.max) then
    return true
  elseif explicit and type:is_arithmetic() then
    return true
  end
  return ArithmeticType.is_convertible_from_type(self, type, explicit)
end

function IntegralType:normalize_value(value)
  if not value:isintegral() then
    value = value:trunc()
  end
  if not self:is_inrange(value) then
    if self:is_signed() and value > self.max then
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
  if type == self or type:is_float() then
    return type
  elseif not type:is_integral() then
    return
  end
  if self:is_unsigned() == type:is_unsigned() then
    -- promote to bigger of the same signess
    return type.size >= self.size and type or self
  else
    -- promote to best signed type that fits both types
    local signedsize = self:is_signed() and self.bitsize or type.bitsize
    local unsignedsize = self:is_unsigned() and self.bitsize or type.bitsize
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
  if not rtype:is_arithmetic() then
    return
  end
  return promote_type_for_attrs(lattr, rattr) or ltype:promote_type(rtype)
end

local function integral_fractional_operation(_, rtype)
  if rtype:is_float() then
    return rtype
  else
    return primtypes.number
  end
end

local function integral_bitwise_operation(ltype, rtype, lattr, rattr)
  if not rtype:is_integral() then
    return
  end
  local retype = promote_type_for_attrs(lattr, rattr)
  if not retype then
    retype = rtype.size > ltype.size and rtype or ltype
  end
  return retype
end

local function integral_shift_operation(ltype, rtype)
  if not rtype:is_integral() then
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
FloatType.float = true

function FloatType:_init(name, size, maxdigits)
  ArithmeticType._init(self, name, size)
  self.maxdigits = maxdigits
  if self.bitsize == 32 then
    self.float32 = true
  elseif self.bitsize == 64 then
    self.float64 = true
  end
end

function FloatType:is_convertible_from_type(type, explicit)
  if type:is_arithmetic() then
    return true
  end
  return ArithmeticType.is_convertible_from_type(self, type, explicit)
end

function FloatType.is_inrange() return true end

function FloatType:promote_type_for_value()
  --assert(traits.is_bignumber(value))
  return self
end

function FloatType:promote_type(type)
  if type == self or type:is_integral() then
    return self
  elseif not type:is_float() then
    return
  end
  if type.size > self.size then
    return type
  end
  return self
end

local function float_arithmetic_operation(ltype, rtype)
  if not rtype:is_arithmetic() then
    return
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
TableType.table = true

function TableType:_init(name)
  Type._init(self, name, cpusize)
end

--------------------------------------------------------------------------------
local ArrayTableType = typeclass()
types.ArrayTableType = ArrayTableType
ArrayTableType.arraytable = true

function ArrayTableType:_init(node, subtype)
  Type._init(self, 'arraytable', cpusize*3, node)
  self.subtype = subtype
  self.codename = subtype.codename .. '_arrtab'
end

function ArrayTableType:is_equal(type)
  return type.name == self.name and
         getmetatable(type) == getmetatable(self) and
         type.subtype == self.subtype
end

function ArrayTableType:__tostring()
  return sstream(self.name, '(', self.subtype, ')'):tostring()
end

ArrayTableType.unary_operators.len = 'integer'

--------------------------------------------------------------------------------
local ArrayType = typeclass()
types.ArrayType = ArrayType
ArrayType.array = true

function ArrayType:_init(node, subtype, length)
  local size = subtype.size * length
  Type._init(self, 'array', size, node)
  self.subtype = subtype
  self.length = length
  self.codename = string.format('%s_arr%d', subtype.codename, length)
end

function ArrayType:is_equal(type)
  return type.name == self.name and
         getmetatable(type) == getmetatable(self) and
         self.subtype == type.subtype and
         self.length == type.length
end

function ArrayType:__tostring()
  return sstream(self.name, '(', self.subtype, ', ', self.length, ')'):tostring()
end

ArrayType.unary_operators.len = function(ltype)
  return primtypes.integer, bn.new(ltype.length)
end

--------------------------------------------------------------------------------
local EnumType = typeclass(IntegralType)
types.EnumType = EnumType
EnumType.enum = true

function EnumType:_init(node, subtype, fields)
  IntegralType._init(self, 'enum', subtype.size, subtype.unsigned)
  self.node = node
  self.subtype = subtype
  self.fields = fields
  self.codename = gencodename(self)
  for _,field in ipairs(fields) do
    field.codename = self.codename .. '_' .. field.name
  end
end

function EnumType:get_field(name)
  return tabler.ifindif(self.fields, function(f)
    return f.name == name
  end)
end

function EnumType:__tostring()
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
FunctionType.Function = true

function FunctionType:_init(node, argtypes, returntypes)
  Type._init(self, 'function', cpusize, node)
  self.argtypes = argtypes or {}
  self.returntypes = returntypes or {}
  self.codename = gencodename(self)
end

function FunctionType:is_equal(type)
  return type.name == self.name and
         getmetatable(type) == getmetatable(self) and
         tabler.deepcompare(type.argtypes, self.argtypes) and
         tabler.deepcompare(type.returntypes, self.returntypes)
end

function FunctionType:get_return_type(index)
  local returntypes = self.returntypes
  local lastindex = #returntypes
  local lastret = returntypes[lastindex]
  if lastret and lastret:is_varanys() and index > lastindex then
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
LazyFunctionType.Function = true
LazyFunctionType.lazyfunction = true

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
    elseif traits.is_attr(larg) and rtype:is_comptime() then
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
MetaType.metatype = true

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
RecordType.record = true

local function compute_record_size(fields, pack)
  local nfields = #fields
  if nfields == 0 then
    return 0
  end
  local size = 0
  local maxfsize = 0
  for i=1,#fields do
    local fsize = fields[i].type.size
    maxfsize = math.max(maxfsize, fsize)
    local pad = 0
    if not pack and size % fsize > 0 then
      pad = fsize - (size % fsize)
    end
    size = size + pad + fsize
  end
  local pad = 0
  if not pack and size % maxfsize > 0 then
    pad = maxfsize - (size % maxfsize)
  end
  size = size + pad
  return size
end

function RecordType:_init(node, fields)
  fields = fields or {}
  local size = compute_record_size(fields)
  Type._init(self, 'record', size, node)
  self.fields = fields
  self.codename = gencodename(self)
  self.metatype = MetaType()
end

function RecordType:add_field(name, type)
  table.insert(self.fields, {name = name, type = type})
  self.size = compute_record_size(self.fields)
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
  return self.metatype:set_field(name, symbol)
end

--------------------------------------------------------------------------------
local PointerType = typeclass()
types.PointerType = PointerType
PointerType.pointer = true

function PointerType:_init(node, subtype)
  Type._init(self, 'pointer', cpusize, node)
  self.subtype = subtype
  if subtype:is_void() then
    self.nodecl = true
    self.genericpointer = true
    self.primitive = true
  elseif subtype.name == 'cchar' then
    self.nodecl = true
    self.cstring = true
    self.primitive = true
    self.codename = 'nelua_cstring'
  else
    self.codename = subtype.codename .. '_ptr'
  end
  self.unary_operators['deref'] = subtype
end

function PointerType:is_convertible_from_attr(attr, explicit)
  local nodetype = attr.type
  if self.subtype == nodetype then
    -- automatic reference
    if not attr.lvalue then
      return false, stringer.pformat('cannot automatic reference rvalue to pointer type "%s"', self)
    end
    attr.autoref = true
    return true
  end
  return Type.is_convertible_from_attr(self, attr, explicit)
end

function PointerType:is_convertible_from_type(type, explicit)
  if type:is_pointer() then
    if explicit then
      return true
    elseif type:is_pointer_of(self.subtype) then
      return true
    elseif self:is_generic_pointer() then
      return true
    end
  end
  if self:is_cstring() and type:is_string() then
    return true
  elseif type:is_nilptr() then
    return true
  end
  return Type.is_convertible_from_type(self, type, explicit)
end

function PointerType:promote_type(type)
  if type:is_nilptr() then
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

function PointerType:__tostring()
  if not self.subtype:is_void() then
    local subtypenick = self.subtype.nick or self.subtype.name
    return sstream(self.name, '(', subtypenick, ')'):tostring()
  else
    return self.name
  end
end

--------------------------------------------------------------------------------
local SpanType = typeclass(RecordType)
types.SpanType = SpanType
SpanType.span = true

function SpanType:_init(node, subtype)
  local fields = {
    {name = 'data', type = PointerType(node, subtype)},
    {name = 'size', type = primtypes.usize}
  }
  RecordType._init(self, node, fields)
  self.name = 'span'
  self.fields = fields
  self.codename = subtype.codename .. '_span'
  self.metatype = MetaType()
  self.subtype = subtype
end

function SpanType:is_equal(type)
  return type.name == self.name and
         getmetatable(type) == getmetatable(self) and
         type.subtype == self.subtype
end

function SpanType:__tostring()
  return sstream(self.name, '(', self.subtype, ')'):tostring()
end

--------------------------------------------------------------------------------
local RangeType = typeclass(RecordType)
types.RangeType = RangeType
RangeType.range = true

function RangeType:_init(node, subtype)
  local fields = {
    {name = 'low', type = subtype},
    {name = 'high', type = subtype}
  }
  RecordType._init(self, node, fields)
  self.name = 'range'
  self.fields = fields
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
  return sstream(self.name, '(', self.subtype, ')'):tostring()
end

--------------------------------------------------------------------------------
function types.set_typedefs(t)
  typedefs = t
  primtypes = t.primtypes
end

function types.get_pointer_type(subtype)
  if subtype == primtypes.cchar then
    return primtypes.cstring
  elseif not subtype.unpointable then
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
      if not btype:is_nilable() then
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
