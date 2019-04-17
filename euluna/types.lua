local class = require 'euluna.utils.class'
local tabler = require 'euluna.utils.tabler'
local iters = require 'euluna.utils.iterators'
local stringer = require 'euluna.utils.stringer'
local sstream = require 'euluna.utils.sstream'
local metamagic = require 'euluna.utils.metamagic'

--------------------------------------------------------------------------------
local Type = class()

Type.unary_operators = {}
Type.binary_operators = {}

function Type:_init(name, node)
  assert(name)
  self.name = name
  self.node = node
  self.integral = false
  self.real = false
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

function Type:is_conversible(type)
  if self == type or self:is_any() or type:is_any() then
    return true
  end
  if type:is_enum() then
    return self:is_conversible(type.subtype)
  end
  return self.conversible_types[type]
end

function Type:is_number()
  return self.integral or self.real
end

function Type:is_float32()
  return self.name == 'float32'
end

function Type:is_real()
  return self.real
end

function Type:is_any()
  return self.name == 'any'
end

function Type:is_nil()
  return self.name == 'nil'
end

function Type:is_type()
  return self.name == 'type'
end

function Type:is_string()
  return self.name == 'string'
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

function Type:is_table()
  return self.name == 'table'
end

function Type:is_array()
  return self.name == 'array'
end

function Type:is_enum()
  return self.name == 'enum'
end

function Type:is_arraytable()
  return self.name == 'arraytable'
end

function Type:is_equal(type)
  return rawequal(self, type)
end

function Type:is_integral()
  return self.integral
end

function Type:__eq(type)
  return self:is_equal(type) and type:is_equal(self)
end

-- the type of 'Type'
Type.type = Type('type')

local function gencodename(self)
  local s = tostring(self)
  return string.format('%s_%s', self.name, stringer.hash(s .. self.key, 16))
end

--------------------------------------------------------------------------------
local ArrayTableType = class(Type)
ArrayTableType.unary_operators = {}
metamagic.setmetaindex(ArrayTableType.unary_operators, Type.unary_operators)

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
local ArrayType = class(Type)

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
local EnumType = class(Type)

function EnumType:_init(node, subtype, fields)
  self.subtype = subtype
  self.fields = fields
  Type._init(self, 'enum', node)
  self.codename = gencodename(self)
end

function EnumType:has_field(name)
  return tabler.ifindif(self.fields, function(f)
    return f.name == name
  end) ~= nil
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
local FunctionType = class(Type)

function FunctionType:_init(node, argtypes, returntypes)
  self.argtypes = argtypes
  self.returntypes = returntypes
  Type._init(self, 'function', node)
  self.codename = gencodename(self)
end

function FunctionType:is_equal(type)
  return
    type.name == 'function' and
    class.is_a(type, FunctionType) and
    tabler.deepcompare(type.argtypes, self.argtypes) and
    tabler.deepcompare(type.returntypes, self.returntypes)
end

function FunctionType:__tostring()
  local ss = sstream('function<(', self.argtypes, ')')
  if #self.returntypes > 0 then
    ss:add(': ', self.returntypes)
  end
  ss:add('>')
  return ss:tostring()
end

--------------------------------------------------------------------------------
local RecordType = class(Type)

function RecordType:_init(node, fields)
  self.fields = fields
  Type._init(self, 'record', node)
  self.codename = gencodename(self)
end

function RecordType:get_field_type(name)
  local field = tabler.ifindif(self.fields, function(f)
    return f.name == name
  end)
  return field and field.type or nil
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

local types = {
  Type = Type,
  ArrayTableType = ArrayTableType,
  ArrayType = ArrayType,
  EnumType = EnumType,
  FunctionType = FunctionType,
  RecordType = RecordType,
}
return types
