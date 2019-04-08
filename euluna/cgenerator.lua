local Emitter = require 'euluna.emitter'
local pegger = require 'euluna.utils.pegger'
local iters = require 'euluna.utils.iterators'
local traits = require 'euluna.utils.traits'
local cdefs = require 'euluna.cdefs'
local cbuiltins = require 'euluna.cbuiltins'
local typedefs = require 'euluna.typedefs'
local fs = require 'euluna.utils.fs'
local config = require 'euluna.configer'.get()
local CContext = require 'euluna.ccontext'

local visitors = {}

local function add_casted_value(_, emitter, type, valnode)
  if type:is_any() then
    if valnode then
      if valnode.type:is_any() then
        emitter:add(valnode)
      else
        emitter:add('(euluna_any_t){&euluna_type_',
                  valnode.type:codegen_name(), ', {', valnode, '}}')
      end
    else
      emitter:add('(euluna_any_t){&euluna_type_nil, {0}}')
    end
  elseif valnode then
    if valnode.type:is_any() then
      emitter:add('euluna_cast_any_', type:codegen_name(), '(', valnode, ')')
    elseif type == valnode.type then
      emitter:add(valnode)
    elseif valnode.type:is_number() and type:is_number() then
      emitter:add(valnode)
    --else
      --emitter:add('(',context:get_ctype(type, valnode),')',valnode)
    end
  else
    emitter:add('{0}')
  end
end

function visitors.Number(context, node, emitter)
  local base, int, frac, exp, literal = node:args()
  if literal then
    local ctype = context:get_ctype(node)
    emitter:add('((', ctype, ')')
  end
  emitter:add_composed_number(base, int, frac, exp)
  if literal then
    emitter:add(')')
  end
end

function visitors.String(context, node, emitter)
  local value, literal = node:args()
  node:assertraisef(literal == nil, 'literals are not supported yet')
  local decemitter = context.declarations_emitter
  local len = #value
  local varname = '__string_literal_' .. node.pos
  local quoted_value = pegger.double_quote_c_string(value)
  decemitter:add_indent_ln('static const struct { uintptr_t len, res; char data[', len + 1, ']; }')
  decemitter:add_indent_ln('  ', varname, ' = {', len, ', ', len, ', ', quoted_value, '};')
  emitter:add('(const euluna_string_t*)&', varname)
end

function visitors.Boolean(_, node, emitter)
  local value = node:args()
  emitter:add(tostring(value))
end

-- TODO: Nil
-- TODO: Varargs
-- TODO: Table
-- TODO: Pair
-- TODO: Function

-- identifier and types
function visitors.Id(_, node, emitter)
  local name = node:args()
  emitter:add(name)
end

function visitors.Paren(_, node, emitter)
  local what = node:args()
  emitter:add('(', what, ')')
end

function visitors.Type(context, node, emitter)
  local ctype = context:get_ctype(node)
  emitter:add(ctype)
end

visitors.FuncType = visitors.Type
visitors.ComposedType = visitors.Type

function visitors.IdDecl(context, node, emitter)
  local name, mut = node:args()
  node:assertraisef(mut == nil or mut == 'var', "variable mutabilities are not supported yet")
  local ctype = context:get_ctype(node)
  emitter:add(ctype, ' ', name)
end

-- indexing
function visitors.DotIndex(_, node, emitter)
  local name, obj = node:args()
  emitter:add(obj, '.', name)
end

-- TODO: ColonIndex

function visitors.ArrayIndex(_, node, emitter)
  local index, varnode = node:args()
  if varnode.type:is_arraytable() then
    emitter:add('*euluna_arrtab_',
      node.type:codegen_name(),
      node.assign and '_at(&' or '_get(&',
      varnode, ', ', index, ')')
  else
    emitter:add(varnode, '[', index, ']')
  end
end

-- calls
function visitors.Call(context, node, emitter)
  local argtypes, args, callee, block_call = node:args()
  if block_call then emitter:add_indent() end
  local builtin
  if callee.tag == 'Id' then
    local fname = callee[1]
    builtin = cbuiltins[fname]
  end
  if builtin then
    callee = builtin(context, node, emitter)
  end
  emitter:add(callee, '(')
  if node.callee_type and node.callee_type:is_function() then
    for i,argtype,argnode in iters.izip(node.callee_type.argtypes, args) do
      if i > 1 then emitter:add(', ') end
      add_casted_value(context, emitter, argtype, argnode)
    end
  else
    --TODO: handle better calls on any types
    emitter:add(args)
  end
  emitter:add(')')
  if block_call then emitter:add_ln(";") end
end

