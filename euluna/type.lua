local class = require 'euluna.utils.class'
local iters = require 'euluna.utils.iterators'
local Symbol = require 'euluna.symbol'

local Type = class(Symbol)

function Type:_init(name, ast)
  Symbol._init(self, ast)
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

function Type:is_any() return self.name == 'any' end
function Type:is_string() return self.name == 'string' end
function Type:is_boolean() return self.name == 'boolean' end
function Type:is_function() return self.name == 'function' end

--[[
function Type:is_integral() return self.integral end
function Type:is_pointer() return self.name == 'pointer' end
]]

function Type:is_equal(type)
  return rawequal(self, type)
end

function Type:__eq(type)
  return self:is_equal(type) and type:is_equal(self)
end

Type.type = Type('type')

return Type
