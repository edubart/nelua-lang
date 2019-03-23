local metamagic = {}

-- set index metamethod for a table
function metamagic.setmetaindex(t, __index, overwrite)
  local mt = getmetatable(t)
  if mt then
    assert(overwrite, 'cannot overwrite metatable')
    mt.__index = __index
    return t
  else
    return setmetatable(t, { __index = __index})
  end
end

-- set call metamethod for a table
function metamagic.setmetacall(t, f)
  local mt = getmetatable(t)
  local callfunc = function(_, ...)
    return f(...)
  end
  assert(not mt, 'cannot overwrite metatable')
  return setmetatable(t, { __call = callfunc})
end

return metamagic
