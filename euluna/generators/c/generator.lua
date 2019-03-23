local Coder = require 'euluna.coder'
local pegger = require 'euluna.utils.pegger'
local iters = require 'euluna.utils.iterators'
local cdefs = require 'euluna.generators.c.definitions'
local cbuiltins = require 'euluna.generators.c.builtins'
local CContext = require 'euluna.generators.c.context'

local visitors = {}

function visitors.Number(context, ast, coder)
  local numtype, value, literal = ast:args()
  local cval
  if numtype == 'int' then
    cval = value
  elseif numtype == 'dec' then
    cval = value
  elseif numtype == 'exp' then
    cval = string.format('%se%s', value[1], value[2])
  elseif numtype == 'hex' then
    cval = string.format('0x%s', value)
  elseif numtype == 'bin' then
    cval = string.format('%u', tonumber(value, 2))
  else --luacov:disable
    ast:errorf('invalid number type "%s" for AST Number', numtype)
  end --luacov:enable
  if literal then
    local ctype = context:get_ctype(ast)
    coder:add('((', ctype, ') ', cval, ')')
  else
    coder:add(cval)
  end
end

function visitors.String(context, ast, coder)
  local value, literal = ast:args()
  ast:assertraisef(literal == nil, 'literals are not supported yet')
  local deccoder = context.declarations_coder
  local len = #value
  local varname = '__string_literal_' .. ast.pos

  local quoted_value = pegger.double_quote_c_string(value)
  context:add_include('<stdint.h>')
  deccoder:add_indent_ln('static const struct { uintptr_t len, res; char data[', len + 1, ']; }')
  deccoder:add_indent_ln('  ', varname, ' = {', len, ', ', len, ', ', quoted_value, '};')
  coder:add(varname)
end

function visitors.Boolean(context, ast, coder)
  local value = ast:args()
  context:add_include('<stdbool.h>')
  coder:add(tostring(value))
end

-- TODO: Nil
-- TODO: Varargs
-- TODO: Table
-- TODO: Pair
-- TODO: Function

-- identifier and types
function visitors.Id(_, ast, coder)
  local name = ast:args()
  coder:add(name)
end
function visitors.Paren(_, ast, coder)
  local what = ast:args()
  coder:add('(', what, ')')
end
function visitors.Type(context, ast, coder)
  local ctype = context:get_ctype(ast)
  coder:add(ctype)
end
function visitors.TypedId(context, ast, coder)
  local name = ast:args()
  if ast.type then
    local ctype = context:get_ctype(ast)
    coder:add(ctype, ' ', name)
  else
    coder:add(name)
  end
end

-- indexing
function visitors.DotIndex(_, ast, coder)
  local name, obj = ast:args()
  coder:add(obj, '.', name)
end

-- TODO: ColonIndex

function visitors.ArrayIndex(_, ast, coder)
  local index, obj = ast:args()
  coder:add(obj, '[', index, ']')
end

-- calls
function visitors.Call(context, ast, coder)
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
end

function visitors.CallMethod(_, ast, coder)
  local name, argtypes, args, caller, block_call = ast:args()
  if block_call then coder:add_indent() end
  coder:add(caller, '.', name, '(', caller, args, ')')
  if block_call then coder:add_ln() end
end

function visitors.FuncArg(_, ast, coder)
  local name, mut, type = ast:args()
  ast:assertraisef(mut == nil or mut == 'var', "variable mutabilities are not supported yet")
  coder:add(type, ' ', name)
end

-- block
function visitors.Block(context, ast, coder, scope)
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
end

