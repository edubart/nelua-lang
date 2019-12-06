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
  self.size = size
  self.unary_operators = {}
  self.binary_operators = {}
  self.codename = string.format('nelua_%s', self.name)
  local mt = getmetatable(self)
  metamagic.setmetaindex(self.unary_operators, mt.unary_operators)
  metamagic.setmetaindex(self.binary_operators, mt.binary_operators)
end

function Type:suggest_nick(nick, prefix)
  if self.nick then return end
  if not prefix then
    self.codename = self.codename:gsub(string.format('^%s_', self.name), nick .. '_')
  else
    self.codename = string.format('%s_%s', prefix, nick)
  end
  self.nick = nick
end

local function get_operator_in_oplist(self, oplist, opname, arg1)
  local opret = oplist[opname]
  local type
  if traits.is_function(opret) then
    type = opret(self, arg1)
  elseif opret == true then
    type = self
  elseif traits.is_string(opret) then
    type = primtypes[opret]
  else
    type = opret
  end
  if not type and self:is_any() then
    type = self
  end
  return type
end

function Type:get_unary_operator_type(opname)
  return get_operator_in_oplist(self, self.unary_operators, opname)
end

function Type:get_binary_operator_type(opname, rtype)
  return get_operator_in_oplist(self, self.binary_operators, opname, rtype)
end

-- Used to check conversion from `type` to `self`
function Type:is_conversible_from_type(type)
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
      type, self)
  end
end

-- Used to check conversion from `node` type to `self` type
function Type:is_conversible_from_node(node, explicit)
  local attr = node.attr
  local type = attr.type

  -- check for compconst number conversions
  if attr.compconst and attr.value and self:is_arithmetic() and type:is_arithmetic() then
    if self:is_integral() then
      if not attr.value:isintegral() then
        return false, stringer.pformat(
          "constant value `%s` is fractional (invalid for the type)",
          attr.value:todec())
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

  return self:is_conversible_from_type(type, explicit)
end

function Type:is_conversible_from(typeornode, explicit)
  if traits.is_astnode(typeornode) then
    return self:is_conversible_from_node(typeornode, explicit)
  else
    return self:is_conversible_from_type(typeornode, explicit)
  end
end

function Type:promote_type(type)
  if self == type then
    return self
  end
end

function Type:clone(node)
  local clone = {}
  for k,v in pairs(self) do
    clone[k] = v
  end
  clone.node = node
  setmetatable(clone, getmetatable(self))
  return clone
end

function Type:clone_compconst(value, node)
  local clone = self:clone(node)
  clone.compconst = true
  clone.value = value
  return clone
end

function Type:is_equal(type)
  if type then
    if rawequal(type, self) then
      return true
    end
    return type.name == self.name and getmetatable(type) == getmetatable(self)
  end
end

function Type:is_primitive() return self.primitive end
function Type:is_compconst() return self.compconst end
function Type:is_arithmetic() return self.arithmetic end
function Type:is_float32() return self.float32 end
function Type:is_float64() return self.float64 end
function Type:is_float() return self.float end
function Type:is_multipletype() return self.multipletype end
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

Type.unary_operators['not'] = 'boolean'
Type.unary_operators.ref = function(self)
  if self.size and self.size > 0 then
    return types.get_pointer_type(self)
  end
end

Type.binary_operators.eq = 'boolean'
Type.binary_operators.ne = 'boolean'

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

function VoidType:_init(name)
  Type._init(self, name, 0)
  self.void = true
  self.primitive = true
end

--------------------------------------------------------------------------------
local TypeType = typeclass()
types.TypeType = TypeType

function TypeType:_init(name)
  Type._init(self, name, 0)
  self.typetype = true
end

TypeType.unary_operators.len = 'integer'

--------------------------------------------------------------------------------
local NilType = typeclass()
types.NilType = NilType

function NilType:_init(name)
  Type._init(self, name, 0)
  self.Nil = true
  self.nilable = true
  self.primitive = true
  self.compconst = true
end

--------------------------------------------------------------------------------
local NilptrType = typeclass()
types.NilptrType = NilptrType

function NilptrType:_init(name, size)
  Type._init(self, name, size)
  self.nilptr = true
  self.primitive = true
  self.compconst = true
