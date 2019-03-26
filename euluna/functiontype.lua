local class = require 'euluna.utils.class'
local Type = require 'euluna.type'

local FunctionType = class(Type)

function FunctionType:_init(ast, arg_types, return_types)
  self.arg_types = arg_types
  self.return_types = return_types
  Type._init(self, 'function', ast)
end

--[[
function FunctionType:__tostring()
  local s = {'function<('}
  for i,arg in ipairs(self.arg_types) do
    if i > 1 then
      table.insert(s, ', ')
    end
    local typestr = tostring(arg.type)
    if arg.id then
      table.insert(s, string.format('%s: %s', arg.id, typestr))
    else
      table.insert(s, typestr)
    end
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
]]

return FunctionType
