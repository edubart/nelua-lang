local plutil = require 'pl.utils'
local lua_compiler = {}

function lua_compiler.run(code)
  local cmd = 'lua -e ' .. plutil.quote_arg(code)
  return plutil.executeex(cmd)
end

return lua_compiler
