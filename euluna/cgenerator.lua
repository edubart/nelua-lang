local CEmitter = require 'euluna.cemitter'
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

function visitors.Number(_, node, emitter)
  local base, int, frac, exp, literal = node:args()
  local value, integral, type = node.attr.value, node.attr.integral, node.attr.type
  if not type:is_float() and literal then
    emitter:add_nodectypecast(node)
  end
  emitter:add_composed_number(base, int, frac, exp, value:abs())
  if type:is_unsigned() then
    emitter:add('U')
  elseif type:is_float32() and base == 'dec' then
    emitter:add(integral and '.0f' or 'f')
  elseif type:is_float64() and base == 'dec' then
    emitter:add(integral and '.0' or '')
  end
end

function visitors.String(context, node, emitter)
  local decemitter = CEmitter(context)
  local value, len = node.attr.value, #node.attr.value
  local varname = '__string_literal_' .. node.pos
  local quoted_value = pegger.double_quote_c_string(value)
  decemitter:add_indent_ln('static const struct { uintptr_t len, res; char data[', len + 1, ']; }')
  decemitter:add_indent_ln('  ', varname, ' = {', len, ', ', len, ', ', quoted_value, '};')
  emitter:add('(const ', primtypes.string, ')&', varname)
  context:add_declaration(decemitter:generate(), varname)
end

function visitors.Boolean(_, node, emitter)
  emitter:add_booleanlit(node.attr.value)
end

function visitors.Pair(_, node, emitter)
  local namenode, valuenode = node:args()
  local parenttype = node.attr.parenttype
  if parenttype and parenttype:is_record() then
    assert(traits.is_string(namenode))
    emitter:add('.', cdefs.quotename(namenode), ' = ', valuenode)
  else --luacov:disable
    error('not implemented yet')
  end --luacov:enable
end

function visitors.Table(context, node, emitter)
  local childnodes, type = node:arg(1), node.attr.type
  local len = #childnodes
  if len == 0 and (type:is_record() or type:is_array() or type:is_arraytable()) then
    emitter:add_nodezerotype(node)
  elseif type:is_record() then
    emitter:add_nodectypecast(node)
    emitter:add('{', childnodes, '}')
  elseif type:is_array() then
    emitter:add_nodectypecast(node)
    emitter:add('{{', childnodes, '}}')
  elseif type:is_arraytable() then
    emitter:add(context:typename(type), '_create((', type.subtype, '[', len, ']){', childnodes, '},', len, ')')
  else --luacov:disable
    error('not implemented yet')
  end --luacov:enable
end

function visitors.Pragma(context, node, emitter)
  local attr = node.attr
  if attr.cinclude then
    context:add_include(attr.cinclude)
  end
  if attr.cemit then
    emitter:add_ln(attr.cemit)
  end
  if attr.cdefine then
    context:add_declaration(string.format('#define %s\n', attr.cdefine))
  end
  if attr.cflags then
    table.insert(context.compileopts.cflags, attr.cflags)
  end
  if attr.ldflags then
    table.insert(context.compileopts.ldflags, attr.ldflags)
  end
  if attr.linklib then
    table.insert(context.compileopts.linklibs, attr.linklib)
  end
end

function visitors.Id(context, node, emitter)
  if node.attr.type:is_nilptr() then
    emitter:add_null()
  else
    emitter:add(context:declname(node))
  end
end

function visitors.Paren(_, node, emitter)
  local innernode = node:args()
  emitter:add('(', innernode, ')')
end

visitors.FuncType = visitors.Type
visitors.ArrayTableType = visitors.Type
visitors.ArrayType = visitors.Type
visitors.PointerType = visitors.Type

function visitors.IdDecl(context, node, emitter)
  local attr = node.attr
  if attr.type:is_type() then return end
  if attr.const    then emitter:add('const ') end
  if attr.volatile then emitter:add('volatile ') end
  if attr.restrict then emitter:add('restrict ') end
  if attr.register then emitter:add('register ') end
  emitter:add(node.attr.type, ' ', context:declname(node))
end

