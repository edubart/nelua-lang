local class = require 'nelua.utils.class'
local tabler = require 'nelua.utils.tabler'
local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local stringer = require 'nelua.utils.stringer'
local sstream = require 'nelua.utils.sstream'
local metamagic = require 'nelua.utils.metamagic'
local config = require 'nelua.configer'.get()

local cpusize = math.floor(config.cpu_bits / 8)

--------------------------------------------------------------------------------
local Type = class()

Type._type = true
Type.unary_operators = {}
Type.binary_operators = {}

function Type:_init(name, size, node)
  assert(name)
  self.name = name
  self.node = node
  self.size = size
  self.integral = false
  self.float = false
  self.unsigned = false
  self.unary_operators = {}
  self.binary_operators = {}
  self.conversible_types = {}
  self.aligned = nil
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

function Type:__tostring()
  return self.name
end

function Type:add_conversible_types(types)
  for _,type in ipairs(types) do
    self.conversible_types[type] = true
  end
end

function Type:add_unary_operator_type(opname, type)
  self.unary_operators[opname] = type
end

function Type:get_unary_operator_type(opname)
  local type = self.unary_operators[opname]
  if traits.is_function(type) then
    type = type(self)
  end
  if not type and self:is_any() then
    type = self
  end
  return type
end

function Type:add_binary_operator_type(opname, type)
  self.binary_operators[opname] = type
end

function Type:get_binary_operator_type(opname, otype)
  local type = self.binary_operators[opname]
  if traits.is_function(type) then
    type = type(self, otype)
  end
  if not type and self:is_any() then
    type = self
  end
  return type
end

function Type:is_coercible_from_type(type, explicit)
  if self == type or self:is_any() or type:is_any() or self:is_boolean() then
    return true
  elseif self:is_string() and type:is_cstring() and explicit then
    -- cstring to string cast
    return true
  elseif type:is_pointer() and type.subtype == self then
    -- automatic deref
    return true
  elseif type:is_enum() then
    return self:is_coercible_from_type(type.subtype, explicit)
  end
  return self.conversible_types[type]
end

function Type:is_coercible_from_node(node, explicit)
  local attr = node.attr
  local type = attr.type
  if self.integral and type.integral and attr.compconst and attr.value then
    return self:is_inrange(attr.value)
  end
  return self:is_coercible_from_type(type, explicit)
end

function Type:is_coercible_from(typeornode, explicit)
  if traits.is_astnode(typeornode) then
    return self:is_coercible_from_node(typeornode, explicit)
  else
    return self:is_coercible_from_type(typeornode, explicit)
  end
end

function Type:is_inrange(value)
  if self:is_float() then return true end
  if not self:is_integral() then return false end
  return value >= self.min and value <= self.max
end

function Type:is_numeric()
  return self.integral or self.float
end

function Type:is_float32()
  return self.name == 'float32'
end

function Type:is_float64()
  return self.name == 'float64'
end

function Type:is_float()
  return self.float
end

function Type:is_any()
  return self.name == 'any' or self.name == 'varanys'
end

function Type:is_varanys()
  return self.name == 'varanys'
end

function Type:is_nil()
  return self.name == 'nil'
end

function Type:is_nilable()
  return self:is_any() or self:is_nil()
end

function Type:is_nilptr()
  return self.name == 'nilptr'
end

function Type:is_type()
  return self.name == 'type'
end

function Type:is_string()
  return self.name == 'string'
end

function Type:is_cstring()
  return self.name == 'pointer' and self.subtype and self.subtype.name == 'cchar'
end

function Type.is_record()
  return false
end

function Type:is_boolean()
  return self.name == 'boolean'
end

function Type:is_function()
  return self.name == 'function'
end

function Type:is_multipletype()
  return self.name == 'multipletype'
end

function Type:is_table()
  return self.name == 'table'
end

function Type:is_array()
  return self.name == 'array'
end

function Type:is_enum()
  return self.name == 'enum'
end

function Type:is_void()
  return self.name == 'void'
end

function Type:is_arraytable()
  return self.name == 'arraytable'
end

function Type:is_pointer()
  return self.name == 'pointer'
end

function Type:is_span()
  return self.name == 'span'
end

function Type:is_range()
  return self.name == 'range'
end

function Type:is_generic_pointer()
  return self.name == 'pointer' and self.subtype:is_void()
end

function Type:is_equal(type)
  return rawequal(self, type)
end

function Type:is_integral()
  return self.integral
end

function Type:is_unsigned()
  return self.unsigned
end

function Type:is_primitive()
  return getmetatable(self) == Type or self:is_generic_pointer()
end

function Type:__eq(type)
  return self:is_equal(type) and type:is_equal(self)
end

-- types used internally
Type.type = Type('type', 0)
Type.void = Type('void', 0)
Type.usize = Type('usize', cpusize)
Type.isize = Type('isize', cpusize)
Type.any = Type('any')

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
  local type = class(base or Type)
  type.unary_operators = {}
  type.binary_operators = {}
  metamagic.setmetaindex(type.unary_operators, Type.unary_operators)
  metamagic.setmetaindex(type.binary_operators, Type.binary_operators)
  return type
