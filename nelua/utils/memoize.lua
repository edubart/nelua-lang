-- Memoize module
--
-- Memoize module is used by the compiler to cache a function,
-- to avoid repeated function evaluations thus increase efficiency in some compiler parts.

-- Wrap a function into another function that cache calls.
local function memoize(f)
  local cache = {}
  return function(...)
    -- search in the cache
    local n = select('#', ...)
    for params,res in pairs(cache) do
      if n == params.n then
        local match = true
        for i=1,n do
          if params[i] ~= select(i, ...)  then
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
