local CEmitter = require 'nelua.cemitter'
local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local stringer = require 'nelua.utils.stringer'
local bn = require 'nelua.utils.bn'
local cdefs = require 'nelua.cdefs'
local cbuiltins = require 'nelua.cbuiltins'
local typedefs = require 'nelua.typedefs'
local CContext = require 'nelua.ccontext'
local types = require 'nelua.types'
local ccompiler = require 'nelua.ccompiler'
local primtypes = typedefs.primtypes
local luatype = type
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
  if lastargnode and lastargnode.tag:find('^Call') and (not calleetype or not calleetype.is_type) then
    -- last arg is a runtime call
    assert(calleetype)
    -- we know the callee type
    return function()
      local var, argnode
      i, var, argnode = iter(ts, i)
      if not i then return nil end
      if i >= lastargindex and lastargnode.attr.multirets then
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

local function finish_scope_defer(context, emitter, scope)
  if scope.deferblocks then
    for i=#scope.deferblocks,1,-1 do
      local deferblock = scope.deferblocks[i]
      emitter:add_indent_ln('{ /* defer */')
      context:push_scope(deferblock.scope.parent)
      emitter:add(deferblock)
      context:pop_scope()
      emitter:add_indent_ln('}')
    end
  end
end

local function finish_upscopes_defer(context, emitter, kind)
  local scope = context.scope
  repeat
    finish_scope_defer(context, emitter, scope)
    scope = scope.parent
  until (scope[kind] or scope == context.rootscope)
  finish_scope_defer(context, emitter, scope)
end

local function visit_assignments(context, emitter, varnodes, valnodes, decl)
  local usetemporary = false
  if not decl and #valnodes > 1 then
    -- multiple assignments must assign to a temporary first (in case of a swap)
    usetemporary = true
  end
  local defemitter = CEmitter(context, emitter.depth)
  local multiretvalname
  for _,varnode,valnode,valtype,lastcallindex in izipargnodes(varnodes, valnodes or {}) do
    local varattr = varnode.attr
    local noinit = varattr.noinit or varattr.cexport or varattr.cimport or varattr.type.is_cvalist
                   or context.pragmas.noinit
    local vartype = varattr.type
    local empty = vartype.size == 0 and not vartype.emptyrefed
    local used = context.pragmas.nodce or -- dead code elimination is disabled
                 not decl or -- have a late definition, must evaluate
                 lastcallindex ~= nil or -- multiple returns, must evaluate
                 (valnode and not valnode.attr.comptime) or -- might have a call
                 varattr:is_used(true) -- used by some other function
    if not vartype.is_type and (not varattr.nodecl or not decl) and not varattr.comptime and used then
      local declared, defined = false, false
      if decl and varattr.staticstorage then
        -- declare main variables in the top scope
        local decemitter = CEmitter(context)
        decemitter:add_indent()
        if varattr.cimport then
          decemitter:add('extern ')
        elseif not varattr.nostatic and not varattr.cexport and not context.pragmas.nostatic then
          decemitter:add('static ')
        end
        decemitter:add(varnode)
        if valnode and valnode.attr.initializer then
          -- initialize to const values
          decemitter:add(' = ')
          assert(not lastcallindex)
          context:push_forked_state{ininitializer = true}
          decemitter:add_converted_val(vartype, valnode)
          context:pop_state()
          defined = true
        else
          -- pre initialize to zeros
          if not noinit then
            decemitter:add(' = ')
            decemitter:add_zeroed_type_literal(vartype)
          end
        end
        decemitter:add_ln(';')
        context:add_declaration(decemitter:generate())
        declared = true
      end

      if lastcallindex == 1 then
        -- last assigment value may be a multiple return call
        multiretvalname = context:genuniquename('ret')
        local rettypename = context:funcrettypename(valnode.attr.calleetype)
        emitter:add_indent_ln(rettypename, ' ', multiretvalname, ' = ', valnode, ';')
      end

      if not empty then -- only define if the type is not empty
        local retvalname
        if lastcallindex then
          assert(multiretvalname)
          retvalname = string.format('%s.r%d', multiretvalname, lastcallindex)
        elseif usetemporary then
          retvalname = context:genuniquename('asgntmp')
          emitter:add_indent(vartype, ' ', retvalname, ' = ')
          emitter:add_converted_val(vartype, valnode)
          emitter:add_ln(';')
        end

        if not declared or (not defined and (valnode or lastcallindex)) then
          -- declare or define if needed
          defemitter:add_indent()
          if not declared then
            defemitter:add(varnode)
          else
            defemitter:add(context:declname(varattr))
          end
          if not noinit or not decl then
            -- initialize variable
            defemitter:add(' = ')
            if retvalname then
              defemitter:add_converted_val(vartype, retvalname, valtype)
            elseif valnode then
              defemitter:add_converted_val(vartype, valnode)
            else
              defemitter:add_zeroed_type_literal(vartype)
            end
          end
          defemitter:add_ln(';')
        end
      end
    elseif used and decl and varattr.cinclude then
      -- not declared, might be an imported variable from C
      context:ensure_include(varattr.cinclude)
    end
  end
  emitter:add(defemitter:generate())
end

local typevisitors = {}
cgenerator.typevisitors = typevisitors

local function emit_type_attributes(decemitter, type)
  if type.aligned then
    decemitter:add(' __attribute__((aligned(', type.aligned, ')))')
  end
  if type.packed then
    decemitter:add(' __attribute__((packed))')
  end
end

typevisitors[types.ArrayType] = function(context, type)
  local decemitter = CEmitter(context, 0)
  decemitter:add('typedef struct {', type.subtype, ' data[', type.length, '];} ', type.codename)
  emit_type_attributes(decemitter, type)
  decemitter:add(';')
  if type.size and type.size > 0 and not context.pragmas.nocstaticassert then
    decemitter:add(' nelua_static_assert(sizeof(',type.codename,') == ', type.size, ' && ',
                      '_Alignof(',type.codename,') == ', type.align,
                      ', "Nelua and C disagree on type size or align");')
  end
  decemitter:add_ln()
  table.insert(context.declarations, decemitter:generate())
end

typevisitors[types.PointerType] = function(context, type)
  local decemitter = CEmitter(context, 0)
  local index = nil
  if type.subtype.is_composite and not type.subtype.nodecl and not context.declarations[type.subtype.codename] then
    -- offset declaration of pointers before records/unions
    index = #context.declarations+2
  end
  if type.subtype.is_array and type.subtype.length == 0 then
    decemitter:add_ln('typedef ', type.subtype.subtype, '* ', type.codename, ';')
  else
    decemitter:add_ln('typedef ', type.subtype, '* ', type.codename, ';')
  end
  if not index then
    index = #context.declarations+1
  end
  table.insert(context.declarations, index, decemitter:generate())
end

