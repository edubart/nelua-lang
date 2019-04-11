local metamagic = require 'euluna.utils.metamagic'

local tabler = {}

--- copy a table into another, in-place.
function tabler.update(t, src)
  for k,v in pairs(src) do
    t[k] = v
  end
  return t
end

-- find a value inside an array table
function tabler.ifind(t, val, idx)
  for i=idx or 1,#t do
    if t[i] == val then return i end
  end
  return nil
end

-- find values inside an array table using a custom if function
function tabler.ifindif(t, fn, idx)
  for i=idx or 1,#t do
    local val = t[i]
    if fn(val) then return val end
  end
  return nil
end

-- create a new table of mapped array values
function tabler.imap(t, f)
  local _t = {}
  for k,v in ipairs(t) do
    local nv, nk = f(v, k)
    _t[nk or k] = nv
  end
  return _t
end

-- shallow copy for table
function tabler.copy(t)
  local _t = {}
  for i,v in pairs(t) do
    _t[i] = v
  end
  return _t
end

-- check if all values of a list pass test
function tabler.iall(t, f)
  for i,v in ipairs(t) do
    if not f(v,i) then return false end
  end
  return true
end

-- compare two tables
function tabler.deepcompare(t1,t2,ignore_mt)
  local ty1 = type(t1)
  local ty2 = type(t2)
  if ty1 ~= ty2 then return false end
  -- non-table types can be directly compared
  if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
  -- as well as tables which have the metamethod __eq
  local mt = getmetatable(t1)
  if not ignore_mt and mt and mt.__eq then return t1 == t2 end
  for k1,v1 in pairs(t1) do
    local v2 = t2[k1]
    if v2 == nil or not tabler.deepcompare(v1,v2) then return false end
  end
  for k2,v2 in pairs(t2) do
    local v1 = t1[k2]
    if v1 == nil or not tabler.deepcompare(v1,v2) then return false end
  end
  return true
end

-- inject lua table methods to use in chain mode
tabler.concat = table.concat
tabler.insert = table.insert
tabler.remove = table.remove
tabler.sort = table.sort

-- compability with lua 5.1
tabler.unpack = table.unpack or unpack
tabler.pack = table.pack or function(...) return {n=select('#',...), ...} end

--- tabler wrapper for using in chain mode
do
  local tabler_wrapper = {}
  local tabler_wrapper_mt = { __index = tabler_wrapper}
  local function new_tabler_wrapper(v)
    return setmetatable({_v = v}, tabler_wrapper_mt)
  end

  -- function for returning the wrapper table
  function tabler_wrapper:value()
    return self._v
  end

  -- inject tabler functions into the wrapper
  for k,f in pairs(tabler) do
    tabler_wrapper[k] = function(v, ...)
      assert(getmetatable(v) == tabler_wrapper_mt)
      return new_tabler_wrapper(f(v._v, ...))
    end
  end

  -- allow calling tabler() to begin chain on tables
  function tabler.chain(v)
    return new_tabler_wrapper(v)
  end
  metamagic.setmetacall(tabler, tabler.chain)
end

return tabler
