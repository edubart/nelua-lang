local metamagic = require 'euluna.utils.metamagic'

local class = {}

-- base class for any object
local Object = {}
Object.__index = Object

-- called when creating a new object
function Object.__call(klass, ...)
  local object = setmetatable({}, klass)
  local init = object._init
  if init then init(object, ...) end
  return object
end

-- called when creating a new class
function class.new(base)
  base = base or Object
  local klass = {}
  for k, v in pairs(base) do
    if k:find("__") == 1 then
      klass[k] = v
    end
  end
  klass.__index = klass
  return setmetatable(klass, base)
end

-- check if a value is an instance of a class
function class.is_a(val, T)
  local mt = getmetatable(val)
  while mt do
    if rawequal(mt, T) then return true end
    mt = getmetatable(mt)
  end
  return false
end

-- implement class() call to create a new class
metamagic.setmetacall(class, class.new)

return class