end

--------------------------------------------------------------------------------
local ArrayTableType = typeclass()

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
  return sstream(self.name, '<', self.subtype, '>'):tostring()
end

--------------------------------------------------------------------------------
local ArrayType = typeclass()

function ArrayType:_init(node, subtype, length)
  self.subtype = subtype
  self.length = length
  local size = subtype.size * length
  Type._init(self, 'array', size, node)
  self.codename = string.format('%s_arr%d', subtype.codename, length)
end

function ArrayType:is_equal(type)
  return type.name == self.name and
         getmetatable(type) == getmetatable(self) and
         self.subtype == type.subtype and
         self.length == type.length
end

function ArrayType:__tostring()
  return sstream('array<', self.subtype, ', ', self.length, '>'):tostring()
end

--------------------------------------------------------------------------------
local EnumType = typeclass()

function EnumType:_init(node, subtype, fields)
  self.subtype = subtype
  self.fields = fields
  Type._init(self, 'enum', subtype.size, node)
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
  local ss = sstream('enum<', self.subtype, '>{')
  for i,field in ipairs(self.fields) do
    if i > 1 then ss:add(', ') end
    ss:add(field.name, '=', field.value)
  end
  ss:add('}')
  return ss:tostring()
end

--------------------------------------------------------------------------------
local FunctionType = typeclass()

function FunctionType:_init(node, argtypes, returntypes)
  self.argtypes = argtypes or {}
  self.returntypes = returntypes or {}
  Type._init(self, 'function', cpusize, node)
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
    return Type.any
  end
  local rettype = returntypes[index]
  if not rettype and index == 1 then
    return Type.void
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
          (argtype and not funcargtype:is_coercible_from(argtype)) or
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
  local ss = sstream('function<(', self.argtypes, ')')
  if self.returntypes and #self.returntypes > 0 then
    ss:add(': ', self.returntypes)
  end
  ss:add('>')
  return ss:tostring()
end

--------------------------------------------------------------------------------
local MultipleType = typeclass()

function MultipleType:_init(node, types)
  self.types = types
  Type._init(self, 'multipletype', 0, node)
end

function MultipleType:is_coercible_from_type(type, explicit)
  for _,possibletype in ipairs(self.types) do
    if possibletype:is_coercible_from_type(type, explicit) then
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
    if not first then ss:add(', ') first = false end
    ss:add(name, ': ', sym.attr.type)
  end
  ss:add('}')
  return ss:tostring()
end

--------------------------------------------------------------------------------
local RecordType = typeclass()

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
  self.fields = fields
  Type._init(self, 'record', size, node)
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

function RecordType.is_record()
  return true
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

function PointerType:_init(node, subtype)
  self.subtype = subtype
  Type._init(self, 'pointer', cpusize, node)
  if not subtype:is_void() then
    self.codename = subtype.codename .. '_ptr'
  end
  self.unary_operators['deref'] = subtype
end

function PointerType:is_coercible_from_node(node, explicit)
  local nodetype = node.attr.type
  if self.subtype == nodetype then
    -- automatic reference
    node:assertraisef(node.attr.lvalue,
      'cannot automatic reference rvalue to pointer type "%s"', self)
    node.attr.autoref = true
    return true
  end
  return Type.is_coercible_from_node(self, node, explicit)
end

function PointerType:is_coercible_from_type(type, explicit)
  if explicit and type:is_pointer() then
    return true
  end
  if type:is_nilptr() then
    return true
  end
  if Type.is_coercible_from_type(self, type, explicit) then
    return true
  end
  return type:is_pointer() and (type.subtype == self.subtype or self.subtype:is_void())
end

function PointerType:is_equal(type)
  return type.name == self.name and
         getmetatable(type) == getmetatable(self) and
         type.subtype == self.subtype
end

function PointerType:__tostring()
  if not self.subtype:is_void() then
    return sstream(self.name, '<', self.subtype, '>'):tostring()
  else
    return self.name
  end
end

--------------------------------------------------------------------------------
local SpanType = typeclass(RecordType)

function SpanType:_init(node, subtype)
  local fields = {
    {name = 'data', type = PointerType(node, subtype)},
    {name = 'size', type = Type.usize}
  }
  local size = compute_record_size(fields)
  Type._init(self, 'span', size, node)
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
  return sstream(self.name, '<', self.subtype, '>'):tostring()
end

--------------------------------------------------------------------------------
local RangeType = typeclass(RecordType)

function RangeType:_init(node, subtype)
  local fields = {
    {name = 'low', type = subtype},
    {name = 'high', type = subtype}
  }
  local size = compute_record_size(fields)
  Type._init(self, 'range', size, node)
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
  return sstream(self.name, '<', self.subtype, '>'):tostring()
end

local types = {
  Type = Type,
  ArrayTableType = ArrayTableType,
  ArrayType = ArrayType,
  EnumType = EnumType,
  FunctionType = FunctionType,
  MultipleType = MultipleType,
  RecordType = RecordType,
  PointerType = PointerType,
  SpanType = SpanType,
  RangeType = RangeType,
}

return types
