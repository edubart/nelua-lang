--[[
Tabler module

The tabler module contains some utilities for working with lua tables.
]]

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
function tabler.insertvalues(t, st)
  local pos = #t
  for i=1,#st do
    t[pos + i] = st[i]
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

-- Shallow copy a table and update its elements.
function tabler.updatecopy(s,t)
  return tabler.update(tabler.copy(s), t)
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

-- Shallow compare two tables without metatable set.
function tabler.shallow_compare_nomt(t1, t2)
  if not getmetatable(t1) and not getmetatable(t2) and
     type(t1) == 'table' and type(t2) == 'table' then
    for k,v in next,t1 do
      if v ~= t2[k] then return false end
    end
    for k,v in next,t2 do
      if v ~= t1[k] then return false end
    end
    return true
  end
  return false
end

-- Make table `dst` identical to table `src` (including metatables).
function tabler.mirror(dst, src)
  if rawequal(dst, src) then
    return
  end
  setmetatable(dst, nil)
  tabler.clear(dst)
  tabler.update(dst, src)
  setmetatable(dst, getmetatable(src))
end

return tabler