-- statements
function visitors.Return(_, ast, coder, scope)
  --TODO: multiple return
  scope.has_return = true
  local rets = ast:args()
  ast:assertraisef(#rets <= 1, "multiple returns not supported yet")
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
end

function visitors.If(_, ast, coder)
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
end

function visitors.Switch(_, ast, coder)
  local val, caseparts, switchelseblock = ast:args()
  coder:add_indent_ln("switch(", val, ") {")
  coder:inc_indent()
  ast:assertraisef(#caseparts > 0, "switch must have case parts")
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
end

function visitors.Do(_, ast, coder)
  local block = ast:args()
  coder:add_indent_ln("{")
  coder:add(block)
  coder:add_indent_ln("}")
end

function visitors.While(_, ast, coder)
  local cond, block = ast:args()
  coder:add_indent_ln("while(", cond, ') {')
  coder:add(block)
  coder:add_indent_ln("}")
end

function visitors.Repeat(_, ast, coder)
  local block, cond = ast:args()
  coder:add_indent_ln("do {")
  coder:add(block)
  coder:add_indent_ln('} while(!(', cond, '));')
end

function visitors.ForNum(_, ast, coder)
  local itvar, beginval, comp, endval, incrval, block  = ast:args()
  ast:assertraisef(comp == 'le', 'for comparator not supported yet')
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
end

-- TODO: ForIn

function visitors.Break(_, _, coder)
  coder:add_indent_ln('break;')
end

function visitors.Continue(_, _, coder)
  coder:add_indent_ln('continue;')
end

function visitors.Label(_, ast, coder)
  local name = ast:args()
  coder:add_indent_ln(name, ':')
end

function visitors.Goto(_, ast, coder)
  local labelname = ast:args()
  coder:add_indent_ln('goto ', labelname, ';')
end

function visitors.VarDecl(_, ast, coder)
  local varscope, mutability, vars, vals = ast:args()
  ast:assertraisef(varscope == 'local', 'global variables not supported yet')
  ast:assertraisef(not vals or #vars == #vals, 'vars and vals count differs')
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
end


function visitors.Assign(_, ast, coder)
  local vars, vals = ast:args()
  ast:assertraisef(#vars == #vals, 'vars and vals count differs')
  coder:add_indent()
  for i,var,val in iters.izip(vars, vals) do
    if i > 1 then coder:add(' ') end
    coder:add(var, ' = ', val, ';')
  end
  coder:add_ln()
end

function visitors.FuncDef(context, ast)
  local varscope, name, args, rets, block = ast:args()
  ast:assertraisef(#rets <= 1, 'multiple returns not supported yet')
  ast:assertraisef(varscope == 'local', 'non local scope for functions not supported yet')
  local coder = context.declarations_coder
  if #rets == 0 then
    coder:add_indent('void ')
  else
    local ret = rets[1]
    ast:assertraisef(ret.tag == 'Type')
    coder:add_indent(ret, ' ')
  end
  coder:add_ln(name, '(', args, ') {')
  coder:add(block)
  coder:add_indent_ln('}')
end

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

function visitors.UnaryOp(context, ast, coder)
  local opname, arg = ast:args()
  local op = ast:assertraisef(cdefs.UNARY_OPS[opname], 'unary operator "%s" not found', opname)
  local surround = is_in_operator(context)
  if surround then coder:add('(') end
  coder:add(op, arg)
  if surround then coder:add(')') end
end

function visitors.BinaryOp(context, ast, coder)
  local opname, left_arg, right_arg = ast:args()
  local op = ast:assertraisef(cdefs.BINARY_OPS[opname], 'binary operator "%s" not found', opname)
  local surround = is_in_operator(context)
  if surround then coder:add('(') end
  coder:add(left_arg, ' ', op, ' ', right_arg)
  if surround then coder:add(')') end
end

function visitors.TernaryOp(context, ast, coder)
  local opname, left_arg, mid_arg, right_arg = ast:args()
  ast:assertraisef(opname == 'if', 'unknown ternary operator "%s"', opname)
  local surround = is_in_operator(context)
  if surround then coder:add('(') end
  coder:add(mid_arg, ' ? ', left_arg, ' : ', right_arg)
  if surround then coder:add(')') end
end

local generator = {}

function generator.generate(ast)
  local context = CContext(visitors)
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
