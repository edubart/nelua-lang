local Traverser = require 'euluna.traverser'
local Coder = require 'euluna.coder'
local pegger = require 'euluna.utils.pegger'
local iters = require 'euluna.utils.iterators'
local cdefs = require 'euluna.generators.c.definitions'
local cbuiltins = require 'euluna.generators.c.builtins'
local CContext = require 'euluna.generators.c.context'

local generator = Traverser()
generator.Context = CContext

generator:register('Number', function(context, ast, coder)
  local numtype, value, literal = ast:args()
  local cval
  if numtype == 'int' then
    cval = value
  elseif numtype == 'dec' then
    cval = value
  elseif numtype == 'exp' then
    cval = string.format('%se%s', value[1], value[2])
  elseif numtype == 'hex' then
    cval = string.format('0x%su', value)
  elseif numtype == 'bin' then
    cval = string.format('%uu', tonumber(value, 2))
  else --luacov:disable
    ast:errorf('invalid number type "%s" for AST Number', numtype)
  end --luacov:enable
  if literal then
    local ctype = context:get_ctype(ast)
    coder:add('((', ctype, ') ', cval, ')')
  else
    coder:add(cval)
  end
end)

generator:register('String', function(context, ast, coder)
  local value, literal = ast:args()
  ast:assertf(literal == nil, 'literals are not supported yet')
  local deccoder = context.declarations_coder
  local len = #value
  local varname = '__string_literal_' .. ast.pos

  local quoted_value = pegger.double_quote_c_string(value)
  context:add_include('<stdint.h>')
  deccoder:add_indent('static const struct { uintptr_t len, res; char data[')
  deccoder:add(len + 1)
  deccoder:add_ln(']; }')
  deccoder:add_indent('  ', varname, ' = {', len, ', ', len, ', ')
  deccoder:add(quoted_value)
  deccoder:add_ln('};')
  coder:add(varname)
end)

generator:register('Boolean', function(context, ast, coder)
  local value = ast:args()
  context:add_include('<stdbool.h>')
  coder:add(tostring(value))
end)

-- TODO: Nil
-- TODO: Varargs
-- TODO: Table
-- TODO: Pair
-- TODO: Function

-- identifier and types
generator:register('Id', function(_, ast, coder)
  local name = ast:args()
  coder:add(name)
end)
generator:register('Paren', function(_, ast, coder)
  local what = ast:args()
  coder:add('(', what, ')')
end)
generator:register('Type', function(context, ast, coder)
  local ctype = context:get_ctype(ast)
  coder:add(ctype)
end)
generator:register('TypedId', function(context, ast, coder)
  local name = ast:args()
  if ast.type then
    local ctype = context:get_ctype(ast)
    coder:add(ctype, ' ', name)
  else
    coder:add(name)
  end
end)

-- indexing
generator:register('DotIndex', function(_, ast, coder)
  local name, obj = ast:args()
  coder:add(obj, '.', name)
end)

-- TODO: ColonIndex

generator:register('ArrayIndex', function(_, ast, coder)
  local index, obj = ast:args()
  coder:add(obj, '[', index, ']')
end)

-- calls
generator:register('Call', function(context, ast, coder)
  local argtypes, args, caller, block_call = ast:args()
  if block_call then coder:add_indent() end
  local builtin
  if caller.tag == 'Id' then
    local fname = caller[1]
    builtin = cbuiltins.functions[fname]
  end
  if builtin then
    builtin(context, ast, coder)
  else
    coder:add(caller, '(', args, ')')
  end
  if block_call then coder:add_ln(";") end
end)

generator:register('CallMethod', function(_, ast, coder)
  local name, argtypes, args, caller, block_call = ast:args()
  if block_call then coder:add_indent() end
  coder:add(caller, '.', name, '(', caller, args, ')')
  if block_call then coder:add_ln() end
end)

generator:register('FuncArg', function(_, ast, coder)
  local name, mut, type = ast:args()
  ast:assertf(mut == nil or mut == 'var', "variable mutabilities are not supported yet")
  coder:add(type, ' ', name)
end)

-- block
generator:register('Block', function(context, ast, coder, scope)
  local stats = ast:args()
  local is_top_scope = scope:is_top()
  if is_top_scope then
    coder:inc_indent()
    coder:add_ln("int main() {")
  end
  coder:inc_indent()
  local inner_scope = context:push_scope()
  coder:add_traversal_list(stats, '')
  if inner_scope:is_main() and not inner_scope.has_return then
    -- main() must always return an integer
    coder:add_indent_ln("return 0;")
  end
  context:pop_scope()
  coder:dec_indent()
  if is_top_scope then
    coder:add_ln("}")
    coder:dec_indent()
  end
end)

