local class = require 'euluna.utils.class'
local tabler = require 'euluna.utils.tabler'
local iters = require 'euluna.utils.iterators'
local sstream = require 'euluna.utils.sstream'
local Symbol = require 'euluna.symbol'

--------------------------------------------------------------------------------
local Type = class(Symbol)

function Type:_init(name, node)
  Symbol._init(self, node)
  self.name = name
  self.unary_operators = {}
  self.binary_operators = {}
  self.conversible_types = {}
  self.integral = false
  self.real = false
end

function Type:__tostring()
  return self.name
end

function Type:codegen_name()
  local name = tostring(self)
  --TODO: replace non alphanumeric characters
  return name
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
  if self:is_any() then return self end
  return self.unary_operators[opname]
end

function Type:add_binary_operator_type(opname, type)
  self.binary_operators[opname] = type
end

function Type:get_binary_operator_type(opname)
  if self:is_any() then return self end
  return self.binary_operators[opname]
end

function Type:is_conversible(type)
  if self == type or self:is_any() or type:is_any() then
    return true
  end
  return self.conversible_types[type]
end

function Type:is_number()
  return self.integral or self.real
end

function Type:is_any()
  return self.name == 'any'
end

function Type:is_string()
  return self.name == 'string'
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

function Type:is_arraytable()
  return self.name == 'table' and
    self.subtypes and
    #self.subtypes == 1
end

function Type:is_equal(type)
  return rawequal(self, type)
end

function Type:__eq(type)
  return self:is_equal(type) and type:is_equal(self)
end

--------------------------------------------------------------------------------
local ComposedType = class(Type)

function ComposedType:_init(node, name, subtypes)
  self.subtypes = subtypes
  Type._init(self, name, node)
end

function ComposedType:is_equal(type)
  return type.name == self.name and
         class.is_a(type, ComposedType) and
         tabler.deepcompare(type.subtypes, self.subtypes)
end

function ComposedType:__tostring()
  return sstream(self.name, '<', self.subtypes, '>'):tostring()
end

--------------------------------------------------------------------------------
local FunctionType = class(Type)

function FunctionType:_init(node, argtypes, returntypes)
  self.argtypes = argtypes
  self.returntypes = returntypes
  Type._init(self, 'function', node)
end

function FunctionType:is_equal(type)
  return type.name == 'function' and
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

local types = {
  Type = Type,
  ComposedType = ComposedType,
  FunctionType = FunctionType
}
return types
