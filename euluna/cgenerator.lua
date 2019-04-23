local Emitter = require 'euluna.emitter'
local iters = require 'euluna.utils.iterators'
local traits = require 'euluna.utils.traits'
local pegger = require 'euluna.utils.pegger'
local fs = require 'euluna.utils.fs'
local config = require 'euluna.configer'.get()
local cdefs = require 'euluna.cdefs'
local cbuiltins = require 'euluna.cbuiltins'
local typedefs = require 'euluna.typedefs'
local CContext = require 'euluna.ccontext'
local primtypes = typedefs.primtypes
local visitors = {}

local function add_casted_value(context, emitter, type, valnode)
  if type:is_any() then
    if valnode then
      if valnode.attr.type:is_any() then
        emitter:add(valnode)
      else
        emitter:add('(', context:get_ctype(primtypes.any), '){&',
                  context:get_typectype(valnode), ', {', valnode, '}}')
      end
    else
      emitter:add('(', context:get_ctype(primtypes.any), '){&',
        context:get_typectype(primtypes.Nil), ', {0}}')
    end
  elseif valnode then
    if valnode.attr.type:is_any() then
      context:get_ctype(primtypes.any) -- to inject any builtin
      emitter:add(context:get_ctype(type), '_any_cast(', valnode, ')')
    elseif type == valnode.attr.type or valnode.attr.type:is_numeric() and type:is_numeric() then
      emitter:add(valnode)
    elseif valnode.attr.type:is_string() and type:is_cstring() then
      emitter:add('(', valnode, ')->data')
    else
      emitter:add('(',context:get_ctype(type, valnode),')',valnode)
    end
  else
    emitter:add('{0}')
  end
end

function visitors.Number(context, node, emitter)
  local base, int, frac, exp, literal = node:args()
  local isintegral = not frac and node.attr.value:isintegral()
  local suffix
  if node.attr.type:is_unsigned() then
    suffix = 'U'
  elseif node.attr.type:is_float32() and base == 'dec' then
    suffix = isintegral and '.0f' or 'f'
  elseif node.attr.type:is_float64() and base == 'dec' then
    suffix = isintegral and '.0' or ''
  end

  if not node.attr.type:is_float() and literal then
    emitter:add('(', context:get_ctype(node.attr.type), ')')
  end

  emitter:add_composed_number(base, int, frac, exp, node.attr.value:abs())
  if suffix then
    emitter:add(suffix)
  end
end

function visitors.String(context, node, emitter)
  local value, literal = node:args()
  node:assertraisef(literal == nil, 'literals are not supported yet')
  local decemitter = Emitter(context)
  local len = #value
  local varname = '__string_literal_' .. node.pos
  local quoted_value = pegger.double_quote_c_string(value)
  decemitter:add_indent_ln('static const struct { uintptr_t len, res; char data[', len + 1, ']; }')
  decemitter:add_indent_ln('  ', varname, ' = {', len, ', ', len, ', ', quoted_value, '};')
  emitter:add('(const ', context:get_ctype(primtypes.string), ')&', varname)
  context:add_declaration(decemitter:generate(), varname)
end

function visitors.Boolean(_, node, emitter)
  local value = node:args()
  emitter:add(tostring(value))
end

function visitors.Pair(_, node, emitter, parent_type)
  local namenode, valuenode = node:args()
  if parent_type:is_record() then
    assert(traits.is_string(namenode))
    emitter:add('.', cdefs.quotename(namenode), ' = ', valuenode)
  else --luacov:disable
    error('not implemented yet')
  end --luacov:enable
end

function visitors.Table(context, node, emitter)
  local childnodes = node:args()
  if node.attr.type:is_record() then
    local ctype = context:get_ctype(node)
    emitter:add('(', ctype, ')', '{')
    emitter:add_traversal_list(childnodes, ', ', node.attr.type)
    emitter:add('}')
  elseif node.attr.type:is_array() then
    local ctype = context:get_ctype(node)
    emitter:add('(', ctype, ')', '{{')
    emitter:add_traversal_list(childnodes)
    emitter:add('}}')
  elseif node.attr.type:is_arraytable() then
    local ctype = context:get_ctype(node)
    local len = #childnodes
    if len > 0 then
      local subctype = context:get_ctype(node.attr.type.subtype)
      emitter:add(ctype, '_create((', subctype, '[', len, ']){')
      emitter:add_traversal_list(childnodes)
      emitter:add('},', len, ')')
    else
      emitter:add('(', ctype, ')', '{0}')
    end
  else --luacov:disable
    error('not implemented yet')
  end --luacov:enable
end

-- TODO: Nil
-- TODO: Varargs
-- TODO: Table
-- TODO: Pair
-- TODO: Function

