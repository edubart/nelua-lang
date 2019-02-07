require 'compat53'
local inspect = require('inspect')

local function dump(...)
  local args = {...}
  for k,v in pairs(args) do
    args[k] = inspect(v)
  end
  print(table.unpack(args))
end

return dump