local function typevisitor_CompositeType(context, type)
  local decemitter = CEmitter(context, 0)
  local kindname = type.is_record and 'struct' or 'union'
  if not context.pragmas.noctypedefs then
    decemitter:add_ln('typedef ', kindname, ' ', type.codename, ' ', type.codename, ';')
  end
  table.insert(context.declarations, decemitter:generate())
  local defemitter = CEmitter(context, 0)
  defemitter:add(kindname, ' ', type.codename)
  defemitter:add(' {')
  if #type.fields > 0 then
    defemitter:add_ln()
    for _,field in ipairs(type.fields) do
      local fieldctype
      if field.type.is_array then
        fieldctype = field.type.subtype
      else
        fieldctype = context:ensure_type(field.type)
      end
      defemitter:add('  ', fieldctype, ' ', field.name)
      if field.type.is_array then
        defemitter:add('[', field.type.length, ']')
      end
      defemitter:add_ln(';')
    end
  end
  defemitter:add('}')
  emit_type_attributes(defemitter, type)
  defemitter:add(';')
  if type.size and type.size > 0 and not context.pragmas.nocstaticassert then
    defemitter:add(' nelua_static_assert(sizeof(',type.codename,') == ', type.size, ' && ',
                      '_Alignof(',type.codename,') == ', type.align,
                      ', "Nelua and C disagree on type size or align");')
  end
  defemitter:add_ln()
  table.insert(context.declarations, defemitter:generate())
end

typevisitors[types.RecordType] = typevisitor_CompositeType
typevisitors[types.UnionType] = typevisitor_CompositeType

typevisitors[types.EnumType] = function(context, type)
  local decemitter = CEmitter(context, 0)
  decemitter:add_ln('typedef ', type.subtype, ' ', type.codename, ';')
  table.insert(context.declarations, decemitter:generate())
end

typevisitors[types.FunctionType] = function(context, type)
  local decemitter = CEmitter(context, 0)
  decemitter:add('typedef ', context:funcrettypename(type), ' (*', type.codename, ')(')
  for i,argtype in ipairs(type.argtypes) do
    if i>1 then
      decemitter:add(', ')
    end
    decemitter:add(argtype)
  end
  decemitter:add_ln(');')
  table.insert(context.declarations, decemitter:generate())
end

typevisitors[types.NiltypeType] = function(context)
  context:ensure_builtin('nlniltype')
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
  retemitter:add_ln('struct ', rettypename, ' {')
  retemitter:inc_indent()
  for i=1,#rettypes do
    retemitter:add_indent_ln(rettypes[i], ' ', 'r', i, ';')
  end
  retemitter:dec_indent()
  retemitter:add_indent('}')
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
  local decemitter = CEmitter(context, 0)
  decemitter:add_ln('typedef void* ', type.codename, ';')
  context:add_declaration(decemitter:generate(), type.codename)
end
]]

typevisitors[types.Type] = function(context, type)
  local node = context:get_visiting_node()
  if type.is_any or type.is_varanys then
    node:raisef("compiler deduced the type 'any' here, but it's not supported yet in the C backend")
  else
    node:raisef("type '%s' is not supported yet in the C backend", type)
  end
end

local visitors = {}
cgenerator.visitors = visitors

function visitors.Number(context, node, emitter)
  local attr = node.attr
  if not attr.type.is_float and not attr.untyped and not context.state.ininitializer then
    emitter:add('(', attr.type, ')')
  end
  emitter:add_scalar_literal(attr)
end

function visitors.String(_, node, emitter)
  local attr = node.attr
  if attr.type.is_stringy then
    emitter:add_string_literal(attr.value, attr.type.is_cstring)
  else
    if attr.type == primtypes.cchar then
      emitter:add("'", string.char(bn.tointeger(attr.value)), "'")
    else
      emitter:add_scalar_literal(attr)
    end
  end
end

function visitors.Boolean(_, node, emitter)
  emitter:add_boolean(node.attr.value)
end

function visitors.Nil(_, _, emitter)
  emitter:add_nil_literal()
end

function visitors.Nilptr(_, _, emitter)
  emitter:add_null()
end

function visitors.VarargsType(_, node, emitter)
  if node.attr.type.is_varanys then
    node:raisef("compiler deduced the type 'varanys' here, but it's not supported yet in the C backend")
  end
  emitter:add('...')
end

-- Check if a an array of nodes can be emitted using an initialize.
local function can_use_initializer(childnodes)
  local hassideeffect = false
  for _,childnode in ipairs(childnodes) do
    local childvalnode
    if childnode.tag == 'Pair' then
      childvalnode = childnode[2]
    else
      childvalnode = childnode
    end
    local childvaltype = childvalnode.attr.type
    local sideeffect = childvalnode:recursive_has_attr('sideeffect')
    if childvaltype.is_array or (hassideeffect and sideeffect) then
      return false
    end
    if sideeffect then hassideeffect = true end
  end
  return true
end

function visitors.InitList(context, node, emitter)
  local attr = node.attr
  local childnodes, type = node, attr.type
  local len = #childnodes
  if len == 0 and type.is_aggregate then
    if not context.state.ininitializer then
      emitter:add('(', type, ')')
    end
    emitter:add_zeroed_type_literal(type)
  elseif type.is_composite then
    if context.state.ininitializer then
      context:push_forked_state{incompositeinitializer = true}
      emitter:add('{')
      emitter:add_list(childnodes)
      emitter:add('}')
      context:pop_state()
    elseif type.cconstruct then -- used to construct vector types when generating GLSL code
      --luacov:disable
      emitter:add(type,'(')
      emitter:add('(')
      emitter:add_list(childnodes)
      emitter:add(')')
      --luacov:enable
    else
      local useinitializer = can_use_initializer(childnodes)
      if useinitializer then
        emitter:add('(',type,'){')
      else
        emitter:add_ln('({')
        emitter:inc_indent()
        emitter:add_indent(type, ' _tmp = ')
        emitter:add_zeroed_type_literal(type)
        emitter:add_ln(';')
      end
      local lastfieldindex = 0
      for i,childnode in ipairs(childnodes) do
        local named = false
        local childvalnode
        local field
        if childnode.tag == 'Pair' then
          childvalnode = childnode[2]
          field = type.fields[childnode[1]]
          named = true
        else
          childvalnode = childnode
          field = type.fields[lastfieldindex + 1]
        end
        lastfieldindex = field.index
        assert(field)
        if useinitializer then
          if i > 1 then
            emitter:add(', ')
          end
          if named then
            emitter:add('.', field.name, ' = ')
          end
        else
          local childvaltype = childvalnode.attr.type
          if childvaltype.is_array then
            emitter:add_indent('(*(', childvaltype, '*)_tmp.', field.name, ') = ')
          else
            emitter:add_indent('_tmp.', field.name, ' = ')
          end
        end
        local fieldtype = type.fields[field.name].type
        assert(fieldtype)
        emitter:add_converted_val(fieldtype, childvalnode)
        if not useinitializer then
          emitter:add_ln(';')
        end
      end
      if useinitializer then
        emitter:add('}')
      else
        emitter:add_indent_ln('_tmp;')
        emitter:dec_indent()
        emitter:add_indent('})')
      end
    end
  elseif type.is_array then
    if context.state.ininitializer then
      if context.state.incompositeinitializer then
        emitter:add('{')
        emitter:add_list(childnodes)
        emitter:add('}')
      else
        emitter:add('{{')
        emitter:add_list(childnodes)
        emitter:add('}}')
      end
    else
      local useinitializer = can_use_initializer(childnodes)
      if useinitializer then
        emitter:add('(', type, '){{')
      else
        emitter:add_ln('({')
        emitter:inc_indent()
        emitter:add_indent(type, ' _tmp = ')
        emitter:add_zeroed_type_literal(type)
        emitter:add_ln(';')
      end
      local subtype = type.subtype
      for i,childnode in ipairs(childnodes) do
        if useinitializer then
          if i > 1 then
            emitter:add(', ')
          end
        else
          emitter:add_indent('_tmp.data[', i-1 ,'] = ')
        end
        emitter:add_converted_val(subtype, childnode)
        if not useinitializer then
          emitter:add_ln(';')
        end
      end
      if useinitializer then
        emitter:add('}}')
      else
        emitter:add_indent_ln('_tmp;')
        emitter:dec_indent()
        emitter:add_indent('})')
      end
    end
  else --luacov:disable
    error('not implemented yet')
  end --luacov:enable
