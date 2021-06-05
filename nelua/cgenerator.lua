local CEmitter = require 'nelua.cemitter'
local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local stringer = require 'nelua.utils.stringer'
local bn = require 'nelua.utils.bn'
local cdefs = require 'nelua.cdefs'
local pegger = require 'nelua.utils.pegger'
local cbuiltins = require 'nelua.cbuiltins'
local typedefs = require 'nelua.typedefs'
local CContext = require 'nelua.ccontext'
local types = require 'nelua.types'
local ccompiler = require 'nelua.ccompiler'
local primtypes = typedefs.primtypes
local luatype = type

local izip2 = iters.izip2
local emptynext = function() end
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
        elseif not varattr.nostatic and not varattr.cexport then
          decemitter:add('static ')
        end
        decemitter:add(varnode)
        if valnode and valnode.attr.initializer then
          -- initialize to const values
          decemitter:add(' = ')
          assert(not lastcallindex)
          context:push_state{ininitializer = true}
          decemitter:add_val2type(vartype, valnode)
          context:pop_state()
          defined = true
        else
          -- pre initialize to zeros
          if not noinit then
            decemitter:add(' = ')
            decemitter:add_zeroed_type_init(vartype)
          end
        end
        decemitter:add_ln(';')
        context:add_declaration(decemitter:generate())
        declared = true
      end

      if not empty then -- only define if the type is not empty
        if lastcallindex == 1 then
          -- last assigment value may be a multiple return call
          multiretvalname = context:genuniquename('ret')
          local rettypename = context:funcrettypename(valnode.attr.calleetype)
          emitter:add_indent_ln(rettypename, ' ', multiretvalname, ' = ', valnode, ';')
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
              defemitter:add_val2type(vartype, retvalname, valtype, varnode.checkcast)
            elseif valnode then
              defemitter:add_val2type(vartype, valnode)
            else
              defemitter:add_zeroed_type_init(vartype)
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
        fieldctype = context:typename(field.type)
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

typevisitors.FunctionReturnType = function(context, functype)
  if #functype.rettypes <= 1 then
    return context:typename(functype:get_return_type(1))
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
  if type.is_any or type.is_varanys then
    local node = context:get_current_node()
    node:raisef("compiler deduced the type 'any' here, but it's not supported yet in the C backend")
  elseif type.is_niltype then
    context:ensure_builtin('nlniltype')
  else
    local node = context:get_current_node()
    node:raisef("type '%s' is not supported yet in the C backend", type)
  end
end

local visitors = {}

function visitors.Number(context, node, emitter)
  local attr = node.attr
  if not attr.type.is_float and not attr.untyped and not context.state.ininitializer then
    emitter:add_typecast(attr.type)
  end
  emitter:add_numeric_literal(attr)
end

function visitors.String(_, node, emitter)
  local attr = node.attr
  if attr.type.is_stringy then
    emitter:add_string_literal(attr.value, attr.type.is_cstring)
  else
    if attr.type == primtypes.cchar then
      emitter:add("'", string.char(bn.tointeger(attr.value)), "'")
    else
      emitter:add_numeric_literal(attr)
    end
  end
end

function visitors.Boolean(_, node, emitter)
  emitter:add_boolean_literal(node.attr.value)
end

