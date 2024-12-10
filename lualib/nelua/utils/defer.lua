--[[
Defer module

]]
-- Execute function at end of the scope, even when an error is raised.
local function defer(f)
  return setmetatable({}, {__close = f})
end

return defer