-- identifier and types
function visitors.Id(_, node, emitter)
  emitter:add(cdefs.quotename(node.attr.codename))
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
visitors.ArrayTableType = visitors.Type
visitors.ArrayType = visitors.Type
visitors.PointerType = visitors.Type

function visitors.IdDecl(context, node, emitter)
  if node.attr.type:is_type() then return end
  local name, mut, typenode, pragmanodes = node:args()
  if pragmanodes then
    for pragmanode in iters.ivalues(pragmanodes) do
      local pragmaname, pragmaargs = pragmanode:args()
      local cattr = cdefs.variable_pragmas[pragmaname]
      pragmanode:assertraisef(cattr, "pragma '%s' is not defined", pragmaname)
      if traits.is_string(cattr) then
        pragmanode:assertraisef(#pragmaargs == 0, "pragma '%s' takes no arguments", pragmaname)
        emitter:add(cattr, ' ')
      end
    end
  end
  if node.attr.const then
    emitter:add('const ')
  end
  local ctype = context:get_ctype(node)
  emitter:add(ctype, ' ', cdefs.quotename(node.attr.codename))
end

-- indexing
function visitors.DotIndex(_, node, emitter)
  local name, objnode = node:args()
  if objnode.attr.type:is_type() then
    local objtype = node.attr.holdedtype
    if objtype:is_enum() then
      emitter:add(objtype:get_field(name).value)
    else --luacov:disable
      error('not implemented yet')
    end --luacov:enable
  elseif objnode.attr.type:is_pointer() then
    emitter:add(objnode, '->', cdefs.quotename(name))
  else
    emitter:add(objnode, '.', cdefs.quotename(name))
  end
end

-- TODO: ColonIndex

function visitors.ArrayIndex(context, node, emitter)
  local index, objnode = node:args()
  local objtype = objnode.attr.type
  local pointer = false
  if objtype:is_pointer() then
    if not objtype:is_generic_pointer() then
      objtype = objtype.subtype
      pointer = true
    end
  end
  if objtype:is_arraytable() then
    emitter:add('*',
      context:get_ctype(objtype),
      node.assign and '_at(&' or '_get(&')
  end
  if pointer then
    emitter:add('(*')
  end
  emitter:add(objnode)
  if pointer then
    emitter:add(')')
  end
  if objtype:is_arraytable() then
    emitter:add(', ', index, ')')
  elseif objtype:is_array() then
    emitter:add('.data[', index, ']')
  else
    emitter:add('[', index, ']')
  end
end

-- calls
function visitors.Call(context, node, emitter)
  local args, callee, block_call = node:args()
  if block_call then emitter:add_indent() end
  local builtin
  if callee.tag == 'Id' then
    local fname = callee[1]
    builtin = cbuiltins[fname]
  end
  if builtin then
    callee = builtin(context, node, emitter)
  end
  if node.callee_type:is_function() then
    emitter:add(callee, '(')
    for i,argtype,argnode in iters.izip(node.callee_type.argtypes, args) do
      if i > 1 then emitter:add(', ') end
      add_casted_value(context, emitter, argtype, argnode)
    end
    emitter:add(')')
  elseif node.callee_type:is_type() then
    -- type assertion
    assert(#args == 1)
    local argnode = args[1]
    if argnode.attr.type ~= node.attr.type then
      emitter:add('(', context:get_ctype(node.attr.type), ')(', args[1], ')')
    else
      emitter:add(args[1])
    end
  else
    --TODO: handle better calls on any types
    emitter:add(callee, '(', args, ')')
  end
  if block_call then emitter:add_ln(";") end
end

function visitors.CallMethod(_, node, emitter)
  local name, args, callee, block_call = node:args()
  if block_call then emitter:add_indent() end
  emitter:add(callee, '.', cdefs.quotename(name), '(', callee, args, ')')
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
  local itvarnode, beginval, compop, endval, incrval, block  = node:args()
  if not compop then
    compop = 'le'
  end
  --TODO: evaluate beginval, endval, incrval only once in case of expressions
  local itname = itvarnode[1]
  emitter:add_indent("for(", itvarnode, ' = ')
  add_casted_value(context, emitter, itvarnode.attr.type, beginval)
  emitter:add('; ', itname, ' ', cdefs.binary_ops[compop], ' ')
  add_casted_value(context, emitter, itvarnode.attr.type, endval)
  emitter:add_ln('; ', cdefs.quotename(itname), ' += ', incrval or '1', ') {')
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
  emitter:add_indent_ln(cdefs.quotename(name), ':')
end

function visitors.Goto(_, node, emitter)
  local labelname = node:args()
  emitter:add_indent_ln('goto ', cdefs.quotename(labelname), ';')
end

local function add_assignments(context, emitter, varnodes, valnodes, decl)
  local added = false
  for _,varnode,valnode in iters.izip(varnodes, valnodes or {}) do
    if not varnode.attr.type:is_type() then
      local varemitter = emitter
      local mainconst = decl and varnode.attr.const and context.scope:is_main()
      if mainconst then
        varemitter = Emitter(context)
        varemitter:add('static ')
      else
        if added then varemitter:add(' ') end
        added = true
      end
      varemitter:add(varnode, ' = ')
      add_casted_value(context, varemitter, varnode.attr.type, valnode)
      varemitter:add(';')
      if mainconst then
        varemitter:add_ln()
        context:add_declaration(varemitter:generate())
      end
    end
  end
end

function visitors.VarDecl(context, node, emitter)
  local varscope, mutability, varnodes, valnodes = node:args()
  node:assertraisef(varscope == 'local', 'global variables not supported yet')
  node:assertraisef(not valnodes or #varnodes == #valnodes, 'vars and vals count differs')
  emitter:add_indent()
  add_assignments(context, emitter, varnodes, valnodes, true)
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
  local varscope, varnode, argnodes, retnodes, pragmanodes, blocknode = node:args()
  node:assertraisef(#retnodes <= 1, 'multiple returns not supported yet')
  node:assertraisef(varscope == 'local', 'non local scope for functions not supported yet')

  local cfirstattr = 'static '
  local cattr = ''
  local declare = true
  local define = true
  for pragmanode in iters.ivalues(pragmanodes) do
    local pragmaname, pragmaargs = pragmanode:args()
    local attr = cdefs.function_pragmas[pragmaname] or cdefs.variable_pragmas[pragmaname]
    pragmanode:assertraisef(attr, "pragma '%s' is not defined", pragmaname)
    if pragmaname == 'cimport' then
      define = false
      local header = pragmaargs[2] and pragmaargs[2].attr.value
      if header then
        context:add_include(header)
        declare = false
      end
      cfirstattr = ''
      pragmanode:assertraisef(#blocknode[1] == 0, 'body of C import function must be empty')
    elseif pragmaname == 'nodecl' then
      declare = false
    elseif traits.is_string(attr) then
      cattr = cattr .. attr .. ' '
    end
  end

  local decemitter, defemitter = Emitter(context), Emitter(context)
  if #retnodes == 0 then
    decemitter:add_indent(cfirstattr, cattr, 'void ')
    defemitter:add_indent('void ')
  else
    local ret = retnodes[1]
    decemitter:add_indent(cfirstattr, cattr, ret, ' ')
    defemitter:add_indent(ret, ' ')
  end
  decemitter:add_ln(varnode, '(', argnodes, ');')
  defemitter:add_ln(varnode, '(', argnodes, ') {')
  defemitter:add(blocknode)
  defemitter:add_indent_ln('}')
  if declare then
    context:add_declaration(decemitter:generate())
  end
  if define then
    context:add_definition(defemitter:generate())
  end
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
  local opname, argnode = node:args()
  local op = node:assertraisef(cdefs.unary_ops[opname], 'unary operator "%s" not found', opname)
  local surround = is_in_operator(context)
  if surround then emitter:add('(') end
  if traits.is_string(op) then
    emitter:add(op, argnode)
  else
    local func = cbuiltins[opname]
    assert(func)
    func(context, node, emitter, argnode)
  end
  if surround then emitter:add(')') end
end

function visitors.BinaryOp(context, node, emitter)
  local opname, lnode, rnode = node:args()
  local op = node:assertraisef(cdefs.binary_ops[opname], 'binary operator "%s" not found', opname)
  local surround = is_in_operator(context)
  if surround then emitter:add('(') end

  if typedefs.binary_conditional_ops[opname] and not node.attr.type:is_boolean() then
    --TODO: create a temporary function in case of expressions and evaluate in order
    if opname == 'and' then
      --TODO: use nilable values here
      emitter:add('(', lnode, ' && ', rnode, ') ? ', rnode, ' : 0')
    elseif opname == 'or' then
      emitter:add(lnode, ' ? ', lnode, ' : ', rnode)
    end
  else
    if traits.is_string(op) then
      emitter:add(lnode, ' ', op, ' ', rnode)
    else
      local func = cbuiltins[opname]
      assert(func)
      func(context, node, emitter, lnode, rnode)
    end
  end
  if surround then emitter:add(')') end
end

local generator = {}

function generator.generate(ast)
  local context = CContext(visitors)
  context.runtime_path = fs.join(config.runtime_path, 'c')

  context:ensure_runtime('euluna_core')

  local main_emitter = Emitter(context, -1)
  main_emitter:add_traversal(ast)

  context:add_definition(main_emitter:generate())

  context:ensure_runtime('euluna_main')
  context:evaluate_templates()

  local code = table.concat({
    table.concat(context.includes),
    table.concat(context.declarations),
    table.concat(context.definitions)
  })

  return code
end

generator.compiler = require('euluna.ccompiler')

return generator
