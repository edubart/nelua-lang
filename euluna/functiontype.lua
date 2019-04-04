local class = require 'euluna.utils.class'
local tabler = require 'euluna.utils.tabler'
local Type = require 'euluna.type'

local FunctionType = class(Type)

function FunctionType:_init(ast, arg_types, return_types)
  self.arg_types = arg_types
  self.return_types = return_types
  Type._init(self, 'function', ast)
end

function FunctionType:is_equal(type)
  return type.name == 'function' and
         class.is_a(type, FunctionType) and
         tabler.deepcompare(type.arg_types, self.arg_types) and
         tabler.deepcompare(type.return_types, self.return_types)
end

function FunctionType:__tostring()
  local s = {'function<('}
  for i,atype in ipairs(self.arg_types) do
    if i > 1 then
      table.insert(s, ', ')
    end
    table.insert(s, tostring(atype))
  end
  table.insert(s, ')')
  for i,rtype in ipairs(self.return_types) do
    if i == 1 then
      table.insert(s, ': ')
    else
      table.insert(s, ', ')
    end
    table.insert(s, tostring(rtype))
  end
  table.insert(s, '>')
  return table.concat(s)
end

return FunctionType
