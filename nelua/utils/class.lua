local metamagic = require 'nelua.utils.metamagic'

local class = {}

-- called when creating a new object
local function createobject(klass, ...)
  local object = setmetatable({}, klass)
  local init = object._init
  if init then init(object, ...) end
  return object
end

-- called when creating a new class
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

-- check if a value is an instance of a class
function class.is(val, T)
  local mt = getmetatable(val)
  while mt do
    local mtindex = rawget(mt, '__index')
    if rawequal(mtindex, T) then return true end
    mt = getmetatable(mtindex)
  end
  return false
end

-- implement class() call to create a new class
metamagic.setmetacall(class, class.new)

return class
