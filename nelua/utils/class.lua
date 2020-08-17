-- Class module
--
-- The class module is used to create object oriented classes using Lua metatables.
-- Used in many parts of the compiler.

local metamagic = require 'nelua.utils.metamagic'

local class = {}

-- Helper called when creating a new object to initialize it.
local function createobject(klass, ...)
  local object = setmetatable({}, klass)
  object:_init(...)
  return object
end

-- Create a new class derived from base.
function class.new(base)
  local klass = {}
  if base then
    for k, v in pairs(base) do
      if k:find("^__") == 1 then
        klass[k] = v
      end
    end
  end
  klass.__index = klass
  return setmetatable(klass, { __index = base, __call = createobject })
end

-- Check if a value is an instance of a class.
function class.is(val, T)
  local mt = getmetatable(val)
  while mt do
    local mtindex = rawget(mt, '__index')
    if rawequal(mtindex, T) then return true end
    mt = getmetatable(mtindex)
  end
  return false
end

-- Allow calling class() call to create a new class.
metamagic.setmetacall(class, class.new)

return class