end

--------------------------------------------------------------------------------
local StringType = typeclass()
types.StringType = StringType

function StringType:_init(name, size)
  Type._init(self, name, size)
  self.string = true
  self.primitive = true
end

function StringType:is_conversible_from_type(type, explicit)
  if self:is_string() and type:is_cstring() and explicit then
    -- explicit cstring to string cast
    return true
  end
  return Type.is_conversible_from_type(self, type, explicit)
end

StringType.unary_operators.len = 'integer'
StringType.binary_operators.le = 'boolean'
StringType.binary_operators.ge = 'boolean'
StringType.binary_operators.lt = 'boolean'
StringType.binary_operators.gt = 'boolean'
StringType.binary_operators.concat = 'string'

--------------------------------------------------------------------------------
local BooleanType = typeclass()
types.BooleanType = BooleanType

function BooleanType:_init(name, size)
  Type._init(self, name, size)
  self.boolean = true
  self.primitive = true
end

function BooleanType.is_conversible_from_type()
  return true
end

--------------------------------------------------------------------------------
local AnyType = typeclass()
types.AnyType = AnyType

function AnyType:_init(name, size)
  Type._init(self, name, size)
  self.any = true
  self.nilable = true
  self.primitive = true
  if name == 'varanys' then
    self.varanys = true
  end
end

function AnyType.is_conversible_from_type()
  return true
end

--------------------------------------------------------------------------------
local ArithmeticType = typeclass()
types.ArithmeticType = ArithmeticType

function ArithmeticType:_init(name, size)
  Type._init(self, name, size)
  self.bitsize = size * 8
  self.arithmetic = true
  self.primitive = true
end

function ArithmeticType:is_conversible_from_type(type, explicit)
  if type:is_enum() then
    return self:is_conversible_from_type(type.subtype, explicit)
  end
  return Type.is_conversible_from_type(self, type, explicit)
end

ArithmeticType.unary_operators.unm = true
ArithmeticType.binary_operators.le = 'boolean'
ArithmeticType.binary_operators.ge = 'boolean'
ArithmeticType.binary_operators.lt = 'boolean'
ArithmeticType.binary_operators.gt = 'boolean'

--------------------------------------------------------------------------------
local IntegralType = typeclass(ArithmeticType)
types.IntegralType = IntegralType

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
  self.integral = true
end

function IntegralType:is_conversible_from_type(type, explicit)
  if type:is_integral() and self:is_inrange(type.min) and self:is_inrange(type.max) then
    return true
  end
  return ArithmeticType.is_conversible_from_type(self, type, explicit)
end

function IntegralType:promote_value(value)
  assert(traits.is_bignumber(value))
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

    -- hope to fit in uint64 type
    if primtypes.uint64:is_inrange(value) then
      return primtypes.uint64
    end
  end

  -- can only be int64 now
  return primtypes.int64
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
  assert(traits.is_bignumber(value))
  return value >= self.min and value <= self.max
end

local function integral_arithmetic_operation(self, rtype)
  if not rtype or not rtype:is_arithmetic() then
    return
  end
  if rtype:is_integral() then
    return self:promote_type(rtype)
  elseif rtype:is_float() then
    -- promote to float
    return rtype
  end
  return self
end

local function integral_div_operation(self, rtype)
  if not rtype then
    return
  end
  if rtype:is_float() then
    return rtype
  elseif math.max(self.size, rtype.size) <= primtypes.float32.size then
    return primtypes.float32
  else
    return primtypes.number
  end
end

local function integral_bitwise_operation(self, rtype)
  if not rtype or not rtype:is_integral() then
    return
  end
  -- return the biggest
  return rtype.size > self.size and rtype or self
end

local function integral_shift_operation(self, rtype)
  if not rtype or not rtype:is_integral() then
    return
  end
  return self
end

local function integral_range_operation(self, rtype)
  local subtype = integral_arithmetic_operation(self, rtype)
  return types.RangeType(nil, subtype)
end