end

function visitors.Pair(_, node, emitter)
  local namenode, valuenode = node[1], node[2]
  local parenttype = node.attr.parenttype
  if parenttype and parenttype.is_composite then
    assert(traits.is_string(namenode))
    local field = parenttype.fields[namenode]
    emitter:add('.', cdefs.quotename(field.name), ' = ')
    emitter:add_converted_val(field.type, valuenode)
  else --luacov:disable
    error('not implemented yet')
  end --luacov:enable
end

function visitors.Directive(context, node, emitter)
  local name, args = node[1], node[2]
  if name == 'cinclude' then
    context:ensure_include(args[1])
  elseif name == 'cfile' then
    context:ensure_cfile(args[1])
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
    assert(type(code) == 'string')
    -- actually add in the directives section (just above declarations section)
    context:add_directive(code)
  elseif name == 'cemitdef' then
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
  elseif name == 'linklib' then
    context:ensure_linklib(args[1])
  elseif name == 'pragmapush' then
    context:push_forked_pragmas(args[1])
  elseif name == 'pragmapop' then
    context:pop_pragmas()
  end
end

function visitors.Id(context, node, emitter)
  local attr = node.attr
  assert(not attr.type.is_comptime)
  if attr.type.is_nilptr then
    emitter:add_null()
  elseif attr.comptime then
    emitter:add_literal(attr)
  else
    emitter:add(context:declname(attr))
  end
end

function visitors.Paren(_, node, emitter)
  local innernode = node[1]
  emitter:add(innernode)
  --emitter:add('(', innernode, ')')
end

visitors.FuncType = visitors.Type
visitors.ArrayType = visitors.Type
visitors.PointerType = visitors.Type

function visitors.IdDecl(context, node, emitter)
  local attr = node.attr
  local type = attr.type
  local name = context:declname(attr)
  if context.state.infuncdecl then
    emitter:add(name)
  elseif attr.comptime or type.is_comptime then
    emitter:add(context:ensure_builtin('nlniltype'), ' ', name)
  else
    if type.is_type then return end
    if attr.cexport then emitter:add(context:ensure_builtin('nelua_cexport'), ' ') end
    if attr.static then emitter:add('static ') end
    if attr.register then emitter:add('register ') end
    if attr.const and attr.type.is_pointer then emitter:add('const ') end
    if attr.volatile then emitter:add('volatile ') end
    if attr.cqualifier then emitter:add(attr.cqualifier, ' ') end
    emitter:add(type, ' ')
    if attr.restrict then emitter:add('__restrict ') end
    emitter:add(name)
    if attr.cattribute then emitter:add(' __attribute__((', attr.cattribute, '))') end
  end
end

