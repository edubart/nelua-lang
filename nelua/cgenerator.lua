local CEmitter = require 'nelua.cemitter'
local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local errorer = require 'nelua.utils.errorer'
local stringer = require 'nelua.utils.stringer'
local tabler = require 'nelua.utils.tabler'
local pegger = require 'nelua.utils.pegger'
local fs = require 'nelua.utils.fs'
local config = require 'nelua.configer'.get()
local cdefs = require 'nelua.cdefs'
local cbuiltins = require 'nelua.cbuiltins'
local typedefs = require 'nelua.typedefs'
local CContext = require 'nelua.ccontext'
local types = require 'nelua.types'
local primtypes = typedefs.primtypes

local function izipargnodes(vars, argnodes)
  local iter = iters.izip(vars, argnodes)
  local lastargindex = #argnodes
  local lastargnode = argnodes[#argnodes]
  local calleetype = lastargnode and lastargnode.attr.calleetype
  if lastargnode and lastargnode.tag:sub(1,4) == 'Call' and (not calleetype or not calleetype:is_type()) then
    -- last arg is a runtime call
    assert(calleetype)
    -- we know the callee type
    return function()
      local i, var, argnode = iter()
      if not i then return nil end
      if i >= lastargindex and lastargnode.attr.multirets then
        -- argnode does not exists, fill with multiple returns type
        -- in case it doest not exists, the argtype will be false
        local callretindex = i - lastargindex + 1
        local argtype = calleetype:get_return_type(callretindex)
        return i, var, argnode, argtype, callretindex, calleetype
      else
        return i, var, argnode, argnode.attr.type, nil
      end
    end
  else
    -- no calls from last argument
    return function()
      local i, var, argnode = iter()
      if not i then return end
      -- we are sure this argument have no type, set argtype to false
      local argtype = argnode and argnode.attr.type
      return i, var, argnode, argtype
    end
  end
end

local function visit_assignments(context, emitter, varnodes, valnodes, decl)
  local defemitter = emitter
  local usetemporary = false
  if not decl and #valnodes > 1 then
    -- multiple assignments must assign to a temporary first (in case of a swap)
    usetemporary = true
    defemitter = CEmitter(context, emitter.depth)
  end
  local multiretvalname
  for _,varnode,valnode,valtype,lastcallindex in izipargnodes(varnodes, valnodes or {}) do
    local varattr = varnode.attr
    local noinit = varattr.noinit or varattr.cexport
    local vartype = varattr.type
    if not vartype:is_type() and not varattr.nodecl and not varattr.compconst then
      local declared, defined = false, false
      if decl and context.scope:is_static_storage() then
        -- declare main variables in the top scope
        local decemitter = CEmitter(context)
        decemitter:add_indent()
        if not varattr.nostatic and not varattr.cexport then
          decemitter:add('static ')
        end
        decemitter:add(varnode)
        if valnode and (valnode.attr.compconst or varattr.const or varattr.compconst) then
          -- initialize to const values
          decemitter:add(' = ')
          assert(not lastcallindex)
          decemitter:add_val2type(vartype, valnode)
          defined = true
        else
          -- pre initialize to zeros
          if not noinit then
            decemitter:add(' = ')
            decemitter:add_zeroinit(vartype)
          end
        end
        decemitter:add_ln(';')
        context:add_declaration(decemitter:generate())
        declared = true
      end

      if lastcallindex == 1 then
        -- last assigment value may be a multiple return call
        multiretvalname = context:genuniquename('ret')
        local retctype = context:funcretctype(valnode.attr.calleetype)
        emitter:add_indent_ln(retctype, ' ', multiretvalname, ' = ', valnode, ';')
      end

      local retvalname
      if lastcallindex then
        retvalname = string.format('%s.r%d', multiretvalname, lastcallindex)
      elseif usetemporary then
        retvalname = context:genuniquename('asgntmp')
        emitter:add_indent(vartype, ' ', retvalname, ' = ')
        emitter:add_val2type(vartype, valnode)
        emitter:add_ln(';')
      end

      if not declared or (not defined and (valnode or lastcallindex)) then
        -- declare or define if needed
        if not declared then
          defemitter:add_indent(varnode)
        else
          defemitter:add_indent(context:declname(varnode))
        end
        if valnode or not noinit then
          -- initialize variable
          defemitter:add(' = ')
          if retvalname then
            defemitter:add_val2type(vartype, retvalname, valtype)
          else
            defemitter:add_val2type(vartype, valnode)
          end
        end
        defemitter:add_ln(';')
      end
    elseif varattr.cinclude then
      -- not declared, might be an imported variable from C
      context:add_include(varattr.cinclude)
    end
  end
  if usetemporary then
    emitter:add(defemitter:generate())
  end
end

local typevisitors = {}

local function emit_type_attributes(decemitter, type)
  if type.aligned then
    decemitter:add(' __attribute__((aligned(', type.aligned, ')))')
  end
end

typevisitors[types.ArrayType] = function(context, type)
  if type.nodecl or context:is_declarated(type.codename) then return end
  local decemitter = CEmitter(context, 0)
  decemitter:add('typedef struct {', type.subtype, ' data[', type.length, '];} ', type.codename)
  emit_type_attributes(decemitter, type)
  decemitter:add_ln(';')
  context:add_declaration(decemitter:generate(), type.codename)
end

typevisitors[types.PointerType] = function(context, type)
  if type.nodecl or context:is_declarated(type.codename) then return end
  local decemitter = CEmitter(context, 0)
  decemitter:add_ln('typedef ', type.subtype, '* ', type.codename, ';')
  context:add_declaration(decemitter:generate(), type.codename)
end

typevisitors[types.RecordType] = function(context, type)
  if type.nodecl or context:is_declarated(type.codename) then return end
  local decemitter = CEmitter(context, 0)
  decemitter:add('typedef struct ', type.codename)
  if #type.fields > 0 then
    decemitter:add_ln(' {')
    for _,field in ipairs(type.fields) do
      decemitter:add_ln('  ', field.type, ' ', field.name, ';')
    end
    decemitter:add('} ', type.codename)
    emit_type_attributes(decemitter, type)
    decemitter:add_ln(';')
  else
    decemitter:add_ln(' ', type.codename, ';')
  end
  context:add_declaration(decemitter:generate(), type.codename)
end

typevisitors[types.EnumType] = function(context, type)
  if type.nodecl or context:is_declarated(type.codename) then return end
  local decemitter = CEmitter(context, 0)
  decemitter:add_ln('typedef ', type.subtype, ' ', type.codename, ';')
  decemitter:add_ln('enum {')
  for _,field in ipairs(type.fields) do
    decemitter:add_ln('  ', field.name, ' = ', field.value, ',')
  end
  decemitter:add_ln('};')
  context:add_declaration(decemitter:generate(), type.codename)
end

typevisitors[types.Type] = function(context, type)
  if context:is_declarated(type.codename) then return end
  if type:is_string() then
    context:ensure_runtime_builtin('nelua_string')
  elseif type:is_function() then
    error('ctype for functions not implemented yet')
  elseif type:is_any() then
    context:ensure_runtime_builtin('nelua_any')
  elseif type:is_arraytable() then
    local subctype = context:ctype(type.subtype)
    context:ensure_runtime(type.codename, 'nelua_arrtab', {
      tyname = type.codename,
      ctype = subctype,
      type = type
    })
    context:use_gc()
  else
    errorer.assertf(cdefs.primitive_ctypes[type], 'C type visitor for "%s" is not defined', type)
  end
end

local visitors = {}

function visitors.Number(context, node, emitter)
  local base, int, frac, exp, literal = node:args()
  local value, integral, type = node.attr.value, node.attr.integral, node.attr.type
  if not type:is_float() and literal then
    emitter:add_nodectypecast(node)
  end
  if integral and exp then
    local numzeros = tonumber(exp)
    assert(numzeros > 0)
    int = int .. string.rep('0', numzeros)
    exp = nil
  end
  emitter:add_composed_number(base, int, frac, exp, value:abs())
  if type:is_unsigned() then
    emitter:add('U')
  elseif type:is_float32() and base == 'dec' and not context.ast.attr.nofloatsuffix then
    emitter:add(integral and '.0f' or 'f')
  elseif type:is_float() and base == 'dec' then
    emitter:add(integral and '.0' or '')
  end
end

function visitors.String(context, node, emitter)
  local decemitter = CEmitter(context)
  local value = node.attr.value
  local len = #value
  local varname = context:genuniquename('strlit')
  local quoted_value = pegger.double_quote_c_string(value)
  decemitter:add_indent('static const struct { uintptr_t len; char data[', len + 1, ']; }')
  decemitter:add_indent_ln(' ', varname, ' = {', len, ', ', quoted_value, '};')
  emitter:add('(const ', primtypes.string, ')&', varname)
  context:add_declaration(decemitter:generate(), varname)
end

function visitors.Boolean(_, node, emitter)
  emitter:add_booleanlit(node.attr.value)
end

-- TODO: Nil

function visitors.Varargs(_, _, emitter)
  emitter:add('...')
end

function visitors.Table(context, node, emitter)
  local childnodes, type = node[1], node.attr.type
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

-- TODO: Function

function visitors.PragmaSet(context, node)
  local name, value = node:args()
  context[name] = value
end

function visitors.PragmaCall(context, node, emitter)
  local name, args = node:args()
  if name == 'cinclude' then
    context:add_include(tabler.unpack(args))
  elseif name == 'cemit' then
    local code, scope = tabler.unpack(args)
    if not stringer.endswith(code, '\n') then
      code = code .. '\n'
    end
    if scope == 'declaration' then
      context:add_declaration(code)
    elseif scope == 'definition' then
      context:add_definition(code)
    elseif not scope then
      emitter:add(code)
    else --luacov:disable
      node:raisef('invalid C emit scope')
    end --luacov:enable
  elseif name == 'cdefine' then
    context:add_declaration(string.format('#define %s\n', args[1]))
  elseif name == 'cflags' then
    table.insert(context.compileopts.cflags, args[1])
  elseif name == 'ldflags' then
    table.insert(context.compileopts.ldflags, args[1])
  elseif name == 'linklib' then
    table.insert(context.compileopts.linklibs, args[1])
  else --luacov:disable
    error('not implemented yet')
  end --luacov:enable
end

function visitors.Id(context, node, emitter)
  local attr = node.attr
  if attr.type:is_nilptr() then
    emitter:add_null()
  elseif attr.compconst then
    emitter:add_literal(attr)
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
  assert(not attr.compconst)
  if attr.funcdecl then
    emitter:add(context:declname(node))
    return
  end
  local type = node.attr.type
  if type:is_type() then return end
  if attr.cexport then emitter:add('extern ') end
  if attr.const then emitter:add('const ') end
  if attr.volatile then emitter:add('volatile ') end
  if attr.restrict then emitter:add('restrict ') end
  if attr.register then emitter:add('register ') end
  if attr.static then emitter:add('static ') end
  if attr.cqualifier then emitter:add(attr.cqualifier, ' ') end
  emitter:add(type, ' ', context:declname(node))
  if attr.cattribute then emitter:add(' __attribute__((', attr.cattribute, '))') end
end

-- indexing
function visitors.DotIndex(context, node, emitter)
  local name, objnode = node:args()
  local type = objnode.attr.type
  if type:is_type() then
    local objtype = node.attr.indextype
    if objtype:is_enum() then
      emitter:add(objtype:get_field(name).value)
    elseif objtype:is_record() then
      local symbol = objtype:get_metafield(name)
      if symbol.attr.compconst then
        emitter:add_literal(symbol.attr)
      else
        emitter:add(context:declname(symbol))
      end
    else --luacov:disable
      error('not implemented yet')
    end --luacov:enable
  elseif type:is_pointer() then
    emitter:add(objnode, '->', cdefs.quotename(name))
  else
    emitter:add(objnode, '.', cdefs.quotename(name))
  end
end

visitors.ColonIndex = visitors.DotIndex

function visitors.ArrayIndex(context, node, emitter)
  local indexnode, objnode = node:args()
  local objtype = objnode.attr.type
  local pointer = false
  if objtype:is_pointer() and not objtype:is_generic_pointer() then
    -- indexing a pointer to an array
    objtype = objtype.subtype
    pointer = true
  end

  local indextype = indexnode.attr.type
  local index = indexnode
  if indextype:is_range() then
    assert(node.attr.type:is_span())
    -- index is a range type, result is a span
    emitter:add_ln('({')
    emitter:inc_indent()
    emitter:add_indent_ln(indextype, ' __range = ', indexnode, ';')
    emitter:add_indent()
    emitter:add_nodectypecast(node)
    emitter:add('{&(')
    index = '__range.low'
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
  elseif objtype:is_array() or objtype:is_span() then
    emitter:add('.data[', index, ']')
  else
    emitter:add('[', index, ']')
  end

  if indextype:is_range() then
    emitter:add_ln('), __range.high - __range.low };')
    emitter:dec_indent()
    emitter:add_indent_ln('})')
  end
end

local function visitor_Call(context, node, emitter, argnodes, callee, isblockcall)
  if isblockcall then
    emitter:add_indent()
  end
  local attr = node.attr
  local calleetype = attr.calleetype
  if calleetype:is_function() then
    -- function call
    local tmpargs = {}
    local tmpcount = 0
    local lastcalltmp
    local sequential = false
    local callargtypes = attr.pseudoargtypes or calleetype.argtypes
    local ismethod = attr.pseudoargtypes ~= nil
    for i,_,argnode,_,lastcallindex in izipargnodes(callargtypes, argnodes) do
      if (argnode and argnode.attr.sideeffect) or lastcallindex == 1 then
        -- expressions with side effects need to be evaluated in sequence
        -- and expressions with multiple returns needs to be stored in a temporary
        tmpcount = tmpcount + 1
        local tmpname = '__tmp' .. tmpcount
        tmpargs[i] = tmpname
        if lastcallindex == 1 then
          lastcalltmp = tmpname
        end
        if tmpcount >= 2 or lastcallindex then
          -- only need to evaluate in sequence mode if we have two or more temporaries
          -- or the last argument is a multiple return call
          sequential = true
        end
      end
    end

    if sequential then
      -- begin sequential expression
      if not isblockcall then
        emitter:add('(')
      end
      emitter:add_ln('{')
      emitter:inc_indent()

      for _,tmparg,argnode,argtype,_,lastcalletype in izipargnodes(tmpargs, argnodes) do
        -- set temporary values in sequence
        if tmparg then
          if lastcalletype then
            -- type for result of multiple return call
            argtype = context:funcretctype(lastcalletype)
          end
          emitter:add_indent_ln(argtype, ' ', tmparg, ' = ', argnode, ';')
        end
      end

      emitter:add_indent()
    end

    if ismethod then
      emitter:add(context:declname(attr.symbol), '(')
      emitter:add_val2type(calleetype.argtypes[1], callee)
    else
      if attr.pointercall then
        emitter:add('(*', callee, ')(')
      else
        emitter:add(callee, '(')
      end
    end

    for i,funcargtype,argnode,argtype,lastcallindex in izipargnodes(callargtypes, argnodes) do
      if i > 1 or ismethod then emitter:add(', ') end
      local arg = argnode
      if sequential then
        if lastcallindex then
          arg = string.format('%s.r%d', lastcalltmp, lastcallindex)
        elseif tmpargs[i] then
          arg = tmpargs[i]
        end
      end
      emitter:add_val2type(funcargtype, arg, argtype)
    end
    emitter:add(')')

    if calleetype:has_multiple_returns() and not attr.multirets then
      -- get just the first result in multiple return functions
      emitter:add('.r1')
    end

    if sequential then
      -- end sequential expression
      emitter:add_ln(';')
      emitter:dec_indent()
      emitter:add_indent('}')
      if not isblockcall then
        emitter:add(')')
      end
    end
  else
    --TODO: handle better calls on any types
    emitter:add(callee, '(', argnodes, ')')
  end
  if isblockcall then
    emitter:add_ln(";")
  end
end

function visitors.Call(context, node, emitter)
  local argnodes, calleenode, isblockcall = node:args()
  local calleetype = node.attr.calleetype
  local callee = calleenode
  if calleenode.attr.builtin then
    local builtin = cbuiltins.inlines[calleenode.attr.name]
    callee = builtin(context, node, emitter)
  end
  if calleetype:is_type() then
    -- type assertion
    assert(#argnodes == 1)
    local argnode = argnodes[1]
    local type = node.attr.type
    if argnode.attr.type ~= type then
      -- type really differs, cast it
      emitter:add_ctypecast(type)
      emitter:add('(')
      emitter:add_val2type(type, argnode)
      emitter:add(')')
    else
      -- same type, no need to cast
      emitter:add(argnode)
    end
  elseif callee then
    visitor_Call(context, node, emitter, argnodes, callee, isblockcall)
  end
end

function visitors.CallMethod(context, node, emitter)
  local name, argnodes, callee, isblockcall = node:args()

  visitor_Call(context, node, emitter, argnodes, callee, isblockcall)

  --[[
  local name, args, callee, block_call = node:args()
  if block_call then
    emitter:add_indent()
  end
  local sep = #args > 0 and ', ' or ''
  emitter:add(callee, '.', cdefs.quotename(name), '(', callee, sep, args, ')')
  if block_call then
    emitter:add_ln()
  end
  ]]
end

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
      emitter:add_indent('return ')
      emitter:add_val2type(primtypes.cint, retnode)
      emitter:add_ln(';')
    end
  else
    local functype = funcscope.functype
    local numfuncrets = functype:get_return_count()
    if numfuncrets == 0 then
      -- no returns
      assert(numretnodes == 0)
      emitter:add_indent_ln('return;')
    elseif numfuncrets == 1 then
      -- one return
      local retnode, rettype = retnodes[1], functype:get_return_type(1)
      emitter:add_indent('return ')
      if retnode then
        -- return value is present
        emitter:add_val2type(rettype, retnode)
        emitter:add_ln(';')
      else
        -- no return value present, generate a zeroed one
        emitter:add_castedzerotype(rettype)
        emitter:add_ln(';')
      end
    else
      -- multiple returns
      local funcretctype = context:funcretctype(functype)
      local retemitter = CEmitter(context, emitter.depth)
      local multiretvalname
      retemitter:add('return (', funcretctype, '){')
      for i,funcrettype,retnode,rettype,lastcallindex in izipargnodes(functype.returntypes, retnodes) do
        if i>1 then retemitter:add(', ') end
        if lastcallindex == 1 then
          -- last assigment value may be a multiple return call
          emitter:add_indent_ln('{')
          emitter:inc_indent()
          multiretvalname = context:genuniquename('ret')
          local retctype = context:funcretctype(retnode.attr.calleetype)
          emitter:add_indent_ln(retctype, ' ', multiretvalname, ' = ', retnode, ';')
        end
        if lastcallindex then
          local retvalname = string.format('%s.r%d', multiretvalname, lastcallindex)
          retemitter:add_val2type(funcrettype, retvalname, rettype)
        else
          retemitter:add_val2type(funcrettype, retnode)
        end
      end
      retemitter:add_ln('};')
      emitter:add_indent(retemitter:generate())
      if multiretvalname then
        emitter:dec_indent()
        emitter:add_indent_ln('}')
      end
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
  for _,casepart in ipairs(caseparts) do
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
  if #blocknode[1] == 0 then return end
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
  emitter:add_indent_ln("while(true) {")
  emitter:add(blocknode)
  emitter:inc_indent()
  emitter:add_indent('if(')
  emitter:add_val2type(primtypes.boolean, condnode)
  emitter:add_ln(') {')
  emitter:inc_indent()
  emitter:add_indent_ln('break;')
  emitter:dec_indent()
  emitter:add_indent_ln('}')
  emitter:dec_indent()
  emitter:add_indent_ln('}')
end

function visitors.ForNum(context, node, emitter)
  local itvarnode, begvalnode, compop, endvalnode, stepvalnode, blocknode  = node:args()
  compop = node.attr.compop
  local fixedstep = node.attr.fixedstep
  local fixedend = node.attr.fixedend
  local itmutate = itvarnode.attr.mutate
  context:push_scope('for')
  do
    local ccompop = cdefs.compare_ops[compop]
    local ittype = itvarnode.attr.type
    local itname = context:declname(itvarnode)
    local itforname = itmutate and '__it' or itname
    emitter:add_indent('for(', ittype, ' ', itforname, ' = ')
    emitter:add_val2type(ittype, begvalnode)
    if not fixedend or not compop then
      emitter:add(', __end = ')
      emitter:add_val2type(ittype, endvalnode)
    end
    if not fixedstep then
      emitter:add(', __step = ')
      emitter:add_val2type(ittype, stepvalnode)
    end
    emitter:add('; ')
    if compop then
      emitter:add(itforname, ' ', ccompop, ' ', fixedend or '__end')
    else
      -- step is an expression, must detect the compare operation at runtime
      assert(not fixedstep)
      emitter:add('__step >= 0 ? ', itforname, ' <= __end : ', itforname, ' >= __end')
    end
    emitter:add('; ', itforname, ' = ', itforname, ' + ')
    if not fixedstep then
      emitter:add('__step')
    elseif stepvalnode then
      emitter:add_val2type(ittype, stepvalnode)
    else
      emitter:add('1')
    end
    emitter:add_ln(') {')
    emitter:inc_indent()
    if itmutate then
      emitter:add_indent_ln(itvarnode, ' = __it;')
    end
    emitter:dec_indent()
    emitter:add(blocknode)
    emitter:add_indent_ln('}')
  end
  context:pop_scope()
end

--[[
function visitors.ForIn(_, node, emitter)
  local itvarnodes, inexpnodes, blocknode = node:args()
  emitter:add_indent_ln("{")
  emitter:inc_indent()
  --visit_assignments(context, emitter, itvarnodes, inexpnodes, true)
  emitter:add_indent("while(true) {")
  emitter:add(blocknode)
  emitter:add_indent_ln("}")
  emitter:dec_indent()
  emitter:add_indent_ln("}")
end
]]

function visitors.Break(_, _, emitter)
  emitter:add_indent_ln('break;')
end

function visitors.Continue(_, _, emitter)
  emitter:add_indent_ln('continue;')
end

function visitors.Label(_, node, emitter)
  local name = node:args()
  emitter:add_ln(cdefs.quotename(name), ':')
end

function visitors.Goto(_, node, emitter)
  local labelname = node:args()
  emitter:add_indent_ln('goto ', cdefs.quotename(labelname), ';')
end

function visitors.VarDecl(context, node, emitter)
  local varscope, varnodes, valnodes = node:args()
  visit_assignments(context, emitter, varnodes, valnodes, true)
end

function visitors.Assign(context, node, emitter)
  local vars, vals = node:args()
  visit_assignments(context, emitter, vars, vals)
end

function visitors.FuncDef(context, node)
  local varscope, varnode, argnodes, retnodes, attribnodes, blocknode = node:args()

  local attr = node.attr
  local type = attr.type
  local numrets = type:get_return_count()
  local qualifier = ''
  if not attr.entrypoint and not attr.nostatic and not attr.cexport then
    qualifier = 'static '
  end
  local declare, define = not attr.nodecl, true

  if attr.cinclude then
    context:add_include(attr.cinclude)
  end
  if attr.cimport then
    qualifier = ''
    define = false
  end

  if attr.cexport then qualifier = qualifier .. 'extern ' end
  if attr.volatile then qualifier = qualifier .. 'volatile ' end
  if attr.inline then qualifier = qualifier .. 'inline ' end
  if attr.noinline then qualifier = qualifier .. context:ensure_runtime_builtin('nelua_noinline') .. ' ' end
  if attr.noreturn then qualifier = qualifier .. context:ensure_runtime_builtin('nelua_noreturn') .. ' ' end
  if attr.cqualifier then qualifier = qualifier .. attr.cqualifier .. ' ' end
  if attr.cattribute then
    qualifier = string.format('%s__attribute__((%s)) ', qualifier, attr.cattribute)
  end

  local decemitter, defemitter, implemitter = CEmitter(context), CEmitter(context), CEmitter(context)
  local retctype = context:funcretctype(type)
  if numrets > 1 then
    node:assertraisef(declare, 'functions with multiple returns must be declared')

    local retemitter = CEmitter(context)
    retemitter:add_indent_ln('typedef struct ', retctype, ' {')
    retemitter:inc_indent()
    for i=1,numrets do
      local rettype = type:get_return_type(i)
      assert(rettype)
      retemitter:add_indent_ln(rettype, ' ', 'r', i, ';')
    end
    retemitter:dec_indent()
    retemitter:add_indent_ln('} ', retctype, ';')
    context:add_declaration(retemitter:generate())
  end

  decemitter:add_indent(qualifier, retctype, ' ')
  defemitter:add_indent(retctype, ' ')

  decemitter:add(varnode)
  defemitter:add(varnode)
  local funcscope = context:push_scope('function')
  funcscope.functype = type
  do
    decemitter:add('(')
    defemitter:add('(')
    if varnode.tag == 'ColonIndex' then
      decemitter:add(node.attr.metarecordtype, ' self')
      defemitter:add(node.attr.metarecordtype, ' self')
      if #argnodes > 0 then
        decemitter:add(', ')
        defemitter:add(', ')
      end
    end
    decemitter:add_ln(argnodes, ');')
    defemitter:add_ln(argnodes, ') {')
    implemitter:add(blocknode)
  end
  context:pop_scope()
  implemitter:add_indent_ln('}')
  if declare then
    context:add_declaration(decemitter:generate())
  end
  if define then
    context:add_definition(defemitter:generate())
    if attr.entrypoint then
      context:add_definition(function() return context.mainemitter:generate() end)
    end
    context:add_definition(implemitter:generate())
  end
end

function visitors.UnaryOp(_, node, emitter)
  local attr = node.attr
  if attr.compconst then
    emitter:add_literal(attr)
    return
  end
  local opname, argnode = node:args()
  local op = cdefs.unary_ops[opname]
  assert(op)
  local surround = attr.inoperator
  if surround then emitter:add('(') end
  if traits.is_string(op) then
    emitter:add(op, argnode)
  else
    local builtin = cbuiltins.operators[opname]
    builtin(node, emitter, argnode)
  end
  if surround then emitter:add(')') end
end

function visitors.BinaryOp(context, node, emitter)
  if node.attr.compconst then
    emitter:add_literal(node.attr)
    return
  end
  local opname, lnode, rnode = node:args()
  local type = node.attr.type
  local op = cdefs.binary_ops[opname]
  assert(op)
  local surround = node.attr.inoperator
  if surround then emitter:add('(') end
  if node.attr.dynamic_conditional then
    emitter:add_ln('({')
    emitter:inc_indent()
    if node.attr.ternaryor then
      -- lua style "ternary" operator
      emitter:add_indent_ln(type, ' t_;')
      emitter:add_indent('bool cond_ = ')
      emitter:add_val2type(primtypes.boolean, lnode[2])
      emitter:add_ln(';')
      emitter:add_indent_ln('if(cond_) {')
      emitter:add_indent('  t_ = ')
      emitter:add_val2type(type, lnode[3])
      emitter:add_ln(';')
      emitter:add_indent('  cond_ = ')
      emitter:add_val2type(primtypes.boolean, 't_', type)
      emitter:add_ln(';')
      emitter:add_indent_ln('}')
      emitter:add_indent_ln('if(!cond_) {')
      emitter:add_indent('  t_ = ')
      emitter:add_val2type(type, rnode)
      emitter:add_ln(';')
      emitter:add_indent_ln('}')
      emitter:add_indent_ln('t_;')
    else
      emitter:add_indent(type, ' t1_ = ')
      emitter:add_val2type(type, lnode)
      --TODO: be smart and remove this unused code
      context:ensure_runtime_builtin('nelua_unused')
      emitter:add_ln('; nelua_unused(t1_);')
      emitter:add_indent_ln(type, ' t2_ = {0}; nelua_unused(t2_);')
      if opname == 'and' then
        assert(not node.attr.ternaryand)
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
    end
    emitter:dec_indent()
    emitter:add_indent('})')
  else
    local sequential = lnode.attr.sideeffect and rnode.attr.sideeffect
    local lname = lnode
    local rname = rnode
    if sequential then
      -- need to evaluate args in sequence when one expression has side effects
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

local function emit_main(ast, context)
  context:add_include('<stddef.h>')
  context:add_include('<stdint.h>')
  context:add_include('<stdbool.h>')

  local mainemitter = CEmitter(context, -1)

  local main_scope = context:push_scope('function')
  main_scope.main = true
  if not ast.attr.entrypoint then
    mainemitter:add_ln(
      '/*********************************** MAIN ***********************************/')
    mainemitter:inc_indent()
    mainemitter:add_ln("int nelua_main() {")
    mainemitter:add_traversal(ast)
    if not main_scope.has_return then
      -- main() must always return an integer
      mainemitter:inc_indent()
      mainemitter:add_indent_ln("return 0;")
      mainemitter:dec_indent()
    end
    mainemitter:add_ln("}")
    mainemitter:dec_indent()

    context:add_declaration('int nelua_main();\n')
  else
    context.mainemitter = mainemitter
    mainemitter:inc_indent()
    mainemitter:add_traversal(ast)
    mainemitter:dec_indent()
  end
  context:pop_scope()

  if not ast.attr.entrypoint then
    mainemitter:add_indent_ln('int main(int argc, char **argv) {')
    mainemitter:inc_indent(2)

    context:ensure_runtime_builtin('nelua_unused')
    mainemitter:add_indent_ln('nelua_unused(argv);')
    if context.has_gc then
      mainemitter:add_indent_ln('nelua_gc_start(&nelua_gc, &argc);')
      mainemitter:add_indent_ln('int (*volatile inner_main)(void) = nelua_main;')
      mainemitter:add_indent_ln('int result = inner_main();')
      mainemitter:add_indent_ln('nelua_gc_stop(&nelua_gc);')
      mainemitter:add_indent_ln('return result;')
    else
      mainemitter:add_indent_ln('nelua_unused(argc);')
      mainemitter:add_indent_ln('return nelua_main();')
    end
    mainemitter:dec_indent(2)
    mainemitter:add_indent_ln('}')

    context:add_definition(mainemitter:generate())
  end
end

function generator.generate(ast)
  local context = CContext(visitors, typevisitors)
  context.ast = ast
  context.runtime_path = fs.join(config.runtime_path, 'c')

  emit_main(ast, context)

  context:evaluate_templates()

  local code = table.concat({
    '/******************************** DECLARATIONS ********************************/\n',
    table.concat(context.declarations),
    '/******************************** DEFINITIONS *********************************/\n',
    table.concat(context.definitions)
  })

  return code, context.compileopts
end

generator.compiler = require('nelua.ccompiler')

return generator