function visitors.Nil(_, _, emitter)
  emitter:add_nil_literal()
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
    local sideeffect = childvalnode:has_sideeffect()
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
      emitter:add_typecast(type)
    end
    emitter:add_zeroed_type_init(type)
  elseif type.is_composite then
    if context.state.ininitializer then
      context:push_state{incompositeinitializer = true}
      emitter:add('{')
      emitter:add_traversal_list(childnodes)
      emitter:add('}')
      context:pop_state()
    elseif type.cconstruct then -- used to construct vector types when generating GLSL code
      emitter:add(type,'(')
      emitter:add('(')
      emitter:add_traversal_list(childnodes)
      emitter:add(')')
    else
      local useinitializer = can_use_initializer(childnodes)
      if useinitializer then
        emitter:add('(',type,'){')
      else
        emitter:add_ln('({')
        emitter:inc_indent()
        emitter:add_indent(type, ' _tmp = ')
        emitter:add_zeroed_type_init(type)
        emitter:add_ln(';')
      end
      for i,childnode in ipairs(childnodes) do
        local fieldname = childnode.fieldname
        local named = false
        local childvalnode
        if childnode.tag == 'Pair' then
          childvalnode = childnode[2]
          named = true
        else
          childvalnode = childnode
        end
        local childvaltype = childvalnode.attr.type
        if useinitializer then
          if i > 1 then
            emitter:add(', ')
          end
          if named then
            emitter:add('.', fieldname, ' = ')
          end
        else
          if childvaltype.is_array then
            emitter:add_indent('(*(', childvaltype, '*)_tmp.', fieldname, ') = ')
          else
            emitter:add_indent('_tmp.', fieldname, ' = ')
          end
        end
        local fieldtype = type.fields[fieldname].type
        assert(fieldtype)
        emitter:add_val2type(fieldtype, childvalnode, childvaltype)
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
        emitter:add_traversal_list(childnodes)
        emitter:add('}')
      else
        emitter:add('{{')
        emitter:add_traversal_list(childnodes)
        emitter:add('}}')
      end
    else
      local useinitializer = can_use_initializer(childnodes)
      if useinitializer then
        emitter:add_typecast(type)
        emitter:add('{{')
      else
        emitter:add_ln('({')
        emitter:inc_indent()
        emitter:add_indent(type, ' _tmp = ')
        emitter:add_zeroed_type_init(type)
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
        emitter:add_val2type(subtype, childnode)
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
  local parenttype = node.parenttype
  if parenttype and parenttype.is_composite then
    assert(traits.is_string(namenode))
    local field = parenttype.fields[namenode]
    emitter:add('.', cdefs.quotename(field.name), ' = ')
    emitter:add_val2type(field.type, valuenode, valuenode.attr.type)
  else --luacov:disable
    error('not implemented yet')
  end --luacov:enable
end

function visitors.PragmaCall(context, node, emitter)
  local name, args = node[1], node[2]
  if name == 'cinclude' then
    context:ensure_include(args[1])
  elseif name == 'cfile' then
    context:ensure_cfile(args[1])
  elseif name == 'cemit' then
    local code = args[1]
    if traits.is_string(code) and not stringer.endswith(code, '\n') then
      code = code .. '\n'
    end
    if traits.is_string(code) then
      emitter:add(code)
    elseif traits.is_function(code) then
      code(emitter)
    end
  elseif name == 'cemitdecl' then
    local code = args[1]
    if traits.is_string(code) and not stringer.endswith(code, '\n') then
      code = code .. '\n'
    end
    -- actually add in the directives section (just above declarations section)
    if traits.is_string(code) then
      context:add_directive(code)
    elseif traits.is_function(code) then
      local decemitter = CEmitter(context)
      code(decemitter)
      context:add_directive(decemitter:generate())
    end
  elseif name == 'cemitdef' then
    local code = args[1]
    if traits.is_string(code) and not stringer.endswith(code, '\n') then
      code = code .. '\n'
    end
    if traits.is_string(code) then
      context:add_definition(code)
    elseif traits.is_function(code) then
      local defemitter = CEmitter(context)
      code(defemitter)
      context:add_definition(defemitter:generate())
    end
  elseif name == 'cdefine' then
    context:ensure_define(args[1])
  elseif name == 'cflags' then
    table.insert(context.compileopts.cflags, args[1])
  elseif name == 'ldflags' then
    table.insert(context.compileopts.ldflags, args[1])
  elseif name == 'linklib' then
    context:ensure_linklib(args[1])
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
  local isblockcall = context:get_parent_node().tag == 'Block'
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
        emitter:add_one('(')
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
        emitter:add_one(context:declname(attr.calleesym))
      else
        assert(luatype(callee) == 'string')
        emitter:add_one('(')
        emitter:add_val2type(selftype, calleeobjnode)
        emitter:add_one(')')
        emitter:add_one(selftype.is_pointer and '->' or '.')
        emitter:add_one(callee)
      end
      emitter:add_one('(')
      emitter:add_val2type(selftype, calleeobjnode)
    else
      local ispointercall = attr.pointercall
      if ispointercall then
        emitter:add_text('(*')
      end
      if luatype(callee) ~= 'string' and attr.calleesym then
        emitter:add_text(context:declname(attr.calleesym))
      else
        emitter:add_one(callee)
      end
      if ispointercall then
        emitter:add_text(')')
      end
      emitter:add_text('(')
    end

    for i,funcargtype,argnode,argtype,lastcallindex in izipargnodes(callargtypes, argnodes) do
      if not argnode and (funcargtype.is_cvarargs or funcargtype.is_varargs) then break end
      if i > 1 or ismethod then emitter:add_one(', ') end
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
        emitter:add_val2type(funcargtype, arg, argtype)
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
        emitter:add_one(')')
      end
    end
  end
  if isblockcall then
    emitter:add_text(";\n")
  end
end

