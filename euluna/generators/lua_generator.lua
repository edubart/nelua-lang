local Generator = require 'euluna.generator'
local generator = Generator()

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
generator:register('Table', function(ast, coder)
  local contents = ast:args()
  coder:add('{', contents, '}')
end)

generator:register('Pair', function(ast, coder)
  local field, value = ast:args()
  if type(field) == 'string' then
    coder:add(field)
  else
    coder:add('[', field, ']')
  end
  coder:add(' = ', value)
end)

-- function
generator:register('Function', function(ast, coder)
  local args, rets, block = ast:args()
  if #block[1] == 0 then
    coder:add('function(', args, ') end')
  else
    coder:add_ln('function(', args, ')')
    coder:add(block)
    coder:add('end')
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
generator:register('DotIndex', function(ast, coder)
  local name, obj = ast:args()
  coder:add(obj, '.', name)
end)

generator:register('ColonIndex', function(ast, coder)
  local name, obj = ast:args()
  coder:add(obj, ':', name)
end)

generator:register('ArrayIndex', function(ast, coder)
  local index, obj = ast:args()
  coder:add(obj, '[', index, ']')
end)

-- calls
local function should_surround_caller(caller)
  if caller.tag == 'Id' or
     caller.tag == 'DotIndex' or
     caller.tag == 'ArrayIndex' or
     caller.tag == 'Call' or
     caller.tag == 'CallMethod' then
     return false
  end
  return true
end

generator:register('Call', function(ast, coder)
  local argtypes, args, caller, block_call = ast:args()
  local surround = should_surround_caller(caller)
  if block_call then coder:add_indent() end
  if surround then coder:add('(') end
  coder:add(caller)
  if surround then coder:add(')') end
  coder:add('(', args, ')')
  if block_call then coder:add_ln() end
end)

generator:register('CallMethod', function(ast, coder)
  local name, argtypes, args, caller, block_call = ast:args()
  local surround = should_surround_caller(caller)
  if block_call then coder:add_indent() end
  if surround then coder:add('(') end
  coder:add(caller)
  if surround then coder:add(')') end
  coder:add(':', name, '(', args, ')')
  if block_call then coder:add_ln() end
end)

-- block
generator:register('Block', function(ast, coder)
  local stats = ast:args()
  coder:inc_indent()
  coder:push_scope()
  coder:add_traversal_list(stats, '')
  coder:pop_scope()
  coder:dec_indent()
end)

-- statements
generator:register('Return', function(ast, coder)
  local rets = ast:args()
  coder:add_indent("return")
  if #rets > 0 then
    coder:add(' ')
  end
  coder:add_ln(rets)
end)

generator:register('If', function(ast, coder)
  local ifparts, elseblock = ast:args()
  for i,ifpart in ipairs(ifparts) do
    local cond, block = ifpart[1], ifpart[2]
    if i == 1 then
      coder:add_indent("if ")
      coder:add(cond)
      coder:add_ln(" then")
    else
      coder:add_indent("elseif ")
      coder:add(cond)
      coder:add_ln(" then")
    end
    coder:add(block)
  end
  if elseblock then
    coder:add_indent_ln("else")
    coder:add(elseblock)
  end
  coder:add_indent_ln("end")
end)

generator:register('Do', function(ast, coder)
  local block = ast:args()
  coder:add_indent_ln("do")
  coder:add(block)
  coder:add_indent_ln("end")
end)

generator:register('While', function(ast, coder)
  local cond, block = ast:args()
  coder:add_indent_ln("while ", cond, ' do')
  coder:add(block)
  coder:add_indent_ln("end")
end)

generator:register('Repeat', function(ast, coder)
  local block, cond = ast:args()
  coder:add_indent_ln("repeat")
  coder:add(block)
  coder:add_indent_ln('until ', cond)
end)

generator:register('ForNum', function(ast, coder)
  local itervar, beginval, comp, endval, incrval, block  = ast:args()
  assert(comp == 'le', 'for comparators not supported in lua yet')
  coder:add_indent("for ", itervar, '=', beginval, ',', endval)
  if incrval then
    coder:add(',', incrval)
  end
  coder:add_ln(' do')
  coder:add(block)
  coder:add_indent_ln("end")
end)

generator:register('ForIn', function(ast, coder)
  local itervars, iterator, block  = ast:args()
  coder:add_indent_ln("for ", itervars, ' in ', iterator, ' do')
  coder:add(block)
  coder:add_indent_ln("end")
end)

generator:register('Break', function(_, coder)
  coder:add_indent_ln('break')
end)

generator:register('Label', function(ast, coder)
  local name = ast:args()
  coder:add_indent_ln('::', name, '::')
end)

generator:register('Goto', function(ast, coder)
  local labelname = ast:args()
  coder:add_indent_ln('goto ', labelname)
end)

generator:register('VarDecl', function(ast, coder, scope)
  local varscope, mutability, vars, vals = ast:args()
  assert(mutability == 'var', 'variable mutability not supported in lua')
  local is_local = (varscope == 'local') or not scope:is_main()
  coder:add_indent()
  if is_local then
    coder:add('local ')
  end
  coder:add(vars)
  if vals or not is_local then
    coder:add(' = ')
  end
  if vals then
    coder:add(vals)
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

generator:register('Assign', function(ast, coder)
  local vars, vals = ast:args()
  coder:add_indent_ln(vars, ' = ', vals)
end)

generator:register('FuncDef', function(ast, coder)
  local varscope, name, args, rets, block = ast:args()
  coder:add_indent()
  if varscope == 'local' then
    coder:add('local ')
  end
  coder:add_ln('function ', name, '(', args, ')')
  coder:add(block)
  coder:add_indent_ln('end')
end)

-- operators
local function is_in_operator(coder)
  local parent_ast = coder:get_parent_ast()
  if not parent_ast then return false end
  local parent_ast_tag = parent_ast.tag
  return
    parent_ast_tag == 'UnaryOp' or
    parent_ast_tag == 'BinaryOp' or
    parent_ast_tag == 'TernaryOp'
end

local LUA_UNARY_OPS = {
  ['not'] = 'not ',
  ['neg'] = '-',
  ['bnot'] = '~',
  ['len'] = '#'
}
generator:register('UnaryOp', function(ast, coder)
  local opname, arg = ast:args()
  if opname == 'tostring' then
    coder:add('tostring(', arg, ')')
  else
    local op = assert(LUA_UNARY_OPS[opname], 'unary operator not found')
    local surround = is_in_operator(coder)
    if surround then coder:add('(') end
    coder:add(op, arg)
    if surround then coder:add(')') end
  end
end)

local LUA_BINARY_OPS = {
  ['or'] = 'or',
  ['and'] = 'and',
  ['ne'] = '~=',
  ['eq'] = '==',
  ['le'] = '<=',
  ['ge'] = '>=',
  ['lt'] = '<',
  ['gt'] = '>',
  ['bor'] = '|',
  ['bxor'] = '~',
  ['band'] = '&',
  ['shl'] = '<<',
  ['shr'] = '>>',
  ['add'] = '+',
  ['sub'] = '-',
  ['mul'] = '*',
  ['div'] = '/',
  ['mod'] = '%',
  ['pow'] = '^',
  ['concat'] = '..'
}
generator:register('BinaryOp', function(ast, coder)
  local opname, left_arg, right_arg = ast:args()
  local op = assert(LUA_BINARY_OPS[opname], 'binary operator not found')
  local surround = is_in_operator(coder)
  if surround then coder:add('(') end
    coder:add(left_arg, ' ', op, ' ', right_arg)
  if surround then coder:add(')') end
end)

generator:register('TernaryOp', function(ast, coder)
  local opname, left_arg, mid_arg, right_arg = ast:args()
  assert(opname == 'if', 'unknown ternary op ')
  local surround = is_in_operator(coder)
  if surround then coder:add('(') end
  coder:add(mid_arg, ' and ', left_arg, ' or ', right_arg)
  if surround then coder:add(')') end
end)

generator:register('Switch', function(ast, coder)
  local val, caseparts, switchelseblock = ast:args()
  local varname = '__switchval' .. ast.pos
  coder:add_indent_ln("local ", varname, " = ", val)
  assert(#caseparts > 0)
  for i,casepart in ipairs(caseparts) do
    local caseval, caseblock = casepart[1], casepart[2]
    if i == 1 then
      coder:add_indent('if ')
    else
      coder:add_indent('elseif ')
    end
    coder:add_ln(varname, ' == ', caseval, ' then')
    coder:add(caseblock)
  end
  if switchelseblock then
    coder:add_indent_ln('else')
    coder:add(switchelseblock)
  end
  coder:add_indent_ln("end")
end)

-- TODO: Continue

return generator
