local class = require 'euluna.utils.class'
local metamagic = require 'euluna.utils.metamagic'

local Scope = class()

function Scope:_init(parent)
  self.parent = parent
  self.vars = {}
  if parent then
    metamagic.setmetaindex(self.vars, parent.vars)
  end
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
