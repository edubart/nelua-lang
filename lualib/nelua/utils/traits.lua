--[[
Traits module

The traits module is used over the code to check if a value is a specific class or Lua type.

This can be used instead of using the `type()` Lua function in the compiler sources,
because the `type` keyword is overused in the compiler and can sometimes lead to confusion.
]]

local traits = {}

local type = _G.type
local math_type = math.type

-- Checks if a value is a Lua string.
function traits.is_string(v)
  return type(v) == 'string'
end

-- Checks if a value is a Lua number.
function traits.is_number(v)
  return type(v) == 'number'
end

-- Checks if a value is a Lua table.
function traits.is_table(v)
  return type(v) == 'table'
end

-- Checks if a value is a Lua function.
function traits.is_function(v)
  return type(v) == 'function'
end

-- Checks if a value is a Lua boolean.
function traits.is_boolean(v)
  return type(v) == 'boolean'
end

-- Checsk if a value is a compiler AST node.
function traits.is_astnode(v)
  return type(v) == 'table' and v._astnode
end

-- Checks if a value is a compiler Attr.
function traits.is_attr(v)
  return type(v) == 'table' and v._attr
end

-- Checks if a value is a compiler Symbol.
function traits.is_symbol(v)
  return type(v) == 'table' and v._symbol
end

-- Checks if a value is a compiler Scope.
function traits.is_scope(v)
  return type(v) == 'table' and v._scope
end

-- Checks if a value is a compiler Type.
function traits.is_type(v)
  return type(v) == 'table' and v._type
end

-- Checks if a value is a scalar for the compiler, i.e., a Lua number or a big number.
function traits.is_scalar(v)
  local ty = type(v)
  return ty == 'number' or (ty == 'table' and v._bn)
end

-- Checks if a value is a big number.
function traits.is_bn(v)
  return type(v) == 'table' and v._bn
end

-- Checks if a value is an integral (whole number) for the compiler.
function traits.is_integral(v)
  return math_type(v) == 'integer' or (type(v) == 'table' and v._bn)
end

return traits
