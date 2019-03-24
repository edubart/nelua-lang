local class = require 'euluna.utils.class'
local Symbol = require 'euluna.symbol'

local Variable = class(Symbol)

function Variable:_init(name, type)
  self.name = name
  self.type = type
end

return Variable
