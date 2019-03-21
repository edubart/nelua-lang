local Traverser = require 'euluna.traverser'
local Coder = require 'euluna.coder'

local generator = Traverser()

-- primitives
generator:register('Number', function(_, ast, coder)
  local type, value, literal = ast:args()
  ast:assertf(literal == nil, 'literals are not supported in lua')
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

generator:register('String', function(_, ast, coder)
  local value, literal = ast:args()
  ast:assertf(literal == nil, 'literals are not supported in lua')
  if value:find('"') and not value:find("'") then
    coder:add_single_quoted(value)
  else
    coder:add_double_quoted(value)
  end
end)

generator:register('Boolean', function(_, ast, coder)
  local value = ast:args()
  coder:add(tostring(value))
end)

generator:register('Nil', function(_, _, coder)
  coder:add('nil')
end)

generator:register('Varargs', function(_, _, coder)
  coder:add('...')
end)

-- table
generator:register('Table', function(_, ast, coder)
  local contents = ast:args()
  coder:add('{', contents, '}')
end)

generator:register('Pair', function(_, ast, coder)
  local field, value = ast:args()
  if type(field) == 'string' then
    coder:add(field)
  else
    coder:add('[', field, ']')
  end
  coder:add(' = ', value)
end)

-- function
generator:register('Function', function(_, ast, coder)
  local args, rets, block = ast:args()
  if #block[1] == 0 then
    coder:add('function(', args, ') end')
  else
    coder:add_ln('function(', args, ')')
    coder:add(block)
    coder:add_indent('end')
  end
end)

-- identifier and types
generator:register('Id', function(_, ast, coder)
  local name = ast:args()
  coder:add(name)
end)
generator:register('Paren', function(_, ast, coder)
  local what = ast:args()
  coder:add('(', what, ')')
end)
generator:register('Type', function() end)
generator:register('TypedId', function(_, ast, coder)
  local name, type = ast:args()
  coder:add(name)
end)
generator:register('FuncArg', function(_, ast, coder)
  local name, mut, type = ast:args()
  ast:assertf(mut == nil or mut == 'var', "variable mutabilities are not supported in lua")
  coder:add(name)
end)

-- indexing
generator:register('DotIndex', function(_, ast, coder)
  local name, obj = ast:args()
  coder:add(obj, '.', name)
end)

generator:register('ColonIndex', function(_, ast, coder)
  local name, obj = ast:args()
  coder:add(obj, ':', name)
end)

generator:register('ArrayIndex', function(_, ast, coder)
  local index, obj = ast:args()
  coder:add(obj, '[', index, ']')
end)

-- calls
generator:register('Call', function(_, ast, coder)
  local argtypes, args, caller, block_call = ast:args()
  if block_call then coder:add_indent() end
  coder:add(caller, '(', args, ')')
  if block_call then coder:add_ln() end
end)

generator:register('CallMethod', function(_, ast, coder)
  local name, argtypes, args, caller, block_call = ast:args()
  if block_call then coder:add_indent() end
  coder:add(caller, ':', name, '(', args, ')')
  if block_call then coder:add_ln() end
end)

-- block
generator:register('Block', function(context, ast, coder)
  local stats = ast:args()
  coder:inc_indent()
  context:push_scope()
  coder:add_traversal_list(stats, '')
  context:pop_scope()
  coder:dec_indent()
end)

-- statements
generator:register('Return', function(_, ast, coder)
  local rets = ast:args()
  coder:add_indent("return")
  if #rets > 0 then
    coder:add(' ')
  end
  coder:add_ln(rets)
end)

generator:register('If', function(_, ast, coder)
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

generator:register('Switch', function(_, ast, coder)
  local val, caseparts, switchelseblock = ast:args()
  local varname = '__switchval' .. ast.pos
  coder:add_indent_ln("local ", varname, " = ", val)
  ast:assertf(#caseparts > 0, "switch must have case parts")
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

generator:register('Do', function(_, ast, coder)
  local block = ast:args()
  coder:add_indent_ln("do")
  coder:add(block)
  coder:add_indent_ln("end")
end)

generator:register('While', function(_, ast, coder)
  local cond, block = ast:args()
  coder:add_indent_ln("while ", cond, ' do')
  coder:add(block)
  coder:add_indent_ln("end")
end)

generator:register('Repeat', function(_, ast, coder)
  local block, cond = ast:args()
  coder:add_indent_ln("repeat")
  coder:add(block)
  coder:add_indent_ln('until ', cond)
end)

generator:register('ForNum', function(_, ast, coder)
  local itvar, beginval, comp, endval, incrval, block  = ast:args()
  ast:assertf(comp == 'le', 'for comparator not supported yet')
  coder:add_indent("for ", itvar, '=', beginval, ',', endval)
  if incrval then
    coder:add(',', incrval)
  end
  coder:add_ln(' do')
  coder:add(block)
  coder:add_indent_ln("end")
end)

generator:register('ForIn', function(_, ast, coder)
  local itvars, iterator, block  = ast:args()
  coder:add_indent_ln("for ", itvars, ' in ', iterator, ' do')
  coder:add(block)
  coder:add_indent_ln("end")
end)

generator:register('Break', function(_, _, coder)
  coder:add_indent_ln('break')
end)

-- TODO: Continue

generator:register('Label', function(_, ast, coder)
  local name = ast:args()
  coder:add_indent_ln('::', name, '::')
end)

generator:register('Goto', function(_, ast, coder)
  local labelname = ast:args()
  coder:add_indent_ln('goto ', labelname)
end)

generator:register('VarDecl', function(_, ast, coder, scope)
  local varscope, mutability, vars, vals = ast:args()
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

generator:register('Assign', function(_, ast, coder)
  local vars, vals = ast:args()
  coder:add_indent_ln(vars, ' = ', vals)
end)

generator:register('FuncDef', function(_, ast, coder)
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
local function is_in_operator(context)
  local parent_ast = context:get_parent_ast()
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
generator:register('UnaryOp', function(context, ast, coder)
  local opname, arg = ast:args()
  if opname == 'tostring' then
    coder:add('tostring(', arg, ')')
  else
    local op = ast:assertf(LUA_UNARY_OPS[opname], 'unary operator "%s" not found', opname)
    local surround = is_in_operator(context)
    if surround then coder:add('(') end
    coder:add(op, arg)
    if surround then coder:add(')') end
  end
end)

local BINARY_OPS = {
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
  ['idiv'] = '//',
  ['mod'] = '%',
  ['pow'] = '^',
  ['concat'] = '..'
}
generator:register('BinaryOp', function(context, ast, coder)
  local opname, left_arg, right_arg = ast:args()
  local op = ast:assertf(BINARY_OPS[opname], 'binary operator "%s" not found', opname)
  local surround = is_in_operator(context)
  if surround then coder:add('(') end
  coder:add(left_arg, ' ', op, ' ', right_arg)
  if surround then coder:add(')') end
end)

generator:register('TernaryOp', function(context, ast, coder)
  local opname, left_arg, mid_arg, right_arg = ast:args()
  ast:assertf(opname == 'if', 'unknown ternary operator "%s"', opname)
  local surround = is_in_operator(context)
  if surround then coder:add('(') end
  coder:add(mid_arg, ' and ', left_arg, ' or ', right_arg)
  if surround then coder:add(')') end
end)

function generator:generate(ast)
  local context = self:newContext()
  local coder = Coder(context)
  context.coder = coder
  coder:add_traversal(ast)
  return coder:generate()
end

generator.compiler = require('euluna.compilers.lua_compiler')

return generator
