local Traverser = require 'euluna.traverser'
local generator = Traverser('Lua')

generator:register('Number', function(ast, coder)
  local type, value, literal = ast:args()
  coder:add(value)
end)

--[[
generator:register('String', function(ast, coder)
  local value, literal = ast:args()
  coder:add(value)
end)
]]

generator:register('Block', function(ast, coder, parent_scope)
  local stats = ast:args()
  local scope = parent_scope:fork()
  for _,stat in ipairs(stats) do
  generator:traverse(stat, coder, scope)
  end
end)

generator:register('StatReturn', function(ast, coder, parent_scope)
  local rets = ast:args()
  coder:add_indent("return")
  for i,ret in ipairs(rets) do
    if i == 1 then
      coder:add(' ')
    else
      coder:add(', ')
    end
    generator:traverse(ret, coder, parent_scope)
  end
  coder:add_ln()
end)

generator:register('StatDo', function(ast, coder, parent_scope)
  local block = ast:args()
  local scope = parent_scope:fork()
  coder:add_indent_ln("do")
  coder:inc_indent()
  generator:traverse(block, coder, scope)
  coder:dec_indent()
  coder:add_indent_ln("end")
end)

generator:register('Id', function(ast, coder)
  local name = ast:args()
  coder:add(name)
end)

return generator