local typer = {}
local iters = require 'euluna.utils.iterators'

function typer.find_common_type_between(typelist, ltype, rtype)
  for type in iters.ivalues(typelist) do
    if type:is_conversible(ltype) and type:is_conversible(rtype) then
      return type
    end
  end
end

function typer.find_common_type(types)
  local len = #types
  if len == 0 then return nil end
  if len == 1 then return types[1] end
  --TODO: find best type
end

return typer