-- statements
generator:register('Return', function(_, ast, coder, scope)
  --TODO: multiple return
  scope.has_return = true
  local rets = ast:args()
  ast:assertf(#rets <= 1, "multiple returns not supported yet")
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

generator:register('If', function(_, ast, coder)
  local ifparts, elseblock = ast:args()
  for i,ifpart in ipairs(ifparts) do
    local cond, block = ifpart[1], ifpart[2]
    if i == 1 then
      coder:add_indent("if(")
      coder:add(cond)
      coder:add_ln(") {")
    else
      coder:add_indent("} else if(")
      coder:add(cond)
      coder:add_ln(") {")
    end
    coder:add(block)
  end
  if elseblock then
    coder:add_indent_ln("} else {")
    coder:add(elseblock)
  end
  coder:add_indent_ln("}")
end)

generator:register('Switch', function(_, ast, coder)
  local val, caseparts, switchelseblock = ast:args()
  coder:add_indent_ln("switch(", val, ") {")
  coder:inc_indent()
  ast:assertf(#caseparts > 0, "switch must have case parts")
  for casepart in iters.ivalues(caseparts) do
    local caseval, caseblock = casepart[1], casepart[2]
    coder:add_indent_ln("case ", caseval, ': {')
    coder:add(caseblock)
    coder:inc_indent() coder:add_indent_ln('break;') coder:dec_indent()
    coder:add_indent_ln("}")
  end
  if switchelseblock then
    coder:add_indent_ln('default: {')
    coder:add(switchelseblock)
    coder:inc_indent() coder:add_indent_ln('break;') coder:dec_indent()
    coder:add_indent_ln("}")
  end
  coder:dec_indent()
  coder:add_indent_ln("}")
end)

generator:register('Do', function(_, ast, coder)
  local block = ast:args()
  coder:add_indent_ln("{")
  coder:add(block)
  coder:add_indent_ln("}")
end)

generator:register('While', function(_, ast, coder)
  local cond, block = ast:args()
  coder:add_indent_ln("while(", cond, ') {')
  coder:add(block)
  coder:add_indent_ln("}")
end)

generator:register('Repeat', function(_, ast, coder)
  local block, cond = ast:args()
  coder:add_indent_ln("do {")
  coder:add(block)
  coder:add_indent_ln('} while(!(', cond, '));')
end)

generator:register('ForNum', function(_, ast, coder)
  local itvar, beginval, comp, endval, incrval, block  = ast:args()
  ast:assertf(comp == 'le', 'for comparator not supported yet')
  local itname = itvar[1]
  coder:add_indent("for(", itvar, ' = ', beginval, '; ', itname, ' <= ', endval, '; ')
  if incrval then
    coder:add(itname, ' += ', incrval)
  else
    coder:add('++', itname)
  end
  coder:add_ln(') {')
  coder:add(block)
  coder:add_indent_ln("}")
end)

-- TODO: ForIn

generator:register('Break', function(_, _, coder)
  coder:add_indent_ln('break;')
end)

generator:register('Continue', function(_, _, coder)
  coder:add_indent_ln('continue;')
end)

generator:register('Label', function(_, ast, coder)
  local name = ast:args()
  coder:add_indent_ln(name, ':')
end)

generator:register('Goto', function(_, ast, coder)
  local labelname = ast:args()
  coder:add_indent_ln('goto ', labelname, ';')
end)

generator:register('VarDecl', function(_, ast, coder)
  local varscope, mutability, vars, vals = ast:args()
  ast:assertf(varscope == 'local', 'global variables not supported yet')
  ast:assertf(not vals or #vars == #vals, 'vars and vals count differs')
  coder:add_indent()
  for i,var,val in iters.izip(vars, vals or {}) do
    if i > 1 then coder:add(' ') end
    coder:add(var)
    if val then
      coder:add(' = ', val)
    end
    coder:add(';')
  end
  coder:add_ln()
end)


generator:register('Assign', function(_, ast, coder)
  local vars, vals = ast:args()
  ast:assertf(#vars == #vals, 'vars and vals count differs')
  coder:add_indent()
  for i,var,val in iters.izip(vars, vals) do
    if i > 1 then coder:add(' ') end
    coder:add(var, ' = ', val, ';')
  end
  coder:add_ln()
end)

generator:register('FuncDef', function(context, ast)
  local varscope, name, args, rets, block = ast:args()
  ast:assertf(#rets <= 1, 'multiple returns not supported yet')
  ast:assertf(varscope == 'local', 'non local scope for functions not supported yet')
  local coder = context.declarations_coder
  if #rets == 0 then
    coder:add_indent('void ')
  else
    local ret = rets[1]
    ast:assertf(ret.tag == 'Type')
    coder:add_indent(ret, ' ')
  end
  coder:add_ln(name, '(', args, ') {')
  coder:add(block)
  coder:add_indent_ln('}')
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

generator:register('UnaryOp', function(context, ast, coder)
  local opname, arg = ast:args()
  local op = ast:assertf(cdefs.UNARY_OPS[opname], 'unary operator "%s" not found', opname)
  local surround = is_in_operator(context)
  if surround then coder:add('(') end
  coder:add(op, arg)
  if surround then coder:add(')') end
end)

generator:register('BinaryOp', function(context, ast, coder)
  local opname, left_arg, right_arg = ast:args()
  local op = ast:assertf(cdefs.BINARY_OPS[opname], 'binary operator "%s" not found', opname)
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
  coder:add(mid_arg, ' ? ', left_arg, ' : ', right_arg)
  if surround then coder:add(')') end
end)

function generator:generate(ast)
  local context = self:newContext()
  local indent = '    '

  context.includes_coder = Coder(context, indent, 0)
  context.builtins_declarations_coder = Coder(context, indent, 0)
  context.builtins_definitions_coder = Coder(context, indent, 0)
  context.declarations_coder = Coder(context, indent, 0)
  context.definitions_coder = Coder(context, indent, 0)
  context.main_coder = Coder(context, indent)

  context.main_coder:add_traversal(ast)

  local code = table.concat({
    context.includes_coder:generate(),
    context.builtins_declarations_coder:generate(),
    context.builtins_definitions_coder:generate(),
    context.declarations_coder:generate(),
    context.definitions_coder:generate(),
    context.main_coder:generate()
  })

  return code
end

generator.compiler = require('euluna.generators.c.compiler')

return generator
