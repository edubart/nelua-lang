local class = require 'pl.class'
local Scope = class()

function Scope:_init(parent)
  self.parent = parent
end

function Scope:fork()
  return Scope(self)
end

return Scope
