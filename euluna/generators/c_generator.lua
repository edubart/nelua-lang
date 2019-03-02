local Generator = require 'euluna.generator'
local generator = Generator()

generator:set_indent('    ')

generator:register('Number', function(ast, coder)
  local type, value, literal = ast:args()
  assert(literal == nil, 'literals are not supported in lua')
  if type == 'int' or type == 'dec' then
    coder:add(value)
  --elseif type == 'exp' then
  --  coder:add(string.format('%se%s', value[1], value[2]))
  --elseif type == 'hex' then
  --  coder:add(string.format('0x%s', value))
  --elseif type == 'bin' then
  --  coder:add(string.format('%u', tonumber(value, 2)))
  end
end)

generator:register('Block', function(ast, coder, scope)
  local stats = ast:args()
  local is_top_scope = scope:is_top()
  if is_top_scope then
    coder:inc_indent()
    coder:add_ln("int main() {")
  end
  coder:inc_indent()
  local inner_scope = coder:push_scope()
  coder:add_traversal_list(stats, '')
  if inner_scope:is_main() and not inner_scope.has_return then
    -- main() must always return an integer
    coder:add_indent_ln("return 0;")
  end
  coder:pop_scope()
  coder:dec_indent()
  if is_top_scope then
    coder:add_ln("}")
    coder:dec_indent()
  end
end)

generator:register('Return', function(ast, coder, scope)
  scope.has_return = true
  local rets = ast:args()
  coder:add_indent("return")
  if #rets > 0 then
    coder:add_ln(' ', rets, ';')
  else
    if scope:is_main() then
      -- main() must always return an integer
      coder:add(' 0')
    end
    coder:add_ln(';')
  end
end)

return generator
