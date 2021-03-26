-- Traits module
--
-- The traits module is used over the code to check if a lua value is a specific class or lua type.
--
-- This module should be used instead of using the 'type()' lua function in the compiler sources,
-- because the 'type' keyword is overused in the compiler and can lead to confusion,
-- (except when needing performance).

local traits = {}

local type = _G.type
local math_type = math.type

-- Check if a value is a lua string.
function traits.is_string(v)
  return type(v) == 'string'
end

-- Check if a value is a lua number.
function traits.is_number(v)
  return type(v) == 'number'
end

-- Check if a value is a lua table.
function traits.is_table(v)
  return type(v) == 'table'
end

-- Check if a value is a lua function.
function traits.is_function(v)
  return type(v) == 'function'
end

-- Check if a value is a lua boolean.
function traits.is_boolean(v)
  return type(v) == 'boolean'
end

-- Check if a value is a compiler AST node.
function traits.is_astnode(v)
  return type(v) == 'table' and v._astnode
end

-- Check if a value is a compiler Attr.
function traits.is_attr(v)
  return type(v) == 'table' and v._attr
end

-- Check if a value is a compiler Symbol.
function traits.is_symbol(v)
  return type(v) == 'table' and v._symbol
end

-- Check if a value is a compiler Type.
function traits.is_type(v)
  return type(v) == 'table' and v._type
end

-- Check if a value is a scalar for the compiler, i.e., a lua number or a big number.
function traits.is_scalar(v)
  local ty = type(v)
  return ty == 'number' or (ty == 'table' and v._bn)
end

-- Check if a value is a big number.
function traits.is_bn(v)
  return type(v) == 'table' and v._bn
end

-- Check if a value is an integral (whole number) for the compiler.
function traits.is_integral(v)
  return math_type(v) == 'integer' or (type(v) == 'table' and v._bn)
end

return traits
