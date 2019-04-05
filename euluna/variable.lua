local class = require 'euluna.utils.class'
local Symbol = require 'euluna.symbol'

local Variable = class(Symbol)

function Variable:_init(name, node, type)
  Symbol._init(self, node)
  self.name = name
  self.type = type
end

return Variable
