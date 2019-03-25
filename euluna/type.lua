local class = require 'euluna.utils.class'
local iters = require 'euluna.utils.iterators'
local Symbol = require 'euluna.symbol'

local Type = class(Symbol)

function Type:_init(name, ast)
  self:super(ast)
  self.name = name
  self.unary_operators = {}
  self.binary_operators = {}
  self.conversible_types = {}
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
  return self.unary_operators[opname]
end

function Type:add_binary_operator_type(opname, type)
  self.binary_operators[opname] = type
end

function Type:get_binary_operator_type(opname)
  return self.binary_operators[opname]
end

function Type:is_conversible(type)
  if self == type then
    return true
  end
  return self.conversible_types[type]
end

Type.type = Type('type')

return Type