function visitors.Call(context, node, emitter)
  if node.attr.omitcall then return end
  local argnodes, calleenode = node[1], node[2]
  local calleetype = node.attr.calleetype
  local callee = calleenode
  if calleenode.attr.builtin then
    local builtin = cbuiltins.inlines[calleenode.attr.name]
    callee = builtin(context, node, emitter)
  end
  if calleetype.is_type then
    -- type cast
    local type = node.attr.type
    if #argnodes == 1 then
      local argnode = argnodes[1]
      if argnode.attr.type ~= type then
        -- type really differs, cast it
        emitter:add_val2type(type, argnode, argnode.attr.type)
      else
        -- same type, no need to cast
        emitter:add(argnode)
      end
    else
      emitter:add_zeroed_type_literal(type)
    end
  elseif callee then
    visitor_Call(context, node, emitter, argnodes, callee)
  end
end

function visitors.CallMethod(context, node, emitter)
  local name, argnodes, calleeobjnode = node[1], node[2], node[3]

  visitor_Call(context, node, emitter, argnodes, name, calleeobjnode)
end

-- indexing
function visitors.DotIndex(context, node, emitter)
  local name = node.dotfieldname or node[1]
  local objnode = node[2]
  local attr = node.attr
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
    objtype = node.indextype
    if objtype.is_enum then
      local field = objtype.fields[name]
      emitter:add_numeric_literal(field, objtype.subtype)
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
      context:push_state{inarrayindex = objnode}
      emitter:add(objnode)
      if context.state.fieldindexed ~= objnode then
        emitter:add('.data')
      end
      emitter:add('[')
      context:pop_state()
    end
    if not node.attr.checkbounds then
      emitter:add(indexnode)
    else
      local indextype = indexnode.attr.type
      emitter:add(context:ensure_builtin('nelua_assert_bounds_', indextype))
      emitter:add('(', indexnode, ', ', objtype.length, ')')
    end
    emitter:add(']')
  end
end

function visitors.Block(context, node, emitter)
  local statnodes = node
  emitter:inc_indent()
  local scope = context:push_forked_scope(node)
  do
    emitter:add_traversal_list(statnodes, '')
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
  funcscope.has_return = true
  if funcscope == context.rootscope then
    -- in main body
    node:assertraisef(numretnodes <= 1, "multiple returns in main is not supported yet")
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
        emitter:add_val2type(primtypes.cint, retnode)
        emitter:add_ln(';')
        emitter:add_one(defercode)
        emitter:add_indent_ln('return ', retname, ';')
      else
        emitter:add_one(defercode)
        emitter:add_indent('return ')
        emitter:add_val2type(primtypes.cint, retnode)
        emitter:add_ln(';')
      end
    end
  elseif funcscope.is_doexpr then
    emitter:add_indent_ln('_expr = ', retnodes[1], ';')
    emitter:add(defercode)
    local needgoto = true
    if context:get_parent_node(2).tag == 'DoExpr' then
      local blockstats = context:get_parent_node()[1]
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
        emitter:add_one(defercode)
        emitter:add_indent_ln('return;')
      elseif numfuncrets == 1 then
        -- one return
        local retnode, rettype = retnodes[1], functype:get_return_type(1)
        if retnode then
          -- return value is present
          if defercode ~= '' and retnode.tag ~= 'Id' and not retnode.attr.comptime then
            local retname = context:genuniquename('ret')
            emitter:add_indent(rettype, ' ', retname, ' = ')
            emitter:add_val2type(rettype, retnode)
            emitter:add_ln(';')
            emitter:add_one(defercode)
            emitter:add_indent_ln('return ', retname, ';')
          else
            emitter:add_one(defercode)
            emitter:add_indent('return ')
            emitter:add_val2type(rettype, retnode)
            emitter:add_ln(';')
          end
        else
          -- no return value present, generate a zeroed one
          emitter:add_one(defercode)
          emitter:add_indent('return ')
          emitter:add_zeroed_type_literal(rettype)
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
          retemitter:add_val2type(funcrettype, retvalname, rettype)
        else
          retemitter:add_val2type(funcrettype, retnode)
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
  if doemitter:is_empty() then return end
  emitter:add_indent_ln("{")
  emitter:add(doemitter:generate())
  emitter:add_indent_ln("}")
end

