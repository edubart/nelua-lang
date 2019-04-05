local tabler = require 'euluna.utils.tabler'

local iterators = {}

-- iterate all values of a array, returning only its value
function iterators.ivalues(t)
  local i = 0
  return function()
    i = i + 1
    return t[i]
  end
end

-- iterate all values of a table, returning only its value
function iterators.values(t)
  local k = nil
  return function()
    local v
    k, v = next(t, k)
    if k ~= nil then
      return v
    end
  end
end

-- iterate `n` values of an array, returning its index and value
function iterators.inpairs(t, n)
  return function(_t, i)
    if i == n then
      return nil
    end
    i = i + 1
    return i, _t[i]
  end, t, 0
end

-- iterate multiples values for multiple arrays, returning its index and values
-- stops only when all values in the arrays are nil
function iterators.izip(...)
  local arrays, ans = tabler.pack(...), {}
  local n = arrays.n
  local i = 0
  return function()
    i = i + 1
    local found
    for j=1,n do
      local v = arrays[j][i]
      if v then
        found = true
      end
      ans[j] = v
    end
    if not found then
      return nil
    end
    return i, tabler.unpack(ans, 1, n)
  end
end

-- ordered pairs iterator
function iterators.opairs(t)
  local okeys = { }
  for k,_ in pairs(t) do
    okeys[#okeys + 1] = k
  end
  table.sort(okeys)
  local i = 1
  return function()
    local k = okeys[i]
    local v = t[k]
    i = i + 1
    if v ~= nil then
      return k, v
    end
  end
end

return iterators
