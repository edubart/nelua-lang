-- Metamagic module
--
-- The metamagic module have a few utilities for working with metatables.

local metamagic = {}

-- Set the __index metamethod for a table, creating a metatable if necessary.
function metamagic.setmetaindex(t, __index, overwrite)
  local mt = getmetatable(t)
  if mt then
    assert(overwrite or mt.__index == __index, 'cannot overwrite metatable')
    mt.__index = __index
    return t
  elseif __index then
    return setmetatable(t, { __index = __index})
  end
end

-- Set __call metamethod for a table, always creating a new metatable.
function metamagic.setmetacall(t, f)
  local mt = getmetatable(t)
  local callfunc = function(_, ...)
    return f(...)
  end
  assert(not mt, 'cannot overwrite metatable')
  return setmetatable(t, { __call = callfunc})
end

-- Check if a value has a specific metamethod in its metatable.
function metamagic.hasmetamethod(t, method)
  local mt = getmetatable(t)
  if mt and mt[method] then return true end
  return false
end

return metamagic
