-- Tabler module
--
-- Tabler module contains some utilities for working with lua tables.

local metamagic = require 'nelua.utils.metamagic'

local tabler = {}

-- Copy a table into another, in-place.
function tabler.update(t, src)
  for k,v in next,src do
    t[k] = v
  end
  return t
end

-- Find a value inside an array table.
function tabler.ifind(t, val, idx)
  for i=idx or 1,#t do
    if t[i] == val then
      return i
    end
  end
  return nil
end

-- Insert values into an array table.
function tabler.insertvalues(t, pos, st)
  if not st then
    st = pos
    pos = #t + 1
  else
    for i=#t,pos,-1 do
      t[i+#st] = t[i]
    end
  end
  for i=1,#st do
    t[pos + i - 1] = st[i]
  end
  return t
end

-- Create a new table of mapped array values.
function tabler.imap(t, fn)
  local ot = {}
  for i=1,#t do
    ot[i] = fn(t[i])
  end
  return ot
end

-- Shallow copy for an array.
function tabler.icopy(t)
  local ot = {}
  for i=1,#t do
    ot[i] = t[i]
  end
  return ot
end

-- Shallow copy for table.
function tabler.copy(t)
  local ot = {}
  for i,v in next,t do
    ot[i] = v
  end
  return ot
end

-- Check if a field is present in all values of an array table.
function tabler.iallfield(t, field)
  for i=1,#t do
    if not t[i][field] then
      return false
    end
  end
  return true
end

-- Clear a table.
function tabler.clear(t)
  for k in next,t do
    t[k] = nil
  end
  return t
end

-- Shallow compare two array tables.
function tabler.icompare(t1, t2)
  for i=1,math.max(#t1, #t2) do
    if t1[i] ~= t2[i] then
      return false
    end
  end
  return true
end

-- Get the key for a table in _G.
function tabler.globaltable2key(t)
  for k,v in pairs(_G) do
    if v == t then
      return k
    end
  end
end

-- Add lua table methods to allow using them in chain mode.
tabler.concat = table.concat
tabler.insert = table.insert
tabler.remove = table.remove
tabler.sort = table.sort

do -- Wrapper for using tabler in chain mode.
  local tablewrapper = {}
  local tablewrapper_mt = { __index = tablewrapper}
  local function createtablewrapper(v)
    return setmetatable({_v = v}, tablewrapper_mt)
  end

  -- function for returning the wrapped table
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