IntegralType.unary_operators.bnot = true
IntegralType.binary_operators.add = integral_arithmetic_operation
IntegralType.binary_operators.sub = integral_arithmetic_operation
IntegralType.binary_operators.mul = integral_arithmetic_operation
IntegralType.binary_operators.div = integral_div_operation
IntegralType.binary_operators.idiv = integral_arithmetic_operation
IntegralType.binary_operators.mod = integral_arithmetic_operation
IntegralType.binary_operators.pow = integral_div_operation
IntegralType.binary_operators.bor = integral_bitwise_operation
IntegralType.binary_operators.bxor = integral_bitwise_operation
IntegralType.binary_operators.band = integral_bitwise_operation
IntegralType.binary_operators.shl = integral_shift_operation
IntegralType.binary_operators.shr = integral_shift_operation
IntegralType.binary_operators.range = integral_range_operation

--------------------------------------------------------------------------------
local FloatType = typeclass(ArithmeticType)
types.FloatType = FloatType

function FloatType:_init(name, size, maxdigits)
  ArithmeticType._init(self, name, size)
  self.maxdigits = maxdigits
  self.float = true
  if self.bitsize == 32 then
    self.float32 = true
  elseif self.bitsize == 64 then
    self.float64 = true
  end
end

function FloatType:is_conversible_from_type(type, explicit)
  if type:is_arithmetic() then
    return true
  end
  return ArithmeticType.is_conversible_from_type(self, type, explicit)
end

function FloatType.is_inrange(value)
  assert(traits.is_bignumber(value))
  return true
end

function FloatType:promote_value()
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

local function float_arithmetic_operation(self, rtype)
  if not rtype or not rtype:is_arithmetic() then
    return
  end
  return self:promote_type(rtype)
end

FloatType.binary_operators.add = float_arithmetic_operation
FloatType.binary_operators.sub = float_arithmetic_operation
FloatType.binary_operators.mul = float_arithmetic_operation
FloatType.binary_operators.div = float_arithmetic_operation
FloatType.binary_operators.idiv = float_arithmetic_operation
FloatType.binary_operators.mod = float_arithmetic_operation
FloatType.binary_operators.pow = float_arithmetic_operation

--------------------------------------------------------------------------------
local TableType = typeclass()
types.TableType = TableType

function TableType:_init(name)
  Type._init(self, name, 0)
  self.table = true
end

--------------------------------------------------------------------------------
local ArrayTableType = typeclass()
types.ArrayTableType = ArrayTableType

function ArrayTableType:_init(node, subtype)
  Type._init(self, 'arraytable', cpusize*3, node)
  self.subtype = subtype
  self.codename = subtype.codename .. '_arrtab'
  self.arraytable = true
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

function ArrayType:_init(node, subtype, length)
  local size = subtype.size * length
  Type._init(self, 'array', size, node)
  self.subtype = subtype
  self.length = length
  self.array = true
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

ArrayType.unary_operators.len = 'integer'

--------------------------------------------------------------------------------
local EnumType = typeclass()
types.EnumType = EnumType

function EnumType:_init(node, subtype, fields)
  Type._init(self, 'enum', subtype.size, node)
  self.enum = true
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

function FunctionType:_init(node, argtypes, returntypes)
  Type._init(self, 'function', cpusize, node)
  self.Function = true
  self.argtypes = argtypes or {}
  self.returntypes = returntypes or {}
  self.codename = gencodename(self)
  self.lazy = tabler.ifindif(argtypes, function(argtype)
    return argtype:is_multipletype()
  end) ~= nil
end

function FunctionType:is_equal(type)
  return
    type.name == 'function' and
    getmetatable(type) == getmetatable(self) and
    tabler.deepcompare(type.argtypes, self.argtypes) and
    tabler.deepcompare(type.returntypes, self.returntypes)
end

