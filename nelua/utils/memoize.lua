local tabler = require 'nelua.utils.tabler'

local function memoize(f)
  local cache = {}

  return function(...)
    local params = tabler.pack(...)
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
end

return memoize