function visitors.CallMethod(_, node, emitter)
  local name, argtypes, args, callee, block_call = node:args()
  if block_call then emitter:add_indent() end
  emitter:add(callee, '.', name, '(', callee, args, ')')
  if block_call then emitter:add_ln() end
end

-- block
function visitors.Block(context, node, emitter)
  local stats = node:args()
  local is_top_scope = context.scope:is_top()
  if is_top_scope then
    emitter:inc_indent()
    emitter:add_ln("int euluna_main() {")
  end
  emitter:inc_indent()
  local inner_scope = context:push_scope()
  emitter:add_traversal_list(stats, '')
  if inner_scope:is_main() and not inner_scope.has_return then
    -- main() must always return an integer
    emitter:add_indent_ln("return 0;")
  end
  context:pop_scope()
  emitter:dec_indent()
  if is_top_scope then
    emitter:add_ln("}")
    emitter:dec_indent()
  end
end

-- statements
function visitors.Return(context, node, emitter)
  --TODO: multiple return
  local scope = context.scope
  scope.has_return = true
  local rets = node:args()
  node:assertraisef(#rets <= 1, "multiple returns not supported yet")
  emitter:add_indent("return")
  if #rets > 0 then
    emitter:add_ln(' ', rets, ';')
  else
    if scope:is_main() then
      -- main() must always return an integer
      emitter:add(' 0')
    end
    emitter:add_ln(';')
  end
end

function visitors.If(_, node, emitter)
  local ifparts, elseblock = node:args()
  for i,ifpart in ipairs(ifparts) do
    local cond, block = ifpart[1], ifpart[2]
    if i == 1 then
      emitter:add_indent("if(")
      emitter:add(cond)
      emitter:add_ln(") {")
    else
      emitter:add_indent("} else if(")
      emitter:add(cond)
      emitter:add_ln(") {")
    end
    emitter:add(block)
  end
  if elseblock then
    emitter:add_indent_ln("} else {")
    emitter:add(elseblock)
  end
  emitter:add_indent_ln("}")
end

function visitors.Switch(_, node, emitter)
  local val, caseparts, switchelseblock = node:args()
  emitter:add_indent_ln("switch(", val, ") {")
  emitter:inc_indent()
  node:assertraisef(#caseparts > 0, "switch must have case parts")
  for casepart in iters.ivalues(caseparts) do
    local caseval, caseblock = casepart[1], casepart[2]
    emitter:add_indent_ln("case ", caseval, ': {')
    emitter:add(caseblock)
    emitter:inc_indent() emitter:add_indent_ln('break;') emitter:dec_indent()
    emitter:add_indent_ln("}")
  end
  if switchelseblock then
    emitter:add_indent_ln('default: {')
    emitter:add(switchelseblock)
    emitter:inc_indent() emitter:add_indent_ln('break;') emitter:dec_indent()
    emitter:add_indent_ln("}")
  end
  emitter:dec_indent()
  emitter:add_indent_ln("}")
end

function visitors.Do(_, node, emitter)
  local block = node:args()
  emitter:add_indent_ln("{")
  emitter:add(block)
  emitter:add_indent_ln("}")
end

function visitors.While(_, node, emitter)
  local cond, block = node:args()
  emitter:add_indent_ln("while(", cond, ') {')
  emitter:add(block)
  emitter:add_indent_ln("}")
end

function visitors.Repeat(_, node, emitter)
  local block, cond = node:args()
  emitter:add_indent_ln("do {")
  emitter:add(block)
  emitter:add_indent_ln('} while(!(', cond, '));')
end

function visitors.ForNum(context, node, emitter)
  local itvar, beginval, comp, endval, incrval, block  = node:args()
  node:assertraisef(comp == 'le', 'for comparator not supported yet')
  --TODO: evaluate beginval, endval, incrval only once in case of expressions
  local itname = itvar[1]
  emitter:add_indent("for(", itvar, ' = ')
  add_casted_value(context, emitter, itvar.type, beginval)
  emitter:add('; ', itname, ' <= ')
  add_casted_value(context, emitter, itvar.type, endval)
  emitter:add_ln('; ', itname, ' += ', incrval or '1', ') {')
  emitter:add(block)
  emitter:add_indent_ln("}")
end

-- TODO: ForIn

function visitors.Break(_, _, emitter)
  emitter:add_indent_ln('break;')
end

function visitors.Continue(_, _, emitter)
  emitter:add_indent_ln('continue;')
end

function visitors.Label(_, node, emitter)
  local name = node:args()
  emitter:add_indent_ln(name, ':')
end

function visitors.Goto(_, node, emitter)
  local labelname = node:args()
  emitter:add_indent_ln('goto ', labelname, ';')
end

local function add_assignments(context, emitter, vars, vals)
  for i,var,val in iters.izip(vars, vals or {}) do
    if i > 1 then emitter:add(' ') end
    emitter:add(var, ' = ')
    add_casted_value(context, emitter, var.type, val)
    emitter:add(';')
  end
end

function visitors.VarDecl(context, node, emitter)
  local varscope, mutability, vars, vals = node:args()
  node:assertraisef(varscope == 'local', 'global variables not supported yet')
  node:assertraisef(not vals or #vars == #vals, 'vars and vals count differs')
  emitter:add_indent()
  add_assignments(context, emitter, vars, vals)
  emitter:add_ln()
end

function visitors.Assign(context, node, emitter)
  local vars, vals = node:args()
  node:assertraisef(#vars == #vals, 'vars and vals count differs')
  emitter:add_indent()
  add_assignments(context, emitter, vars, vals)
  emitter:add_ln()
end

function visitors.FuncDef(context, node)
  local varscope, varnode, args, rets, block = node:args()
  node:assertraisef(#rets <= 1, 'multiple returns not supported yet')
  node:assertraisef(varscope == 'local', 'non local scope for functions not supported yet')
  local emitter = context.declarations_emitter
  if #rets == 0 then
    emitter:add_indent('void ')
  else
    local ret = rets[1]
    node:assertraisef(ret.tag == 'Type')
    emitter:add_indent(ret, ' ')
  end
  emitter:add_ln(varnode, '(', args, ') {')
  emitter:add(block)
  emitter:add_indent_ln('}')
end

-- operators
local function is_in_operator(context)
  local parent_node = context:get_parent_node()
  if not parent_node then return false end
  local parent_node_tag = parent_node.tag
  return
    parent_node_tag == 'UnaryOp' or
    parent_node_tag == 'BinaryOp'
end

function visitors.UnaryOp(context, node, emitter)
  local opname, arg = node:args()
  local op = node:assertraisef(cdefs.unary_ops[opname], 'unary operator "%s" not found', opname)
  local surround = is_in_operator(context)
  if surround then emitter:add('(') end
  emitter:add(op, arg)
  if surround then emitter:add(')') end
end

function visitors.BinaryOp(context, node, emitter)
  local opname, lnode, rnode = node:args()
  local op = node:assertraisef(cdefs.binary_ops[opname], 'binary operator "%s" not found', opname)
  local surround = is_in_operator(context)
  if surround then emitter:add('(') end

  if typedefs.binary_conditional_ops[opname] and not node.type:is_boolean() then
    --TODO: create a temporary function in case of expressions and evaluate in order
    if opname == 'and' then
      --TODO: usa nilable values here
      emitter:add('(', lnode, ' && ', rnode, ') ? ', rnode, ' : 0')
    elseif opname == 'or' then
      emitter:add(lnode, ' ? ', lnode, ' : ', rnode)
    end
  else
    if traits.is_string(op) then
      emitter:add(lnode, ' ', op, ' ', rnode)
    else
      local func = cbuiltins[opname]
      assert(func, 'impossible')
      func(context, node, emitter, lnode, rnode)
    end
  end
  if surround then emitter:add(')') end
end

local generator = {}

local function build_runtime_code(context)
  local decs, defs = {}, {}
  for filename in iters.ivalues(cdefs.runtime_files) do
    local hfile = fs.join(config.runtime_path, 'c', filename .. '.h')
    local cfile = fs.join(config.runtime_path, 'c', filename .. '.c')
    local deccode = pegger.render_template(fs.tryreadfile(hfile), { context = context })
    local defcode = pegger.render_template(fs.tryreadfile(cfile), { context = context })
    table.insert(decs, deccode)
    table.insert(defs, defcode)
  end
  return table.concat(decs), table.concat(defs)
end

function generator.generate(ast)
  local context = CContext(visitors)
  local indent = '    '

  context.builtins_declarations_emitter = Emitter(context, indent, 0)
  context.builtins_definitions_emitter = Emitter(context, indent, 0)
  context.declarations_emitter = Emitter(context, indent, 0)
  context.definitions_emitter = Emitter(context, indent, 0)
  context.main_emitter = Emitter(context, indent)

  context.main_emitter:add_traversal(ast)
  local runtime_declarations, runtime_definitions = build_runtime_code(context)

  local code = table.concat({
    '#define EULUNA_COMPILER\n',
    runtime_declarations,
    runtime_definitions,
    context.builtins_declarations_emitter:generate(),
    context.builtins_definitions_emitter:generate(),
    context.declarations_emitter:generate(),
    context.definitions_emitter:generate(),
    context.main_emitter:generate(),
  })

  return code
end

generator.compiler = require('euluna.ccompiler')

return generator
