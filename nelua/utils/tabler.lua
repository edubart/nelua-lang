local metamagic = require 'nelua.utils.metamagic'

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
    if t[i] == val then
      return i
    end
  end
  return nil
end

-- insert values
function tabler.insertvalues(t, st)
  local tlen = #t
  for i=1,#st do
    t[tlen + i] = st[i]
  end
  return t
end

-- find values inside an array table using a custom if function
function tabler.ifindif(t, fn, idx)
  for i=idx or 1,#t do
    local val = t[i]
    if fn(val) then
      return val,i
    end
  end
  return nil
end

-- create a new table of mapped array values
function tabler.imap(t, f)
  local ot = {}
  for i=1,#t do
    local nv, ni = f(t[i], i)
    ot[ni or i] = nv
  end
  return ot
end

-- shallow copy for table
function tabler.copy(t)
  local ot = {}
  for i,v in pairs(t) do
    ot[i] = v
  end
  return ot
end

-- check if all values of a list pass test
function tabler.iall(t, f)
  for i=1,#t do
    if not f(t[i],i) then
      return false
    end
  end
  return true
end

function tabler.clear(t)
  for k in pairs(t) do
    t[k] = nil
  end
  return t
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
  local tablewrapper = {}
  local tablewrapper_mt = { __index = tablewrapper}
  local function createtablewrapper(v)
    return setmetatable({_v = v}, tablewrapper_mt)
  end

  -- function for returning the wrapper table
  function tablewrapper:value()
    return self._v
  end

  -- inject tabler functions into the wrapper
  for k,f in pairs(tabler) do
    tablewrapper[k] = function(v, ...)
      assert(getmetatable(v) == tablewrapper_mt)
      return createtablewrapper(f(v._v, ...))
    end
  end

  -- allow calling tabler() to begin chain on tables
  function tabler.chain(v)
    return createtablewrapper(v)
  end
  metamagic.setmetacall(tabler, tabler.chain)
end

return tabler