function FunctionType:get_return_type(index)
  if not self.returntypes then return nil end
  local returntypes = self.returntypes
  local lastindex = #returntypes
  local lastret = returntypes[#returntypes]
  if lastret and lastret:is_varanys() and index > lastindex then
    return primtypes.any
  end
  local rettype = returntypes[index]
  if not rettype and index == 1 then
    return primtypes.void
  end
  return rettype
end

function FunctionType:get_functype_for_argtypes(argtypes)
  local lazytypes = self.node.lazytypes
  if not lazytypes then return nil end
  for _,functype in pairs(lazytypes) do
    if functype then
      local ok = true
      for _,funcargtype,argtype in iters.izip(functype.argtypes, argtypes) do
        if not funcargtype or
          (argtype and not funcargtype:is_conversible_from(argtype)) or
          (not argtype and not funcargtype:is_nilable()) then
          ok = false
          break
        end
      end
      if ok then
        return functype
      end
    end
  end
end

function FunctionType:get_return_type_for_argtypes(argtypes, index)
  if self.lazy then
    local functype = self:get_functype_for_argtypes(argtypes)
    if functype then
      return functype:get_return_type(index)
    elseif functype ~= false then
      if not self.node.lazytypes then
        self.node.lazytypes = {}
      end
      self.node.lazytypes[argtypes] = false
    end
  end
  return self:get_return_type(index)
end

function FunctionType:has_multiple_returns()
  return #self.returntypes > 1
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
local MultipleType = typeclass()
types.MultipleType = MultipleType

function MultipleType:_init(node, typelist)
  Type._init(self, 'multipletype', 0, node)
  self.types = typelist
  self.multipletype = true
end

function MultipleType:is_conversible_from_type(type, explicit)
  for _,possibletype in ipairs(self.types) do
    if possibletype:is_conversible_from_type(type, explicit) then
      return true
    end
  end
  return false
end

function MultipleType:__tostring()
  local ss = sstream()
  ss:addlist(self.types, ' | ')
  return ss:tostring()
end

--------------------------------------------------------------------------------
local MetaType = typeclass()
types.MetaType = MetaType

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
    ss:add(name, ': ', sym.attr.type)
  end
  ss:add('}')
  return ss:tostring()
end

--------------------------------------------------------------------------------
local RecordType = typeclass()
types.RecordType = RecordType

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
  local size = compute_record_size(fields)
  Type._init(self, 'record', size, node)
  self.fields = fields
  self.record = true
  self.codename = gencodename(self)
  self.metatype = MetaType()
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

RecordType.unary_operators.len = 'integer'

--------------------------------------------------------------------------------
local PointerType = typeclass()
types.PointerType = PointerType

function PointerType:_init(node, subtype)
  Type._init(self, 'pointer', cpusize, node)
  self.subtype = subtype
  self.pointer = true
  if subtype:is_void() then
    self.genericpointer = true
    self.nodecl = true
    self.primitive = true
  elseif subtype.name == 'cchar' then
    self.cstring = true
    self.primitive = true
    self.nodecl = true
    self.codename = 'nelua_cstring'
  else
    self.codename = subtype.codename .. '_ptr'
  end
  self.unary_operators['deref'] = subtype
end

function PointerType:is_conversible_from_node(node, explicit)
  local nodetype = node.attr.type
  if self.subtype == nodetype then
    -- automatic reference
    node:assertraisef(node.attr.lvalue,
      'cannot automatic reference rvalue to pointer type "%s"', self)
    node.attr.autoref = true
    return true
  end
  return Type.is_conversible_from_node(self, node, explicit)
end

function PointerType:is_conversible_from_type(type, explicit)
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
  return Type.is_conversible_from_type(self, type, explicit)
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
    return sstream(self.name, '(', self.subtype, ')'):tostring()
  else
    return self.name
  end
end

--------------------------------------------------------------------------------
local SpanType = typeclass(RecordType)
types.SpanType = SpanType

function SpanType:_init(node, subtype)
  local fields = {
    {name = 'data', type = PointerType(node, subtype)},
    {name = 'size', type = primtypes.usize}
  }
  RecordType._init(self, node, fields)
  self.name = 'span'
  self.span = true
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

function RangeType:_init(node, subtype)
  local fields = {
    {name = 'low', type = subtype},
    {name = 'high', type = subtype}
  }
  RecordType._init(self, node, fields)
  self.name = 'range'
  self.range = true
  self.record = true
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

function types.get_pointer_type(subtype, node)
  if subtype == primtypes.cchar then
    return primtypes.cstring
  elseif subtype:is_void() then
    return primtypes.pointer
  else
    return types.PointerType(node, subtype)
  end
end

function types.find_common_type(possibletypes)
  local commontype = possibletypes[1]
  for i=2,#possibletypes do
    commontype = commontype:promote_type(possibletypes[i])
    if not commontype then
      break
    end
  end
  return commontype
end

return types
