local Traverser = require 'euluna.traverser'
local generator = Traverser('Lua')

-- primitives
generator:register('Number', function(ast, coder)
  local type, value, literal = ast:args()
  assert(literal == nil, 'literals are not supported in lua')
  if type == 'int' or type == 'dec' then
    coder:add(value)
  elseif type == 'exp' then
    coder:add(string.format('%se%s', value[1], value[2]))
  elseif type == 'hex' then
    coder:add(string.format('0x%s', value))
  elseif type == 'bin' then
    coder:add(string.format('%u', tonumber(value, 2)))
  end
end)

generator:register('String', function(ast, coder)
  local value, literal = ast:args()
  assert(literal == nil, 'literals are not supported in lua')
  if value:find('"') and not value:find("'") then
    coder:add_single_quoted(value)
  else
    coder:add_double_quoted(value)
  end
end)

generator:register('Boolean', function(ast, coder)
  local value = ast:args()
  coder:add(tostring(value))
end)

generator:register('Nil', function(_, coder)
  coder:add('nil')
end)

generator:register('Varargs', function(_, coder)
  coder:add('...')
end)

-- table
generator:register('Table', function(ast, coder, scope)
  local contents = ast:args()
  coder:add('{')
  for i,content in ipairs(contents) do
    if i > 1 then coder:add(', ') end
    generator:traverse(content, coder, scope)
  end
  coder:add('}')
end)

generator:register('Pair', function(ast, coder, scope)
  local field, value = ast:args()
  if type(field) == 'string' then
    coder:add(field)
  else
    coder:add('[')
    generator:traverse(field, coder, scope)
    coder:add(']')
  end
  coder:add(' = ')
  generator:traverse(value, coder, scope)
end)

-- function
generator:register('Function', function(ast, coder, scope)
  local args, rets, block = ast:args()
  coder:add('function(')
  for i,arg in ipairs(args) do
    if i > 1 then coder:add(', ') end
    generator:traverse(arg, coder, scope)
  end
  if #block[1] == 0 then
    coder:add(') end')
  else
    coder:add_ln(')')
    generator:traverse(block, coder, scope)
    coder:dec_indent()
    coder:add_ln('end')
  end
end)

-- identifier and types
generator:register('Id', function(ast, coder)
  local name = ast:args()
  coder:add(name)
end)
generator:register('Type', function() end)
generator:register('TypedId', function(ast, coder)
  local name, type = ast:args()
  coder:add(name)
end)

-- indexing
generator:register('DotIndex', function(ast, coder, scope)
  local name, obj = ast:args()
  generator:traverse(obj, coder, scope)
  coder:add('.', name)
end)

generator:register('ArrayIndex', function(ast, coder, scope)
  local index, obj = ast:args()
  generator:traverse(obj, coder, scope)
  coder:add('[')
  generator:traverse(index, coder, scope)
  coder:add(']')
end)

-- calls
generator:register('Call', function(ast, coder, scope)
  local argtypes, args, caller = ast:args()
  generator:traverse(caller, coder, scope)
  coder:add('(')
  coder:add_traversal_list(generator, scope, args)
  coder:add(')')
end)

generator:register('CallMethod', function(ast, coder, scope)
  local name, argtypes, args, caller = ast:args()
  generator:traverse(caller, coder, scope)
  coder:add(':', name, '(')
  coder:add_traversal_list(generator, scope, args)
  coder:add(')')
end)

-- block
generator:register('Block', function(ast, coder, scope)
  local stats = ast:args()
  local blockscope = scope:fork()
  coder:inc_indent()
  coder:add_traversal_list(generator, blockscope, stats, '')
  coder:dec_indent()
end)

-- statements
generator:register('Return', function(ast, coder, scope)
  local rets = ast:args()
  coder:add_indent("return")
  if #rets > 0 then
    coder:add(' ')
  end
  coder:add_traversal_list(generator, scope, rets)
  coder:add_ln()
end)

