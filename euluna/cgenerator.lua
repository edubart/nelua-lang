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

local function add_zeroinit(emitter, type)
  local s
  if type:is_float64() then
    s = '0.0'
  elseif type:is_float32() then
    s = '0.0f'
  elseif type:is_unsigned() then
    s = '0U'
  elseif type:is_numeric() then
    s = '0'
  elseif type:is_pointer() then
    s = 'NULL'
  elseif type:is_boolean() then
    s = 'false'
  else
    s = '{0}'
  end
  emitter:add(s)
end

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
      context:get_ctype(primtypes.any)
      context:get_ctype(type)
      emitter:add(context:get_typename(type), '_any_cast(', valnode, ')')
    elseif type == valnode.attr.type or
           (valnode.attr.type:is_numeric() and type:is_numeric()) or
           (valnode.attr.type:is_nilptr() and type:is_pointer()) then
      emitter:add(valnode)
    elseif valnode.attr.type:is_string() and type:is_cstring() then
      emitter:add('(', valnode, ')->data')
    else
      emitter:add('(',context:get_ctype(type),')',valnode)
    end
  else
    add_zeroinit(emitter, type)
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
    emitter:add('(', context:get_ctype(node), ')')
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
    if #childnodes == 0 then
      -- initialize everything to zeroes
      emitter:add('0')
    else
      emitter:add_traversal_list(childnodes, ', ', node.attr.type)
    end
    emitter:add('}')
  elseif node.attr.type:is_array() then
    local ctype = context:get_ctype(node)
    emitter:add('(', ctype, ')', '{')
    if #childnodes == 0 then
      -- initialize everything to zeroes
      emitter:add('0')
    else
      emitter:add('{', childnodes, '}')
    end
    emitter:add('}')
  elseif node.attr.type:is_arraytable() then
    local ctype = context:get_ctype(node)
    local len = #childnodes
    if len > 0 then
      local subctype = context:get_ctype(node.attr.type.subtype)
      emitter:add(context:get_typename(node), '_create((', subctype, '[', len, ']){')
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

function visitors.Pragma(context, node, emitter)
  if node.attr.cinclude then
    context:add_include(node.attr.cinclude)
  end
  if node.attr.cemit then
    emitter:add_ln(node.attr.cemit)
  end
  if node.attr.cdefine then
    context:add_declaration(string.format('#define %s\n', node.attr.cdefine))
  end
  if node.attr.cflags then
    table.insert(context.compileopts.cflags, node.attr.cflags)
  end
  if node.attr.ldflags then
    table.insert(context.compileopts.ldflags, node.attr.ldflags)
  end
  if node.attr.linklib then
    table.insert(context.compileopts.linklibs, node.attr.linklib)
  end
end

-- identifier and types
function visitors.Id(context, node, emitter)
  if node.attr.type:is_nilptr() then
    emitter:add('NULL')
  else
    emitter:add(context:get_declname(node))
  end
end

function visitors.Paren(_, node, emitter, ...)
  local innernode = node:args()
  emitter:add('(')
  local ret = emitter:add_traversal(innernode, ...)
  emitter:add(')')
  return ret
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
  if node.attr.const then
    emitter:add('const ')
  end
  if node.attr.volatile then
    emitter:add('volatile ')
  end
  if node.attr.restrict then
    emitter:add('restrict ')
  end
  if node.attr.register then
    emitter:add('register ')
  end
  local ctype = context:get_ctype(node)
  emitter:add(ctype, ' ', context:get_declname(node))
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
      context:get_typename(objtype),
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
      emitter:add('(', context:get_ctype(node), ')(', args[1], ')')
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
  local sep = #args > 0 and ', ' or ''
  emitter:add(callee, '.', cdefs.quotename(name), '(', callee, sep, args, ')')
  if block_call then emitter:add_ln() end
end

-- block
function visitors.Block(context, node, emitter)
  local stats = node:args()
  emitter:inc_indent()
  context:push_scope('block')
  do
    emitter:add_traversal_list(stats, '')
  end
  context:pop_scope()
  emitter:dec_indent()
end