function visitors.DoExpr(context, node, emitter)
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
    end
    emitter:dec_indent()
    emitter:add_indent("})")
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
  emitter:add_val2type(primtypes.boolean, condnode)
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
  emitter:add_val2type(primtypes.boolean, condnode)
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
    emitter:add_val2type(ittype, begvalnode)
    local cmpval
    if (not fixedend or not compop) then
      emitter:add(', _end = ')
      emitter:add_val2type(ittype, endvalnode)
      cmpval = '_end'
    else
      cmpval = endvalnode
    end
    local stepval
    if not fixedstep then
      emitter:add(', _step = ')
      emitter:add_val2type(ittype, stepvalnode)
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
        emitter:add_val2type(ittype, cmpval)
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
  if not attr.entrypoint and not attr.nostatic and not attr.cexport then
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
  local hookmain = attr.cimport and attr.codename == 'nelua_main'
  if hookmain then
    context.maindeclared = true
  end
  local declare = not attr.nodecl or hookmain
  local define = not attr.cimport

  if not declare and not define then -- nothing to do
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

  context:push_state{infuncdecl = true}
  decemitter:add(funcid)
  defemitter:add(funcid)
  context:pop_state()

  local funcscope = context:push_forked_scope(node)
  funcscope.functype = type
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
    context:add_declaration(decemitter:generate())
  end
  if define then
    context:add_definition(defemitter:generate())
    if attr.entrypoint and not context.hookmain then
      context:add_definition(function() return context.mainemitter:generate() end)
    end
    context:add_definition(implemitter:generate())
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

function visitors.UnaryOp(_, node, emitter)
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
  if surround then emitter:add_one('(') end
  builtin(node, emitter, argnode)
  if surround then emitter:add_one(')') end
end

function visitors.BinaryOp(_, node, emitter)
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
        emitter:add_val2type(primtypes.boolean, anode)
        emitter:add(' ? ')
        emitter:add_val2type(type, bnode)
        emitter:add(' : ')
        emitter:add_val2type(type, cnode)
      else
        emitter:add_ln('({')
        emitter:inc_indent()
        emitter:add_indent_ln(type, ' t_;')
        emitter:add_indent(primtypes.boolean, ' cond_ = ')
        emitter:add_val2type(primtypes.boolean, anode)
        emitter:add_ln(';')
        emitter:add_indent_ln('if(cond_) {')
        emitter:add_indent('  t_ = ')
        emitter:add_val2type(type, bnode)
        emitter:add_ln(';')
        emitter:add_indent('  cond_ = ')
        emitter:add_val2type(primtypes.boolean, 't_', type)
        emitter:add_ln(';')
        emitter:add_indent_ln('}')
        emitter:add_indent_ln('if(!cond_) {')
        emitter:add_indent('  t_ = ')
        emitter:add_val2type(type, cnode)
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
      emitter:add_val2type(type, lnode)
      --TODO: be smart and remove this unused code
      emitter:add_ln(';')
      emitter:add_indent_ln(type, ' t2_ = {0};')
      if opname == 'and' then
        assert(not node.attr.ternaryand)
        emitter:add_indent(primtypes.boolean, ' cond_ = ')
        emitter:add_val2type(primtypes.boolean, 't1_', type)
        emitter:add_ln(';')
        emitter:add_indent_ln('if(cond_) {')
        emitter:inc_indent()
        emitter:add_indent('t2_ = ')
        emitter:add_val2type(type, rnode)
        emitter:add_ln(';')
        emitter:add_indent('cond_ = ')
        emitter:add_val2type(primtypes.boolean, 't2_', type)
        emitter:add_ln(';')
        emitter:dec_indent()
        emitter:add_indent_ln('}')
        emitter:add_indent_ln('cond_ ? t2_ : (', type, '){0};')
      elseif opname == 'or' then
        assert(not node.attr.ternaryor)
        emitter:add_indent(primtypes.boolean, ' cond_ = ')
        emitter:add_val2type(primtypes.boolean, 't1_', type)
        emitter:add_ln(';')
        emitter:add_indent_ln('if(!cond_) {')
        emitter:inc_indent()
        emitter:add_indent('t2_ = ')
        emitter:add_val2type(type, rnode)
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
    builtin(node, emitter, lnode, rnode, lname, rname)
    if sequential then
      emitter:add_ln(';')
      emitter:dec_indent()
      emitter:add_indent('})')
    end
  end
  if surround then emitter:add(')') end
end

local generator = {}