generator:register('If', function(ast, coder, scope)
  local ifparts, elseblock = ast:args()
  for i,ifpart in ipairs(ifparts) do
    local cond, block = ifpart[1], ifpart[2]
    if i == 1 then
      coder:add_indent("if ")
      generator:traverse(cond, coder, scope)
      coder:add_ln(" then")
    else
      coder:add_indent("elseif ")
      generator:traverse(cond, coder, scope)
      coder:add_ln(" then")
    end
    generator:traverse(block, coder, scope)
  end
  if elseblock then
    coder:add_indent_ln("else")
    generator:traverse(elseblock, coder, scope)
  end
  coder:add_indent_ln("end")
end)

-- TODO: Switch

generator:register('Do', function(ast, coder, scope)
  local block = ast:args()
  coder:add_indent_ln("do")
  generator:traverse(block, coder, scope)
  coder:add_indent_ln("end")
end)

generator:register('While', function(ast, coder, scope)
  local cond, block = ast:args()
  coder:add_indent("while ")
  generator:traverse(cond, coder, scope)
  coder:add_ln(' do')
  generator:traverse(block, coder, scope)
  coder:add_indent_ln("end")
end)

generator:register('Repeat', function(ast, coder, scope)
  local block, cond = ast:args()
  coder:add_indent_ln("repeat")
  generator:traverse(block, coder, scope)
  coder:add_indent('until ')
  generator:traverse(cond, coder, scope)
  coder:add_ln()
end)

generator:register('ForNum', function(ast, coder, scope)
  local itervar, beginval, comp, endval, incrval, block  = ast:args()
  assert(comp == 'le', 'for comparators not supported in lua yet')
  coder:add_indent("for ")
  generator:traverse(itervar, coder, scope)
  coder:add('=')
  generator:traverse(beginval, coder, scope)
  coder:add(',')
  generator:traverse(endval, coder, scope)
  if incrval then
    coder:add(',')
    generator:traverse(incrval, coder, scope)
  end
  coder:add_ln(' do')
  generator:traverse(block, coder, scope)
  coder:add_indent_ln("end")
end)

generator:register('ForIn', function(ast, coder, scope)
  local itervars, iterator, block  = ast:args()
  coder:add_indent("for ")
  coder:add_traversal_list(generator, scope, itervars, ',')
  coder:add(' in ')
  generator:traverse(iterator, coder, scope)
  coder:add_ln(' do')
  generator:traverse(block, coder, scope)
  coder:add_indent_ln("end")
end)

generator:register('Break', function(_, coder)
  coder:add_indent_ln('break')
end)

-- Continue

generator:register('Label', function(ast, coder)
  local name = ast:args()
  coder:add_indent('::')
  coder:add(name)
  coder:add_ln('::')
end)

generator:register('Goto', function(ast, coder)
  local labelname = ast:args()
  coder:add_indent('goto ')
  coder:add_ln(labelname)
end)

generator:register('VarDecl', function(ast, coder, scope)
  local varscope, mutability, vars, vals = ast:args()
  assert(mutability == 'var', 'variable mutability not supported in lua')
  local is_local = (varscope == 'local')
  coder:add_indent()
  if is_local then
    coder:add('local ')
  end
  coder:add_traversal_list(generator, scope, vars)
  if vals or not is_local then
    coder:add(' = ')
  end
  if vals then
    coder:add_traversal_list(generator, scope, vals)
  end
  if not is_local then
    local istart = 1
    if vals then
      istart = #vals+1
    end
    for i=istart,#vars do
      if i > 1 then coder:add(', ') end
      coder:add('nil')
    end
  end
  coder:add_ln()
end)

generator:register('Assign', function(ast, coder, scope)
  local vars, vals = ast:args()
  coder:add_indent()
  coder:add_traversal_list(generator, scope, vars)
  coder:add(' = ')
  coder:add_traversal_list(generator, scope, vals)
  coder:add_ln()
end)

generator:register('FuncDef', function(ast, coder, scope)
  local varscope, name, args, rets, block = ast:args()
  coder:add_indent()
  if varscope == 'local' then
    coder:add('local ')
  end
  coder:add('function ', name, '(')
  coder:add_traversal_list(generator, scope, args)
  coder:add_ln(')')
  generator:traverse(block, coder, scope)
  coder:add_indent_ln('end')
end)

-- TODO: UnaryOp
-- TODO: BinaryOp
-- TODO: TernaryOp

return generator