-- statements
function visitors.Return(context, node, emitter)
  --TODO: multiple return
  local scope = context.scope
  scope:get_parent_of_kind('function').has_return = true
  local rets = node:args()
  node:assertraisef(#rets <= 1, "multiple returns not supported yet")
  emitter:add_indent("return")
  if #rets > 0 then
    emitter:add_ln(' ', rets, ';')
  else
    if scope:get_parent_of_kind('function').main then
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
  context:push_scope('for')
  do
    local itname = context:get_declname(itvarnode)
    emitter:add_indent("for(", itvarnode, ' = ')
    add_casted_value(context, emitter, itvarnode.attr.type, beginval)
    emitter:add('; ', itname, ' ', cdefs.binary_ops[compop], ' ')
    add_casted_value(context, emitter, itvarnode.attr.type, endval)
    emitter:add_ln('; ', itname, ' += ', incrval or '1', ') {')
    emitter:add(block)
    emitter:add_indent_ln("}")
  end
  context:pop_scope()
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
  for _,varnode,valnode in iters.izip(varnodes, valnodes or {}) do
    if not varnode.attr.type:is_type() and not varnode.attr.nodecl then
      local declared, defined = false, false
      -- declare main variables in the top scope
      if decl and context.scope:is_main() then
        local decemitter = Emitter(context)
        decemitter:add_indent('static ')
        decemitter:add(varnode, ' = ')
        if valnode and valnode.attr.const then
          -- initialize to const values
          add_casted_value(context, decemitter, varnode.attr.type, valnode)
          defined = true
        else
          -- pre initialize to zeros
          add_zeroinit(decemitter, varnode.attr.type)
        end
        decemitter:add_ln(';')
        context:add_declaration(decemitter:generate())
        declared = true
      end

      if not declared or (not defined and valnode) then
        if not declared then
          emitter:add_indent(varnode)
        else
          emitter:add_indent(context:get_declname(varnode))
        end
        emitter:add(' = ')
        add_casted_value(context, emitter, varnode.attr.type, valnode)
        emitter:add_ln(';')
      end
    elseif varnode.attr.cinclude then
      context:add_include(varnode.attr.cinclude)
    end
  end
end

function visitors.VarDecl(context, node, emitter)
  local varscope, mutability, varnodes, valnodes = node:args()
  node:assertraisef(varscope == 'local', 'global variables not supported yet')
  node:assertraisef(not valnodes or #varnodes == #valnodes, 'vars and vals count differs')
  add_assignments(context, emitter, varnodes, valnodes, true)
end

function visitors.Assign(context, node, emitter)
  local vars, vals = node:args()
  node:assertraisef(#vars == #vals, 'vars and vals count differs')
  add_assignments(context, emitter, vars, vals)
end

function visitors.FuncDef(context, node)
  local varscope, varnode, argnodes, retnodes, pragmanodes, blocknode = node:args()
  node:assertraisef(#retnodes <= 1, 'multiple returns not supported yet')
  node:assertraisef(varscope == 'local', 'non local scope for functions not supported yet')

  local decoration = 'static '
  local declare = not node.attr.nodecl
  local define = true

  if node.attr.cinclude then
    context:add_include(node.attr.cinclude)
  end
  if node.attr.cimport then
    decoration = ''
    define = false
  end
  if node.attr.volatile then
    decoration = decoration .. 'volatile '
  end
  if node.attr.inline then
    decoration = decoration .. 'inline '
  end
  if node.attr.noinline then
    decoration = decoration .. 'EULUNA_NOINLINE '
  end
  if node.attr.noreturn then
    decoration = decoration .. 'EULUNA_NORETURN '
  end

  local decemitter, defemitter = Emitter(context), Emitter(context)
  if #retnodes == 0 then
    decemitter:add_indent(decoration, 'void ')
    defemitter:add_indent('void ')
  else
    local ret = retnodes[1]
    decemitter:add_indent(decoration, ret, ' ')
    defemitter:add_indent(ret, ' ')
  end
  decemitter:add(varnode)
  defemitter:add(varnode)
  context:push_scope('function')
  do
    decemitter:add_ln('(', argnodes, ');')
    defemitter:add_ln('(', argnodes, ') {')
    defemitter:add(blocknode)
  end
  context:pop_scope()
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

  local mainemitter = Emitter(context, -1)

  local main_scope = context:push_scope('function')
  main_scope.main = true
  do
    mainemitter:inc_indent()
    mainemitter:add_ln("int euluna_main() {")
    mainemitter:add_traversal(ast)
    if not main_scope.has_return then
      -- main() must always return an integer
      mainemitter:inc_indent()
      mainemitter:add_indent_ln("return 0;")
      mainemitter:dec_indent()
    end
    mainemitter:add_ln("}")
    mainemitter:dec_indent()
  end
  context:pop_scope()

  context:add_definition(mainemitter:generate())

  context:ensure_runtime('euluna_main')
  context:evaluate_templates()

  local code = table.concat({
    table.concat(context.declarations),
    table.concat(context.definitions)
  })

  return code, context.compileopts
end

generator.compiler = require('euluna.ccompiler')

return generator
