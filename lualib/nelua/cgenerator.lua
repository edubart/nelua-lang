local CEmitter = require 'nelua.cemitter'
local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local stringer = require 'nelua.utils.stringer'
local tabler = require 'nelua.utils.tabler'
local bn = require 'nelua.utils.bn'
local pegger = require 'nelua.utils.pegger'
local cdefs = require 'nelua.cdefs'
local cbuiltins = require 'nelua.cbuiltins'
local typedefs = require 'nelua.typedefs'
local CContext = require 'nelua.ccontext'
local types = require 'nelua.types'
local ccompiler = require 'nelua.ccompiler'
local primtypes = typedefs.primtypes
local izip2 = iters.izip2
local emptynext = function() end

local cgenerator = {}
cgenerator.compiler = ccompiler

local function izipargnodes(vars, argnodes)
  if #vars == 0 and #argnodes == 0 then return emptynext end
  local iter, ts, i = izip2(vars, argnodes)
  local lastargindex = #argnodes
  local lastargnode = argnodes[#argnodes]
  local calleetype = lastargnode and lastargnode.attr.calleetype
  if lastargnode and lastargnode.is_call and (not calleetype or not calleetype.is_type) then
    -- last arg is a runtime call
    assert(calleetype)
    -- we know the callee type
    return function()
      local var, argnode
      i, var, argnode = iter(ts, i)
      if not i then return nil end
      if i >= lastargindex and lastargnode.attr.usemultirets then
        -- argnode does not exists, fill with multiple returns type
        -- in case it doest not exists, the argtype will be false
        local callretindex = i - lastargindex + 1
        local argtype = calleetype:get_return_type(callretindex)
        return i, var, argnode, argtype, callretindex, calleetype
      else
        local argtype = argnode and argnode.attr.type
        return i, var, argnode, argtype, nil
      end
    end
  else
    -- no calls from last argument
    return function()
      local var, argnode
      i, var, argnode = iter(ts, i)
      if i then
        return i, var, argnode, argnode and argnode.attr.type
      end
    end
  end
end


local typevisitors = {}
cgenerator.typevisitors = typevisitors

typevisitors[types.ArrayType] = function(context, type)
  local decemitter = CEmitter(context)
  context:ensure_builtin('NELUA_MAYALIAS')
  decemitter:add('typedef struct NELUA_MAYALIAS')
  decemitter:add_type_qualifiers(type)
  local array_type = type
  local len_part = ''
  while array_type and array_type.is_array do
    local len = math.max(array_type.length, typedefs.emptysize)
    len_part = len_part..'['..len..']'
    array_type = array_type.is_array and array_type.subtype
  end
  decemitter:add_ln(' ', type.codename, ' {', type.inner_subtype, ' v',len_part,';} ', type.codename, ';')
  decemitter:add_ln('typedef union NELUA_MAYALIAS ', type.codename, '_cast {',
    type.codename, ' a; ',
    type.inner_subtype, ' p',len_part,';',
    '} ', type.codename, '_cast;')
  if type.size and type.size > 0 and not context.pragmas.nocstaticassert then
    context:ensure_builtins('NELUA_STATIC_ASSERT', 'NELUA_ALIGNOF')
    decemitter:add_ln('NELUA_STATIC_ASSERT(sizeof(',type.codename,') == ', type.size, ' && ',
                      'NELUA_ALIGNOF(',type.codename,') == ', type.align,
                      ', "Nelua and C disagree on type size or align");')
  end
  table.insert(context.declarations, decemitter:generate())
end

typevisitors[types.PointerType] = function(context, type)
  if context.ctypedefs[type.codename] then return end
  local decemitter = CEmitter(context)
  local subtype = type.subtype
  if type.is_unbounded_pointer then
    subtype = subtype.subtype
  end
  local subcodename = subtype.codename
  if subtype.is_composite and not subtype.nodecl and
     not context.declarations[subcodename] and not context.ctypedefs[subcodename] then
    -- just declared a typedef for composite type, because they may have cyclic dependency
    local kindname = subtype.is_record and 'struct' or 'union'
    decemitter:add_ln('typedef ', kindname, ' ', subcodename, ' ', subcodename, ';')
    table.insert(context.latedecls, subtype)
    context.ctypedefs[subcodename] = true
    decemitter:add_ln('typedef ', subcodename, '* ', type.codename, ';')
  elseif context.ctypedefs[subcodename] then
    decemitter:add_ln('typedef ', subcodename, '* ', type.codename, ';')
  else
    decemitter:add_ln('typedef ', subtype, '* ', type.codename, ';')
  end
  table.insert(context.declarations, decemitter:generate())
end

local function typevisitor_CompositeType(context, type)
  local kindname = type.is_record and 'struct' or 'union'
  if not context.ctypedefs[type.codename] and not context.pragmas.noctypedefs then
    local decemitter = CEmitter(context)
    decemitter:add_ln('typedef ', kindname, ' ', type.codename, ' ', type.codename, ';')
    table.insert(context.declarations, decemitter:generate())
    context.ctypedefs[type.codename] = true
  end
  local defemitter = CEmitter(context)
  defemitter:add(kindname)
  defemitter:add_type_qualifiers(type)
  defemitter:add(' ', type.codename, ' {')
  if #type.fields > 0 then
    defemitter:add_ln()
    for _,field in ipairs(type.fields) do
      if field.type.is_array then
        local fieldtype = field.type
        while fieldtype.is_array do
          fieldtype = fieldtype.subtype
        end
        defemitter:add('  ', fieldtype, ' ', field.name)
        fieldtype = field.type
        while fieldtype.is_array do
          defemitter:add('[', fieldtype.length, ']')
          fieldtype = fieldtype.subtype
        end
      else
        defemitter:add('  ', field.type, ' ', field.name)
      end
      defemitter:add_ln(';')
    end
  elseif typedefs.emptysize > 0 then
    defemitter:add('char x;')
  end
  defemitter:add_ln('};')
  if type.size and type.size > 0 and not context.pragmas.nocstaticassert then
    context:ensure_builtins('NELUA_STATIC_ASSERT', 'NELUA_ALIGNOF')
    defemitter:add_ln('NELUA_STATIC_ASSERT(sizeof(',type.codename,') == ', type.size, ' && ',
                      'NELUA_ALIGNOF(',type.codename,') == ', type.align,
                      ', "Nelua and C disagree on type size or align");')
  end
  table.insert(context.declarations, defemitter:generate())
end

typevisitors[types.RecordType] = typevisitor_CompositeType
typevisitors[types.UnionType] = typevisitor_CompositeType

typevisitors[types.EnumType] = function(context, type)
  local decemitter = CEmitter(context)
  decemitter:add_ln('typedef ', type.subtype, ' ', type.codename, ';')
  table.insert(context.declarations, decemitter:generate())
end

typevisitors[types.FunctionType] = function(context, type)
  local decemitter = CEmitter(context)
  decemitter:add('typedef ', context:funcrettypename(type), ' (*', type.codename, ')')
  if #type.argtypes > 0 then
    decemitter:add_text('(')
    for i,argtype in ipairs(type.argtypes) do
      if i>1 then
        decemitter:add(', ')
      end
      decemitter:add(argtype)
    end
    decemitter:add_ln(');')
  else
    decemitter:add_ln('(void);')
  end
  table.insert(context.declarations, decemitter:generate())
end

typevisitors[types.NiltypeType] = function(context)
  context:ensure_builtin('nlniltype')
end

typevisitors[types.TypeType] = function(context)
  context:ensure_builtin('nltype')
end

typevisitors.FunctionReturnType = function(context, functype)
  if #functype.rettypes <= 1 then
    return context:ensure_type(functype:get_return_type(1))
  end
  local rettypes = functype.rettypes
  local retnames = {'nlmulret'}
  for i=1,#rettypes do
    retnames[#retnames+1] = rettypes[i].codename
  end
  local rettypename = table.concat(retnames, '_')
  if context:is_declared(rettypename) then return rettypename end
  local retemitter = CEmitter(context)
  retemitter:add_indent()
  if not context.pragmas.noctypedefs then
    retemitter:add('typedef ')
  end
  retemitter:add_ln('struct ', rettypename, ' {') retemitter:inc_indent()
  for i=1,#rettypes do
    retemitter:add_indent_ln(rettypes[i], ' ', 'r', i, ';')
  end
  retemitter:dec_indent() retemitter:add_indent('}')
  if not context.pragmas.noctypedefs then
    retemitter:add(' ', rettypename)
  end
  retemitter:add_ln(';')
  context:add_declaration(retemitter:generate(), rettypename)
  return rettypename
end

--[[
typevisitors[types.PolyFunctionType] = function(context, type)
  if type.nodecl or context:is_declared(type.codename) then return end
  local decemitter = CEmitter(context)
  decemitter:add_ln('typedef void* ', type.codename, ';')
  context:add_declaration(decemitter:generate(), type.codename)
end
]]

typevisitors[types.Type] = function(context, type)
  local node = context:get_visiting_node()
  if type.is_any or type.is_varanys then
    node:raisef("compiler deduced type 'any' here, but it's not supported yet, please fix this variable type")
  else
    node:raisef("type '%s' is not supported yet in the C backend", type)
  end
end

local visitors = {}
cgenerator.visitors = visitors

function visitors.Number(_, node, emitter)
  local attr = node.attr
  emitter:add_scalar_literal(attr.value, attr.type, attr.base)
end

-- Emits a string literal.
function visitors.String(_, node, emitter, untypedinit)
  local attr = node.attr
  local type = attr.type
  if type.is_stringy then
    if type.is_acstring then
      emitter:add('(', type, ')')
    end
    emitter:add_string_literal(attr.value, type.is_cstring or type.is_acstring, untypedinit)
  else -- an integral
    if type == primtypes.cchar then -- C character literal
      emitter:add(pegger.single_quote_c_string(string.char(bn.tointeger(attr.value))))
    else -- number
      emitter:add_scalar_literal(attr.value, type, attr.base)
    end
  end
end

-- Emits a boolean literal.
function visitors.Boolean(_, node, emitter)
  emitter:add_boolean(node.attr.value)
end

-- Emits a `nil` literal.
function visitors.Nil(_, _, emitter)
  emitter:add_nil_literal()
end

-- Emits a `nilptr` literal.
function visitors.Nilptr(_, _, emitter)
  emitter:add_null()
end

-- Emits C varargs `...` in function arguments.
function visitors.VarargsType(_, node, emitter)
  local type = node.attr.type
  if type.is_varanys then
    node:raisef("compiler deduced the type 'varanys' here, but it's not supported yet in the C backend")
  end
  assert(type.is_cvarargs)
  emitter:add('...')
end

-- Checks if an initializer node can be emitted using a C initializer.
local function can_use_initializer(node)
  local hassideeffect = false
  for i=1,#node do
    local childnode = node[i]
    local childvalnode
    if childnode.is_Pair then
      childvalnode = childnode[2]
    else
      childvalnode = childnode
    end
    if childvalnode.is_InitList then
      if not can_use_initializer(childvalnode) then
        return false
      end
    end
    local childvalattr = childvalnode.attr
    local sideeffect = childvalattr.sideeffect
    if sideeffect then
      if hassideeffect then
        return false
      end
      hassideeffect = true
    end
    if childvalattr.type.is_array and not childvalattr.comptime then
      return false
    end
  end
  return true
end

function visitors.InitList(_, node, emitter, untypedinit)
  local attr = node.attr
  local childnodes, type = node, attr.type
  local len = #childnodes
  if len == 0 and type.is_aggregate then
    emitter:add_zeroed_type_literal(type, not untypedinit)
  elseif type.is_composite then
    if type.cconstruct then -- used to construct vector types when generating GLSL code
      --luacov:disable
      emitter:add(type,'(')
      emitter:add_list(childnodes)
      emitter:add(')')
      --luacov:enable
    else
      if can_use_initializer(node) then
        if not untypedinit then
          emitter:add('(',type,')')
        end
        emitter:add_text('{')
        local lastfieldindex = 0
        for i=1,#childnodes do
          local childnode = childnodes[i]
          if i > 1 then
            emitter:add_text(', ')
          end
          local childvalnode, field
          if childnode.is_Pair then
            childvalnode = childnode[2]
            field = type.fields[childnode[1]]
            emitter:add('.', field.name, ' = ')
          else
            childvalnode = childnode
            field = type.fields[lastfieldindex + 1]
          end
          lastfieldindex = field.index
          assert(field)
          local fieldtype = type.fields[field.name].type
          if fieldtype.is_array then
            assert(childvalnode.is_InitList)
            emitter:add_text('{')
            for j,arrchildnode in ipairs(childvalnode) do
              if j > 1 then
                emitter:add_text(', ')
              end
              emitter:add_converted_val(fieldtype.subtype, arrchildnode, nil, nil, true)
            end
            emitter:add_text('}')
          else
            emitter:add_converted_val(fieldtype, childvalnode, nil, nil, true)
          end
        end
        emitter:add_text('}')
      else
        emitter:add_ln('({') emitter:inc_indent()
        emitter:add_indent(type, ' _tmp = ')
        emitter:add_zeroed_type_literal(type)
        emitter:add_ln(';')
        local lastfieldindex = 0
        for i=1,#childnodes do
          local childnode = childnodes[i]
          local childvalnode, field
          if childnode.is_Pair then
            childvalnode = childnode[2]
            field = type.fields[childnode[1]]
          else
            childvalnode = childnode
            field = type.fields[lastfieldindex + 1]
          end
          lastfieldindex = field.index
          assert(field)
          local childvaltype = childvalnode.attr.type
          if childvaltype.is_array then
            emitter:add_indent('((', childvaltype, '_cast*)&_tmp.', field.name, ')->a = ')
          else
            emitter:add_indent('_tmp.', field.name, ' = ')
          end
          local fieldtype = type.fields[field.name].type
          emitter:add_converted_val(fieldtype, childvalnode)
          emitter:add_ln(';')
        end
        emitter:add_indent_ln('_tmp;')
        emitter:dec_indent() emitter:add_indent('})')
      end
    end
  elseif type.is_array then
    local subtype = type.subtype
    if can_use_initializer(node) then
      if untypedinit then
        emitter:add_text('{')
      else
        emitter:add('(',type,'){{')
      end
      for i,childnode in ipairs(childnodes) do
        if i > 1 then
          emitter:add_text(', ')
        end
        emitter:add_converted_val(subtype, childnode, nil, nil, true)
      end
      if untypedinit then
        emitter:add_text('}')
      else
        emitter:add_text('}}')
      end
    else
      emitter:add_ln('({') emitter:inc_indent()
      emitter:add_indent(type, ' _tmp = ')
      emitter:add_zeroed_type_literal(type)
      emitter:add_ln(';')
      for i=1,#childnodes do
        if subtype.is_array then
          emitter:add_indent('((', subtype, '_cast*)&_tmp.v[', i-1 ,'])->a = ')
        else
          emitter:add_indent('_tmp.v[', i-1 ,'] = ')
        end
        emitter:add_converted_val(subtype, childnodes[i])
        emitter:add_ln(';')
      end
      emitter:add_indent_ln('_tmp;')
      emitter:dec_indent() emitter:add_indent('})')
    end
  else --luacov:disable
    assert(type.is_table)
    node:raisef('table literals is not implemented yet')
  end --luacov:enable
end

-- Process directives, they may effect code generation.
function visitors.Directive(context, node, emitter)
  local name, args = node[1], node[2]
  if name == 'cinclude' then
    local code = args[1]
    if traits.is_function(code) then
      local decemitter = CEmitter(context)
      code(decemitter)
      code = decemitter:generate()
      context:add_directive(code)
    else
      context:ensure_include(code)
    end
  elseif name == 'cfile' then
    context:ensure_cfile(args[1])
  elseif name == 'cincdir' then
    context:ensure_cincdir(args[1])
  elseif name == 'cemit' then
    local code = args[1]
    if traits.is_string(code) then
      emitter:add(stringer.ensurenewline(code))
    elseif traits.is_function(code) then
      code(emitter)
    end
  elseif name == 'cemitdecl' then
    local code = args[1]
    if traits.is_string(code) then
      code = stringer.ensurenewline(code)
    elseif traits.is_function(code) then
      local decemitter = CEmitter(context)
      code(decemitter)
      code = decemitter:generate()
    end
    context:add_declaration(code)
  elseif name == 'cemitdefn' then
    local code = args[1]
    if traits.is_string(code) then
      code = stringer.ensurenewline(code)
    elseif traits.is_function(code) then
      local defemitter = CEmitter(context)
      code(defemitter)
      code = defemitter:generate()
    end
    context:add_definition(code)
  elseif name == 'cdefine' then
    context:ensure_define(args[1])
  elseif name == 'cflags' then
    table.insert(context.compileopts.cflags, args[1])
  elseif name == 'ldflags' then
    table.insert(context.compileopts.ldflags, args[1])
  elseif name == 'stripflags' then
    table.insert(context.compileopts.stripflags, args[1])
  elseif name == 'linklib' then
    context:ensure_linklib(args[1])
  elseif name == 'linkdir' then
    context:ensure_linkdir(args[1])
  elseif name == 'pragmapush' then
    context:push_forked_pragmas(args[1])
  elseif name == 'pragmapop' then
    context:pop_pragmas()
  elseif name == 'pragma' then
    tabler.update(context.pragmas, args[1])
  end
end

-- Emits a identifier.
function visitors.Id(context, node, emitter, untypedinit)
  local attr = node.attr
  local type = attr.type
  if type.is_nilptr then
    emitter:add_null()
  elseif type.is_niltype then
    emitter:add_nil_literal()
  elseif attr.comptime then
    emitter:add_literal(attr, untypedinit)
  else
    emitter:add(context:declname(attr))
  end
end

-- Emits a expression between parenthesis.
function visitors.Paren(_, node, emitter)
  -- adding parenthesis is not needed, because other expressions already adds them
  emitter:add(node[1])
end

-- Emits declaration of identifiers.
function visitors.IdDecl(context, node, emitter)
  local attr = node.attr
  local type = attr.type
  local name = context:declname(attr)
  if context.state.infuncdecl then -- function name
    emitter:add(name)
  elseif type.is_comptime or attr.comptime then -- pass compile-time identifiers as `nil`
    emitter:add_builtin('nlniltype')
    emitter:add(' ', name)
  else -- runtime declaration
    emitter:add_qualified_declaration(attr, type, name)
  end
end

local function visitor_Call(context, node, emitter, argnodes, callee, calleeobjnode)
  local isstatement = context:get_visiting_node(1).is_Block
  local attr = node.attr
  local calleetype = attr.calleetype
  assert(calleetype.is_procedure) -- a function call is expected
  local sequential = false -- whether arguments need to be evaluated sequentially
  local returnfirst = false -- whether to return just the first of a multiple return
  local tmpcallee = false -- whether callee object should be evaluated temporary
  local lastcalltmp = nil -- name of the last argument call temporary multiple return
  local tmpcount = 0
  local tmpargs = {}
  local calleesym = attr.calleesym
  local calleeobj = calleeobjnode
  local calleeobjtype
  local selftype = attr.ismethod and calleetype.argtypes[1]
  local callargtypes = attr.pseudoargtypes or calleetype.argtypes
  local callargattrs = attr.pseudoargattrs or calleetype.argattrs
  for i,funcargtype,argnode,_,lastcallindex in izipargnodes(callargtypes, argnodes) do
    if not argnode and funcargtype.is_multipleargs then
      break
    end
    if (argnode and argnode.attr.sideeffect) or lastcallindex == 1 then
      -- expressions with side effects need to be evaluated in sequence
      -- and expressions with multiple returns needs to be stored in a temporary
      tmpcount = tmpcount + 1
      tmpargs[i] = '_tmp'..tmpcount
      if lastcallindex == 1 then
        lastcalltmp = tmpargs[i]
      end
      if tmpcount >= 2 or lastcallindex then
        -- only need to evaluate in sequence mode if we have two or more temporaries
        -- or the last argument is a multiple return call
        sequential = true
      end
    end
  end
  if not isstatement and #calleetype.rettypes > 1 and not attr.usemultirets then -- we are handling the returns
    returnfirst = true
  end
  if selftype and not calleesym and not calleeobjnode.is_Id then
    tmpcallee = true
    sequential = true
  end
  -- begin call
  if sequential then -- begin sequential expression
    if isstatement then
      emitter:add_indent_ln('{')
    else
      emitter:add_ln('({')
    end
    emitter:inc_indent()
    -- evaluate arguments in sequence
    for _,tmparg,argnode,argtype,_,lastcalletype in izipargnodes(tmpargs, argnodes) do
      if tmparg then -- evaluate temporary values in sequence
        if lastcalletype then -- type for result of multiple return call
          argtype = context:funcrettypename(lastcalletype)
        end
        emitter:add_indent_ln(argtype, ' ', tmparg, ' = ', argnode, ';')
      end
    end
    if tmpcallee then -- temporary callee
      emitter:add_indent(selftype, ' _calleobj = ')
      emitter:add_converted_val(selftype, calleeobjnode)
      emitter:add_ln(';')
      calleeobj = '_calleobj'
      calleeobjtype = selftype
    end
    emitter:add_indent()
  elseif isstatement then -- begin statement
    emitter:add_indent()
  end
  -- add callee
  if selftype then
    if calleesym then
      emitter:add_value(calleesym)
    else
      emitter:add_converted_val(selftype, calleeobj, calleeobjtype)
      emitter:add_text(selftype.is_pointer and '->' or '.')
      emitter:add_value(callee)
    end
    emitter:add_text('(')
    if attr.ismetacall then
      emitter:add_converted_val(selftype, node[2], calleeobjtype)
    else
      emitter:add_converted_val(selftype, calleeobj, calleeobjtype)
    end
  else
    emitter:add_value(callee)
    emitter:add_text('(')
  end
  -- add call arguments
  for i,funcargtype,argnode,argtype,lastcallindex in izipargnodes(callargtypes, argnodes) do
    if not argnode and funcargtype.is_multipleargs then
      break
    end
    if i > 1 or selftype then
      emitter:add_text(', ')
    end
    local arg = argnode
    if sequential then
      if lastcallindex then
        arg = lastcalltmp..'.r'..lastcallindex
      elseif tmpargs[i] then
        arg = tmpargs[i]
      end
    end
    local callargattr = callargattrs[i]
    if callargattr.comptime then -- compile time function argument
      emitter:add_nil_literal()
      if argnode and argnode.is_Function then -- force declaration of anonymous functions
        emitter:fork():add(argnode)
      end
    else
      emitter:add_converted_val(funcargtype, arg, argtype)
    end
  end
  emitter:add_text(')')
  -- add returns
  if returnfirst then -- get just the first result from a multiple return
    emitter:add_text('.r1')
  end
  -- end call
  if sequential then -- end sequential expression
    emitter:add_ln(';')
    emitter:dec_indent()
    if isstatement then
      emitter:add_indent_ln('}')
    else
      emitter:add_indent('})')
    end
  elseif isstatement then -- finish statement
    emitter:add_ln(";")
  end
end

-- Emits a call.
function visitors.Call(context, node, emitter, untyped)
  local argnodes, calleenode = node[1], node[2]
  local attr = node.attr
  if attr.calleetype.is_type then -- is a type cast?
    local argnode = argnodes[1]
    local argtype = argnode and argnode.attr.type
    local type = attr.type
    untyped = untyped and (not argtype or type == argtype)
    emitter:add_converted_val(type, argnode, argtype, true, untyped)
  else -- usual function call
    local callee = calleenode
    local calleeattr = calleenode.attr
    local calleesym = attr.calleesym
    if calleeattr.builtin then -- is a builtin call?
      local builtin = cbuiltins.calls[calleeattr.name]
      callee = builtin(context, node, emitter)
    elseif calleesym then
      if calleesym.type.is_function then -- force declaration of functions
        emitter:fork():add(calleenode)
      end
      callee = calleesym
    end
    if callee then -- call not omitted?
      visitor_Call(context, node, emitter, argnodes, callee)
    end
  end
end

-- Emits a method call.
function visitors.CallMethod(context, node, emitter)
  local name, argnodes, calleeobjnode = node[1], node[2], node[3]
  visitor_Call(context, node, emitter, argnodes, name, calleeobjnode)
end

-- Emits field indexing.
function visitors.DotIndex(context, node, emitter, untypedinit)
  local attr = node.attr
  local objnode = node[2]
  local objtype = objnode.attr.type
  if objnode.attr.requirename then -- require call
    local rollbackpos = emitter:get_pos()
    emitter:add_indent()
    emitter:add(objnode)
    if emitter:get_pos() == rollbackpos+1 then
      emitter:rollback(rollbackpos) -- revert text added
    else
      emitter:add(';')
    end
  elseif attr.comptime then -- compile-time constant
    emitter:add_literal(attr, untypedinit)
  elseif objtype.is_type then -- global field
    emitter:add(context:declname(attr))
  else -- record/union field
    local type = attr.type
    local castarray = type.is_array and not attr.arrayindex
    if castarray then
      emitter:add('(((', type, '_cast*)&')
    end
    local name = attr.dotfieldname or node[1]
    if objtype.is_pointer then
      emitter:add(objnode, '->', cdefs.quotename(name))
    else
      emitter:add(objnode, '.', cdefs.quotename(name))
    end
    if castarray then
      emitter:add(')->a)')
    end
  end
end

-- Emits method field indexing.
function visitors.ColonIndex(context, node, emitter)
  visitors.DotIndex(context, node, emitter)
end

-- Emits key indexing.
function visitors.KeyIndex(context, node, emitter)
  local indexnode, objnode = node[1], node[2]
  local objattr = objnode.attr
  local type = node.attr.type
  local objtype = objattr.type
  local pointer = false
  if objtype.is_pointer and objtype.subtype then -- indexing a pointer to an array
    objtype = objtype.subtype
    pointer = true
  end
  if objtype.is_array then -- array indexing
    local topobjnode = node
    while topobjnode.is_KeyIndex do
      topobjnode = topobjnode[2]
    end
    local castarray
    if type.is_array then
      local parent_node = context:get_visiting_node(1)
      if not parent_node.is_KeyIndex or not parent_node[2].attr.type.is_array then
        emitter:add('(((', type, '_cast*)&')
        castarray = true
      end
    end
    if (pointer and objtype.length == 0) or -- unbounded array
       (not pointer and objnode.is_KeyIndex and objnode.attr.type.is_array) or -- multidimensional index
       (not pointer and topobjnode.is_DotIndex and topobjnode[2].attr.type:implicit_deref_type().is_composite) then
      -- record/union array field
      objattr.arrayindex = true
      emitter:add(objnode, '[')
    elseif pointer then -- pointer to bounded array
      emitter:add(objnode, '->v[')
    else -- bounded array
      emitter:add(objnode, '.v[')
    end
    if not context.pragmas.nochecks and objtype.length > 0 and not indexnode.attr.comptime then
      emitter:add_builtin('nelua_assert_bounds_', indexnode.attr.type)
      emitter:add('(', indexnode, ', ', objtype.length, ')]')
    else
      emitter:add(indexnode, ']')
    end
    if castarray then
      emitter:add(')->a)')
    end
  else --luacov:disable
    assert(objtype.is_table)
    node:raisef('table indexing is not implemented yet')
  end --luacov:enable
end

-- Emits all statements from a block.
function visitors.Block(context, node, emitter)
  local scope = context:push_forked_scope(node)
  emitter:inc_indent()
  emitter:add_list(node, '')
  if scope.parent.is_repeat_loop then
    scope.parent.emit_repeat_stop(emitter)
  end
  local laststat = node[#node]
  if laststat and not laststat.is_breakflow then
    cgenerator.emit_close_scope(context, emitter, scope, true)
  end
  emitter:dec_indent()
  context:pop_scope()
end

-- Emits `return` statement.
function visitors.Return(context, node, emitter)
  local deferemitter = emitter:fork()
  -- close parent blocks before returning
  local scope = context.scope
  local retscope = scope:get_up_function_scope()
  cgenerator.emit_close_upscopes(context, deferemitter, scope, retscope)
  local funcscope = context.state.funcscope
  assert(funcscope == retscope)
  local functype = funcscope.funcsym and funcscope.funcsym.type
  local numrets = functype and #functype.rettypes or #node
  if numrets == 0 then -- no returns
    emitter:add_value(deferemitter)
    if retscope.is_root then -- main must always return an integer
      emitter:add_indent_ln('return 0;')
    else
      emitter:add_indent_ln('return;')
    end
  elseif numrets == 1 then -- one return
    local retnode = node[1]
    local rettype
    if retscope.is_root then
      rettype = retscope.rettypes and retscope.rettypes[1] or primtypes.cint
      if rettype and not rettype.is_integral then
        node:raisef("main cannot return value of type '%s', only integral numbers can be returned", rettype)
      end
    else
      rettype = functype:get_return_type(1)
    end
    if not deferemitter:empty() and not (retnode and retnode.attr.comptime) then
      local retname = funcscope:generate_name('_ret')
      emitter:add_indent(rettype, ' ', retname, ' = ')
      emitter:add_converted_val(rettype, retnode)
      emitter:add_ln(';')
      emitter:add_value(deferemitter)
      emitter:add_indent_ln('return ', retname, ';')
    else
      emitter:add_value(deferemitter)
      emitter:add_indent('return ')
      emitter:add_converted_val(rettype, retnode, nil, true)
      emitter:add_ln(';')
    end
  else -- multiple returns
    if retscope.is_root then
      node:raisef("multiple returns in main is not supported")
    end
    local funcrettypename = context:funcrettypename(functype)
    local multiretvalname, retname, retemitter
    local sideeffects = not deferemitter:empty() or node:recursive_has_attr('sideeffect')
    if sideeffects then
      retname = funcscope:generate_name('_mulret')
      emitter:add_indent_ln(funcrettypename, ' ', retname, ';')
    else -- no side effects
      retemitter = emitter:fork()
      retemitter:add_indent('return (', funcrettypename, '){')
    end
    for i,funcrettype,retnode,rettype,lastcallindex in izipargnodes(functype.rettypes, node) do
      if not sideeffects and i > 1 then
        retemitter:add(', ')
      end
      if lastcallindex == 1 then -- last assignment value may be a multiple return call
        multiretvalname = funcscope:generate_name('_ret')
        local rettypename = context:funcrettypename(retnode.attr.calleetype)
        emitter:add_indent_ln(rettypename, ' ', multiretvalname, ' = ', retnode, ';')
      end
      local retvalname = retnode
      if lastcallindex then
        retvalname = string.format('%s.r%d', multiretvalname, lastcallindex)
      end
      if sideeffects then
        emitter:add_indent(string.format('%s.r%d', retname, i), ' = ')
        emitter:add_converted_val(funcrettype, retvalname, rettype)
        emitter:add_ln(';')
      else
        retemitter:add_converted_val(funcrettype, retvalname, rettype)
      end
    end
    if sideeffects then
      emitter:add(deferemitter)
      emitter:add_indent_ln('return ', retname, ';')
    else -- no side effects
      retemitter:add_ln('};')
      emitter:add(retemitter)
    end
  end
end

-- Emits `in` statement.
function visitors.In(context, node, emitter)
  -- close parent blocks before returning
  local scope = context.scope
  local exprscope = scope:get_up_doexpr_scope()
  local deferemitter = emitter:fork()
  cgenerator.emit_close_upscopes(context, deferemitter, scope, exprscope)
  local retnode = node[1]
  emitter:add_indent_ln('_expr = ', retnode, ';')
  emitter:add(deferemitter)
  local needgoto = true
  if context:get_visiting_node(2).is_DoExpr then
    local blockstats = context:get_visiting_node(1)
    if node == blockstats[#blockstats] then -- last statement does not need goto
      needgoto = false
    end
  end
  if needgoto then
    local doexprlabel = exprscope.doexprlabel
    if not doexprlabel then
      doexprlabel = context.scope:get_up_function_scope():generate_name('_doexprlabel')
      exprscope.doexprlabel = doexprlabel
    end
    emitter:add_indent_ln('goto ', doexprlabel, ';')
  end
end

-- Emits `if` statement.
function visitors.If(_, node, emitter)
  local ifpairs, elseblock = node[1], node[2]
  for i=1,#ifpairs,2 do
    local condnode, blocknode = ifpairs[i], ifpairs[i+1]
    if i == 1 then -- first if
      emitter:add_indent("if(")
      emitter:add_val2boolean(condnode)
      emitter:add_ln(") {")
    else -- other ifs
      emitter:add_indent("} else if(")
      emitter:add_val2boolean(condnode)
      emitter:add_ln(") {")
    end
    emitter:add(blocknode)
  end
  if elseblock then -- else
    emitter:add_indent_ln("} else {")
    emitter:add(elseblock)
  end
  emitter:add_indent_ln("}")
end

-- Emits `switch` statement.
function visitors.Switch(context, node, emitter)
  local valnode, casepairs, elsenode = node[1], node[2], node[3]
  emitter:add_indent_ln("switch(", valnode, ") {") emitter:inc_indent()
  context:push_forked_scope(node)
  for i=1,#casepairs,2 do -- add case blocks
    local caseexprs, caseblock = casepairs[i], casepairs[i+1]
    for j=1,#caseexprs-1 do -- multiple cases
      emitter:add_indent_ln("case ", caseexprs[j], ":")
    end
    emitter:add_indent_ln("case ", caseexprs[#caseexprs], ': {') -- last case
    emitter:add(caseblock) -- block
    local laststmt = caseblock[#caseblock]
    if not laststmt or not laststmt.is_breakflow then
      emitter:add_indent_ln('  break;')
    end
    emitter:add_indent_ln("}")
  end
  if elsenode then -- add default case block
    emitter:add_indent_ln('default: {')
    emitter:add(elsenode)
    local laststmt = elsenode[#elsenode]
    if not laststmt or not laststmt.is_breakflow then
      emitter:add_indent_ln('  break;')
    end
    emitter:add_indent_ln("}")
  end
  context:pop_scope(node)
  emitter:dec_indent() emitter:add_indent_ln("}")
end

-- Emits `do` statement.
function visitors.Do(_, node, emitter)
  local blocknode = node[1]
  local rollbackpos = emitter:get_pos()
  emitter:add_indent_ln("{")
  local startpos = emitter:get_pos()
  emitter:add(blocknode)
  if emitter:get_pos() == startpos then -- no statement added, we can rollback
    emitter:rollback(rollbackpos)
  else
    emitter:add_indent_ln("}")
  end
end

-- Emits `(do end)` expression.
function visitors.DoExpr(context, node, emitter)
  local attr = node.attr
  local isstatement = context:get_visiting_node(1).is_Block
  if isstatement then
    if #node[1] == 0 then -- no statements
      return
    end
    emitter:add_indent()
  end
  local blocknode = node[1]
  if blocknode[1] and blocknode[1].is_In then -- single statement
    emitter:add(blocknode[1][1])
  elseif not attr.type then
    assert(isstatement)
    emitter:add_ln("{") emitter:inc_indent()
    context:push_forked_scope(node)
    emitter:add(blocknode)
    context:pop_scope()
    emitter:dec_indent() emitter:add_indent("}")
  else -- multiple statements
    assert(attr.type)
    emitter:add_ln("({") emitter:inc_indent()
    emitter:add_indent_ln(attr.type, ' _expr;')
    emitter:dec_indent()
    local scope = context:push_forked_scope(node)
    emitter:add(blocknode)
    context:pop_scope()
    emitter:inc_indent()
    local doexprlabel = scope.doexprlabel
    if doexprlabel then
      emitter:add_indent_ln(doexprlabel, ': _expr;')
    else
      emitter:add_indent_ln('_expr;')
    end
    emitter:dec_indent() emitter:add_indent("})")
  end
  if isstatement then
    emitter:add_ln(';')
  end
end

-- Emits `defer` statement.
function visitors.Defer(context, node)
  local blocknode = node[1]
  context.scope:add_defer_block(blocknode)
end

-- Emits `while` statement.
function visitors.While(context, node, emitter)
  local condnode, blocknode = node[1], node[2]
  emitter:add_indent("while(")
  emitter:add_val2boolean(condnode)
  emitter:add_ln(') {')
  local scope = context:push_forked_scope(node)
  emitter:add(blocknode)
  context:pop_scope()
  emitter:add_indent_ln("}")
  if scope.breaklabel then
    emitter:add_indent_ln(scope.breaklabel, ':;')
  end
end

-- Emits `repeat` statement.
function visitors.Repeat(context, node, emitter)
  local blocknode, condnode = node[1], node[2]
  emitter:add_indent_ln("{")
  emitter:inc_indent()
  context:ensure_type(primtypes.boolean)
  emitter:add_indent_ln("bool _repeat_stop;")
  emitter:add_indent_ln("do {")
  local scope = context:push_forked_scope(node)
  scope.emit_repeat_stop = function(block_emitter)
    context:push_node(node) -- to fix get_visiting_node() call
    block_emitter:add_indent('_repeat_stop = ')
    block_emitter:add_val2boolean(condnode)
    block_emitter:add_ln(';')
    context:pop_node(node)
  end
  emitter:add(blocknode)
  context:pop_scope()
  emitter:add_indent_ln('} while(!_repeat_stop);')
  emitter:dec_indent()
  if scope.breaklabel then
    emitter:add_indent_ln(scope.breaklabel, ':;')
  end
  emitter:add_indent_ln('}')
end

-- Emits numeric `for` statement.
function visitors.ForNum(context, node, emitter)
  local itnode, begvalnode, endvalnode, stepvalnode, blocknode = node[1], node[2], node[4], node[5], node[6]
  local attr = node.attr
  local compop, fixedstep, fixedend = attr.compop, attr.fixedstep, attr.fixedend
  local itattr = itnode.attr
  local ittype, itmutate = itattr.type, itattr.mutate or itattr.refed
  local itforname = itmutate and '_it' or context:declname(itattr)
  local scope = context:push_forked_scope(node)
  emitter:add_indent('for(')
  emitter:add_qualified_declaration({}, ittype, itforname)
  emitter:add(' = ')
  emitter:add_converted_val(ittype, begvalnode)
  local cmpval, stepval = endvalnode, fixedstep
  if not fixedend or not compop then -- end expression
    emitter:add(', _end = ')
    emitter:add_converted_val(ittype, endvalnode)
    cmpval = '_end'
  end
  if not fixedstep then -- step expression
    emitter:add(', _step = ')
    emitter:add_converted_val(ittype, stepvalnode)
    stepval = '_step'
  end
  emitter:add('; ')
  if compop then -- fixed compare operator
    local for_compare_ops = {
      le = '<=', ge = '>=',
      lt = '<',  gt = '>',
      ne = '!=', eq = '==',
    }
    emitter:add(itforname, ' ', for_compare_ops[compop], ' ')
    if traits.is_string(cmpval) then
      emitter:add(cmpval)
    else
      emitter:add_converted_val(ittype, cmpval)
    end
  else -- step is an expression, must detect the compare operation at runtime
    emitter:add('_step >= 0 ? ', itforname, ' <= _end : ', itforname, ' >= _end')
  end
  emitter:add_ln('; ', itforname, ' += ', stepval, ') {')

  if itmutate then -- block mutates the iterator, copy it
    emitter:inc_indent()
    emitter:add_indent_ln(itnode, ' = _it;')
    emitter:dec_indent()
  end
  emitter:add(blocknode)
  emitter:add_indent_ln('}')
  context:pop_scope()
  if scope.breaklabel then
    emitter:add_indent_ln(scope.breaklabel, ':;')
  end
end

-- Emits `break` statement.
function visitors.Break(context, _, emitter)
  local scope = context.scope
  cgenerator.emit_close_upscopes(context, emitter, scope, scope:get_up_loop_scope())
  local breakscope = context.scope:get_up_scope_of_any_kind('is_loop', 'is_switch')
  if breakscope.is_switch then -- use goto when inside a switch to not break it
    breakscope = context.scope:get_up_loop_scope()
    local breaklabel = breakscope.breaklabel
    if not breaklabel then -- generate a break label
      breaklabel = context.scope:get_up_function_scope():generate_name('_breaklabel')
      breakscope.breaklabel = breaklabel
    end
    emitter:add_indent_ln('goto ', breaklabel, ';')
  else
    emitter:add_indent_ln('break;')
  end
end

-- Emits `continue` statement.
function visitors.Continue(context, _, emitter)
  local scope = context.scope
  local loopscope = scope:get_up_loop_scope()
  if loopscope.is_repeat_loop then
    loopscope.emit_repeat_stop(emitter)
  end
  cgenerator.emit_close_upscopes(context, emitter, scope, scope:get_up_loop_scope())
  emitter:add_indent_ln('continue;')
end

-- Emits `fallthrough` statement.
function visitors.Fallthrough(context, _, emitter)
  context:ensure_builtin('NELUA_FALLTHROUGH')
  emitter:add_indent_ln('NELUA_FALLTHROUGH(); /* fallthrough */')
end

function visitors.NoOp() end

-- Emits label statement.
function visitors.Label(context, node, emitter)
  local attr = node.attr
  if not attr.used then return end -- ignore unused labels
  emitter:add_ln(context:declname(attr), ':;')
end

-- Emits `goto` statement.
function visitors.Goto(context, node, emitter)
  local label = node.attr.label
  emitter:add_indent_ln('goto ', context:declname(label), ';')
end

-- Emits variable declaration statement.
function visitors.VarDecl(context, node, emitter)
  local varnodes, valnodes = node[2], node[3]
  local defemitter = emitter:fork()
  local multiretvalname
  local upfuncscope = context.scope:get_up_function_scope()
  for _,varnode,valnode,valtype,lastcallindex in izipargnodes(varnodes, valnodes or {}) do
    local varattr = varnode.attr
    local vartype = varattr.type
    if lastcallindex == 1 then -- last assignment may be a multiple return call
      multiretvalname = upfuncscope:generate_name('_asgnret')
      local rettypename = context:funcrettypename(valnode.attr.calleetype)
      emitter:add_indent_ln(rettypename, ' ', multiretvalname, ' = ', valnode, ';')
    end
    if varattr:must_declare_at_runtime() and (context.pragmas.nodce or varattr:is_used(true)) then
      local zeroinit = not context.pragmas.noinit and varattr:must_zero_initialize()
      local declared, defined
      if varattr.staticstorage then -- declare variables in the top scope
        local decemitter = CEmitter(context)
        local custominit = (valnode and vartype:is_initializable_from_attr(valnode.attr)) or varattr.ctopinit
        declared = true
        defined = custominit or (not valnode and not lastcallindex)
        varnode.attr.ignoreconst = not defined
        decemitter:add_indent(varnode)
        if custominit then -- initialize to const values
          assert(not lastcallindex)
          decemitter:add_text(' = ')
          if vartype.is_array then
            decemitter:add_text('{.v = ')
          end
          decemitter:add_converted_val(vartype, valnode, nil, nil, vartype.is_aggregate)
          if vartype.is_array then
            decemitter:add_text('}')
          end
        end
        decemitter:add_ln(';')
        context:add_declaration(decemitter:generate())
      end
      if varattr:must_define_at_runtime() then
        local asgnvalname, asgnvaltype = valnode, valtype
        if lastcallindex then
          asgnvalname = string.format('%s.r%d', multiretvalname, lastcallindex)
        end
        local mustdefine = not defined and (zeroinit or asgnvalname)
        if not declared or mustdefine then -- declare or define if needed
          if not declared then
            defemitter:add_indent(varnode)
          else
            defemitter:add_indent(context:declname(varattr))
          end
          if mustdefine then -- initialize variable
            defemitter:add(' = ')
            defemitter:add_converted_val(vartype, asgnvalname, asgnvaltype)
          end
          defemitter:add_ln(';')
        end
      elseif not defined and not vartype.is_comptime and valnode and
                             not valnode.attr.comptime and not lastcallindex then -- could be a call
        emitter:add_indent_ln(valnode, ';')
      end
    elseif not vartype.is_comptime and valnode and
           not valnode.attr.comptime and not lastcallindex then -- could be a call
      emitter:add_indent_ln(valnode, ';')
    elseif valnode and valnode.attr.requirename then -- require call
      local rollbackpos = emitter:get_pos()
      emitter:add_indent()
      emitter:add(valnode)
      if emitter:get_pos() == rollbackpos+1 then
        emitter:rollback(rollbackpos) -- revert text added
      else
        emitter:add(';')
      end
    end
    if varattr.cinclude and (context.pragmas.nodce or varattr:is_used(true)) then
      context:ensure_include(varattr.cinclude)
    end
  end
  emitter:add(defemitter)
end

-- Emits assignment statement.
function visitors.Assign(context, node, emitter)
  local varnodes, valnodes = node[1], node[2]
  local defemitter = emitter:fork()
  local multiretvalname
  local upfuncscope = context.scope:get_up_function_scope()
  for _,varnode,valnode,valtype,lastcallindex in izipargnodes(varnodes, valnodes or {}) do
    local varattr = varnode.attr
    local vartype = varattr.type
    if lastcallindex == 1 then -- last assignment may be a multiple return call
      multiretvalname = upfuncscope:generate_name('_asgnret')
      local rettypename = context:funcrettypename(valnode.attr.calleetype)
      emitter:add_indent_ln(rettypename, ' ', multiretvalname, ' = ', valnode, ';')
    end
    if varattr:must_define_at_runtime() then
      local asgnvalname, asgnvaltype = valnode, valtype
      if lastcallindex then
        asgnvalname = string.format('%s.r%d', multiretvalname, lastcallindex)
      elseif #valnodes > 1 then -- multiple assignments, assign to a temporary first
        asgnvalname, asgnvaltype = upfuncscope:generate_name('_asgntmp'), valtype
        emitter:add_indent(vartype, ' ', asgnvalname, ' = ')
        emitter:add_converted_val(vartype, valnode, valtype)
        emitter:add_ln(';')
      end
      defemitter:add_indent(varnode, ' = ')
      defemitter:add_converted_val(vartype, asgnvalname, asgnvaltype)
      defemitter:add_ln(';')
    elseif not vartype.is_comptime and valnode and
           not valnode.attr.comptime and not lastcallindex then -- could be a call
      emitter:add_indent_ln(valnode, ';')
    elseif valnode and valnode.attr.requirename then -- require call
      local rollbackpos = emitter:get_pos()
      emitter:add_indent()
      emitter:add(valnode)
      if emitter:get_pos() == rollbackpos+1 then
        emitter:rollback(rollbackpos) -- revert text added
      else
        emitter:add(';')
      end
    end
  end
  emitter:add(defemitter)
end

-- Emits function definition statement.
function visitors.FuncDef(context, node, emitter)
  local attr = node.attr
  local type = attr.type
  if type.is_polyfunction then -- is a polymorphic function?
    local polyevals = type.evals
    for i=1,#polyevals do -- emit all evaluations
      local polyeval = polyevals[i]
      emitter:add(polyeval.node)
    end
    return -- nothing more to do
  end
  if not context.pragmas.nodce and not attr:is_used(true) then
    return -- didn't pass dead code elimination, omit it
  end
  if attr.cinclude then -- requires a including a C file?
    context:ensure_include(attr.cinclude)
  end
  if attr.cimport and cdefs.builtins_headers[attr.codename] then -- importing a builtin?
    context:ensure_builtin(attr.codename) -- ensure the builtin is declared and defined
    return -- nothing more to do
  end
  local mustdecl, mustdefn = node.funcdecl and not attr.nodecl, node.funcdefn
  if attr.forwarddecl and not attr.funcdefined then
    node:raisef("function '%s' marked as forward declaration but was never defined", attr)
  end
  if not (mustdecl or mustdefn) then -- do we need to declare or define?
    return -- nothing to do
  end
  -- lets declare or define the function
  local varnode, argnodes, blocknode = node[2], node[3], node[6]
  local funcname = varnode
  -- handle function variable assignment
  if not attr.funcdeclared or not attr.comptime then
    if varnode.is_IdDecl then
      funcname = context.rootscope:generate_name(context:declname(varnode.attr))
      emitter:add_indent_ln(varnode, ' = ', funcname, ';')
    elseif varnode.is_Id then
      funcname = context.rootscope:generate_name(context:declname(varnode.attr))
      emitter:add_indent_ln(varnode, ' = ', funcname, ';')
    elseif varnode.is_index then
      local fieldname, objtype = varnode[1], varnode[2].attr.type
      if objtype.is_record or (objtype.is_pointer and objtype.subtype.is_record) then
        funcname = context.rootscope:generate_name(objtype.codename..'_funcdef_'..fieldname)
        emitter:add_indent_ln(varnode, ' = ', funcname, ';')
      end
    end
  end
  -- push function state
  local funcscope = context:push_forked_scope(node)
  context:push_forked_state{funcscope = funcscope}
  -- add function return type and name
  context:push_forked_state{infuncdecl = true}
  local rettypename = context:funcrettypename(type)
  local decemitter, defemitter
  if mustdecl then
    decemitter = CEmitter(context)
    decemitter:add_indent()
    decemitter:add_qualified_declaration(attr, rettypename, funcname)
  end
  if mustdefn then
    defemitter = CEmitter(context)
    defemitter:add_indent(rettypename, ' ', funcname)
  end
  context:pop_state()
  -- add function arguments
  local argsemitter = CEmitter(context)
  if varnode.is_ColonIndex or #argnodes > 0 then
    argsemitter:add('(')
    if varnode.is_ColonIndex then -- need to inject first argument `self`
      local selftype = type.argtypes[1]
      argsemitter:add(selftype, ' self')
      if #argnodes > 0 then -- extra arguments?
        argsemitter:add(', ')
      end
    end
    argsemitter:add(argnodes, ')')
  else
    argsemitter:add('(void)')
  end
  -- add function declaration
  if mustdecl then
    decemitter:add_ln(argsemitter, ';')
    context:add_declaration(decemitter:generate(), attr.codename)
  end
  -- add function definition
  if mustdefn then
    defemitter:add_ln(argsemitter, ' {')
    local implemitter = CEmitter(context)
    implemitter:add(blocknode)
    implemitter:add_indent_ln('}')
    if attr.entrypoint and not context.hookmain then -- this function is the main hook
      context.emitentrypoint = function(mainemitter)
        defemitter:add(mainemitter) -- emit top scope statements
        defemitter:add(implemitter) -- emit this function statements
        context:add_definition(defemitter:generate())
      end
    else
      defemitter:add(implemitter)
      context:add_definition(defemitter:generate())
    end
  end
  -- restore state
  context:pop_state()
  context:pop_scope()
end

-- Emits anonymous functions.
function visitors.Function(context, node, emitter)
  local argnodes, blocknode = node[1], node[4]
  local attr = node.attr
  local argsemitter, decemitter, defemitter = CEmitter(context), CEmitter(context), CEmitter(context)
  -- add function qualifiers and name
  local declname = context:declname(attr)
  local rettypename = context:funcrettypename(attr.type)
  decemitter:add_qualified_declaration(attr, rettypename, declname)
  defemitter:add(rettypename, ' ', declname)
  emitter:add(declname)
  local funcscope = context:push_forked_scope(node)
  context:push_forked_state{funcscope = funcscope}
  -- add function arguments
  if #argnodes > 0 then
    argsemitter:add('(', argnodes, ')')
  else
    argsemitter:add('(void)')
  end
  decemitter:add_ln(argsemitter, ';')
  defemitter:add_ln(argsemitter, ' {')
  -- add function block
  defemitter:add(blocknode)
  defemitter:add_ln('}')
  context:pop_state()
  context:pop_scope()
  -- add function declaration and definition
  context:add_declaration(decemitter:generate())
  context:add_definition(defemitter:generate())
end

-- Emits operation on one expression.
function visitors.UnaryOp(context, node, emitter, untypedinit)
  local attr = node.attr
  if attr.type.is_any then
    node:raisef("compiler deduced type 'any' here, but it's not supported yet, please fix this variable type")
  end
  if attr.comptime then -- compile time constant
    emitter:add_literal(attr, untypedinit)
    return
  end
  local opname, argnode = node[1], node[2]
  local builtin = cbuiltins.operators[opname]
  builtin(context, node, emitter, argnode.attr, argnode)
end

-- Emits operation between two expressions.
function visitors.BinaryOp(context, node, emitter, untypedinit)
  local attr = node.attr
  local type = attr.type
  if type.is_any then
    node:raisef("compiler deduced type 'any' here, but it's not supported yet, please fix this variable type")
  end
  if attr.comptime then -- compile time constant
    emitter:add_literal(attr, untypedinit)
    return
  end
  local lnode, opname, rnode = node[1], node[2], node[3]
  if attr.dynamic_conditional then
    if attr.ternaryor then -- lua style "ternary" operator
      local anode, bnode, cnode = lnode[1], lnode[3], rnode
      if anode.attr.type.is_boolean and not bnode.attr.type.is_falseable then -- use C ternary operator
        emitter:add('(')
        emitter:add_val2boolean(anode)
        emitter:add(' ? ')
        emitter:add_converted_val(type, bnode)
        emitter:add(' : ')
        emitter:add_converted_val(type, cnode)
        emitter:add(')')
      else
        emitter:add_ln('({') emitter:inc_indent()
        emitter:add_indent(type, ' t_ = ')
        emitter:add_zeroed_type_literal(type)
        emitter:add_ln(';')
        emitter:add_indent(primtypes.boolean, ' cond_ = ')
        emitter:add_val2boolean(anode)
        emitter:add_ln(';')
        emitter:add_indent_ln('if(cond_) {') emitter:inc_indent()
        emitter:add_indent('t_ = ')
        emitter:add_converted_val(type, bnode)
        emitter:add_ln(';')
        emitter:add_indent('cond_ = ')
        emitter:add_val2boolean('t_', type)
        emitter:add_ln(';')
        emitter:dec_indent() emitter:add_indent_ln('}')
        emitter:add_indent_ln('if(!cond_) {') emitter:inc_indent()
        emitter:add_indent('t_ = ')
        emitter:add_converted_val(type, cnode)
        emitter:add_ln(';')
        emitter:dec_indent() emitter:add_indent_ln('}')
        emitter:add_indent_ln('t_;')
        emitter:dec_indent() emitter:add_indent('})')
      end
    else
      emitter:add_ln('({') emitter:inc_indent()
      emitter:add_indent(type, ' t1_ = ')
      emitter:add_converted_val(type, lnode)
      --TODO: be smart and remove this unused code
      emitter:add_ln(';')
      emitter:add_indent(type, ' t2_ = ')
      emitter:add_zeroed_type_literal(type)
      emitter:add_ln(';')
      if opname == 'and' then
        emitter:add_indent(primtypes.boolean, ' cond_ = ')
        emitter:add_val2boolean('t1_', type)
        emitter:add_ln(';')
        emitter:add_indent_ln('if(cond_) {') emitter:inc_indent()
        emitter:add_indent('t2_ = ')
        emitter:add_converted_val(type, rnode)
        emitter:add_ln(';')
        emitter:add_indent('cond_ = ')
        emitter:add_val2boolean('t2_', type)
        emitter:add_ln(';')
        emitter:dec_indent() emitter:add_indent_ln('}')
        emitter:add_indent('cond_ ? t2_ : ')
        emitter:add_zeroed_type_literal(type, true)
        emitter:add_ln(';')
      elseif opname == 'or' then
        emitter:add_indent(primtypes.boolean, ' cond_ = ')
        emitter:add_val2boolean('t1_', type)
        emitter:add_ln(';')
        emitter:add_indent_ln('if(!cond_) {') emitter:inc_indent()
        emitter:add_indent('t2_ = ')
        emitter:add_converted_val(type, rnode)
        emitter:add_ln(';')
        emitter:dec_indent() emitter:add_indent_ln('}')
        emitter:add_indent_ln('cond_ ? t1_ : t2_;')
      end
      emitter:dec_indent() emitter:add_indent('})')
    end
  else
    local lname, rname = lnode, rnode
    local lattr, rattr = lnode.attr, rnode.attr
    local sequential = (lattr.sideeffect and rattr.sideeffect) and
                        not (opname == 'or' or opname == 'and')
    if sequential then
      -- need to evaluate args in sequence when a expression has side effects
      emitter:add_ln('({') emitter:inc_indent()
      emitter:add_indent_ln(lattr.type, ' t1_ = ', lnode, ';')
      emitter:add_indent_ln(rattr.type, ' t2_ = ', rnode, ';')
      emitter:add_indent()
      lname, rname = 't1_', 't2_'
    end
    local builtin = cbuiltins.operators[opname]
    builtin(context, node, emitter, lattr, rattr, lname, rname)
    if sequential then
      emitter:add_ln(';')
      emitter:dec_indent() emitter:add_indent('})')
    end
  end
end

-- Emits defers before exiting scope `scope`.
function cgenerator.emit_close_scope(context, emitter, scope)
  if scope.closing then return end
  scope.closing = true -- prevent closing again
  local deferblocks = scope.deferblocks
  if deferblocks then
    for i=#deferblocks,1,-1 do
      local deferblock = deferblocks[i]
      emitter:add_indent_ln('{ /* defer */')
      context:push_scope(deferblock.scope.parent)
      emitter:add(deferblock)
      context:pop_scope()
      emitter:add_indent_ln('}')
    end
  end
  scope.closing = nil -- allow to close again
end

-- Emits all defers when exiting a nested scope.
function cgenerator.emit_close_upscopes(context, emitter, scope, topscope)
  cgenerator.emit_close_scope(context, emitter, scope)
  if topscope and topscope ~= scope then
    repeat
      scope = scope.parent
      cgenerator.emit_close_scope(context, emitter, scope)
    until scope == topscope
  end
end

-- Emits C pragmas to disable harmless C warnings that the generated code may trigger.
function cgenerator.emit_warning_pragmas(context)
  if context.pragmas.nocwarnpragmas then return end
  local emitter = CEmitter(context)
  emitter:add[[
/* Disable some warnings that the generated code can trigger. */
#if defined(__clang__) && __clang_major__ >= 3
  #pragma clang diagnostic ignored "-Wtype-limits"
  #pragma clang diagnostic ignored "-Wwrite-strings"
  #pragma clang diagnostic ignored "-Wunused"
  #pragma clang diagnostic ignored "-Wunused-parameter"
  #pragma clang diagnostic ignored "-Wmissing-field-initializers"
  #pragma clang diagnostic ignored "-Wparentheses-equality"
  #pragma clang diagnostic ignored "-Wtautological-compare"
  #pragma clang diagnostic ignored "-Wmissing-braces"
  #ifndef __cplusplus
    #pragma clang diagnostic ignored "-Wincompatible-pointer-types"
    #pragma clang diagnostic error   "-Wimplicit-function-declaration"
    #pragma clang diagnostic error   "-Wimplicit-int"
  #else
    #pragma clang diagnostic ignored "-Wnarrowing"
    #pragma clang diagnostic ignored "-Wc99-designator"
  #endif
#elif defined(__GNUC__) && __GNUC__ >= 5
  #pragma GCC diagnostic ignored "-Wtype-limits"
  #pragma GCC diagnostic ignored "-Wwrite-strings"
  #pragma GCC diagnostic ignored "-Wunused-parameter"
  #pragma GCC diagnostic ignored "-Wunused-value"
  #pragma GCC diagnostic ignored "-Wunused-variable"
  #pragma GCC diagnostic ignored "-Wunused-function"
  #pragma GCC diagnostic ignored "-Wunused-but-set-variable"
  #pragma GCC diagnostic ignored "-Wmissing-field-initializers"
  #ifndef __cplusplus
    #pragma GCC diagnostic ignored "-Wmissing-braces"
    #pragma GCC diagnostic ignored "-Wincompatible-pointer-types"
    #pragma GCC diagnostic ignored "-Wdiscarded-qualifiers"
    #pragma GCC diagnostic error   "-Wimplicit-function-declaration"
    #pragma GCC diagnostic error   "-Wimplicit-int"
  #else
    #pragma GCC diagnostic ignored "-Wnarrowing"
  #endif
#endif
#if defined(_WIN32) && !defined(_CRT_SECURE_NO_WARNINGS)
  #define _CRT_SECURE_NO_WARNINGS
#endif
]]
  context:add_directive(emitter:generate(), 'warnings_pragmas') -- defines all the above pragmas
end

-- Emits C features checks, to make sure the Nelua compiler and the C compiler agrees on features.
function cgenerator.emit_feature_checks(context)
  if context.pragmas.nocstaticassert then return end
  local emitter = CEmitter(context)
  context:ensure_builtin('NELUA_STATIC_ASSERT')
  context:ensure_builtin('NELUA_ALIGNOF')
  emitter:add_ln('/* Checks if Nelua and C agrees on pointer size. */')
  -- it's important that pointer size is on agreement, otherwise primitives sizes will wrong
  emitter:add_ln('NELUA_STATIC_ASSERT(',
              'sizeof(void*) == ', primtypes.pointer.size, ' && ',
              'NELUA_ALIGNOF(void*) == ', primtypes.pointer.align,
              ', "Nelua and C disagree on pointer size or alignment");')
  context:add_directive(emitter:generate(), 'features_checks')
end

function cgenerator.emit_features_setup(context)
  if context.pragmas.nocfeaturessetup then return end
  local emitter = CEmitter(context)
  emitter:add([[
/* Enable 64 bit offsets for stdio APIs. */
#if !defined(_FILE_OFFSET_BITS) && __SIZEOF_LONG__ >= 8
  #define _FILE_OFFSET_BITS 64
#endif
/* Enable POSIX APIs in included headers. */
#if !defined(_POSIX_C_SOURCE) && !defined(_XOPEN_SOURCE) && !defined(_GNU_SOURCE) && !defined(_DEFAULT_SOURCE)
  #if defined(__gnu_linux__)
    #define _GNU_SOURCE
  #else
    #define _XOPEN_SOURCE 600
  #endif
#endif
]])
  context:add_directive(emitter:generate(), 'features_setup')
end

-- Emits `nelua_main`.
function cgenerator.emit_nelua_main(context, ast, emitter)
  assert(ast.is_Block) -- ast is expected to be a Block
  local rollbackpos = emitter:get_pos()
  emitter:add_text("int nelua_main(int argc, char** argv) {\n") -- begin block
  if context.cmainimports then
    emitter:inc_indent()
    for _,varname in ipairs(context.cmainimports) do
      emitter:add_indent_ln('nelua_',varname,' = ',varname,';')
    end
    emitter:dec_indent()
  end
  local startpos = emitter:get_pos() -- save current emitter position
  context:traverse_node(ast, emitter) -- emit ast statements
  if context.hookmain or emitter:get_pos() ~= startpos then -- main is used or statements were added
    if #ast == 0 or not ast[#ast].is_Return then -- last statement is not a return
      emitter:add_indent_ln("  return 0;") -- ensures that an int is always returned
    end
    emitter:add_ln("}") -- end bock
    local maindecl = 'static int nelua_main(int argc, char** argv);\n'
    if context.hookmain and context.hookmain.noinline then
      context:ensure_builtin('NELUA_NOINLINE')
      maindecl = 'NELUA_NOINLINE '..maindecl
    end
    context:add_declaration(maindecl, 'nelua_main')
  else -- empty main, we can skip `nelua_main` usage
    emitter:rollback(rollbackpos) -- revert text added for begin block
  end
end

-- Emits C `main`.
function cgenerator.emit_entrypoint(context, ast)
  local emitter = CEmitter(context)
  if context.pragmas.nocheading then
    context.compileopts.nocheading = true
  end
  context:push_forked_state{funcscope = context.rootscope}
  -- if custom entry point is set while `nelua_main` is not hooked,
  -- then we can skip `nelua_main` and `main` declarations
  if context.entrypoint and not context.hookmain then
    context:traverse_node(ast, emitter) -- emit ast statements
    context.emitentrypoint(emitter) -- inject ast statements into the custom entry point
  else -- need to define `nelua_main`, it will be called from the entry point
    cgenerator.emit_nelua_main(context, ast, emitter)
    -- if no custom entry point is set, then use `main` as the default entry point
    if not context.entrypoint and not context.pragmas.noentrypoint then
      emitter:add_indent_ln('int main(int argc, char** argv) {') emitter:inc_indent() -- begin block
      if context:is_declared('nelua_main') then -- `nelua_main` is declared
        emitter:add_indent_ln('return nelua_main(argc, argv);') -- return `nelua_main` results
      else -- `nelua_main` is not be declared, probably it was empty
        emitter:add_indent_ln('return 0;') -- ensures that an int is always returned
      end
      emitter:dec_indent() emitter:add_indent_ln('}') -- end block
    end
    context:add_definition(emitter:generate()) -- defines `nelua_main` and/or `main`
  end
  context:pop_state()
end

-- Generates C code for the analyzed context `context`.
function cgenerator.generate(context)
  context:promote(CContext, visitors, typevisitors) -- promote AnalyzerContext to CContext
  cgenerator.emit_warning_pragmas(context) -- silent some C warnings
  cgenerator.emit_feature_checks(context) -- check C primitive sizes
  cgenerator.emit_features_setup(context)
  cgenerator.emit_entrypoint(context, context.ast) -- emit `main` and `nelua_main`
  return context:concat_chunks(cdefs.template) -- concatenate emitted chunks
end

return cgenerator
