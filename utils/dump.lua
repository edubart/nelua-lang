local inspect = require('inspect')
local unpack = table.unpack or unpack

local function dump(...)
  local args = {...}
  for k,v in pairs(args) do
    args[k] = inspect(v)
  end
  print(unpack(args))
end

return dump