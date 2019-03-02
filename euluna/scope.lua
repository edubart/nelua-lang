local class = require 'pl.class'
local Scope = class()

function Scope:_init(parent)
  self.parent = parent
end

function Scope:fork()
  return Scope(self)
end

function Scope:is_top()
  return not self.parent
end

function Scope:is_main()
  return self.parent and not self.parent.parent
end

return Scope
