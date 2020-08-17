-- Memoize module
--
-- Memoize module is used by the compiler to cache a function,
-- to avoid repeated function evaluations thus increase efficiency in some compiler parts.

local tabler = require 'nelua.utils.tabler'
local table_icompare = tabler.icompare

-- Wrap a function into another function that cache calls.
local function memoize(f)
  local cache = {}
  return function(...)
    local params = table.pack(...)
    -- search in the cache
    for cparams,cres in pairs(cache) do
      if table_icompare(cparams, params) then
        -- found an evaluation with the same arguments, return the results
        return table.unpack(cres, 1, cres.n)
      end
    end
    local res = table.pack(f(...))
    cache[params] = res
    return table.unpack(res, 1, res.n)
  end
end

return memoize
