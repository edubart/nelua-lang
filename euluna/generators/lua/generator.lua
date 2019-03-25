local TraverseContext = require 'euluna.traversecontext'
local Coder = require 'euluna.coder'
local pegger = require 'euluna.utils.pegger'
local luadefs = require 'euluna.generators.lua.definitions'

local visitors = {}

-- primitives
function visitors.Number(_, ast, coder)
  local numtype, value, literal = ast:args()
  ast:assertraisef(literal == nil, 'literals are not supported in lua')
  if numtype == 'int' or numtype == 'dec' then
    coder:add(value)
  elseif numtype == 'exp' then
    coder:add(string.format('%se%s', value[1], value[2]))
  elseif numtype == 'hex' then
    coder:add(string.format('0x%s', value))
  elseif numtype == 'bin' then
    coder:add(string.format('%u', tonumber(value, 2)))
  else --luacov:disable
    ast:errorf('invalid number type "%s" for AST Number', numtype)
  end --luacov:enable
end

function visitors.String(_, ast, coder)
  local value, literal = ast:args()
  ast:assertraisef(literal == nil, 'literals are not supported in lua')
  local quoted_value
  if value:find('"') and not value:find("'") then
    quoted_value = pegger.single_quote_lua_string(value)
  else
    quoted_value = pegger.double_quote_lua_string(value)
  end
  coder:add(quoted_value)
end

function visitors.Boolean(_, ast, coder)
  local value = ast:args()
  coder:add(tostring(value))
end

function visitors.Nil(_, _, coder)
  coder:add('nil')
end

function visitors.Varargs(_, _, coder)
  coder:add('...')
end

-- table
function visitors.Table(_, ast, coder)
  local contents = ast:args()
  coder:add('{', contents, '}')
end

function visitors.Pair(_, ast, coder)
  local field, value = ast:args()
  if type(field) == 'string' then
    coder:add(field)
  else
    coder:add('[', field, ']')
  end
  coder:add(' = ', value)
end

-- function
function visitors.Function(_, ast, coder)
  local args, rets, block = ast:args()
  if #block[1] == 0 then
    coder:add('function(', args, ') end')
  else
    coder:add_ln('function(', args, ')')
    coder:add(block)
    coder:add_indent('end')
  end
end

-- identifier and types
function visitors.Id(_, ast, coder)
  local name = ast:args()
  coder:add(name)
end
function visitors.Paren(_, ast, coder)
  local what = ast:args()
  coder:add('(', what, ')')
end
function visitors.Type() end
function visitors.IdDecl(_, ast, coder)
  local name, type = ast:args()
  coder:add(name)
end
function visitors.FuncArg(_, ast, coder)
  local name, mut, type = ast:args()
  ast:assertraisef(mut == nil or mut == 'var', "variable mutabilities are not supported in lua")
  coder:add(name)
end

-- indexing
function visitors.DotIndex(_, ast, coder)
  local name, obj = ast:args()
  coder:add(obj, '.', name)
end

function visitors.ColonIndex(_, ast, coder)
  local name, obj = ast:args()
  coder:add(obj, ':', name)
end

function visitors.ArrayIndex(_, ast, coder)
  local index, obj = ast:args()
  coder:add(obj, '[', index, ']')
end

-- calls
function visitors.Call(_, ast, coder)
  local argtypes, args, caller, block_call = ast:args()
  if block_call then coder:add_indent() end
  coder:add(caller, '(', args, ')')
  if block_call then coder:add_ln() end
end

function visitors.CallMethod(_, ast, coder)
  local name, argtypes, args, caller, block_call = ast:args()
  if block_call then coder:add_indent() end
  coder:add(caller, ':', name, '(', args, ')')
  if block_call then coder:add_ln() end
end

-- block
function visitors.Block(context, ast, coder)
  local stats = ast:args()
  coder:inc_indent()
  context:push_scope()
  coder:add_traversal_list(stats, '')
  context:pop_scope()
  coder:dec_indent()
end

-- statements
function visitors.Return(_, ast, coder)
  local rets = ast:args()
  coder:add_indent("return")
  if #rets > 0 then
    coder:add(' ')
  end
  coder:add_ln(rets)