local function emit_features_setup(context)
  local emitter = CEmitter(context)
  local ccinfo = ccompiler.get_cc_info()
  if not context.pragmas.nocwarnpragmas then -- warnings
    emitter:add_ln('#ifdef __GNUC__')
    -- throw error on implicit declarations
    emitter:add_ln('#pragma GCC diagnostic error   "-Wimplicit-function-declaration"')
    emitter:add_ln('#pragma GCC diagnostic error   "-Wimplicit-int"')
    -- importing C functions can cause this warn
    emitter:add_ln('#pragma GCC diagnostic ignored "-Wincompatible-pointer-types"')
    -- C zero initialization for anything
    emitter:add_ln('#pragma GCC diagnostic ignored "-Wmissing-braces"')
    emitter:add_ln('#pragma GCC diagnostic ignored "-Wmissing-field-initializers"')
    -- the code generator may generate always true/false expressions for integers
    emitter:add_ln('#pragma GCC diagnostic ignored "-Wtype-limits"')
    -- the code generator may generate unused variables, parameters, functions
    emitter:add_ln('#pragma GCC diagnostic ignored "-Wunused-parameter"')
    do
      emitter:add_ln('#if defined(__clang__)')
      emitter:add_ln('#pragma GCC diagnostic ignored "-Wunused"')
      emitter:add_ln('#else')
      emitter:add_ln('#pragma GCC diagnostic ignored "-Wunused-variable"')
      emitter:add_ln('#pragma GCC diagnostic ignored "-Wunused-function"')
      emitter:add_ln('#pragma GCC diagnostic ignored "-Wunused-but-set-variable"')
      -- for ignoring const* on pointers
      emitter:add_ln('#pragma GCC diagnostic ignored "-Wdiscarded-qualifiers"')
      emitter:add_ln('#endif')
    end
    if ccinfo.is_emscripten then
      emitter:add_ln('#ifdef __EMSCRIPTEN__')
      -- printf format for PRIxPTR generate warnings on emscripten, report to upstream later?
      emitter:add_ln('#pragma GCC diagnostic ignored "-Wformat"')
      emitter:add_ln('#endif')
    end
    emitter:add_ln('#endif')
  end
  if not context.pragmas.nocstaticassert then -- static assert macro
    emitter:add([[#if __STDC_VERSION__ >= 201112L
#define nelua_static_assert _Static_assert
#else
#define nelua_static_assert(x, y)
#endif
]])
    emitter:add_ln('nelua_static_assert(sizeof(void*) == ', primtypes.pointer.size,
                ', "Nelua and C disagree on architecture size");')
  end
  context:add_directive(emitter:generate())
end

local function emit_main(ast, context)
  local mainemitter = CEmitter(context, -1)
  context.mainemitter = mainemitter

  local emptymain = false
  if not context.entrypoint or context.hookmain then
    mainemitter:inc_indent()
    mainemitter:add_one("int nelua_main(int nelua_argc, char** nelua_argv) {\n")
    local startpos = mainemitter:get_pos()
    mainemitter:add_traversal(ast)
    emptymain = not context.hookmain and mainemitter:get_pos() == startpos
    if not emptymain then -- main has statements
      if not context.rootscope.has_return then
        -- main() must always return an integer
        mainemitter:inc_indent()
        mainemitter:add_indent_ln("return 0;")
        mainemitter:dec_indent()
      end
      mainemitter:add_ln("}")
      mainemitter:dec_indent()

      if not context.maindeclared then
        context:add_declaration('static int nelua_main(int nelua_argc, char** nelua_argv);\n')
      end
    else -- empty main, we can skip `nelua_main` usage
      mainemitter.codes[startpos] = ''
    end
  else
    mainemitter:inc_indent()
    mainemitter:add_traversal(ast)
    mainemitter:dec_indent()
  end

  if not context.entrypoint and not context.pragmas.noentrypoint then
    mainemitter:add_indent_ln('int main(int argc, char** argv) {')
    mainemitter:inc_indent()
    if not emptymain then
      mainemitter:add_indent_ln('return nelua_main(argc, argv);')
    else
      mainemitter:add_indent_ln('return 0;')
    end
    mainemitter:dec_indent()
    mainemitter:add_indent_ln('}')
  end

  if not context.entrypoint or context.hookmain then
    context:add_definition(mainemitter:generate())
  end
end

generator.template = [[
/* ------------------------------ DIRECTIVES -------------------------------- */
$(directives)
/* ------------------------------ DECLARATIONS ------------------------------ */
$(declarations)
/* ------------------------------ DEFINITIONS ------------------------------- */
$(definitions)
]]

function generator.generate(ast, context)
  CContext.promote_context(context, visitors, typevisitors)

  emit_features_setup(context)
  emit_main(ast, context)

  context:evaluate_templates()

  local code = pegger.substitute(generator.template, {
    directives = table.concat(context.directives):sub(1, -2),
    declarations = table.concat(context.declarations):sub(1, -2),
    definitions = table.concat(context.definitions):sub(1, -2)
  })

  return code, context.compileopts
end

generator.compiler = ccompiler

return generator
