local class = require 'euluna.utils.class'
local tabler = require 'euluna.utils.tabler'
local iters = require 'euluna.utils.iterators'
local traits = require 'euluna.utils.traits'
local stringer = require 'euluna.utils.stringer'
local sstream = require 'euluna.utils.sstream'
local metamagic = require 'euluna.utils.metamagic'

--------------------------------------------------------------------------------
local Type = class()

Type._type = true
Type.unary_operators = {}
Type.binary_operators = {}

function Type:_init(name, node)
  assert(name)
  self.name = name
  self.node = node
  self.integral = false
  self.float = false
  self.unsigned = false
  self.unary_operators = {}
  self.binary_operators = {}
  self.conversible_types = {}
  self.codename = string.format('euluna_%s', self.name)
  local mt = getmetatable(self)
  metamagic.setmetaindex(self.unary_operators, mt.unary_operators)
  metamagic.setmetaindex(self.binary_operators, mt.binary_operators)

  if node then
    self.key = tostring(self.node.srcname) .. tostring(self.node.pos)
  else
    self.key = name
  end
end

function Type:suggest_nick(nick)
  if self.nick then return end
  self.codename = self.codename:gsub(string.format('^%s_', self.name), nick .. '_')
  self.nick = nick
end

function Type:__tostring()
  return self.name
end

function Type:add_conversible_types(types)
  for type in iters.ivalues(types) do
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

function Type:get_binary_operator_type(opname)
  local type = self.binary_operators[opname]
  if not type and self:is_any() then
    type = self
  end
  return type
end

function Type:is_coercible_from_type(type, explicit)
  if self == type or self:is_any() or type:is_any() then
    return true
  end
  if type:is_enum() then
    return self:is_coercible_from_type(type.subtype, explicit)
  end
  return self.conversible_types[type]
end

function Type:is_coercible_from_node(node, explicit)
  local type = node.attr.type
  if self.integral and type.integral and node.attr.const and node.attr.value then
    return self:is_inrange(node.attr.value)
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
  return value >= self.range.min and value <= self.range.max
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
  return self.name == 'cstring'
end

function Type:is_record()
  return self.name == 'record'
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
Type.type = Type('type')
Type.void = Type('void')
Type.any = Type('any')

local function gencodename(self)
  local s = tostring(self)
  return string.format('%s_%s', self.name, stringer.hash(s .. self.key, 16))
end

local function typeclass()
  local type = class(Type)
  type.unary_operators = {}
  type.binary_operators = {}
  metamagic.setmetaindex(type.unary_operators, Type.unary_operators)
  metamagic.setmetaindex(type.binary_operators, Type.binary_operators)
  return type
end

--------------------------------------------------------------------------------
local ArrayTableType = typeclass()

function ArrayTableType:_init(node, subtype)
  Type._init(self, 'arraytable', node)
  self.subtype = subtype
  self.codename = subtype.codename .. '_arrtab'
end

function ArrayTableType:is_equal(type)
  return type.name == self.name and
         class.is_a(type, getmetatable(self)) and
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
  Type._init(self, 'array', node)
  self.codename = gencodename(self)
end

function ArrayType:is_equal(type)
  return type.name == self.name and
         class.is_a(type, getmetatable(self)) and
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
  Type._init(self, 'enum', node)
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
  self.argtypes = argtypes
  self.returntypes = returntypes
  Type._init(self, 'function', node)
  self.codename = gencodename(self)
  self.lazy = tabler.ifindif(argtypes, function(argtype)
    return argtype:is_multipletype()
  end) ~= nil
end

function FunctionType:is_equal(type)
  return
    type.name == 'function' and
    class.is_a(type, FunctionType) and
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
  Type._init(self, 'multipletype', node)
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
local RecordType = typeclass()

function RecordType:_init(node, fields)
  self.fields = fields
  Type._init(self, 'record', node)
  self.codename = gencodename(self)
end

function RecordType:get_field(name)
  return tabler.ifindif(self.fields, function(f)
    return f.name == name
  end)
end

function RecordType:is_equal(type)
  return type.name == self.name and
         type.key == self.key
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

--------------------------------------------------------------------------------
local PointerType = typeclass()

function PointerType:_init(node, subtype)
  self.subtype = subtype
  Type._init(self, 'pointer', node)
  if not subtype:is_void() then
    self.codename = subtype.codename .. '_pointer'
  end
  self.unary_operators['deref'] = subtype
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
  return type:is_pointer() and type.subtype == self.subtype or self.subtype:is_void()
end

function PointerType:is_equal(type)
  return type.name == self.name and
         class.is_a(type, getmetatable(self)) and
         type.subtype == self.subtype
end

function PointerType:__tostring()
  if not self.subtype:is_void() then
    return sstream(self.name, '<', self.subtype, '>'):tostring()
  else
    return self.name
  end
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
}
return types