-- indexing
function visitors.DotIndex(_, node, emitter)
  local name, objnode = node:args()
  local type = objnode.attr.type
  if type:is_type() then
    local objtype = node.attr.holdedtype
    if objtype:is_enum() then
      emitter:add(objtype:get_field(name).value)
    else --luacov:disable
      error('not implemented yet')
    end --luacov:enable
  elseif type:is_pointer() then
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
  if objtype:is_pointer() and not objtype:is_generic_pointer() then
    objtype = objtype.subtype
    pointer = true
  end
  if objtype:is_arraytable() then
    emitter:add('*', context:typename(objtype))
    emitter:add(node.assign and '_at(&' or '_get(&')
  end
  if pointer then
    emitter:add('(*', objnode, ')')
  else
    emitter:add(objnode)
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
  local type = node.attr.type
  if block_call then
    emitter:add_indent()
  end
  local builtin
  if callee.tag == 'Id' then
    --TODO: move builtin detection to type checker
    local fname = callee[1]
    builtin = cbuiltins.functions[fname]
  end
  if builtin then
    callee = builtin(context, node, emitter)
  end
  if node.callee_type:is_function() then
    -- function call
    emitter:add(callee, '(')
    for i,argtype,argnode in iters.izip(node.callee_type.argtypes, args) do
      if i > 1 then emitter:add(', ') end
      emitter:add_val2type(argtype, argnode)
    end
    emitter:add(')')

    if node.callee_type:has_multiple_returns() then
      -- get just the first result in multiple return functions
      emitter:add('.r1')
    end
  elseif node.callee_type:is_type() then
    -- type assertion
    assert(#args == 1)
    local argnode = args[1]
    if argnode.attr.type ~= type then
      emitter:add_ctypecast(type)
      emitter:add('(', argnode, ')')
    else
      emitter:add(argnode)
    end
  else
    --TODO: handle better calls on any types
    emitter:add(callee, '(', args, ')')
  end
  if block_call then
    emitter:add_ln(";")
  end
end

function visitors.CallMethod(_, node, emitter)
  local name, args, callee, block_call = node:args()
  if block_call then
    emitter:add_indent()
  end
  local sep = #args > 0 and ', ' or ''
  emitter:add(callee, '.', cdefs.quotename(name), '(', callee, sep, args, ')')
  if block_call then
    emitter:add_ln()
  end
end

-- block
function visitors.Block(context, node, emitter)
  local statnodes = node:args()
  emitter:inc_indent()
  context:push_scope('block')
  do
    emitter:add_traversal_list(statnodes, '')
  end
  context:pop_scope()
  emitter:dec_indent()
end

-- statements
function visitors.Return(context, node, emitter)
  local retnodes = node:args()
  local funcscope = context.scope:get_parent_of_kind('function')
  local numretnodes = #retnodes
  funcscope.has_return = true
  if funcscope.main then
    -- in main body
    node:assertraisef(numretnodes <= 1, "multiple returns in main is not supported yet")
    if numretnodes == 0 then
      -- main must always return an integer
      emitter:add_indent_ln('return 0;')
    else
      -- return one value (an integer expected)
      local retnode = retnodes[1]
      emitter:add_indent_ln('return ', retnode, ';')
    end
  else
    local functype = funcscope.functype
    local rettypes = functype.returntypes
    local numfuncrets = #rettypes
    if numfuncrets == 0 then
      -- no returns
      assert(numretnodes == 0)
      emitter:add_indent_ln('return;')
    elseif numfuncrets == 1 then
      -- one return
      local retnode, rettype = retnodes[1], rettypes[1]
      emitter:add_indent('return ')
      if retnode then
        -- return value is present
        emitter:add_ln(retnode, ';')
      else
        -- no return value present, generate a zeroed one
        emitter:add_castedzerotype(rettype)
        emitter:add_ln(';')
      end
    else
      -- multiple returns
      local retctype = context:funcretctype(functype)
      emitter:add_indent('return (', retctype, '){')
      for i,retnode,rettype in iters.izip(retnodes, rettypes) do
        if i>1 then emitter:add(', ') end
        emitter:add_val2type(rettype, retnode)
      end
      emitter:add_ln('};')
    end
  end
end

function visitors.If(_, node, emitter)
  local ifparts, elseblock = node:args()
  for i,ifpart in ipairs(ifparts) do
    local condnode, blocknode = ifpart[1], ifpart[2]
    if i == 1 then
      emitter:add_indent("if(")
      emitter:add_val2type(primtypes.boolean, condnode)
      emitter:add_ln(") {")
    else
      emitter:add_indent("} else if(")
      emitter:add_val2type(primtypes.boolean, condnode)
      emitter:add_ln(") {")
    end
    emitter:add(blocknode)
  end
  if elseblock then
    emitter:add_indent_ln("} else {")
    emitter:add(elseblock)
  end
  emitter:add_indent_ln("}")
end

function visitors.Switch(_, node, emitter)
  local valnode, caseparts, elsenode = node:args()
  emitter:add_indent_ln("switch(", valnode, ") {")
  emitter:inc_indent()
  node:assertraisef(#caseparts > 0, "switch must have case parts")
  for casepart in iters.ivalues(caseparts) do
    local casenode, blocknode = casepart[1], casepart[2]
    emitter:add_indent_ln("case ", casenode, ': {')
    emitter:add(blocknode)
    emitter:inc_indent() emitter:add_indent_ln('break;') emitter:dec_indent()
    emitter:add_indent_ln("}")
  end
  if elsenode then
    emitter:add_indent_ln('default: {')
    emitter:add(elsenode)
    emitter:inc_indent() emitter:add_indent_ln('break;') emitter:dec_indent()
    emitter:add_indent_ln("}")
  end
  emitter:dec_indent()
  emitter:add_indent_ln("}")
end

function visitors.Do(_, node, emitter)
  local blocknode = node:args()
  emitter:add_indent_ln("{")
  emitter:add(blocknode)
  emitter:add_indent_ln("}")
end

function visitors.While(_, node, emitter)
  local condnode, blocknode = node:args()
  emitter:add_indent("while(")
  emitter:add_val2type(primtypes.boolean, condnode)
  emitter:add_ln(') {')
  emitter:add(blocknode)
  emitter:add_indent_ln("}")
end

function visitors.Repeat(_, node, emitter)
  local blocknode, condnode = node:args()
  emitter:add_indent_ln("do {")
  emitter:add(blocknode)
  emitter:add_indent('} while(!(')
  emitter:add_val2type(primtypes.boolean, condnode)
  emitter:add_ln('));')
end

function visitors.ForNum(context, node, emitter)
  local itvarnode, beginvalnode, compop, endvalnode, stepvalnode, blocknode  = node:args()
  compop = node.attr.compop
  local fixedstep = node.attr.fixedstep
  context:push_scope('for')
  do
    local ccompop = cdefs.binary_ops[compop]
    local ittype = itvarnode.attr.type
    local itname = context:declname(itvarnode)
    emitter:add_indent('for(', ittype, ' __it = ')
    emitter:add_val2type(ittype, beginvalnode)
    emitter:add(', __end = ')
    emitter:add_val2type(ittype, endvalnode)
    if not fixedstep then
      emitter:add(', __step = ')
      emitter:add_val2type(ittype, stepvalnode)
    end
    emitter:add('; ')
    if compop then
      emitter:add('__it ', ccompop, ' __end')
    else
      -- step is an expression, must detect the compare operation at runtime
      assert(not fixedstep)
      emitter:add('(__step >= 0 && __it <= __end) || (__step < 0 && __it >= __end)')
    end
    emitter:add('; __it = __it + ')
    if not fixedstep then
      emitter:add('__step')
    elseif stepvalnode then
      emitter:add_val2type(ittype, stepvalnode)
    else
      emitter:add('1')
    end
    emitter:add_ln(') {')
    emitter:inc_indent()
    emitter:add_indent_ln(itvarnode, ' = __it; EULUNA_UNUSED(', itname, ');')
    emitter:dec_indent()
    emitter:add(blocknode)
    emitter:add_indent_ln('}')
  end
  context:pop_scope()
end

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

local function visit_assignments(context, emitter, varnodes, valnodes, decl)
  for _,varnode,valnode in iters.izip(varnodes, valnodes or {}) do
    if not varnode.attr.type:is_type() and not varnode.attr.nodecl then
      local declared, defined = false, false
      -- declare main variables in the top scope
      if decl and context.scope:is_main() then
        local decemitter = CEmitter(context)
        decemitter:add_indent('static ', varnode, ' = ')
        if valnode and valnode.attr.const then
          -- initialize to const values
          decemitter:add_val2type(varnode.attr.type, valnode)
          defined = true
        else
          -- pre initialize to zeros
          decemitter:add_zeroinit(varnode.attr.type)
        end
        decemitter:add_ln(';')
        context:add_declaration(decemitter:generate())
        declared = true
      end

      if not declared or (not defined and valnode) then
        -- decalre or define if needed
        if not declared then
          emitter:add_indent(varnode)
        else
          emitter:add_indent(context:declname(varnode))
        end
        emitter:add(' = ')
        emitter:add_val2type(varnode.attr.type, valnode)
        emitter:add_ln(';')
      end
    elseif varnode.attr.cinclude then
      -- not declared, might be an imported variable from C
      context:add_include(varnode.attr.cinclude)
    end
  end
end

function visitors.VarDecl(context, node, emitter)
  local varscope, mutability, varnodes, valnodes = node:args()
  node:assertraisef(varscope == 'local', 'global variables not supported yet')
  visit_assignments(context, emitter, varnodes, valnodes, true)
end

function visitors.Assign(context, node, emitter)
  local vars, vals = node:args()
  node:assertraisef(#vars == #vals, 'vars and vals count differs')
  visit_assignments(context, emitter, vars, vals)
end

function visitors.FuncDef(context, node)
  local varscope, varnode, argnodes, retnodes, pragmanodes, blocknode = node:args()
  node:assertraisef(varscope == 'local', 'non local scope for functions not supported yet')

  local attr = node.attr
  local type = attr.type
  local rettypes = type.returntypes
  local numrets = #rettypes
  local decoration = 'static '
  local declare, define = not attr.nodecl, true

  if attr.cinclude then
    context:add_include(attr.cinclude)
  end
  if attr.cimport then
    decoration = ''
    define = false
  end

  if attr.volatile then decoration = decoration .. 'volatile ' end
  if attr.inline then decoration = decoration .. 'inline ' end
  if attr.noinline then decoration = decoration .. 'EULUNA_NOINLINE ' end
  if attr.noreturn then decoration = decoration .. 'EULUNA_NORETURN ' end

  local decemitter, defemitter = CEmitter(context), CEmitter(context)
  local retctype = context:funcretctype(type)
  if numrets > 1 then
    node:assertraisef(declare, 'functions with multiple returns must be declared')

    local retemitter = CEmitter(context)
    retemitter:add_indent_ln('typedef struct ', retctype, ' {')
    retemitter:inc_indent()
    for i,rettype in ipairs(rettypes) do
      retemitter:add_indent_ln(rettype, ' ', 'r', i, ';')
    end
    retemitter:dec_indent()
    retemitter:add_indent_ln('} ', retctype, ';')
    context:add_declaration(retemitter:generate())
  end

  decemitter:add_indent(decoration, retctype, ' ')
  defemitter:add_indent(retctype, ' ')

  decemitter:add(varnode)
  defemitter:add(varnode)
  local funcscope = context:push_scope('function')
  funcscope.functype = type
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

function visitors.UnaryOp(_, node, emitter)
  local opname, argnode = node:args()
  local op = cdefs.unary_ops[opname]
  assert(op)
  local surround = node.attr.inoperator
  if surround then emitter:add('(') end
  if traits.is_string(op) then
    emitter:add(op, argnode)
  else
    local builtin = cbuiltins.operators[opname]
    builtin(node, emitter, argnode)
  end
  if surround then emitter:add(')') end
end

function visitors.BinaryOp(_, node, emitter)
  local opname, lnode, rnode = node:args()
  local type = node.attr.type
  local op = cdefs.binary_ops[opname]
  assert(op)
  local surround = node.attr.inoperator
  if surround then emitter:add('(') end
  if node.attr.dynamic_conditional then
    emitter:add_ln('({')
    emitter:inc_indent()
    emitter:add_indent(type, ' t1_ = ')
    emitter:add_val2type(type, lnode)
    emitter:add_ln('; EULUNA_UNUSED(t1_);')
    emitter:add_indent_ln(type, ' t2_ = {0}; EULUNA_UNUSED(t2_);')
    if opname == 'and' then
      emitter:add_indent('bool cond_ = ')
      emitter:add_val2type(primtypes.boolean, 't1_', type)
      emitter:add_ln(';')
      emitter:add_indent_ln('if(cond_) {')
      emitter:add_indent('  t2_ = ')
      emitter:add_val2type(type, rnode)
      emitter:add_ln(';')
      emitter:add_indent('  cond_ = ')
      emitter:add_val2type(primtypes.boolean, 't2_', type)
      emitter:add_ln(';')
      emitter:add_indent_ln('}')
      emitter:add_indent_ln('cond_ ? t2_ : (', type, '){0};')
    elseif opname == 'or' then
      emitter:add_indent('bool cond_ = ')
      emitter:add_val2type(primtypes.boolean, 't1_', type)
      emitter:add_ln(';')
      emitter:add_indent_ln('if(cond_)')
      emitter:add_indent('  t2_ = ')
      emitter:add_val2type(type, rnode)
      emitter:add_ln(';')
      emitter:add_indent_ln('cond_ ? t1_ : t2_;')
    end
    emitter:dec_indent()
    emitter:add_indent('})')
  else
    local sequential = lnode.attr.sideeffect and rnode.attr.sideeffect
    local lname = lnode
    local rname = rnode
    if sequential then
      emitter:add_ln('({')
      emitter:inc_indent()
      emitter:add_indent_ln(lnode.attr.type, ' t1_ = ', lnode, ';')
      emitter:add_indent_ln(rnode.attr.type, ' t2_ = ', rnode, ';')
      emitter:add_indent()
      lname = 't1_'
      rname = 't2_'
    end
    if traits.is_string(op) then
      emitter:add(lname, ' ', op, ' ', rname)
    else
      local builtin = cbuiltins.operators[opname]
      builtin(node, emitter, lnode, rnode, lname, rname)
    end
    if sequential then
      emitter:add_ln(';')
      emitter:dec_indent()
      emitter:add_indent('})')
    end
  end
  if surround then emitter:add(')') end
end

local generator = {}

function generator.generate(ast)
  local context = CContext(visitors)
  context.runtime_path = fs.join(config.runtime_path, 'c')

  context:ensure_runtime('euluna_core')

  local mainemitter = CEmitter(context, -1)

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
