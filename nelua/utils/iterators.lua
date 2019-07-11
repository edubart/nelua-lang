local tabler = require 'nelua.utils.tabler'

local iterators = {}

-- iterate multiples values for multiple arrays, returning its index and values
-- stops only when all values in the arrays are nil
local pack, unpack = tabler.pack, tabler.unpack
function iterators.izip(...)
  local arrays, ans = pack(...), {}
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
    return i, unpack(ans, 1, n)
  end
end

-- iterate multiples values from multiple iterators,
-- returning a index and first value of each iterator
-- stops only when all values are nil
--[[
function iterators.izipit(...)
  local fs, ans = tabler.pack(...), {}
  local n = fs.n
  local i = 0
  return function()
    i = i + 1
    local found
    for j=1,n do
      local v = fs[j]()
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
]]

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

-- pairs() for string keys only
function iterators.spairs(t)
  return function(st, k)
    local v
    repeat
      k, v = next(st, k)
    until k == nil or type(k) == 'string'
    if k ~= nil then
      return k, v
    end
  end, t, nil
end

-- ordered pairs for string keys only
function iterators.ospairs(t)
  local okeys = {}
  for k,_ in pairs(t) do
    if type(k) == 'string' then
      okeys[#okeys + 1] = k
    end
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