end

function visitors.If(_, ast, coder)
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
end

function visitors.Switch(_, ast, coder)
  local val, caseparts, switchelseblock = ast:args()
  local varname = '__switchval' .. ast.pos
  coder:add_indent_ln("local ", varname, " = ", val)
  ast:assertraisef(#caseparts > 0, "switch must have case parts")
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
end

function visitors.Do(_, ast, coder)
  local block = ast:args()
  coder:add_indent_ln("do")
  coder:add(block)
  coder:add_indent_ln("end")
end

function visitors.While(_, ast, coder)
  local cond, block = ast:args()
  coder:add_indent_ln("while ", cond, ' do')
  coder:add(block)
  coder:add_indent_ln("end")
end

function visitors.Repeat(_, ast, coder)
  local block, cond = ast:args()
  coder:add_indent_ln("repeat")
  coder:add(block)
  coder:add_indent_ln('until ', cond)
end

function visitors.ForNum(_, ast, coder)
  local itvar, beginval, comp, endval, incrval, block  = ast:args()
  ast:assertraisef(comp == 'le', 'for comparator not supported yet')
  coder:add_indent("for ", itvar, '=', beginval, ',', endval)
  if incrval then
    coder:add(',', incrval)
  end
  coder:add_ln(' do')
  coder:add(block)
  coder:add_indent_ln("end")
end

function visitors.ForIn(_, ast, coder)
  local itvars, iterator, block  = ast:args()
  coder:add_indent_ln("for ", itvars, ' in ', iterator, ' do')
  coder:add(block)
  coder:add_indent_ln("end")
end

function visitors.Break(_, _, coder)
  coder:add_indent_ln('break')
end

-- TODO: Continue

function visitors.Label(_, ast, coder)
  local name = ast:args()
  coder:add_indent_ln('::', name, '::')
end

function visitors.Goto(_, ast, coder)
  local labelname = ast:args()
  coder:add_indent_ln('goto ', labelname)
end

function visitors.VarDecl(context, ast, coder)
  local varscope, mutability, vars, vals = ast:args()
  local is_local = (varscope == 'local') or not context.scope:is_main()
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
end

function visitors.Assign(_, ast, coder)
  local vars, vals = ast:args()
  coder:add_indent_ln(vars, ' = ', vals)
end

function visitors.FuncDef(_, ast, coder)
  local varscope, name, args, rets, block = ast:args()
  coder:add_indent()
  if varscope == 'local' then
    coder:add('local ')
  end
  coder:add_ln('function ', name, '(', args, ')')
  coder:add(block)
  coder:add_indent_ln('end')
end

-- operators
local function is_in_operator(context)
  local parent_ast = context:get_parent_ast()
  if not parent_ast then return false end
  local parent_ast_tag = parent_ast.tag
  return
    parent_ast_tag == 'UnaryOp' or
    parent_ast_tag == 'BinaryOp'
end

function visitors.UnaryOp(context, ast, coder)
  local opname, arg = ast:args()
  if opname == 'tostring' then
    coder:add('tostring(', arg, ')')
  else
    local op = ast:assertraisef(luadefs.unary_ops[opname], 'unary operator "%s" not found', opname)
    local surround = is_in_operator(context)
    if surround then coder:add('(') end
    coder:add(op, arg)
    if surround then coder:add(')') end
  end
end

function visitors.BinaryOp(context, ast, coder)
  local opname, left_arg, right_arg = ast:args()
  local op = ast:assertraisef(luadefs.binary_ops[opname], 'binary operator "%s" not found', opname)
  local surround = is_in_operator(context)
  if surround then coder:add('(') end
  coder:add(left_arg, ' ', op, ' ', right_arg)
  if surround then coder:add(')') end
end

local generator = {}

function generator.generate(ast)
  local context = TraverseContext(visitors)
  local coder = Coder(context)
  context.coder = coder
  coder:add_traversal(ast)
  return coder:generate()
end

generator.compiler = require('euluna.generators.lua.compiler')

return generator
