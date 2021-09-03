--[[
Memoize function

The memoize function is used to cache a function,
to avoid repeated function evaluations thus increase efficiency in some compiler parts.
]]

local shallow_compare_nomt = require 'nelua.utils.tabler'.shallow_compare_nomt

--[[
Wraps a function `f` into a memoized function.
A memoized function is evaluated only once for different arguments,
second evaluations returns a cached result.
]]
local function memoize(f)
  local cache = {}
  return function(...)
    -- search in the cache
    local n = select('#', ...)
    for params,res in pairs(cache) do
      if n == params.n then
        local match = true
        for i=1,n do
          local pv = params[i]
          local av = select(i, ...)
          if pv ~= av and not shallow_compare_nomt(pv, av) then
            match = false
            break
          end
        end
        if match then
          -- found an evaluation with the same arguments, return the results
          return table.unpack(res, 1, res.n)
        end
      end
    end
    local params = table.pack(...)
    local res = table.pack(f(...))
    cache[params] = res
    return table.unpack(res, 1, res.n)
  end
end

return memoize
