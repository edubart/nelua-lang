--[[
Metamagic module

The metamagic module have a few utilities for working with metatables.
]]

local metamagic = {}

-- Set the `__index` metamethod for a table, creating a metatable if necessary.
function metamagic.setmetaindex(t, __index, overwrite)
  local mt = getmetatable(t)
  if mt then
    assert(overwrite or mt.__index == __index, 'cannot overwrite metatable')
    mt.__index = __index
  elseif __index then
    setmetatable(t, { __index = __index})
  end
  return t
end

-- Set the `__call` metamethod for a table, always creating a new metatable.
function metamagic.setmetacall(t, f)
  local mt = getmetatable(t)
  local callfunc = function(_, ...)
    return f(...)
  end
  assert(not mt, 'cannot overwrite metatable')
  setmetatable(t, { __call = callfunc})
  return t
end

-- Check if a value has metamethod `method` in its metatable.
function metamagic.hasmetamethod(t, method)
  local mt = getmetatable(t)
  return (mt and mt[method]) and true or false
end

return metamagic
