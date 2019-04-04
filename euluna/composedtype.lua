local class = require 'euluna.utils.class'
local tabler = require 'euluna.utils.tabler'
local Type = require 'euluna.type'

local ComposedType = class(Type)

function ComposedType:_init(ast, name, subtypes)
  self.subtypes = subtypes
  Type._init(self, name, ast)
end

function ComposedType:is_equal(type)
  return type.name == self.name and
         class.is_a(type, ComposedType) and
         tabler.deepcompare(type.subtypes, self.subtypes)
end

function ComposedType:__tostring()
  local s = { self.name, '<'}
  for i,stype in ipairs(self.subtypes) do
    if i > 1 then
      table.insert(s, ', ')
    end
    table.insert(s, tostring(stype))
  end
  table.insert(s, '>')
  return table.concat(s)
end

return ComposedType
