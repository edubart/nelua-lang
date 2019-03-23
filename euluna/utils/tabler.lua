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
function tabler.find(t, val, idx)
  for i=idx or 1,#t do
    if t[i] == val then return i end
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

function tabler.insert_many(t, v, ...)
  if v == nil and select('#', ...) == 0 then return end
  table.insert(t, v)
  tabler.insert_many(t, ...)
end

-- inject lua table methods to use in chain mode
tabler.concat = table.concat
tabler.insert = table.insert
tabler.remove = table.remove
tabler.unpack = table.unpack or unpack
tabler.sort = table.sort

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
