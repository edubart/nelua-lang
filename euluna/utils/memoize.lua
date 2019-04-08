local tabler = require 'euluna.utils.tabler'

local cache = {}

local function cache_get(f, params)
  local cachef = cache[f]
  if cachef then
    for cparams,cres in pairs(cachef) do
      if tabler.deepcompare(cparams, params) then
        return tabler.unpack(cres, 1, cres.n)
      end
    end
  else
    cachef = {}
    cache[f] = cachef
  end
  local res = table.pack(f(tabler.unpack(params, 1, params.n)))
  cachef[params] = res
  return tabler.unpack(res, 1, res.n)
end

local function memoize(f)
  return function(...)
    return cache_get(f, table.pack(...))
  end
end

return memoize