local function visitor_Call(context, node, emitter, argnodes, callee, calleeobjnode)
  local isblockcall = context:get_visiting_node(1).tag == 'Block'
  if isblockcall then
    emitter:add_indent()
  end
  local attr = node.attr
  local calleetype = attr.calleetype
  if calleetype.is_procedure then
    -- function call
    local tmpargs
    local tmpcount = 0
    local lastcalltmp
    local sequential
    local serialized
    local callargtypes = attr.pseudoargtypes or calleetype.argtypes
    local callargattrs = attr.pseudoargattrs or calleetype.argattrs
    for i,funcargtype,argnode,_,lastcallindex in izipargnodes(callargtypes, argnodes) do
      if not argnode and (funcargtype.is_cvarargs or funcargtype.is_varargs) then break end
      if (argnode and argnode.attr.sideeffect) or lastcallindex == 1 then
        -- expressions with side effects need to be evaluated in sequence
        -- and expressions with multiple returns needs to be stored in a temporary
        if tmpcount == 0 then
          tmpargs = {}
        end
        tmpcount = tmpcount + 1
        local tmpname = '_tmp' .. tmpcount
        tmpargs[i] = tmpname
        if lastcallindex == 1 then
          lastcalltmp = tmpname
        end
        if tmpcount >= 2 or lastcallindex then
          -- only need to evaluate in sequence mode if we have two or more temporaries
          -- or the last argument is a multiple return call
          sequential = true
          serialized = true
        end
      end
    end

    local handlereturns
    local retvalname
    local returnfirst
    if #calleetype.rettypes > 1 and not isblockcall and not attr.multirets then
      -- we are handling the returns
      returnfirst = true
      handlereturns = true
      serialized = true
    end

    if serialized then
      -- break apart the call into many statements
      if not isblockcall then
        emitter:add_value('(')
      end
      emitter:add_ln('{')
      emitter:inc_indent()
    end

    if sequential then
      for _,tmparg,argnode,argtype,_,lastcalletype in izipargnodes(tmpargs, argnodes) do
        -- set temporary values in sequence
        if tmparg then
          if lastcalletype then
            -- type for result of multiple return call
            argtype = context:funcrettypename(lastcalletype)
          end
          emitter:add_indent_ln(argtype, ' ', tmparg, ' = ', argnode, ';')
        end
      end
    end

    if serialized then
      emitter:add_indent()
      if handlereturns then
        -- save the return type
        local rettypename = context:funcrettypename(calleetype)
        retvalname = context:genuniquename('ret')
        emitter:add(rettypename, ' ', retvalname, ' = ')
      end
    end

    local ismethod = attr.ismethod
    if ismethod then
      local selftype = calleetype.argtypes[1]
      if attr.calleesym then
        emitter:add_value(context:declname(attr.calleesym))
      else
        assert(luatype(callee) == 'string')
        emitter:add_value('(')
        emitter:add_converted_val(selftype, calleeobjnode)
        emitter:add_value(')')
        emitter:add_value(selftype.is_pointer and '->' or '.')
        emitter:add_value(callee)
      end
      emitter:add_value('(')
      emitter:add_converted_val(selftype, calleeobjnode)
    else
      local ispointercall = attr.pointercall
      if ispointercall then
        emitter:add_text('(*')
      end
      if luatype(callee) ~= 'string' and attr.calleesym then
        emitter:add_text(context:declname(attr.calleesym))
      else
        emitter:add_value(callee)
      end
      if ispointercall then
        emitter:add_text(')')
      end
      emitter:add_text('(')
    end

    for i,funcargtype,argnode,argtype,lastcallindex in izipargnodes(callargtypes, argnodes) do
      if not argnode and (funcargtype.is_cvarargs or funcargtype.is_varargs) then break end
      if i > 1 or ismethod then emitter:add_value(', ') end
      local arg = argnode
      if sequential then
        if lastcallindex then
          arg = string.format('%s.r%d', lastcalltmp, lastcallindex)
        elseif tmpargs[i] then
          arg = tmpargs[i]
        end
      end

      local callargattr = callargattrs[i]
      if callargattr.comptime then
        -- compile time function argument
        emitter:add_nil_literal()

        if argnode and argnode.tag == 'Function' then -- force declaration of anonymous functions
          CEmitter(context, emitter.depth):add(argnode)
        end
      else
        emitter:add_converted_val(funcargtype, arg, argtype)
      end
    end
    emitter:add_text(')')

    if serialized then
      -- end sequential expression
      emitter:add_ln(';')
      if returnfirst then
        -- get just the first result in multiple return functions
        assert(#calleetype.rettypes > 1)
        emitter:add_indent_ln(retvalname, '.r1;')
      end
      emitter:dec_indent()
      emitter:add_indent('}')
      if not isblockcall then
        emitter:add_value(')')
      end
    end
  end
  if isblockcall then
    emitter:add_text(";\n")
  end
end

function visitors.Call(context, node, emitter)
  local argnodes, calleenode = node[1], node[2]
  local calleetype = node.attr.calleetype
  if calleetype.is_type then -- type cast
    local type = node.attr.type
    if #argnodes == 1 then
      local argnode = argnodes[1]
      local argtype = argnode.attr.type
      if argtype ~= type then
        -- type really differs, cast it
        emitter:add_converted_val(type, argnode, argtype, true)
      else
        -- same type, no need to cast
        emitter:add(argnode)
      end
    else
      emitter:add_zeroed_type_literal(type, true)
    end
  else -- call
    local callee = calleenode
    if calleenode.attr.builtin then
      local builtin = cbuiltins.calls[calleenode.attr.name]
      callee = builtin(context, node, emitter)
    end
    if callee then
      visitor_Call(context, node, emitter, argnodes, callee)
    end
  end
end

function visitors.CallMethod(context, node, emitter)
  local name, argnodes, calleeobjnode = node[1], node[2], node[3]

  visitor_Call(context, node, emitter, argnodes, name, calleeobjnode)
end

-- indexing
function visitors.DotIndex(context, node, emitter)
  local attr = node.attr
  local name = attr.dotfieldname or node[1]
  local objnode = node[2]
  local type = attr.type
  local objtype = objnode.attr.type
  local poparray = false
  if type.is_array then
    if objtype:implicit_deref_type().is_composite and context.state.inarrayindex == node then
      context.state.fieldindexed = node
    elseif not attr.globalfield then
      emitter:add('(*(', type, '*)')
      poparray = true
    end
  end
  if objtype.is_type then
    objtype = attr.indextype
    if objtype.is_enum then
      local field = objtype.fields[name]
      emitter:add_scalar_literal(field, objtype.subtype)
    elseif objtype.is_composite then
      if attr.comptime then
        emitter:add_literal(attr)
      else
        emitter:add(context:declname(attr))
      end
    else --luacov:disable
      error('not implemented yet')
    end --luacov:enable
  elseif objtype.is_pointer then
    emitter:add(objnode, '->', cdefs.quotename(name))
  else
    emitter:add(objnode, '.', cdefs.quotename(name))
  end
  if poparray then
    emitter:add(')')
  end
end

visitors.ColonIndex = visitors.DotIndex

function visitors.KeyIndex(context, node, emitter)
  local indexnode, objnode = node[1], node[2]
  local objtype = objnode.attr.type
  local pointer = false
  if objtype.is_pointer and not objtype.is_generic_pointer then
    -- indexing a pointer to an array
    objtype = objtype.subtype
    pointer = true
  end

  if objtype.is_record then
    local atindex = node.attr.calleesym and node.attr.calleesym.name:match('.__atindex')
    if atindex then
      emitter:add('(*')
    end
    visitor_Call(context, node, emitter, {indexnode}, nil, objnode)
    if atindex then
      emitter:add(')')
    end
  else
    if not objtype.is_array then --luacov:disable
      error('not implemented yet')
    end --luacov:enable

    if pointer then
      if objtype.length == 0 then
        emitter:add('(',objnode, ')[')
      else
        emitter:add('((', objtype.subtype, '*)', objnode, ')[')
      end
    elseif objtype.length == 0 then
      emitter:add('((', objtype.subtype, '*)&', objnode, ')[')
    else
      context:push_forked_state{inarrayindex = objnode}
      emitter:add(objnode)
      if context.state.fieldindexed ~= objnode then
        emitter:add('.data')
      end
      emitter:add('[')
      context:pop_state()
    end
    if not context.pragmas.nochecks and objtype.length > 0 and not indexnode.attr.comptime then
      local indextype = indexnode.attr.type
      emitter:add(context:ensure_builtin('nelua_assert_bounds_', indextype))
      emitter:add('(', indexnode, ', ', objtype.length, ')')
    else
      emitter:add(indexnode)
    end
    emitter:add(']')
  end
end

function visitors.Block(context, node, emitter)
  local statnodes = node
  emitter:inc_indent()
  local scope = context:push_forked_scope(node)
  do
    emitter:add_list(statnodes, '')
  end
  if not node.attr.returnending and not scope.alreadydestroyed then
    finish_scope_defer(context, emitter, scope)
  end
  context:pop_scope()
  emitter:dec_indent()
end

function visitors.Return(context, node, emitter)
  local retnodes = node
  local numretnodes = #retnodes or 0
  -- destroy parent blocks
  local deferemitter = CEmitter(context, emitter.depth)
  finish_upscopes_defer(context, deferemitter, 'is_returnbreak')
  local defercode = deferemitter:generate()
  local funcscope = context.scope:get_up_return_scope() or context.rootscope
  context.scope.alreadydestroyed = true
  if funcscope == context.rootscope then
    -- in main body
    if numretnodes > 1 then
      node:raisef("multiple returns in main is not supported")
    end
    if numretnodes == 0 then
      -- main must always return an integer
      emitter:add(deferemitter:generate())
      emitter:add_indent_ln('return 0;')
    else
      -- return one value (an integer expected)
      local retnode = retnodes[1]
      if defercode ~= '' and retnode.tag ~= 'Id' and not retnode.attr.comptime then
        local retname = context:genuniquename('ret')
        emitter:add_indent(primtypes.cint, ' ', retname, ' = ')
        emitter:add_converted_val(primtypes.cint, retnode)
        emitter:add_ln(';')
        emitter:add_value(defercode)
        emitter:add_indent_ln('return ', retname, ';')
      else
        emitter:add_value(defercode)
        emitter:add_indent('return ')
        emitter:add_converted_val(primtypes.cint, retnode)
        emitter:add_ln(';')
      end
    end
  elseif funcscope.is_doexpr then
    emitter:add_indent_ln('_expr = ', retnodes[1], ';')
    emitter:add(defercode)
    local needgoto = true
    if context:get_visiting_node(2).tag == 'DoExpr' then
      local blockstats = context:get_visiting_node(1)
      if node == blockstats[#blockstats] then -- last statement does not need goto
        needgoto = false
      end
    end
    if needgoto then
      emitter:add_indent_ln('goto ', funcscope.doexprlabel, ';')
      funcscope.usedexprlabel = true
    end
  else
    local functype = funcscope.functype
    local numfuncrets = #functype.rettypes
    if numfuncrets <= 1 then
      if numfuncrets == 0 then
        -- no returns
        assert(numretnodes == 0)
        emitter:add_value(defercode)
        emitter:add_indent_ln('return;')
      elseif numfuncrets == 1 then
        -- one return
        local retnode, rettype = retnodes[1], functype:get_return_type(1)
        if retnode then
          -- return value is present
          if defercode ~= '' and retnode.tag ~= 'Id' and not retnode.attr.comptime then
            local retname = context:genuniquename('ret')
            emitter:add_indent(rettype, ' ', retname, ' = ')
            emitter:add_converted_val(rettype, retnode)
            emitter:add_ln(';')
            emitter:add_value(defercode)
            emitter:add_indent_ln('return ', retname, ';')
          else
            emitter:add_value(defercode)
            emitter:add_indent('return ')
            emitter:add_converted_val(rettype, retnode)
            emitter:add_ln(';')
          end
        else
          -- no return value present, generate a zeroed one
          emitter:add_value(defercode)
          emitter:add_indent('return ')
          emitter:add_zeroed_type_literal(rettype, true)
          emitter:add_ln(';')
        end
      end
    else
      -- multiple returns
      local funcrettypename = context:funcrettypename(functype)
      local retemitter = CEmitter(context, emitter.depth)
      local multiretvalname
      local retname
      if defercode == '' then
        retemitter:add_indent('return (', funcrettypename, '){')
      else
        retname = context:genuniquename('ret')
        retemitter:add_indent(funcrettypename, ' ', retname, ' = (', funcrettypename, '){')
      end
      for i,funcrettype,retnode,rettype,lastcallindex in izipargnodes(functype.rettypes, retnodes) do
        if i>1 then retemitter:add(', ') end
        if lastcallindex == 1 then
          -- last assignment value may be a multiple return call
          multiretvalname = context:genuniquename('ret')
          local rettypename = context:funcrettypename(retnode.attr.calleetype)
          emitter:add_indent_ln(rettypename, ' ', multiretvalname, ' = ', retnode, ';')
        end
        if lastcallindex then
          local retvalname = string.format('%s.r%d', multiretvalname, lastcallindex)
          retemitter:add_converted_val(funcrettype, retvalname, rettype)
        else
          retemitter:add_converted_val(funcrettype, retnode)
        end
      end
      retemitter:add_ln('};')
      if retname then
        retemitter:add(defercode)
        retemitter:add_indent_ln('return ', retname, ';')
      end
      emitter:add(retemitter:generate())
    end
  end
end

function visitors.If(_, node, emitter)
  local ifpairs, elseblock = node[1], node[2]
  for i=1,#ifpairs,2 do
    local condnode, blocknode = ifpairs[i], ifpairs[i+1]
    if i == 1 then
      emitter:add_indent("if(")
      emitter:add_converted_val(primtypes.boolean, condnode)
      emitter:add_ln(") {")
    else
      emitter:add_indent("} else if(")
      emitter:add_converted_val(primtypes.boolean, condnode)
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

function visitors.Switch(context, node, emitter)
  local valnode, casepairs, elsenode = node[1], node[2], node[3]
  emitter:add_indent_ln("switch(", valnode, ") {")
  emitter:inc_indent()
  context:push_forked_scope(node)
  for i=1,#casepairs,2 do
    local caseexprs, caseblock = casepairs[i], casepairs[i+1]
    for j=1,#caseexprs-1 do
      emitter:add_indent_ln("case ", caseexprs[j], ":")
    end
    emitter:add_indent_ln("case ", caseexprs[#caseexprs], ': {') -- last case
    emitter:add(caseblock) -- block
    emitter:inc_indent() emitter:add_indent_ln('break;') emitter:dec_indent()
    emitter:add_indent_ln("}")
  end
  if elsenode then
    emitter:add_indent_ln('default: {')
    emitter:add(elsenode)
    emitter:inc_indent() emitter:add_indent_ln('break;') emitter:dec_indent()
    emitter:add_indent_ln("}")
  end
  context:pop_scope(node)
  emitter:dec_indent()
  emitter:add_indent_ln("}")
end

function visitors.Do(context, node, emitter)
  local blocknode = node[1]
  local doemitter = CEmitter(context, emitter.depth)
  doemitter:add(blocknode)
  if doemitter:empty() then return end
  emitter:add_indent_ln("{")
  emitter:add(doemitter:generate())
  emitter:add_indent_ln("}")
end

function visitors.DoExpr(context, node, emitter)
  local isstatement = context:get_visiting_node(1).tag == 'Block'
  if isstatement then -- a macros could have replaced a statement with do exprs
    if isstatement and node.attr.noop then -- skip macros without operations
      return true
    end
    emitter:add_indent('(void)')
  end
  local blocknode = node[1]
  if blocknode[1].tag == 'Return' then -- single statement
    emitter:add(blocknode[1][1])
  else
    emitter:add_ln("({")
    emitter:inc_indent()
    emitter:add_indent_ln(node.attr.type, ' _expr;')
    emitter:dec_indent()
    local scope = context:push_forked_scope(node)
    if not scope.doexprlabel then
      scope.doexprlabel = context:genuniquename('do_expr_label')
    end
    emitter:add(blocknode)
    context:pop_scope()
    emitter:inc_indent()
    if scope.usedexprlabel then
      emitter:add_indent_ln(scope.doexprlabel, ': _expr;')
    else
      emitter:add_indent_ln('_expr;')
    end
    emitter:dec_indent()
    emitter:add_indent("})")
  end
  if isstatement then
    emitter:add_ln(';')
  end
end

function visitors.Defer(context, node)
  local blocknode = node[1]
  local deferblocks = context.scope.deferblocks
  if not deferblocks then
    deferblocks = {}
    context.scope.deferblocks = deferblocks
  end
  table.insert(deferblocks, blocknode)
end

function visitors.While(context, node, emitter)
  local condnode, blocknode = node[1], node[2]
  emitter:add_indent("while(")
  emitter:add_converted_val(primtypes.boolean, condnode)
  emitter:add_ln(') {')
  local scope = context:push_forked_scope(node)
  emitter:add(blocknode)
  context:pop_scope()
  emitter:add_indent_ln("}")
  if scope.breaklabel then
    emitter:add_ln(scope.breaklabel, ':;')
  end
end

function visitors.Repeat(context, node, emitter)
  local blocknode, condnode = node[1], node[2]
  emitter:add_indent_ln("while(1) {")
  local scope = context:push_forked_scope(node)
  emitter:add(blocknode)
  emitter:inc_indent()
  emitter:add_indent('if(')
  emitter:add_converted_val(primtypes.boolean, condnode)
  emitter:add_ln(') {')
  emitter:inc_indent()
  emitter:add_indent_ln('break;')
  emitter:dec_indent()
  emitter:add_indent_ln('}')
  context:pop_scope()
  emitter:dec_indent()
  emitter:add_indent_ln('}')
  if scope.breaklabel then
    emitter:add_ln(scope.breaklabel, ':;')
  end
end

function visitors.ForNum(context, node, emitter)
  local itvarnode, begvalnode, endvalnode, stepvalnode, blocknode = node[1], node[2], node[4], node[5], node[6]
  local compop = node.attr.compop
  local fixedstep = node.attr.fixedstep
  local fixedend = node.attr.fixedend
  local itvarattr = itvarnode.attr
  local itmutate = itvarattr.mutate
  local scope = context:push_forked_scope(node)
  do
    local ccompop = cdefs.for_compare_ops[compop]
    local ittype = itvarattr.type
    local itname = context:declname(itvarattr)
    local itforname = itmutate and '_it' or itname
    emitter:add_indent('for(', ittype, ' ', itforname, ' = ')
    emitter:add_converted_val(ittype, begvalnode)
    local cmpval
    if (not fixedend or not compop) then
      emitter:add(', _end = ')
      emitter:add_converted_val(ittype, endvalnode)
      cmpval = '_end'
    else
      cmpval = endvalnode
    end
    local stepval
    if not fixedstep then
      emitter:add(', _step = ')
      emitter:add_converted_val(ittype, stepvalnode)
      stepval = '_step'
    else
      stepval = fixedstep
    end
    emitter:add('; ')
    if compop then
      emitter:add(itforname, ' ', ccompop, ' ')
      if traits.is_string(cmpval) then
        emitter:add(cmpval)
      else
        emitter:add_converted_val(ittype, cmpval)
      end
    else
      -- step is an expression, must detect the compare operation at runtime
      assert(not fixedstep)
      emitter:add('_step >= 0 ? ', itforname, ' <= _end : ', itforname, ' >= _end')
    end
    emitter:add_ln('; ', itforname, ' = ', itforname, ' + ', stepval, ') {')
    emitter:inc_indent()
    if itmutate then
      emitter:add_indent_ln(itvarnode, ' = _it;')
    end
    emitter:dec_indent()
    emitter:add(blocknode)
    emitter:add_indent_ln('}')
  end
  context:pop_scope()
  if scope.breaklabel then
    emitter:add_ln(scope.breaklabel, ':;')
  end
end

function visitors.Break(context, _, emitter)
  finish_upscopes_defer(context, emitter, 'is_loop')
  context.scope.alreadydestroyed = true
  local breakscope = context.scope:get_up_scope_of_any_kind('is_loop', 'is_switch')
  if breakscope.is_switch then
    breakscope = context.scope:get_up_scope_of_any_kind('is_loop')
    local breaklabel = breakscope.breaklabel
    if not breaklabel then
      breaklabel = context:genuniquename('loop_break_label')
      breakscope.breaklabel = breaklabel
    end
    emitter:add_indent_ln('goto ', breaklabel, ';')
  else
    emitter:add_indent_ln('break;')
  end
end

function visitors.Continue(context, _, emitter)
  finish_upscopes_defer(context, emitter, 'is_loop')
  context.scope.alreadydestroyed = true
  emitter:add_indent_ln('continue;')
end

function visitors.Label(context, node, emitter)
  local attr = node.attr
  if attr.used then
    emitter:add_ln(context:declname(attr), ':;')
  end
end

function visitors.Goto(context, node, emitter)
  emitter:add_indent_ln('goto ', context:declname(node.attr.label), ';')
end

function visitors.VarDecl(context, node, emitter)
  local varnodes, valnodes = node[2], node[3]
  visit_assignments(context, emitter, varnodes, valnodes, true)
end

function visitors.Assign(context, node, emitter)
  local vars, vals = node[1], node[2]
  visit_assignments(context, emitter, vars, vals)
end

local function resolve_function_qualifier(context, attr)
  local qualifier = ''
  if not attr.entrypoint and not attr.nostatic and not attr.cexport and not context.pragmas.nostatic then
    qualifier = 'static '
  end
  if attr.cinclude then
    context:ensure_include(attr.cinclude)
  end
  if attr.cimport and attr.codename ~= 'nelua_main' then
    qualifier = ''
  end

  if attr.cexport then
    qualifier = qualifier .. context:ensure_builtin('nelua_cexport') .. ' '
  end
  if attr.volatile then
    qualifier = qualifier .. 'volatile '
  end
  if attr.inline and not context.pragmas.nocinlines then
    qualifier = qualifier .. context:ensure_builtin('nelua_inline') .. ' '
  end
  if attr.noinline and not context.pragmas.nocinlines then
    qualifier = qualifier .. context:ensure_builtin('nelua_noinline') .. ' '
  end
  if attr.noreturn then
    qualifier = qualifier .. context:ensure_builtin('nelua_noreturn') .. ' '
  end
  if attr.cqualifier then qualifier = qualifier .. attr.cqualifier .. ' ' end
  if attr.cattribute then
    qualifier =  string.format('%s__attribute__((%s)) ', qualifier, attr.cattribute)
  end
  return qualifier
end

function visitors.FuncDef(context, node, emitter)
  local attr = node.attr
  local type = attr.type

  if type.is_polyfunction then
    for _,polyeval in ipairs(type.evals) do
      emitter:add(polyeval.node)
    end
    return
  end

  if not context.pragmas.nodce and not attr:is_used(true) then
    return
  end

  local varscope, varnode, argnodes, blocknode = node[1], node[2], node[3], node[6]

  local qualifier = resolve_function_qualifier(context, attr)
  local cimport = attr.cimport
  local codename = attr.codename
  local declare = not attr.nodecl
  local define = not cimport

  if not declare and not define then -- nothing to do
    return
  end

  if cimport and cdefs.builtins_headers[codename] then
    context:ensure_builtin(codename)
    return
  end

  local decemitter, defemitter, implemitter = CEmitter(context), CEmitter(context), CEmitter(context)
  local rettypename = context:funcrettypename(type)

  decemitter:add_indent(qualifier, rettypename, ' ')
  defemitter:add_indent(rettypename, ' ')

  local funcid = varnode
  if not varscope then -- maybe assigning a variable to a function
    if varnode.tag == 'Id' then
      funcid = context:genuniquename(context:declname(varnode.attr), '%s_%d')
      emitter:add_indent_ln(varnode, ' = ', funcid, ';')
    elseif varnode.tag == 'ColonIndex' or varnode.tag == 'DotIndex' then
      local fieldname, objtype = varnode[1], varnode[2].attr.type
      if objtype.is_record then
        funcid = context:genuniquename('func_'..fieldname, '%s_%d')
        emitter:add_indent_ln(varnode, ' = ', funcid, ';')
      end
    end
  end

  context:push_forked_state{infuncdecl = true}
  decemitter:add(funcid)
  defemitter:add(funcid)
  context:pop_state()

  local funcscope = context:push_forked_scope(node)
  funcscope.functype = type
  funcscope.funcsym = node.attr
  do
    decemitter:add('(')
    defemitter:add('(')
    if varnode.tag == 'ColonIndex' then
      local selftype = type.argtypes[1]
      decemitter:add(selftype, ' self')
      defemitter:add(selftype, ' self')
      if #argnodes > 0 then
        decemitter:add(', ')
        defemitter:add(', ')
      end
    end
    decemitter:add_ln(argnodes, ');')
    defemitter:add_ln(argnodes, ') {')
    implemitter:add(blocknode)
    if not blocknode.attr.returnending then
      implemitter:inc_indent()
      finish_scope_defer(context, implemitter, funcscope)
      implemitter:dec_indent()
    end
  end
  context:pop_scope()
  implemitter:add_indent_ln('}')
  if declare then
    context:add_declaration(decemitter:generate(), attr.codename)
  end
  if define then
    if attr.entrypoint and not context.hookmain then
      context.emitentrypoint = function(mainemitter)
        context:add_definition(defemitter:generate())
        context:add_definition(mainemitter:generate())
        context:add_definition(implemitter:generate())
      end
    else
      context:add_definition(defemitter:generate())
      context:add_definition(implemitter:generate())
    end
  end
end

function visitors.Function(context, node, emitter)
  local argnodes, blocknode = node[1], node[4]
  local attr = node.attr
  local type = attr.type
  local qualifier = resolve_function_qualifier(context, attr)

  local decemitter, defemitter, implemitter = CEmitter(context), CEmitter(context), CEmitter(context)
  local rettypename = context:funcrettypename(type)

  decemitter:add_indent(qualifier, rettypename, ' ')
  defemitter:add_indent(rettypename, ' ')

  local declname = context:declname(attr)
  decemitter:add(declname)
  defemitter:add(declname)

  local funcscope = context:push_forked_scope(node)
  funcscope.functype = type
  funcscope.funcsym = node.attr
  do
    decemitter:add('(')
    defemitter:add('(')
    decemitter:add_ln(argnodes, ');')
    defemitter:add_ln(argnodes, ') {')
    implemitter:add(blocknode)
    if not blocknode.attr.returnending then
      implemitter:inc_indent()
      finish_scope_defer(context, implemitter, funcscope)
      implemitter:dec_indent()
    end
  end
  context:pop_scope()
  implemitter:add_indent_ln('}')
  context:add_declaration(decemitter:generate())
  context:add_definition(defemitter:generate())
  context:add_definition(implemitter:generate())
  emitter:add(declname)
end

function visitors.UnaryOp(context, node, emitter)
  local attr = node.attr
  if attr.comptime then
    emitter:add_literal(attr)
    return
  end
  if attr.type.is_any then
    node:raisef("compiler deduced the type 'any' here, but it's not supported yet in the C backend")
  end
  local opname, argnode = node[1], node[2]
  local builtin = cbuiltins.operators[opname]
  local surround = not node.attr.inconditional
  if surround then emitter:add_value('(') end
  builtin(context, node, emitter, argnode)
  if surround then emitter:add_value(')') end
end

function visitors.BinaryOp(context, node, emitter)
  if node.attr.comptime then
    emitter:add_literal(node.attr)
    return
  end
  local lnode, opname, rnode = node[1], node[2], node[3]
  local type = node.attr.type
  if type.is_any then
    node:raisef("compiler deduced the type 'any' here, but it's not supported yet in the C backend")
  end
  local surround = not node.attr.inconditional
  if surround then emitter:add('(') end
  if node.attr.dynamic_conditional then
    if node.attr.ternaryor then
      -- lua style "ternary" operator
      local anode, bnode, cnode = lnode[1], lnode[3], rnode
      if anode.attr.type.is_boolean and not bnode.attr.type.is_falseable then -- use C ternary operator
        emitter:add_converted_val(primtypes.boolean, anode)
        emitter:add(' ? ')
        emitter:add_converted_val(type, bnode)
        emitter:add(' : ')
        emitter:add_converted_val(type, cnode)
      else
        emitter:add_ln('({')
        emitter:inc_indent()
        emitter:add_indent_ln(type, ' t_;')
        emitter:add_indent(primtypes.boolean, ' cond_ = ')
        emitter:add_converted_val(primtypes.boolean, anode)
        emitter:add_ln(';')
        emitter:add_indent_ln('if(cond_) {')
        emitter:add_indent('  t_ = ')
        emitter:add_converted_val(type, bnode)
        emitter:add_ln(';')
        emitter:add_indent('  cond_ = ')
        emitter:add_converted_val(primtypes.boolean, 't_', type)
        emitter:add_ln(';')
        emitter:add_indent_ln('}')
        emitter:add_indent_ln('if(!cond_) {')
        emitter:add_indent('  t_ = ')
        emitter:add_converted_val(type, cnode)
        emitter:add_ln(';')
        emitter:add_indent_ln('}')
        emitter:add_indent_ln('t_;')
        emitter:dec_indent()
        emitter:add_indent('})')
      end
    else
      emitter:add_ln('({')
      emitter:inc_indent()
      emitter:add_indent(type, ' t1_ = ')
      emitter:add_converted_val(type, lnode)
      --TODO: be smart and remove this unused code
      emitter:add_ln(';')
      emitter:add_indent_ln(type, ' t2_ = {0};')
      if opname == 'and' then
        assert(not node.attr.ternaryand)
        emitter:add_indent(primtypes.boolean, ' cond_ = ')
        emitter:add_converted_val(primtypes.boolean, 't1_', type)
        emitter:add_ln(';')
        emitter:add_indent_ln('if(cond_) {')
        emitter:inc_indent()
        emitter:add_indent('t2_ = ')
        emitter:add_converted_val(type, rnode)
        emitter:add_ln(';')
        emitter:add_indent('cond_ = ')
        emitter:add_converted_val(primtypes.boolean, 't2_', type)
        emitter:add_ln(';')
        emitter:dec_indent()
        emitter:add_indent_ln('}')
        emitter:add_indent_ln('cond_ ? t2_ : (', type, '){0};')
      elseif opname == 'or' then
        assert(not node.attr.ternaryor)
        emitter:add_indent(primtypes.boolean, ' cond_ = ')
        emitter:add_converted_val(primtypes.boolean, 't1_', type)
        emitter:add_ln(';')
        emitter:add_indent_ln('if(!cond_) {')
        emitter:inc_indent()
        emitter:add_indent('t2_ = ')
        emitter:add_converted_val(type, rnode)
        emitter:add_ln(';')
        emitter:dec_indent()
        emitter:add_indent_ln('}')
        emitter:add_indent_ln('cond_ ? t1_ : t2_;')
      end
      emitter:dec_indent()
      emitter:add_indent('})')
    end
  else
    local sequential = (lnode.attr.sideeffect and rnode.attr.sideeffect) and
                        not (opname == 'or' or opname == 'and')
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
    local builtin = cbuiltins.operators[opname]
    builtin(context, node, emitter, lnode, rnode, lname, rname)
    if sequential then
      emitter:add_ln(';')
      emitter:dec_indent()
      emitter:add_indent('})')
    end
  end
  if surround then emitter:add(')') end
end

-- Emits C pragmas to disable harmless C warnings that the generated code may trigger.
function cgenerator.emit_warning_pragmas(context)
  if context.pragmas.nocwarnpragas then return end
  local emitter = CEmitter(context)
  emitter:add_ln('#ifdef __GNUC__')
  emitter:add_ln('  #ifndef __cplusplus')
  -- disallow implicit declarations
  emitter:add_ln('    #pragma GCC diagnostic error   "-Wimplicit-function-declaration"')
  emitter:add_ln('    #pragma GCC diagnostic error   "-Wimplicit-int"')
  -- importing C functions can cause this warn
  emitter:add_ln('    #pragma GCC diagnostic ignored "-Wincompatible-pointer-types"')
  emitter:add_ln('  #else')
  emitter:add_ln('    #pragma GCC diagnostic ignored "-Wwrite-strings"')
  emitter:add_ln('  #endif')
  -- C zero initialization for anything
  emitter:add_ln('  #pragma GCC diagnostic ignored "-Wmissing-braces"')
  emitter:add_ln('  #pragma GCC diagnostic ignored "-Wmissing-field-initializers"')
  -- may generate always true/false expressions for integers
  emitter:add_ln('  #pragma GCC diagnostic ignored "-Wtype-limits"')
  -- may generate unused variables, parameters, functions
  emitter:add_ln('  #pragma GCC diagnostic ignored "-Wunused-parameter"')
  emitter:add_ln('  #ifdef __clang__')
  emitter:add_ln('    #pragma GCC diagnostic ignored "-Wunused"')
  emitter:add_ln('  #else')
  emitter:add_ln('    #pragma GCC diagnostic ignored "-Wunused-variable"')
  emitter:add_ln('    #pragma GCC diagnostic ignored "-Wunused-function"')
  emitter:add_ln('    #pragma GCC diagnostic ignored "-Wunused-but-set-variable"')
  emitter:add_ln('    #ifndef __cplusplus')
  -- for ignoring const* on pointers
  emitter:add_ln('      #pragma GCC diagnostic ignored "-Wdiscarded-qualifiers"')
  emitter:add_ln('    #endif')
  emitter:add_ln('  #endif')
  emitter:add_ln('#endif')
  if ccompiler.get_cc_info().is_emscripten then --luacov:disable
    emitter:add_ln('#ifdef __EMSCRIPTEN__')
    -- will be fixed in future upstream release
    emitter:add_ln('  #pragma GCC diagnostic ignored "-Wformat"')
    emitter:add_ln('#endif')
  end --luacov:enable
  if not context.pragmas.nocstaticassert then -- check pointer size
    context:ensure_builtin('nelua_static_assert')
  end
  context:add_directive(emitter:generate(), 'warnings_pragmas') -- defines all the above pragmas
end

-- Emits C features checks, to make sure the Nelua compiler and the C compiler agrees on features.
function cgenerator.emit_feature_checks(context)
  if context.pragmas.nocstaticassert then return end
  local emitter = CEmitter(context)
  context:ensure_builtin('nelua_static_assert')
  -- it's important that pointer size is on agreement, otherwise primitives sizes will wrong
  emitter:add_ln('nelua_static_assert(sizeof(void*) == ',primtypes.pointer.size,
              ', "Nelua and C disagree on pointer size");')
  context:add_directive(emitter:generate(), 'features_checks')
end

-- Emits `nelua_main`.
function cgenerator.emit_nelua_main(context, ast, emitter)
  assert(ast.tag == 'Block') -- ast is expected to be a Block
  emitter:add_text("int nelua_main(int nelua_argc, char** nelua_argv) {\n") -- begin block
  local startpos = emitter:get_pos() -- save current emitter position
  context:traverse_node(ast, emitter) -- emit ast statements
  if context.hookmain or emitter:get_pos() ~= startpos then -- main is used or statements were added
    if #ast == 0 or ast[#ast].tag ~= 'Return' then -- last statement is not a return
      emitter:add_indent_ln("  return 0;") -- ensures that an int is always returned
    end
    emitter:add_ln("}") -- end bock
    context:add_declaration('static int nelua_main(int nelua_argc, char** nelua_argv);\n', 'nelua_main')
  else -- empty main, we can skip `nelua_main` usage
    emitter:trim(startpos-1) -- revert text added for begin block
  end
end

-- Emits C `main`.
function cgenerator.emit_entrypoint(context, ast)
  local emitter = CEmitter(context)
  -- if custom entry point is set while `nelua_main` is not hooked,
  -- then we can skip `nelua_main` and `main` declarations
  if context.entrypoint and not context.hookmain then
    context:traverse_node(ast, emitter) -- emit ast statements
    context.emitentrypoint(emitter) -- inject ast statements into the custom entry point
    return
  end
  -- need to define `nelua_main`, it will be called from the entry point
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

-- Generates C code for the analyzed context `context`.
function cgenerator.generate(context)
  context:promote(CContext, visitors, typevisitors) -- promote AnalyzerContext to CContext
  cgenerator.emit_warning_pragmas(context) -- silent some C warnings
  cgenerator.emit_feature_checks(context) -- check C primitive sizes
  cgenerator.emit_entrypoint(context, context.ast) -- emit `main` and `nelua_main`
  return context:concat_chunks(cdefs.template) -- concatenate emitted chunks
end

return cgenerator
