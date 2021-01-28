-- Class module
--
-- The class module is used to create object oriented classes using Lua metatables.
-- Used in many parts of the compiler.

local metamagic = require 'nelua.utils.metamagic'

local class = {}

-- Helper called to initialize a new object.
local function createobject(klass, ...)
  local object = setmetatable({}, klass)
  object:_init(...)
  return object
end

-- Create a new class derived from base.
function class.new(base)
  local klass = {}
  local create = createobject
  if base then
    for k, v in pairs(base) do
      if k:find("^__") == 1 then
        klass[k] = v
      end
    end
    create = getmetatable(base).__call
  end
  klass.__index = klass
  setmetatable(klass, { __index = base, __call = create })
  return klass
end

-- Check if a value is an instance of a class.
function class.is(val, klass)
  local mt = getmetatable(val)
  while mt do
    local mtindex = rawget(mt, '__index')
    if rawequal(mtindex, klass) then return true end
    mt = getmetatable(mtindex)
  end
  return false
end

-- Allow calling class() to create a new class.
metamagic.setmetacall(class, class.new)

return class
