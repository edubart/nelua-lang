local class = require 'euluna.utils.class'
local iters = require 'euluna.utils.iterators'
local Symbol = require 'euluna.symbol'

local Type = class(Symbol)

function Type:_init(name)
  self.name = name
end

function Type:__tostring()
  return self.name
end

function Type:add_conversible_types(types)
  self.conversible_types = self.conversible_types or {}
  for type in iters.ivalues(types) do
    self.conversible_types[type] = true
  end
end

function Type:is_conversible(type)
  if self == type then
    return true
  end
  return self.conversible_types and self.conversible_types[type]
end

Type.type = Type('type')

return Type
