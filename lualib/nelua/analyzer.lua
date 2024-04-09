local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local tabler = require 'nelua.utils.tabler'
local pegger = require 'nelua.utils.pegger'
local fs = require 'nelua.utils.fs'
local typedefs = require 'nelua.typedefs'
local Attr = require 'nelua.attr'
local Symbol = require 'nelua.symbol'
local types = require 'nelua.types'
local bn = require 'nelua.utils.bn'
local except = require 'nelua.utils.except'
local preprocessor = require 'nelua.preprocessor'
local builtins = require 'nelua.builtins'
local config = require 'nelua.configer'.get()
local console = require 'nelua.utils.console'
local nanotimer = require 'nelua.utils.nanotimer'
local aster = require 'nelua.aster'
local analyzer = {}
local luatype = type

local primtypes = typedefs.primtypes
local visitors = {}
analyzer.visitors = visitors

local function emptynext() end

-- Number literal.
function visitors.Number(_, node, opts)
  local attr = node.attr
  local value, base = bn.from(node[1])
  local literal = node[2]
  if literal then -- a literal suffix is set
    local type = primtypes[typedefs.number_literal_types[literal]]
    if not type then
      node:raisef("literal suffix '%s' is undefined for numbers", literal)
    end
    if not type:is_inrange(value) then
      node:raisef("value `%s` for literal type `%s` is out of range, \z
        the minimum is `%s` and maximum is `%s`",
        value, type, type.min, type.max)
    end
    attr.type = type
  else -- no literal suffix is set
    local desiredtype = opts and opts.desiredtype
    if desiredtype and
       (desiredtype.is_unsigned or desiredtype.is_float) and
       desiredtype:is_inrange(value) then
      -- parent desires unsigned or float type
      attr.type = desiredtype
    else -- the number has unfixed type
      attr.untyped = true
      if bn.isintegral(value) then -- try to use the default integer type
        if base ~= 10 then -- wrap overflows when not in base 10
          -- the value may still be out range here, but it's fine, it will be wrapped later
          attr.type = primtypes.integer
        elseif primtypes.integer:is_inrange(value) then -- the value can fit an integer
          attr.type = primtypes.integer
        else -- value is too large to fit an integer
          attr.type = primtypes.number
        end
      else -- can only use the default float number type
        attr.type = primtypes.number
      end
    end
  end
  attr.value = value
  attr.base = base
  attr.comptime = true
  node.done = true
end

-- String literal.
function visitors.String(_, node, opts)
  local attr = node.attr
  local value, literal = node[1], node[2]
  local type
  if literal then -- has literal suffix
    type = typedefs.string_literals_types[literal]
    if not type then
      node:raisef("literal suffix '%s' is undefined for strings", literal)
    end
    if not type.is_stringy then -- a byte/char literal
      if #value ~= 1 then
        node:raisef("literal suffix '%s' expects a string of length 1", literal)
      end
      value = bn.new(string.byte(value))
    end
  else -- no literal suffix is set
    local desiredtype = opts and opts.desiredtype
    if desiredtype and desiredtype.is_stringy then
      type = desiredtype
    else
      type = primtypes.string
    end
  end
  attr.value = value
  attr.type = type
  attr.comptime = true
  node.done = true
end

-- Boolean literal.
function visitors.Boolean(_, node)
  local attr = node.attr
  attr.value = node[1] == true
  attr.type = primtypes.boolean
  attr.comptime = true
  node.done = true
end

-- Nil literal.
function visitors.Nil(_, node)
  local attr = node.attr
  attr.type = primtypes.niltype
  attr.comptime = true
  node.done = true
end

-- Nilptr literal.
function visitors.Nilptr(_, node)
  local attr = node.attr
  attr.type = primtypes.nilptr
  attr.comptime = true
  node.done = true
end

-- Varargs (`...`).
function visitors.Varargs(context, node)
  local polyeval = context.state.inpolyeval
  if polyeval and polyeval.varargsnodes then -- unpack arguments of a polymorphic function
    local parentnode = context:get_visiting_node(1)
    local nvarargs = #polyeval.varargsnodes
    if parentnode.is_unpackable then -- can unpack all arguments
      local parent, pindex = parentnode:recursive_find_child(node)
      if nvarargs > 0 then -- unpack many arguments
        local ret
        for j=1,nvarargs do
          local argnode = aster.Id{'__arg'..j}
          if j == 1 then -- first argument
            ret = context:transform_and_traverse_node(node, argnode) -- transform to reuse ref
          else -- next arguments
            parent[pindex+j-1] = argnode
            context:traverse_node(argnode)
          end
        end
        return ret
      else -- unpack 0 arguments
        context:transform_and_traverse_node(node, aster.Nil{}) -- transform just in case
        parent[pindex] = nil -- remove the node
        return
      end
    else -- unpack just the first argument
      local argnode
      if nvarargs > 0 then -- unpack just the first argument
        argnode = aster.Id{'__arg1'}
      else -- no arguments
        argnode = aster.Nil{}
      end
      return context:transform_and_traverse_node(node, argnode)
    end
  else -- runtime varargs
    if context.scope.is_topscope then
      node:raisef("cannot unpack varargs in this context")
    end
    local mulargtype = types.get_multiple_argtype_from_attrs(context.state.funcscope.funcsym.argattrs)
    if not mulargtype then
      node:raisef("cannot unpack varargs in this context")
    elseif mulargtype.is_cvarargs then
      node:raisef("cannot unpack 'cvarargs', use 'cvalist' instead")
    end
    node.attr.type = mulargtype
    node.done = true
  end
end

local function visitor_convert(context, parent, parentindex, vartype, valnode, valtype, callargs)
  if not vartype or not valtype then
    -- convert possible only when types are known
    return valnode, valtype
  end
  if vartype.is_concept then
    vartype = vartype:get_convertible_from_attr(valnode.attr, false, not not callargs, callargs)
    if not vartype then
      -- concept failed
      return valnode, valtype
    end
  end
  if vartype.is_auto then
    -- convert ignored on concepts
    return valnode, valtype
  end
  local objsym
  local objtype = vartype:implicit_deref_type()
  if vartype.is_stringy and not valtype.is_stringy then
    -- __convert not allowed on stringy types
    return valnode, valtype
  end
  if not (valtype and objtype and objtype.is_record and vartype ~= valtype) then
    -- convert cannot be overridden
    return valnode, valtype
  end
  if valtype:is_pointer_of(vartype) or vartype:is_pointer_of(valtype) then
    -- ignore automatic deref/ref
    return valnode, valtype
  end
  if valtype.is_nilptr and vartype.is_pointer then
    return valnode, valtype
  end
  local mtsym = objtype.metafields.__convert
  if not mtsym then
    return valnode, valtype
  end
  objsym = objtype.symbol
  local idnode = aster.Id{objsym.name, pattr={forcesymbol=objsym}}
  local newvalnode = aster.Call{{valnode}, aster.DotIndex{'__convert', idnode}}
  newvalnode.src = valnode.src
  newvalnode.pos = valnode.pos
  newvalnode.endpos = valnode.endpos
  parent[parentindex] = newvalnode
  context:traverse_node(newvalnode)
  if newvalnode.attr.type then
    assert(newvalnode.attr.type == objtype)
  end
  return newvalnode, newvalnode.attr.type
end

local function visitor_Array_literal(context, node, littype)
  local attr = node.attr
  local childnodes = node
  local subtype = littype.subtype
  local nchildnodes = #childnodes
  do -- need to unpack last varargs first
    local lastchildnode = nchildnodes > 0 and childnodes[nchildnodes]
    if lastchildnode and lastchildnode.is_Varargs then
      context:traverse_node(lastchildnode)
      nchildnodes = #childnodes
    end
  end
  if not (nchildnodes <= littype.length or nchildnodes == 0) then
    node:raisef("expected at most %d values in array literal but got %d", littype.length, nchildnodes)
  end
  local comptime = true
  local done = true
  local sideeffect
  for i=1,nchildnodes do
    local childnode = childnodes[i]
    if childnode.is_Pair then
      childnode:raisef("fields are disallowed for array literals")
    end
    context:traverse_node(childnode, {desiredtype=subtype})
    local childtype = childnode.attr.type
    childnode, childtype = visitor_convert(context, childnodes, i, subtype, childnode, childtype)
    local childattr = childnode.attr
    if childtype then
      if not subtype:is_initializable_from_attr(childattr) then
        comptime = nil
      end
      local ok, err = subtype:is_convertible_from_attr(childattr)
      if not ok then
        childnode:raisef("in array literal at index %d: %s", i, err)
      end
      if not childattr:can_copy() then
        childnode:raisef("in array literal at index %d: cannot pass non copyable type '%s' by value",
          i, childtype)
      end
    end
    sideeffect = sideeffect or childattr.sideeffect
    comptime = comptime and childattr.comptime
    done = done and childtype and childnode.done and true
  end
  if comptime then
    local value = {}
    for i=1,#childnodes do
      local childnode = childnodes[i]
      local childattr = childnode.attr
      assert(childattr.comptime)
      value[#value+1] = childattr
    end
    value.type = littype
    attr.value = value
  end
  attr.type = littype
  attr.comptime = comptime
  attr.sideeffect = sideeffect
  node.done = done
end

local function visitor_Record_literal(context, node, littype)
  local attr = node.attr
  local childnodes = node
  local comptime = true
  local lastfieldindex = 0
  local done = true
  local sideeffect
  for i=1,#childnodes do
    local childnode = childnodes[i]
    local parent, parentindex
    local fieldname, fieldvalnode, field, fieldindex
    if childnode.is_Pair then
      fieldname, fieldvalnode = childnode[1], childnode[2]
      if luatype(fieldname) ~= 'string' then
        childnode:raisef("only string literals are allowed in record's field names")
      end
      field = littype.fields[fieldname]
      if field then
        fieldindex = field.index
        fieldname = field.name
      end
      parent = childnode
      parentindex = 2
      childnode.attr.parenttype = littype
    else
      fieldindex = lastfieldindex + 1
      field = littype.fields[fieldindex]
      if not field then
        childnode:raisef("field at index %d is invalid, record has only %d fields",
          fieldindex, #littype.fields)
      end
      fieldname = field.name
      fieldvalnode = childnode
      parent = childnodes
      parentindex = i
    end
    if not field then
      childnode:raisef("field '%s' is not present in record '%s'", fieldname, littype)
    end
    local fieldtype = field.type
    context:traverse_node(fieldvalnode, {desiredtype=fieldtype})
    local fieldvaltype = fieldvalnode.attr.type
    fieldvalnode, fieldvaltype = visitor_convert(context, parent, parentindex, fieldtype, fieldvalnode, fieldvaltype)
    local fieldvalattr = fieldvalnode.attr
    lastfieldindex = fieldindex
    if fieldvaltype then
      if not fieldtype:is_initializable_from_attr(fieldvalattr) then
        comptime = nil
      end
      local ok, err = fieldtype:is_convertible_from_attr(fieldvalattr)
      if not ok then
        childnode:raisef("in record literal field '%s': %s", fieldname, err)
      end
      if not fieldvalattr:can_copy() then
        childnode:raisef("in record literal field '%s': cannot pass non copyable type '%s' by value",
          fieldname, fieldvaltype)
      end
    end
    if not fieldvalattr.comptime then
      comptime = nil
    end
    if fieldvalattr.sideeffect then
      sideeffect = true
    end
    if not fieldvaltype or not fieldvalnode.done then
      done = nil
    end
  end
  attr.type = littype
  attr.comptime = comptime
  attr.sideeffect = sideeffect
  node.done = done
end

local function visitor_Union_literal(context, node, littype)
  local attr = node.attr
  local childnodes = node
  local done = true
  local comptime = true
  local sideeffect
  if #childnodes > 1 then
    node:raisef("unions can only be initialized with at most 1 field, but got %d", #childnodes)
  end
  local childnode = childnodes[1]
  if childnode then
    if not childnode.is_Pair then
      childnode:raisef("union field is missing a name")
    end
    local fieldname, fieldvalnode = childnode[1], childnode[2]
    if luatype(fieldname) ~= 'string' then
      childnode:raisef("only string literals are allowed in union's field names")
    end
    local field = littype.fields[fieldname]
    if not field then
      childnode:raisef("field '%s' is not present in union '%s'", fieldname, littype)
    end
    fieldname = field.name
    local fieldtype = field.type
    context:traverse_node(fieldvalnode, {desiredtype=fieldtype})
    local fieldvaltype = fieldvalnode.attr.type
    fieldvalnode, fieldvaltype = visitor_convert(context, childnode, 2, fieldtype, fieldvalnode, fieldvaltype)
    local fieldvalattr = fieldvalnode.attr
    if fieldvaltype then
      if not fieldtype:is_initializable_from_attr(fieldvalattr) then
        comptime = nil
      end
      local ok, err = fieldtype:is_convertible_from_attr(fieldvalattr)
      if not ok then
        childnode:raisef("in union literal field '%s': %s", fieldname, err)
      end
      if not fieldvalattr:can_copy() then
        childnode:raisef("in record literal field '%s': cannot pass non copyable type '%s' by value",
          fieldname, fieldvaltype)
      end
    end
    if not fieldvalattr.comptime then
      comptime = nil
    end
    if fieldvalattr.sideeffect then
      sideeffect = true
    end
    childnode.attr.parenttype = littype
    if not fieldvaltype or not fieldvalnode.done then
      done = nil
    end
  end
  attr.type = littype
  attr.comptime = comptime
  attr.sideeffect = sideeffect
  node.done = done
end

local function visitor_Table_literal(context, node)
  local attr = node.attr
  local childnodes = node
  local done = true
  for i=1,#childnodes do
    local childnode = childnodes[i]
    context:traverse_node(childnode)
    done = done and childnode.done and true
  end
  -- TODO: check side effects?
  attr.type = primtypes.table
  attr.node = node
  attr.done = done
end

function visitors.InitList(context, node, opts)
  local desiredtype = (opts and opts.desiredtype) or node.attr.desiredtype
  if desiredtype then
    local objtype = desiredtype:implicit_deref_type()
    if objtype.metafields and objtype.metafields.__convert then
      local argtype = objtype.metafields.__convert.type.argtypes[1]
      if argtype.is_concept then
        local listtype = argtype:get_desired_type_from_node(node)
        if listtype then
          desiredtype = listtype
        end
      end
    end
  end
  if not desiredtype or (desiredtype.is_table or desiredtype.is_polymorphic) then
    visitor_Table_literal(context, node)
  elseif desiredtype.is_array then
    visitor_Array_literal(context, node, desiredtype)
  elseif desiredtype.is_record then
    visitor_Record_literal(context, node, desiredtype)
  elseif desiredtype.is_union then
    visitor_Union_literal(context, node, desiredtype)
  elseif desiredtype.is_array_pointer then
    local clone = node:clone()
    clone.attr.desiredtype = desiredtype.subtype
    local newnode = aster.UnaryOp{'ref', clone}
    context:transform_and_traverse_node(node, newnode)
  else
    node:raisef("type '%s' cannot be initialized using an initializer list", desiredtype)
  end
end

-- Pair inside an init list.
function visitors.Pair(context, node)
  local namenode, exprnode = node[1], node[2]
  local namedone = true
  if luatype(namenode) ~= 'string' then -- name is a node
    context:traverse_node(namenode)
    namedone = namenode.done
  end
  context:traverse_node(exprnode)
  node.done = namedone and exprnode.done and true
end

function visitors.Directive(context, node)
  local name, args = node[1], node[2]
  -- check directive shape
  if not node.checked then
    local paramshape = typedefs.pp_directives[name]
    if not paramshape then
      node:raisef("directive '%s' is undefined", name)
    end
    local ok, err = paramshape(args)
    if not ok then
      node:raisef("invalid arguments for directive '%s': %s", name, err)
    end
    node.checked = true
  end
  -- handle directive
  if name == 'pragmapush' then
    context:push_forked_pragmas(args[1])
  elseif name == 'pragmapop' then
    context:pop_pragmas()
  elseif name == 'pragma' then
    tabler.update(context.pragmas, args[1])
  elseif name == 'libpath' then
    table.insert(context.libpaths, args[1])
  else
    node.done = true
  end
end

function visitors.Annotation(context, node, opts)
  local symbol = opts.symbol
  local name = node[1]

  local istypedecl
  local paramshape
  local symboltype
  if name == 'comptime' then
    paramshape = true
  else
    symboltype = symbol.type
    istypedecl = symboltype and symboltype.is_type
    local parentnode = context:get_visiting_node(1)
    local isfuncdecl = parentnode and parentnode.is_function
    if not isfuncdecl and not symboltype or (istypedecl and not symbol.value) then
      if name == 'cimport' and context.state.anyphase then
        node:raisef('imported variables from C must have an explicit type')
      end
      -- in the next traversal we will have the type
      return
    end
    local annotype
    if isfuncdecl then
      paramshape = typedefs.function_annots[name]
      annotype = 'functions'
    elseif istypedecl then
      paramshape = typedefs.type_annots[name]
      annotype = 'types'
    else -- variable declaration
      paramshape = typedefs.variable_annots[name]
      annotype = 'variables'
    end
    if not paramshape then
      node:raisef("annotation '%s' is undefined for %s", name, annotype)
    end
  end

  local argnodes = node[2]

  local params = {}
  if argnodes then
    context:traverse_nodes(argnodes)
    for i=1,#argnodes do
      local param = argnodes[i].attr.value
      if bn.isnumeric(param) then
        param = param:tointeger()
      end
      params[i] = param
    end
  end

  if paramshape == true then
    if argnodes and #argnodes ~= 0 then
      node:raisef("annotation '%s' takes no arguments", name)
    end
    params = true
  else
    local ok, err = paramshape(params)
    if not ok then
      node:raisef("annotation '%s' arguments are invalid: %s", name, err)
    end
    if #paramshape.shape == 1 then
      params = params[1]
      if params == nil then
        params = true
      end
    end
  end

  local objattr
  if istypedecl then
    objattr = symbol.value
  else
    objattr = symbol
  end
  objattr[name] = params

  if name == 'cimport' then
    objattr.cimport = true
    local codename
    if luatype(params) == 'string' then
      codename = params
    else
      codename = symbol.name:match('[%w_]+$')
    end
    if objattr._type then
      -- changing codename only on non primitives
      if not types.is_primitive_type(objattr) then
        objattr:set_codename(codename)
      end
    else
      objattr.codename = codename
    end
    if codename == 'nelua_argc' or codename == 'nelua_argv' then
      context.cmainimports = context.cmainimports or {}
      table.insert(context.cmainimports, (codename:gsub('nelua_', '')))
    end
    context.cimports = context.cimports or {}
    context.cimports[codename] = true
  elseif name == 'nickname' then
    assert(objattr._type and objattr.is_nameable)
    local type, nickname = objattr, params
    local codename = context:choose_codename(nickname)
    symbol.codename = codename
    type:set_codename(codename)
  elseif name == 'packed' or name == 'aligned' then
    if objattr._type then
      objattr:update_fields()
    end
  elseif name == 'codename' or (name == 'cexport' and params ~= true) then
    if name == 'cexport' then
      objattr.codename = params
    end
    objattr.fixedcodename = params
    objattr.nodce = true
    if objattr.type and objattr.type.is_polyfunction then
      node:raisef("polymorphic functions cannot use codename annotation")
    end
  elseif istypedecl and (name == 'cincomplete' or name =='forwarddecl') then
    if name =='forwarddecl' and objattr._type and objattr.fields and #objattr.fields > 0 then
      node:raisef("defining fields in types marked with forward declaration is not allowed")
    end
    objattr.size = nil
    objattr.bitsize = nil
    objattr.align = nil
    objattr.is_empty = nil
  elseif name == 'using' then
    assert(objattr._type)
    if not objattr.is_enum then
      node:raisef("annotation 'using' can only be used with enums")
    end
    -- inject all enum fields as comptime values
    for _,field in ipairs(objattr.fields) do
      local fieldsymbol = Symbol{
        name = field.name,
        codename = objattr.codename..'_'..field.name,
        comptime = true,
        type = objattr,
        value = field.value,
        scope = symbol.scope,
      }
      symbol.scope:add_symbol(fieldsymbol)
    end
    return -- we want to skip node.done = true
  elseif name == 'close' then
    if not context:get_visiting_node(2).is_VarDecl then
      node:raisef("annotation 'close' is only allowed in variable declarations")
    end
  elseif name == 'atomic' then
    local objtype = objattr.type
    if not objtype.is_atomicable then
      node:raisef("variable of type '%s' cannot be atomic", objtype)
    end
  elseif name == 'cinclude' and objattr.cimport then
    objattr.nodecl = true
  end

  node.done = true
end

function visitors.Id(context, node)
  local name = node[1]
  local state = context.state
  if name == 'type' and state.intypeexpr  then
    name = 'typetype'
  end
  local symbol
  local attr = node.attr
  if not attr.forcesymbol then
    symbol = context.scope.symbols[name]
    if not symbol then
      local modname = typedefs.symbol_modules[name]
      if modname then
        node:raisef("undeclared symbol '%s', maybe you forgot to require module '%s'?",
          name, modname)
      elseif state.infuncdef then
        node:raisef("undeclared symbol '%s', maybe you forgot to declare it as 'global' or 'local'?", name)
      else
        node:raisef("undeclared symbol '%s'", name)
      end
    end
  else
    symbol = attr.forcesymbol
  end
  symbol:link_node(node)
  if not symbol.staticstorage and symbol.scope ~= context.rootscope and context.generator ~= 'lua' and
     not symbol:is_directly_accesible_from_scope(context.scope) then
    node:raisef("attempt to access upvalue '%s', but closures are not supported", name)
  end
  if symbol.deprecated then
    node:warnf("use of deprecated symbol '%s'", name)
  end
  symbol:add_use_by(state.funcscope.funcsym)
  if symbol.type then
    node.done = symbol
  end
  return symbol
end

function visitors.IdDecl(context, node)
  local namenode, typenode, annotnodes = node[1], node[2], node[3]
  local attr = node.attr
  if not attr.type and typenode then
    context:push_forked_state{intypeexpr = true}
    context:traverse_node(typenode)
    context:pop_state()
    local typeattr = typenode.attr
    local typetype = typeattr.type
    local type = typeattr.value
    if not typetype or not typetype.is_type or not type then
      typenode:raisef("invalid type")
    end
    if type.is_void then
      node:raisef("variable declaration cannot be of the type '%s'", type)
    elseif type.is_generic then
      node:raisef("variable declaration cannot be of the type '%s', \z
        maybe you forgot to instantiate the generic?", type)
    end
    attr.type = type
  end
  local symbol
  if luatype(namenode) == 'string' then
    if attr._symbol then
      symbol = attr
      symbol:clear_possible_types()
    else
      symbol = Symbol.promote_attr(attr, node, namenode)
      local scope
      if symbol.global then
        scope = context.rootscope
      else
        scope = context.scope
      end
      if not symbol.codename then
        if not symbol.staticstorage then
          symbol.codename = namenode
        else
          symbol.codename = context:choose_codename(namenode)
        end
      end
      symbol.scope = scope
      symbol.lvalue = true
    end
  else -- record field
    assert(namenode.is_DotIndex)
    context:push_forked_state{infielddecl=node}
    symbol = context:traverse_node(namenode)
    context:pop_state()
    symbol.scope = context.rootscope
    symbol.lvalue = true
  end
  if annotnodes then
    local type = attr.type
    if not (type and type.is_type and not attr.value) then -- skip unresolved types
      context:traverse_nodes(annotnodes, {symbol=symbol})
    end
  end
  return symbol
end

function visitors.Paren(context, node, ...)
  local innernode = node[1]
  local ret = context:traverse_node(innernode, ...)
  -- inherit attributes from inner node
  node.attr = innernode.attr
  node.done = innernode.done
  -- forward anything from inner node traverse
  return ret
end

function visitors.Type(context, node, opts)
  local symbol = opts and opts.symbol
  local typenode = node[1]
  context:push_forked_state{intypeexpr = true}
  context:traverse_node(typenode, {symbol=symbol})
  context:pop_state()
  -- inherit attributes from inner node
  local attr = typenode.attr
  node.attr = attr
  local type = attr.value
  if not traits.is_type(type) then
    typenode:raisef("invalid type")
  end
  if symbol then
    if symbol.type and not (symbol.type.is_type or symbol.type.is_auto) then
      node:raisef("attempt to assign a type to a symbol of type '%s'", symbol.type)
    end
    if symbol.value then
      -- overwrite old symbol value, (this fixes forward declarations on generics)
      tabler.mirror(symbol.value, type)
    end
    symbol.type = primtypes.type
    symbol.value = type
    context:choose_type_symbol_names(symbol)
  end
  node.done = true
end

function visitors.VarargsType(_, node)
  local attr = node.attr
  local name = node[1]
  local type
  if name then
    type = primtypes[name]
    assert(type)
  else
    type = primtypes.varanys
  end
  attr.type = type
  node.done = true
end

function visitors.FuncType(context, node)
  local attr = node.attr
  local argnodes, retnodes = node[1], node[2]
  context:traverse_nodes(argnodes)
  if retnodes then
    context:traverse_nodes(retnodes)
  end
  local argattrs = {}
  for i=1,#argnodes do
    local argnode = argnodes[i]
    local argattr
    if argnode.is_IdDecl or argnode.is_VarargsType then
      argattr = argnode.attr
    else
      local argtype = argnode.attr.value
      if not traits.is_type(argtype) then
        argnode:raisef("invalid type")
      end
      argattr = Attr{type = argtype}
    end
    argattrs[i] = argattr
  end
  local rettypes
  if retnodes then
    for i=1,#retnodes do
      local retnode = retnodes[i]
      local rettype = retnode.attr.value
      if not traits.is_type(rettype) then
        retnode:raisef("invalid type")
      end
    end
    rettypes = types.typenodes_to_types(retnodes)
  else
    rettypes = {}
  end
  local type = types.FunctionType(argattrs, rettypes, node, true)
  type.sideeffect = true
  attr.type = primtypes.type
  attr.value = type
  node.done = true
end

function visitors.RecordField(context, node, recordtype)
  local attr = node.attr
  local name, typenode = node[1], node[2]
  context:traverse_node(typenode)
  local typeattr = typenode.attr
  local type = typeattr.value
  if not traits.is_type(type) then
    typenode:raisef("invalid type")
  end
  attr.type = typeattr.type
  attr.value = type
  recordtype:add_field(name, type, false)
  node.done = true
end

function visitors.RecordType(context, node, opts)
  local symbol = opts and opts.symbol
  local attr = node.attr
  local recordtype
  if symbol and symbol.value then
    recordtype = symbol.value
    assert(recordtype.forwarddecl)
    recordtype.forwarddefn = true -- not forward decl anymore
    assert(recordtype.is_record)
    recordtype.node = node
  else
    recordtype = types.RecordType({}, node)
    recordtype.size = nil -- size is unknown yet
  end
  attr.type = primtypes.type
  attr.value = recordtype
  if symbol and not symbol.value then
    -- must populate this type symbol early in case its used in the records fields
    if symbol.type and not symbol.type.is_type then
      node:raisef("attempt to assign a type to a symbol of type '%s'", symbol.type)
    end
    symbol.type = primtypes.type
    symbol.value = recordtype
    context:choose_type_symbol_names(symbol)
    recordtype.symbol = symbol
  end
  local fieldnodes = node
  context:traverse_nodes(fieldnodes, recordtype)
  recordtype:update_fields()
  node.done = true
end

function visitors.UnionField(context, node, uniontype)
  local attr = node.attr
  local name, typenode = node[1], node[2]
  context:traverse_node(typenode)
  local typeattr = typenode.attr
  local type = typeattr.value
  if not traits.is_type(type) then
    typenode:raisef("invalid type")
  end
  attr.type = typeattr.type
  attr.value = type
  uniontype:add_field(name, type, false)
  node.done = true
end

function visitors.UnionType(context, node, opts)
  local symbol = opts and opts.symbol
  local attr = node.attr
  local uniontype
  if symbol and symbol.value then
    uniontype = symbol.value
    assert(uniontype.forwarddecl)
    uniontype.forwarddefn = true -- not forward decl anymore
    assert(uniontype.is_union)
    uniontype.node = node
  else
    uniontype = types.UnionType({}, node)
    uniontype.size = nil -- size is unknown yet
  end
  local fieldnodes = node
  for i=1,#fieldnodes do
    local fnode = fieldnodes[i]
    context:traverse_node(fnode, uniontype)
  end
  attr.type = primtypes.type
  attr.value = uniontype
  uniontype:update_fields()
  node.done = true
end

function visitors.VariantType(_, node)
  node:raisef("variant type not implemented yet")
end

function visitors.OptionalType(_, node)
  node:raisef("optional type not implemented yet")
end

function visitors.EnumField(context, node, desiredtype)
  local name, numnode = node[1], node[2]
  local field = Attr{name = name}
  if numnode then
    context:traverse_node(numnode, {desiredtype=desiredtype})
    local numattr = numnode.attr
    local numtype = numattr.type
    if not numattr.comptime then
      numnode:raisef("in enum field '%s': enum fields can only be assigned to compile time values", name)
    elseif not numtype.is_integral then
      numnode:raisef("in enum field '%s': only integral types are allowed in enums, but got type '%s'",
        name, numtype)
    end
    local ok, err = desiredtype:is_convertible_from_attr(numattr)
    if not ok then
      numnode:raisef("in enum field '%s': %s", name, err)
    end
    field.value = numnode.attr.value
  end
  node.done = field
  return field
end

function visitors.EnumType(context, node)
  local attr = node.attr
  local typenode, fieldnodes = node[1], node[2]
  local subtype = primtypes.integer
  if typenode then
    context:traverse_node(typenode)
    subtype = typenode.attr.value
    if not traits.is_type(subtype) then
      typenode:raisef("invalid type")
    end
  end
  local fields = {}
  for i=1,#fieldnodes do
    local fnode = fieldnodes[i]
    local field = context:traverse_node(fnode, subtype)
    if not field.value then
      if i == 1 then
        fnode:raisef("first enum field requires an initial value", field.name)
      else
        field.value = fields[i-1].value + 1
      end
    end
    if not subtype:is_inrange(field.value) then
      fnode:raisef("in enum field '%s': value %s is out of range for type '%s'",
        field.name, field.value:todecint(), subtype)
    end
    assert(field.name)
    fields[i] = field
  end
  attr.type = primtypes.type
  local type = types.EnumType(subtype, fields, node)
  attr.value = type
  node.done = true
end

function visitors.ArrayType(context, node)
  local attr = node.attr
  local subtypenode, lengthnode = node[1], node[2]
  context:traverse_node(subtypenode)
  local subtype = subtypenode.attr.value
  if not traits.is_type(subtype) then
    subtypenode:raisef("invalid type")
  end
  local length
  if lengthnode then
    context:traverse_node(lengthnode)
    if not lengthnode.attr.value then
      lengthnode:raisef("unknown comptime value for expression")
    end
    length = bn.tointeger(lengthnode.attr.value)
    if not lengthnode.attr.type.is_integral then
      lengthnode:raisef("cannot have non integral type '%s' for array size",
        lengthnode.attr.type)
    elseif length < 0 then
      lengthnode:raisef("cannot have negative array size %d", length)
    end
  else -- must infer the length
    local pnode1 = context:get_visiting_node(1)
    local pnode2 = context:get_visiting_node(2)
    local pnode3 = context:get_visiting_node(3)
    local valnode
    if pnode1.is_IdDecl and
       pnode2 and pnode2.is_VarDecl then -- typed declaration
      local varnodes, valnodes = pnode2[2], pnode2[3]
      if valnodes then
        local varindex = tabler.ifind(varnodes, pnode1)
        valnode = valnodes[varindex]
      end
    elseif pnode1.is_Type and
           pnode2 and pnode2.is_Paren and
           pnode3 and pnode3.is_Call then -- inline type initialization
      valnode = pnode3[1][1]
    else
      node:raisef("cannot infer array size, use a fixed size")
    end
    if not (valnode and valnode.is_InitList) then
      node:raisef("cannot infer array size in this context")
    end
    length = #valnode
    if length > 0 and valnode[length].is_Varargs then
      local polyeval = context.state.inpolyeval
      if polyeval then
        length = length - 1 + #polyeval.varargsnodes
      end
    end
  end
  local type = types.ArrayType(subtype, length, node)
  type.node = node
  attr.type = primtypes.type
  attr.value = type
  node.done = true
end

function visitors.PointerType(context, node)
  local attr = node.attr
  local subtypenode = node[1]
  if subtypenode then
    context:traverse_node(subtypenode)
    local subtype = subtypenode.attr.value
    if not traits.is_type(subtype) then
      subtypenode:raisef("invalid type")
    end
    if not subtype.is_unpointable then
      attr.value = types.PointerType(subtype)
    else
      node:raisef("subtype '%s' is not addressable thus cannot have a pointer", subtype)
    end
  else
    attr.value = primtypes.pointer
  end
  attr.type = primtypes.type
  node.done = true
end

function visitors.GenericType(context, node)
  local attr = node.attr
  local namenode, argnodes = node[1], node[2]
  assert(namenode.is_Id)
  local name = namenode[1]
  local symbol = context:traverse_node(namenode)
  if not symbol.type or not symbol.type.is_type then
    node:raisef("in generic evaluation: symbol '%s' is not a type", name)
  end
  local generic_type
  if symbol.value then
    generic_type = symbol.value.is_generic and symbol.value or symbol.value.generic
  end
  if not generic_type or not traits.is_type(generic_type) or not generic_type.is_generic then
    node:raisef("in generic evaluation: symbol '%s' of type '%s' cannot generalize", name, symbol.type)
  end
  local params = {n=#argnodes}
  for i=1,#argnodes do
    local argnode = argnodes[i]
    context:traverse_node(argnode)
    local argattr = argnode.attr
    local argtype = argattr.type
    if not argtype then
      node:raisef("in generic evaluation '%s': \z
        argument #%d type is not resolved yet (generics can only be used with typed arguments)", name, i)
    end
    local argvalue = argattr.value
    local argcomptime = argattr.comptime
    local value
    if argtype.is_scalar and argcomptime then -- number
      value = bn.compress(argvalue)
    elseif argtype.is_boolean and argcomptime then -- boolean
      value = argvalue
    elseif argtype.is_string and argcomptime then -- string
      value = argvalue
    elseif argtype.is_niltype then -- nil
      value = argvalue
    elseif argtype.is_type then -- type
      assert(argvalue)
      value = argvalue
    elseif argattr._symbol then -- symbol
      value = argattr
    else -- give up, pass the argument node itself (the user knows what he is doing?)
      value = argnode
    end
    params[i] = value
  end
  local type, err = generic_type:eval_type(params)
  if err then
    if except.isexception(err) then
      except.reraise(err)
    else
      node:raisef('error in generic instantiation: %s', err)
    end
  end
  attr.type = primtypes.type
  attr.value = type
  node.done = true
end

local function iargnodes(argnodes)
  if #argnodes == 0 then return emptynext end
  local i = 0
  local lastargindex = #argnodes
  local lastargnode = argnodes[#argnodes]
  local calleetype = lastargnode and lastargnode.attr.calleetype
  if lastargnode and lastargnode.is_call and calleetype and
    not calleetype.is_type and not calleetype.is_any then
    -- last arg is a runtime call with known return type at compile time
    return function()
      i = i + 1
      if i < lastargindex then
        local argnode = argnodes[i]
        return i, argnode, argnode.attr.type
      else
        -- argnode does not exists, fill with multiple returns type
        local callretindex = i - lastargindex + 1
        local argtype = calleetype:get_return_type(callretindex)
        if not argtype then return nil end
        if callretindex > 1 and not argtype.is_niltype then
          -- mark node as multiple returns for usage later
          lastargnode.attr.usemultirets = true
        end
        return i, nil, argtype, callretindex
      end
    end
  end
  return function()
    i = i + 1
    local argnode = argnodes[i]
    if argnode then
      return i, argnode, argnode.attr.type
    end
  end
end

local izip2 = iters.izip2
local function izipargnodes(vars, argnodes)
  if #vars == 0 and #argnodes == 0 then return emptynext end
  local iter, ts, i = izip2(vars, argnodes)
  local lastargindex = #argnodes
  local lastargnode = argnodes[lastargindex]
  local lastcalleetype = lastargnode and lastargnode.attr.calleetype
  local niltype = primtypes.niltype
  local lastvarnode = vars[#vars]
  local multipleargs = lastvarnode and lastvarnode.type and lastvarnode.type.is_multipleargs
  if lastargnode and lastargnode.is_call and
     (not lastcalleetype or not lastcalleetype.is_type) then
    -- last arg is a runtime call
    return function()
      local previ, var, argnode = i
      i, var, argnode = iter(ts, i)
      if i then
        -- NOTE: the calletype may change while iterating
        local calleetype = argnodes[lastargindex].attr.calleetype
        if calleetype then
          if calleetype.is_type then
            return i, var, argnode, niltype
          elseif not calleetype.is_any then
            -- we know the callee type
            if i < lastargindex then
              return i, var, argnode, argnode.attr.type
            else
              -- argnode does not exists, fill with multiple returns type
              -- in case it doest not exists, the argtype will be nil type
              local callretindex = i - lastargindex + 1
              local argtype = calleetype:get_return_type(callretindex) or niltype
              if callretindex > 1 and not argtype.is_niltype then
                lastargnode.attr.usemultirets = true
              end
              return i, var, argnode, argtype, callretindex
            end
          else
            -- calling any types makes last arguments always a varanys
            local argtype = argnode and argnode.attr.type
            assert(i ~= lastargindex or (argtype and argtype.is_varanys))
            return i, var, argnode, argtype
          end
        else
          -- call type is now known yet, argtype will be nil
          return i, var, argnode, argnode and argnode.attr.type
        end
      elseif multipleargs then
        local calleetype = argnodes[lastargindex].attr.calleetype
        if calleetype and calleetype.is_procedure then
          i = previ + 1
          local callretindex = i - lastargindex + 1
          local argtype = calleetype:get_return_type(callretindex)
          if argtype and not argtype.is_niltype and callretindex > 1 then
            lastargnode.attr.usemultirets = true
            return i, primtypes.varargs, nil, argtype, callretindex
          end
        end
      end
    end
  else
    -- no calls from last argument
    return function()
      local var, argnode
      i, var, argnode = iter(ts, i)
      if i then
        -- in case this is nonexistent, set argtype to nil type
        return i, var, argnode, not argnode and niltype or argnode.attr.type
      end
    end
  end
end

local function visitor_Call_type_cast(context, node, argnodes, type)
  local attr = node.attr
  assert(type)
  if type.is_generic then
    node:raisef("type cast to generic '%s': cannot do type cast on generics", type)
  end
  if #argnodes > 1 then
    node:raisef("type cast to type '%s': expected at most 1 argument, but got %d",
      type, #argnodes)
  end
  local argnode = argnodes[1]
  if argnode then
    context:traverse_node(argnode, {desiredtype=type})
    local argattr = argnode.attr
    local argtype = argattr.type
    if argtype then
      local ok = type:is_convertible_from_attr(argattr, true)
      if not ok then
        -- failed to convert, try to convert metamethods
        argnode, argtype = visitor_convert(context, argnodes, 1, type, argnode, argtype)
        argattr = argnode.attr -- argattr may have changed to a new node
        -- test again
        if argtype then
          local err
          ok, err = type:is_convertible_from_attr(argattr, true)
          if not ok then
            argnode:raisef("in type cast: %s", err)
          end
        end
      end
      if argtype then
        if not argattr:can_copy() then
          argnode:raisef("in type cast: cannot pass non copyable type '%s' by value", argtype)
        end
        if argattr.comptime then
          attr.value = type:wrap_value(argattr.value)
          if attr.value or argtype == type then
            attr.comptime = true
          end
        end
        attr.type = type
        attr.calleetype = primtypes.type
        attr.sideeffect = argattr.sideeffect
        attr.lvalue = argattr.lvalue and type.is_pointer
        if argnode.done then
          node.done = true
        end
      end
    end
  else -- zero initializer
    attr.type = type
    attr.calleetype = primtypes.type
    node.done = true
  end
end

local function visitor_Call(context, node, argnodes, calleetype, calleesym, calleeobjnode)
  local attr = node.attr
  if calleetype then
    local sideeffect
    local origintype = calleetype
    if calleetype.is_record and calleetype.metafields.__call ~= nil then
      calleetype = calleetype.metafields.__call.type
      if not calleetype.is_procedure then
        node:raisef("invalid metamethod __call in '%s'", calleetype)
      end
      attr.ismetacall = true
      calleeobjnode = node[2]
    end
    if calleetype.is_procedure then -- function call
      local argattrs = {}
      for i=1,#argnodes do
        argattrs[i] = argnodes[i].attr
      end
      local calleename = calleesym and calleesym.name or calleetype
      local funcargtypes = calleetype.argtypes
      local funcargattrs = calleetype.argattrs or calleetype.args
      local mulargstype = calleetype:get_multiple_argtype()
      -- TODO: rethink this pseudo args thing
      local pseudoargtypes = tabler.icopy(funcargtypes)
      local pseudoargattrs = tabler.icopy(funcargattrs)
      attr.pseudoargtypes = pseudoargtypes
      attr.pseudoargattrs = pseudoargattrs
      local selftype
      if calleeobjnode then
        attr.ismethod = true
        selftype = funcargtypes[1]
        if not selftype then
          node:raisef("in method call '%s' at argument 'self': the function cannot have arguments", calleename)
        end
        if selftype.is_auto or selftype.is_concept then -- self argument is a concept
          selftype = calleeobjnode.attr.type
        end
        local ok, err = selftype:is_convertible_from_attr(calleeobjnode.attr, nil, true, argattrs)
        if not ok then
          node:raisef("in method call '%s' at argument 'self': %s", calleename, err)
        end
        if not calleeobjnode.attr:can_copy() and calleeobjnode.attr.type == selftype then
          local selfattr = funcargattrs[1]
          if not (selfattr and selfattr.const) then
            calleeobjnode:raisef("in method call '%s' at argument 'self': cannot pass non copyable type '%s'",
              calleename, selftype)
          end
        end
        table.remove(pseudoargtypes, 1)
        table.remove(pseudoargattrs, 1)
      end
      if not mulargstype and #argnodes > #pseudoargattrs then
        if not (#argnodes == #pseudoargattrs+1 and argnodes[#argnodes].is_Varargs) then
          node:raisef("in call of function '%s': expected at most %d arguments but got %d",
            calleename, #pseudoargattrs, #argnodes)
        end
      end
      local polyargs = {}
      local knownallargs = true
      for i,funcarg,argnode,argtype,lastcallindex in izipargnodes(pseudoargattrs, argnodes) do
        local arg
        local funcargtype
        if traits.is_type(funcarg) then funcargtype = funcarg
        elseif funcarg then
          funcargtype = funcarg.type
        end
        if argnode then
          local desiredtype = funcargtype
          if desiredtype then
            if desiredtype.is_concept then
              desiredtype = desiredtype:get_desired_type_from_node(argnode)
            elseif desiredtype.is_auto then
              desiredtype = nil
            end
          end
          context:traverse_node(argnode, {desiredtype=desiredtype})
          if not argnodes[i] and (not funcargtype or funcargtype.is_varargs) then
            break -- varargs unpacked 0 arguments
          end
          argtype = argnode.attr.type
          argnode, argtype = visitor_convert(context, argnodes, i, funcargtype, argnode, argtype, argattrs, true)
          if argtype then
            arg = argnode.attr
          end
        else
          if (funcargtype.is_cvarargs or funcargtype.is_varargs) and
            (not (argtype and funcargtype.is_varargs and lastcallindex and lastcallindex > 1) or
            (argtype and argtype.is_niltype)) then
            break
          end
          arg = argtype
        end
        if mulargstype then
          if not funcargtype or funcargtype.is_multipleargs then
            if mulargstype.is_cvarargs and argtype then
              if argtype.is_string then -- we actually want a cstring
                argtype = primtypes.cstring
              elseif argtype.is_record then
                node:raisef("in call of function '%s' at argument %d: invalid type '%s' for 'cvarargs'",
                  calleename, i, argtype)
              end
            end
            funcargtype = argtype
            if funcargtype then
              pseudoargtypes[i] = funcargtype
              pseudoargattrs[i] = Attr{type = funcargtype}
            end
          end
        elseif not funcargtype then
          break
        end
        if argtype and argnode and argtype.is_niltype and not funcargtype.is_nilable then
          node:raisef("in call of function '%s': expected an argument at index %d but got nil",
            calleename, i)
        end
        if arg then
          local argattr = arg
          if traits.is_type(arg) then
            argattr = Attr{type=arg}
          end
          local wantedtype, err = funcargtype:get_convertible_from_attr(argattr, false, true, argattrs)
          if not wantedtype then
            node:raisef("in call of function '%s' at argument %d: %s",
              calleename, i, err)
          end

          if funcargtype ~= wantedtype and argnode then
            -- new type suggested, need to traverse again
            context:traverse_node(argnode, {desiredtype=wantedtype})
          end
          funcargtype = wantedtype

          -- check again the new type
          wantedtype, err = funcargtype:get_convertible_from_attr(argattr, false, true, argattrs)
          if not wantedtype then
            node:raisef("in call of function '%s' at argument %d: %s",
              calleename, i, err)
          end

          if not wantedtype.is_pointer and not argattr:can_copy() then
            argnode:raisef("in call of function '%s' at argument %d: cannot pass non copyable type '%s' by value",
              calleename, i, argtype)
          end
        else
          knownallargs = false
        end

        if knownallargs and calleetype.is_polyfunction then
          local funcargcomptime = funcarg and funcarg.comptime
          if funcargcomptime and
            not funcarg.type.is_auto and not funcarg.type.is_overload and
            (not arg or arg.value == nil) then
            node:raisef("in call of function '%s': expected a compile time argument at index %d",
              calleename, i)
          end
          if funcargtype.is_polymorphic or funcargcomptime then
            polyargs[i] = arg
            if arg._attr then
              pseudoargtypes[i] = arg.type
              pseudoargattrs[i] = arg
            else
              assert(arg._type)
              pseudoargtypes[i] = arg
              pseudoargattrs[i] = Attr{type = arg}
            end
          else
            polyargs[i] = funcargtype
            pseudoargtypes[i] = funcargtype
            pseudoargattrs[i] = Attr{type = funcargtype}
          end
        end

        if calleeobjnode and argtype and pseudoargtypes[i].is_polymorphic then
          pseudoargtypes[i] = argtype
        end
      end
      if selftype then
        table.insert(polyargs, 1, selftype)
      end
      if calleetype.is_polyfunction then
        local polycalleetype = calleetype
        calleetype = nil
        calleesym = nil
        if knownallargs then
          local polyeval = attr.polyeval
          if not polyeval then
            polyeval = polycalleetype:eval_poly(polyargs, node)
            attr.polyeval = polyeval
          end
          if polyeval and polyeval.node and polyeval.node.attr.type then
            calleesym = polyeval.node.attr
            calleetype = polyeval.node.attr.type
          elseif context.state.inpolyeval ~= polyeval then
            -- must traverse the poly function scope again to infer types for assignment to this call
            context.scope:find_shared_up_scope(polycalleetype.node.attr.scope):delay_resolution()
          end
        end
      end
      if attr.ismetacall then
        attr.calleesym = calleetype.symbol
      else
        attr.calleesym = calleesym
      end
      if calleetype then
        attr.type, attr.value = calleetype:get_return_type_and_value(1)
        sideeffect = calleetype.sideeffect
        if calleetype.symbol then
          calleetype.symbol:add_use_by(context.state.funcscope.funcsym)
        end
      end
    elseif calleetype.is_table then -- table call (allowed for tables with metamethod __index)
      context:traverse_nodes(argnodes)
      sideeffect = true
      attr.type = primtypes.varanys
    elseif calleetype.is_any then -- call on any values
      context:traverse_nodes(argnodes)
      sideeffect = true
      attr.type = primtypes.varanys
    else
      -- call on invalid types (i.e: numbers)
      node:raisef("cannot call type '%s'", calleetype)
    end
    if sideeffect then
      attr.sideeffect = true
      context:mark_funcscope_sideeffect()
    end
    attr.calleetype = calleetype
  else
    context:traverse_nodes(argnodes)
  end
end

function visitors.Call(context, node, opts)
  local attr = node.attr
  local argnodes, calleenode = node[1], node[2]

  context:traverse_node(calleenode)

  local calleeattr = calleenode.attr
  local calleetype = calleeattr.type
  local calleesym = calleeattr._symbol and calleeattr
  if calleesym and calleesym.comptime and calleesym.value then -- handle comptime function argument
    calleesym = calleesym.value
  end

  if calleetype and calleetype.is_type then
    visitor_Call_type_cast(context, node, argnodes, calleeattr.value)
  else
    if calleeattr.builtin then
      local builtinfunc = builtins[calleeattr.name]
      if builtinfunc then
        local builtintype = attr.builtintype
        if builtintype and builtinfunc ~= builtins.require then
          -- cache type if not require builtin
          calleetype = builtintype
        else
          builtintype = builtinfunc(context, node, argnodes, calleenode)
          assert(builtintype ~= nil or calleetype)
          if builtintype then
            attr.builtintype = builtintype
            calleetype = builtintype
          elseif builtintype == false then -- wait resolution
            context:traverse_nodes(argnodes)
            return
          end
        end
      end
    end

    visitor_Call(context, node, argnodes, calleetype, calleesym)

    if calleeattr.cimport then
      local desiredtype = opts and opts.desiredtype
      local type = attr.type
      if desiredtype and type and desiredtype.is_boolean and not type.is_falseable then
        node:raisef("call expression will always be true, maybe you want to do a comparison?")
      end
    end

    if attr.calleetype and not attr.requirename and calleenode.done and tabler.iallfield(argnodes, 'done') then
      node.done = true
    end
  end
end

function visitors.CallMethod(context, node)
  local name, argnodes, calleeobjnode = node[1], node[2], node[3]
  local attr = node.attr

  context:traverse_nodes(argnodes)
  context:traverse_node(calleeobjnode)

  local calleeobjattr = calleeobjnode.attr
  local calleetype = calleeobjattr.type
  local calleesym = nil
  if calleeobjattr.builtin then
    node:raisef("cannot call method '%s' on builtin '%s'", name, calleeobjattr.name)
  end
  if calleetype then
    if calleetype.is_pointer then
      calleetype = calleetype.subtype
    end

    if calleetype.metafields then
      local field = calleetype.fields and calleetype.fields[name]
      if field then
        calleetype = field.type
      else
        calleesym = calleetype.metafields[name]
        if not calleesym then
          if calleetype.is_string and not calleetype.metafields.sub then
            node:raisef("cannot index meta field '%s' for type '%s', \z
              maybe you forgot to require module 'string'?", name, calleetype)
          else
            node:raisef("cannot index meta field '%s' for type '%s'", name, calleetype)
          end
        end
        if calleesym.deprecated then
          node:warnf("use of deprecated method '%s'", name)
        end
        calleetype = calleesym.type
      end
    elseif calleetype.is_any then
      calleetype = primtypes.any
    elseif calleetype.is_type then
      node:raisef("cannot call method '%s' on type symbol for '%s'", name, calleeobjattr.value)
    end

    if calleetype and calleetype.is_procedure then
      -- convert callee object if needed
      local calleeobjtype = calleeobjnode.attr.type
      local selftype = calleetype.argtypes[1]
      calleeobjnode = visitor_convert(context, node, 3, selftype, calleeobjnode, calleeobjtype)
    end
  end

  visitor_Call(context, node, argnodes, calleetype, calleesym, calleeobjnode)

  if attr.calleetype and calleeobjnode.done and tabler.iallfield(argnodes, 'done') then
    node.done = true
  end
end

local function visitor_Composite_FieldIndex(_, node, objtype, name)
  local attr = node.attr
  local field = objtype.fields[name]
  local type = field and field.type
  if not type then
    node:raisef("cannot index field '%s' on value of type '%s'", name, objtype)
  end
  attr.dotfieldname = field.name
  attr.type = type
end

local function visitor_Type_MetaFieldIndex(context, node, objtype, name)
  local attr = node.attr
  local symbol = objtype.metafields and objtype.metafields[name]
  local parentnode = context:get_visiting_node(1)
  local infuncdef = (context.state.infuncdef == parentnode) and parentnode
  local infielddecl = (context.state.infielddecl == parentnode) and parentnode
  local inpolydef = context.state.inpolydef and symbol == context.state.inpolydef
  if inpolydef then
    symbol = attr._symbol and attr or nil
  end
  if not symbol then
    local symname = string.format('%s.%s', objtype.nickname or objtype.name, name)
    symbol = Symbol.promote_attr(attr, node, symname)
    symbol.codename = context:choose_codename(string.format('%s_%s', objtype.codename, name))
    if infuncdef then
      symbol:link_node(infuncdef)
      -- declaration of record global function
      symbol.metafunc = true
      symbol.staticstorage = true
      if node.is_ColonIndex then
        symbol.metafuncselftype = types.PointerType(objtype)
      end
    elseif infielddecl then -- meta field declaration
      symbol:link_node(infielddecl)
      -- declaration of record meta field variable
      symbol.metafield = true
    else
      symbol:link_node(node)
      if objtype.is_string and objtype.metafields and not objtype.metafields.sub then
        node:raisef("cannot index meta field '%s' in record '%s', \z
          maybe you forgot to require module 'string'?", name, objtype)
      else
        node:raisef("cannot index meta field '%s' in record '%s'", name, objtype)
      end
    end
    if not inpolydef then
      objtype:set_metafield(name, symbol)
    end
    symbol.anonymous = true
    symbol.scope = context.rootscope
  elseif (infuncdef or infielddecl) and not symbol.forwarddecl then
    if symbol.node ~= node then
      node:raisef("cannot redefine meta type field '%s' in record '%s'", name, objtype)
    end
  else
    symbol:link_node(node)
  end
  if symbol.deprecated then
    node:warnf("use of deprecated metafield '%s'", name)
  end
  if not infuncdef then
    symbol:add_use_by(context.state.funcscope.funcsym)
  end
  return symbol
end

local function visitor_EnumType_FieldIndex(context, node, objtype, name)
  local attr = node.attr
  local field = objtype.fields[name]
  if not field then
    local metafield = objtype.metafields and objtype.metafields[name]
    if not metafield then
      node:raisef("cannot index field '%s' on enum '%s'", name, objtype)
    end
    return visitor_Type_MetaFieldIndex(context, node, objtype, name)
  end
  attr.dotfieldname = field.name
  attr.comptime = true
  attr.value = field.value
  attr.type = objtype
end

local function visitor_Type_FieldIndex(context, node, objtype, name)
  objtype = objtype:implicit_deref_type()
  if objtype.is_enum and not (context.state.infuncdef or context.state.infielddecl) then
    return visitor_EnumType_FieldIndex(context, node, objtype, name)
  else
    return visitor_Type_MetaFieldIndex(context, node, objtype, name)
  end
end

local function visitor_FieldIndex(context, node)
  local name, objnode = node[1], node[2]
  context:traverse_node(objnode)
  local objattr = objnode.attr
  local objtype = objattr.type
  local attr = node.attr
  local ret
  if objtype then
    objtype = objtype:implicit_deref_type()
    if objtype.is_composite then
      ret = visitor_Composite_FieldIndex(context, node, objtype, name)
    elseif objtype.is_type then
      ret = visitor_Type_FieldIndex(context, node, objattr.value, name)
    elseif objtype.is_table or objtype.is_any then
      attr.type = primtypes.any
    else
      node:raisef("cannot index field '%s' on type '%s'", name, objtype.name)
    end
    if objnode.done then
      node.done = ret or true
    end
  end
  if objattr.lvalue or (objtype and objtype.is_pointer) then
    attr.lvalue = true
  end
  if objattr.const then
    attr.const = true
  end
  return ret
end

visitors.DotIndex = visitor_FieldIndex
visitors.ColonIndex = visitor_FieldIndex

local function visitor_Array_KeyIndex(_, node, objtype, _, indexnode)
  local attr = node.attr
  local indexattr = indexnode.attr
  local indextype = indexattr.type
  if indextype then
    if indextype.is_integral then
      local indexvalue = indexattr.value
      if indexvalue then
        if bn.isneg(indexvalue) then
          indexnode:raisef("cannot index negative value %s", indexvalue)
        end
        if objtype.length ~= 0 and indexvalue >= bn.new(objtype.length) then
          indexnode:raisef("index %s is out of bounds, array maximum index is %d",
            indexvalue:todecint(), objtype.length - 1)
        end
      end
      attr.type = objtype.subtype
    else
      indexnode:raisef("cannot index with value of type '%s'", indextype)
    end
  end
end

local function visitor_Type_MetaKeyIndex(context, node, objtype, objnode, indexnode)
  local newnode
  local metafields = objtype.metafields
  if metafields.__index then
    newnode = aster.CallMethod{'__index', {indexnode}, objnode}
  elseif metafields.__atindex then
    newnode = aster.UnaryOp{'deref', aster.CallMethod{'__atindex', {indexnode}, objnode}}
  else
    node:raisef("cannot index record of type '%s': no `__index` or `__atindex` metamethod found", objtype)
  end
  context:transform_and_traverse_node(node, newnode)
end

function visitors.KeyIndex(context, node)
  local indexnode, objnode = node[1], node[2]
  context:traverse_node(indexnode)
  context:traverse_node(objnode)
  local attr = node.attr
  if attr.type then
    if indexnode.done and objnode.done then node.done = true end
    return
  end
  if node.checked then return end
  local objattr = objnode.attr
  local objtype = objattr.type
  if objtype then
    objtype = objtype:implicit_deref_type()
    if objtype.is_array then
      visitor_Array_KeyIndex(context, node, objtype, objnode, indexnode)
    elseif objtype.metafields then
      visitor_Type_MetaKeyIndex(context, node, objtype, objnode, indexnode)
    elseif objtype.is_table or objtype.is_any then
      attr.type = primtypes.any
    else
      node:raisef("cannot index variable of type '%s'", objtype.name)
    end
  end
  if objattr.lvalue or (objtype and objtype.is_pointer) then
    attr.lvalue = true
  end
  if objattr.const then
    attr.const = true
  end
  if attr.type then
    node.checked = true
    if indexnode.done and objnode.done then
      node.done = true
    end
  end
end

function visitors.Block(context, node)
  if node.preprocess then
    local scope = context:push_forked_cleaned_scope(node)
    scope.is_block = true

    local polyeval = context.state.inpolyeval
    local ok, err
    if polyeval and polyeval.varargsnodes then
      ok, err = except.trycall(node.preprocess, node, table.unpack(polyeval.varargsnodes))
    else
      ok, err = except.trycall(node.preprocess, node)
    end
    if not ok then
      if except.isexception(err) then
        except.reraise(err)
      else
        node:raisef('error while preprocessing block: %s', context.ppcontext:translate_error(err))
      end
    end
    node.preprocess = nil
    node.preprocessed = true

    local resolutions_count = scope:resolve()
    context:pop_scope()
    if resolutions_count == 0 then
      return
    end
  end

  local statnodes = node

  if #statnodes > 0 or not node.scope then
    local scope
    repeat
      scope = context:push_forked_cleaned_scope(node)
      scope.is_block = true
      context:traverse_nodes(statnodes)
      local resolutions_count = scope:resolve()
      context:pop_scope()
    until resolutions_count == 0
  end

  -- preprocessed blocks can never be done
  -- because new statements may be injected at anytime
  -- TODO: improve this later
  if not node.preprocessed then
    local done = true
    for i=1,#statnodes do
      local statnode = statnodes[i]
      if not (statnode.done or statnode.is_Directive) then
        done = nil
        break
      end
    end
    if done then
      node.done = true
    end
  end
end

function visitors.If(context, node)
  local ifpairs, elsenode = node[1], node[2]
  local done = true
  for i=1,#ifpairs,2 do
    local ifcondnode, ifblocknode = ifpairs[i], ifpairs[i+1]
    context:traverse_node(ifcondnode, {desiredtype=primtypes.boolean})
    context:traverse_node(ifblocknode)
    done = done and ifblocknode.done and ifcondnode.done
  end
  if elsenode then
    context:traverse_node(elsenode)
    done = done and elsenode.done and true
  end
  node.done = done
end

function visitors.Switch(context, node)
  local valnode, casepairs, elsenode = node[1], node[2], node[3]
  context:traverse_node(valnode)
  local scope = context:push_forked_cleaned_scope(node)
  scope.is_switch = true
  local valtype = valnode.attr.type
  if valtype and not (valtype.is_any or valtype.is_integral) then
    valnode:raisef(
      "`switch` statement must be convertible to an integral type, but got type `%s` (non integral)",
      valtype)
  end
  local done = valnode.done
  for i=1,#casepairs,2 do
    local caseexprs, caseblock = casepairs[i], casepairs[i+1]
    for j=1,#caseexprs do
      local casenode = caseexprs[j]
      context:traverse_node(casenode)
      if not (casenode.attr.type and casenode.attr.type.is_integral and
             (casenode.attr.comptime or casenode.attr.cimport)) then
        casenode:raisef("`case` statement must evaluate to a compile time integral value")
      end
      done = done and casenode.done and true
    end
    done = done and caseblock.done and true
    local casescope = context:get_forked_scope(caseblock)
    casescope.switchcase_index = 1
    context:traverse_node(caseblock)
    if casescope.fallthrough and casescope.fallthrough ~= caseblock[#caseblock] then
      casescope.fallthrough:raisef("`fallthrough` statement must be the very last statement of a switch case block")
    end
  end
  if elsenode then
    context:traverse_node(elsenode)
    done = done and elsenode.node and true
  end
  context:pop_scope()
  node.done = done
end

function visitors.Defer(context, node)
  local blocknode = node[1]
  context:traverse_node(blocknode)
  -- mark `has_defer`, used to check mixing with `goto`
  context.scope.has_defer = true
  blocknode.scope.has_defer = true
  node.done = blocknode.done
end

function visitors.While(context, node)
  local condnode, blocknode = node[1], node[2]
  context:traverse_node(condnode, {desiredtype=primtypes.boolean})
  local scope = context:push_forked_cleaned_scope(node)
  scope.is_loop = true
  context:traverse_node(blocknode)
  context:pop_scope()
  node.done = blocknode.done and condnode.done and true
end

function visitors.Repeat(context, node)
  local blocknode, condnode = node[1], node[2]
  local scope = context:push_forked_cleaned_scope(node)
  scope.is_loop = true
  scope.is_repeat_loop = true
  context:traverse_node(blocknode)
  context:push_scope(blocknode.scope)
  context:traverse_node(condnode, {desiredtype=primtypes.boolean})
  context:pop_scope()
  context:pop_scope()
  node.done = blocknode.done and condnode.done and true
end

function visitors.ForNum(context, node)
  local itvarnode, begvalnode, compop, endvalnode, stepvalnode, blocknode =
        node[1], node[2], node[3], node[4], node[5], node[6]
  local itname = itvarnode[1]
  context:traverse_node(begvalnode)
  context:traverse_node(endvalnode)
  local battr, eattr = begvalnode.attr, endvalnode.attr
  local btype, etype = battr.type, eattr.type
  local sattr, stype
  if stepvalnode then
    context:traverse_node(stepvalnode)
    sattr = stepvalnode.attr
    stype = sattr.type
  end
  local ittype
  repeat
    local scope = context:push_forked_cleaned_scope(node)
    scope.is_loop = true

    local itsymbol = context:traverse_node(itvarnode)
    itsymbol.scope:add_symbol(itsymbol)
    ittype = itsymbol.type
    if not ittype then
      itsymbol:add_possible_type(btype, begvalnode)
      itsymbol:add_possible_type(etype, endvalnode)
      if btype and etype then
        itsymbol:resolve_type()
        ittype = itsymbol.type
      end
    end
    if ittype and not node.checked then
      if not (ittype.is_scalar or (ittype.is_any and not ittype.is_varanys)) then
        itvarnode:raisef("`for` variable '%s' must be a number, but got type '%s'", itname, ittype)
      end
      if btype then
        if btype.is_comptime then
          begvalnode:raisef("in `for` variable '%s' begin: cannot be of type '%s'", itname, btype)
        end
        local ok, err = ittype:is_convertible_from_attr(battr)
        if not ok then
          begvalnode:raisef("in `for` variable '%s' begin: %s", itname, err)
        end
      end
      if etype then
        if etype.is_comptime then
          endvalnode:raisef("in `for` variable '%s' end: cannot be of type '%s'", itname, etype)
        end
        local ok, err = ittype:is_convertible_from_attr(eattr)
        if not ok then
          endvalnode:raisef("in `for` variable '%s' end: %s", itname, err)
        end
      end
      if stype then
        if stype.is_comptime then
          stepvalnode:raisef("in `for` variable '%s' step: cannot be of type '%s'", itname, etype)
        end
        local _, _, err = ittype:binary_operator('add', stype, itsymbol, sattr)
        if stype.is_float and ittype.is_integral then
          err = 'cannot have fractional step for an integral iterator'
        end
        if err then
          stepvalnode:raisef("in `for` variable '%s' step: %s", itname, err)
        end
      end
    end
    context:traverse_node(blocknode)

    local resolutions_count = scope:resolve()
    context:pop_scope()
  until resolutions_count == 0

  node.done = ittype and blocknode.done and begvalnode.done and endvalnode.done and
              (not stepvalnode or stepvalnode.done) and true

  -- early return
  if node.checked then return end

  local fixedstep
  local stepvalue
  if stype and stype.is_scalar and (sattr.comptime or (sattr.const and stype == ittype)) then
    -- constant step
    fixedstep = stepvalnode
    stepvalue = sattr.value
    if stepvalue and bn.iszero(stepvalue) then
      stepvalnode:raisef("`for` step cannot be zero")
    end
  elseif not stepvalnode then
    -- default step is '1'
    stepvalue = bn.one()
    fixedstep = '1'
  end
  local fixedend
  if etype and etype.is_scalar and (eattr.comptime or (eattr.const and etype == ittype)) then
    fixedend = true
  end
  if not compop and stepvalue then
    -- we now that the step is a constant numeric value
    -- compare operation must be `ge` ('>=') when step is negative
    compop = bn.isneg(stepvalue) and 'ge' or 'le'
  end
  local attr = node.attr
  attr.fixedstep = fixedstep
  attr.fixedend = fixedend
  attr.compop = compop

  if ittype and btype and etype and (not stepvalnode or stype) then
    node.checked = true
  end
end

function visitors.ForIn(context, node)
  local itvarnodes, inexpnodes, blocknode = node[1], node[2], node[3]
  if #inexpnodes > 4 then
    node:raisef("`in` statement can have at most 4 arguments")
  end

  if context.generator == 'lua' then -- lua backend
    context:traverse_nodes(inexpnodes)
    repeat
      local scope = context:push_forked_cleaned_scope(node)
      scope.is_loop = true
      context:traverse_node(blocknode)
      local resolutions_count = scope:resolve()
      context:pop_scope()
    until resolutions_count == 0
  else -- on other backends must implement using while loops
    -- replace the for in node with a while loop
    local newnode = aster.Do{aster.Block{
      aster.VarDecl{'local', {
          aster.IdDecl{'__fornext'},
          aster.IdDecl{'__forstate'},
          aster.IdDecl{'__fornextit'},
          aster.IdDecl{'__forclose', false, {aster.Annotation{'close'}}},
        },
        inexpnodes
      },
      aster.While{aster.Boolean{true}, aster.Block{
        aster.VarDecl{'local', tabler.insertvalues({
          aster.IdDecl{'__forcont'},
        }, itvarnodes), {
            aster.Call{{aster.Id{'__forstate'}, aster.Id{'__fornextit'}}, aster.Id{'__fornext'}}
          }
        },
        aster.If{{aster.UnaryOp{'not', aster.Id{'__forcont'}}, aster.Block{
          aster.Break{}
        }}},
        aster.Assign{{aster.Id{'__fornextit'}}, {aster.Id{itvarnodes[1][1]}}},
        aster.Do{blocknode}
      }}
    }}
    context:transform_and_traverse_node(node, newnode)
  end
end

function visitors.Break(context, node)
  if not context.scope:get_up_scope_of_kind('is_loop') then
    node:raisef("`break` statement is not inside a loop")
  end
  node.done = true
end

function visitors.Continue(context, node)
  if not context.scope:get_up_scope_of_kind('is_loop') then
    node:raisef("`continue` statement is not inside a loop")
  end
  node.done = true
end

function visitors.Fallthrough(context, node)
  local scope = context.scope
  local switchcase_index = scope.switchcase_index
  if not switchcase_index then
    node:raisef("`fallthrough` statement must be inside a switch case black")
  end
  local switchnode = context:get_visiting_node(2)
  assert(switchnode.is_Switch)
  local casepairs, elsenode = switchnode[2], switchnode[3]
  if not (casepairs[switchcase_index+2] or elsenode) then
    node:raisef("`fallthrough` statement must be followed by another switch block")
  end
  if scope.fallthrough and scope.fallthrough ~= node then
    node:raisef("`fallthrough` statement must be used at most once per switch case block")
  end
  scope.fallthrough = node
  node.done = true
end

function visitors.NoOp(_, node)
  node.done = true
end

function visitors.Label(context, node)
  local labelname = node[1]
  local label = context.scope:find_label(labelname)
  if not label then
    label = node.attr
    label.name = labelname
    label.scope = context.scope
    label.codename = context:choose_codename(labelname)
    label.node = node
    context.scope:add_label(label)
  elseif label ~= node.attr then
    node:raisef("label '%s' already defined", labelname)
  end
  node.done = true
end

function visitors.Goto(context, node)
  local labelname = node[1]
  local label, labelscope = context.scope:find_label(labelname)
  if not label then
    local funcscope = context.scope:get_up_function_scope() or context.rootscope
    if not funcscope.resolved_once then
      -- we should find it in the next traversal
      funcscope:delay_resolution(true)
      return
    end
    node:raisef("no visible label '%s' found for `goto`", labelname)
  end
  -- `goto` changes the control flow and cannot be used with defer statement
  for scope in context.scope:iterate_up_scopes() do
    if scope.has_defer then
      node:raisef("cannot mix `goto` and `defer` statements")
    end
    if scope == labelscope then
      break
    end
  end
  label.used = true
  node.attr.label = label
  node.done = true
end

local function visit_close(context, declnode, varnode, symbol)
  local objtype = varnode.attr.type
  if not objtype then return end
  if objtype.is_niltype then return end
  objtype = objtype:implicit_deref_type()
  if not objtype.metafields or not objtype.metafields.__close then
    varnode:raisef(
      "in variable '%s' declaration: cannot close because type '%s' does not have '__close' metamethod",
      symbol.name, objtype)
  end
  if symbol.closed then return end
  -- create a defer call to __close method
  local idnode
  if traits.is_string(varnode[1]) then
    idnode = aster.Id{varnode[1]}
  else
    idnode = varnode[1]:clone()
  end
  local callnode = aster.Defer{aster.Block{aster.CallMethod{'__close', {}, idnode}}}
  -- inject defer call after variable declaration
  local blocknode = context:get_visiting_node(1) -- get parent block node
  assert(blocknode.is_Block)
  local statindex = tabler.ifind(blocknode, declnode) -- find this node index
  assert(statindex)
  local declattr = declnode.attr
  local closeindex = (declattr.closeindex or statindex) + 1
  table.insert(blocknode, closeindex, callnode) -- insert the new statement
  declattr.closeindex = closeindex
  blocknode.scope:delay_resolution() -- must delay resolution
  symbol.closed = true
end

function visitors.VarDecl(context, node)
  local declscope, varnodes, valnodes = node[1], node[2], node[3]
  local assigning = not not valnodes
  local last_call_node
  if assigning then
    local last_node = valnodes[#valnodes]
    if last_node.is_call then
      last_call_node = last_node
    end
  end
  valnodes = valnodes or {}
  if #varnodes < #valnodes then
    node:raisef("extra expressions in declaration, expected at most %d but got %d",
    #varnodes, #valnodes)
  end
  local done = true
  for i,varnode,valnode,valtype in izipargnodes(varnodes, valnodes) do
    varnode.attr.vardecl = true
    if declscope == 'global' then
      if not context.scope.is_topscope then
        varnode:raisef("global variables can only be declared in top scope")
      end
      varnode.attr.global = true
    end
    if declscope == 'global' or context.scope.is_topscope then
      varnode.attr.staticstorage = true
    end
    local symbol = context:traverse_node(varnode)
    assert(symbol)
    local inscope = false
    if valnode and valnode.is_Type then
      symbol.scope:add_symbol(symbol)
      inscope = true
    end
    local vartype = varnode.attr.type
    if vartype then
      if not vartype:is_defined() then
        varnode:raisef("cannot be of forward declared type '%s'", vartype)
      end
      if vartype.is_nolvalue then
        varnode:raisef("variable declaration cannot be of the type '%s'", vartype)
      end
    end
    assert(symbol.type == vartype)
    if valnode then
      context:traverse_node(valnode, {symbol=symbol, desiredtype=vartype})
      valtype = valnode.attr.type
      valnode, valtype = visitor_convert(context, valnodes, i, vartype, valnode, valtype)

      if valtype then
        if valtype.is_varanys then
          -- varanys are always stored as any in variables
          valtype = primtypes.any
        elseif valtype.is_void then
          valtype = primtypes.niltype
        end
      end
      if varnode.attr.comptime then
        if not (valnode.attr.comptime and valtype) then
          varnode:raisef("compile time variables can only assign to compile time expressions")
        elseif (valnode.attr.value == nil and valnode.attr.type ~= primtypes.niltype) then
          varnode:raisef("compile time variables cannot be of type '%s'", vartype)
        end
      end
      if vartype and vartype.is_auto then
        if not valtype then
          varnode:raisef("auto variables must be assigned to expressions where type is known ahead")
        elseif valtype.is_nolvalue then
          varnode:raisef("auto variables cannot be assigned to expressions of type %s", valtype)
        end
      elseif varnode.attr.cimport and not
        (vartype == primtypes.type or (vartype == nil and valtype == primtypes.type)) then
        varnode:raisef("cannot assign imported variables, only imported types can be assigned")
      elseif vartype == primtypes.type and valtype ~= primtypes.type then
        valnode:raisef("cannot assign a type to '%s'", valtype)
      end
    else
      if i > 1 and (valtype and valtype.is_type) then
        varnode:raisef("a type declaration can only assign to the first assignment expression")
      end
      if vartype and vartype.is_type then
        varnode:raisef("a type declaration must assign to a type")
      end
      if (varnode.attr.comptime or varnode.attr.const) and not varnode.attr.nodecl then
        varnode:raisef("const variables must have an initial value")
      end
    end
    if not inscope then
      symbol.scope:add_symbol(symbol)
    end
    if assigning and valtype then
      local assignvaltype = false
      if varnode.attr.comptime then
        -- for comptimes the type must be known ahead
        assert(valnode)
        assignvaltype = not vartype
        symbol.value = valnode.attr.value
      elseif valtype.is_type then
        -- for 'type' types the type must also be known ahead
        assert(valnode and valnode.attr.value)
        assignvaltype = vartype ~= valtype
        symbol.value = valnode.attr.value
        context:choose_type_symbol_names(symbol)
      end

      if vartype and (vartype.is_auto or vartype.is_type) then
        assignvaltype = true
      end

      if assignvaltype then
        vartype = valtype
        symbol.type = vartype

        local annotnode = varnode[3]
        if annotnode then
          -- must traverse again annotation node early once type is found ahead
          context:traverse_nodes(annotnode, {symbol=symbol})
        end
      end
      if vartype then
        local ok, err = vartype:is_convertible_from(valnode or valtype)
        if not ok then
          varnode:raisef("in variable '%s' declaration: %s", symbol.name, err)
        end
        if valnode and not valnode.attr:can_copy() then
          valnode:raisef("cannot assign non copyable type '%s'", valtype)
        end
        if vartype.is_polyfunction then
          -- skip declaration for poly function aliases
          varnode.attr.nodecl = true
        end
      end
    end
    if assigning and (valtype or valnode or last_call_node) then
      symbol:add_possible_type(valtype, valnode or last_call_node)
    end
    if symbol.close then -- process close annotation
      visit_close(context, node, varnode, symbol)
    end
    done = done and varnode.done
    if valnode then
      done = done and valnode.done
    end
  end
  node.done = done
end

function visitors.Assign(context, node)
  local varnodes, valnodes = node[1], node[2]
  if #varnodes < #valnodes then
    node:raisef("extra expressions in assign, expected at most %d but got %d", #varnodes, #valnodes)
  end
  local last_call_node
  local last_node = valnodes[#valnodes]
  if last_node.is_call then
    last_call_node = last_node
  end
  local done = true
  for i,varnode,valnode,valtype in izipargnodes(varnodes, valnodes) do
    local symbol = context:traverse_node(varnode)
    local vartype = varnode.attr.type
    local varattr = varnode.attr
    if varattr:is_readonly() and not varattr:is_forward_declare_type() then
      varnode:raisef("cannot assign a constant variable")
    end
    if valnode then
      context:traverse_node(valnode, {symbol=symbol, desiredtype=vartype})
      valtype = valnode.attr.type
      valnode, valtype = visitor_convert(context, valnodes, i, vartype, valnode, valtype)
    end
    if valtype then
      if valnode and not valnode.attr:can_copy() then
        valnode:raisef("cannot assign non copyable type '%s'", valtype)
      end
      if valtype and valtype.is_varanys then
        -- varanys are always stored as any in variables
        valtype = primtypes.any
      end
    end
    if symbol then -- symbol may nil in case of array/dot index
      if valtype or valnode or last_call_node then
        symbol:add_possible_type(valtype, valnode or last_call_node)
      end
      symbol.mutate = true

      if symbol.staticstorage then -- assign of an external variable trigger side effects
        context:mark_funcscope_sideeffect()
      end
    end
    if not valnode and valtype and valtype.is_niltype then
      varnode:raisef("variable assignment at index '%d' is assigning to nothing in the expression", i)
    end
    if vartype and valtype then
      local ok, err = vartype:is_convertible_from(valnode or valtype)
      if not ok then
        varnode:raisef("in variable assignment: %s", err)
      end
    end
    done = done and vartype and varnode.done and (not valnode or valnode.done) and true
  end
  node.done = done
end

function visitors.Return(context, node)
  local retnodes = node
  local funcscope = context.scope:get_up_function_scope() or context.rootscope
  funcscope.hasreturn = true
  if funcscope.rettypes then
    local done = true
    for i,funcrettype,retnode,rettype in izipargnodes(funcscope.rettypes, retnodes) do
      if retnode then
        local desiredtype = funcrettype and not funcrettype.is_auto and funcrettype
        context:traverse_node(retnode, {desiredtype=desiredtype})
        rettype = retnode.attr.type
      end
      if rettype then
        if funcrettype then
          if funcrettype.is_auto then
            funcscope.rettypes[i] = rettype
          else
            if retnode and rettype then
              retnode, rettype = visitor_convert(context, retnodes, i, funcrettype, retnode, rettype)
            end
            if retnode and rettype then
              local ok, err = funcrettype:is_convertible_from(retnode or rettype)
              if not ok then
                (retnode or node):raisef("return at index %d: %s", i, err)
              end
              local retattr = retnode and retnode.attr
              if retattr and not retattr:can_copy() and
                 not (retattr.scope and retattr.scope:get_up_function_scope() == funcscope) then
                retnode:raisef("return at index %d: cannot pass non copyable type '%s' by value",
                  i, rettype)
              end
            end
          end
        elseif #retnodes ~= 0 then
          node:raisef("invalid return expression at index %d", i)
        end
      end
      if retnode then
        if rettype and rettype.is_type then
          funcscope:add_return_value(i, retnode.attr.value)
        end
        done = done and retnode.done and true
      end
    end
    node.done = done
  else
    context:traverse_nodes(retnodes)
    for i,retnode,rettype in iargnodes(retnodes) do
      funcscope:add_return_type(i, rettype, retnode)
      if rettype and retnode and rettype.is_type then
        funcscope:add_return_value(i, retnode.attr.value)
      end
    end
  end
end

function visitors.In(context, node)
  local retnode = node[1]
  local exprscope = context.scope:get_up_doexpr_scope()
  if not exprscope then
    retnode:raisef("no do expression block found to use `in` statement")
  end
  if exprscope.rettypes then
    local inrettype = exprscope.rettypes[1]
    assert(inrettype)
    context:traverse_node(retnode, {desiredtype=inrettype})
    local rettype = retnode.attr.type
    if rettype then
      retnode, rettype = visitor_convert(context, node, 1, inrettype, retnode, rettype)
      if rettype then
        local ok, err = inrettype:is_convertible_from(retnode or rettype)
        assert(ok, err) -- we always expect a successful conversion
        local retattr = retnode and retnode.attr
        if retattr and not retattr:can_copy() and
           not (retattr.scope and retattr.scope:get_up_function_scope() == exprscope) then
          retnode:raisef("in `in` expression: cannot pass non copyable type '%s' by value",
            rettype)
        end
      end
    end
    node.done = retnode.done and true
  else
    context:traverse_node(retnode)
    local retattr = retnode.attr
    local rettype = retattr.type
    exprscope:add_return_type(1, retattr.type, retnode)
    if rettype and rettype.is_type then
      exprscope:add_return_value(1, retattr.value)
    end
  end
end

function visitors.Do(context, node)
  local blocknode = node[1]
  context:traverse_node(blocknode)
  node.done = blocknode.done
end

function visitors.DoExpr(context, node)
  local blocknode = node[1]
  local exprscope
  repeat
    exprscope = context:push_forked_cleaned_scope(node)
    exprscope.is_doexpr = true
    exprscope.is_resultbreak = true
    context:traverse_node(blocknode)
    local resolutions_count = exprscope:resolve()
    context:pop_scope()
  until resolutions_count == 0

  local attr = node.attr
  if not node.checked then
    -- this block requires a return
    local topblock = context:get_visiting_node(1)
    if not topblock.is_Block and not blocknode:ends_with('In') then
      node:raisef("a `in` statement is missing inside do expression block")
    end
    local firstnode = blocknode[1]
    if firstnode and firstnode.is_In then -- forward attr from first expression
      local exprattr = firstnode[1].attr
      attr.sideeffect = exprattr.sideeffect
      attr.comptime = exprattr.comptime
      attr.untyped = exprattr.untyped
      attr.value = exprattr.value
    else -- statements inside may cause side effects
      attr.sideeffect = true
    end
    node.checked = true
  end

  if not attr.type then
    local rettypes = exprscope.rettypes
    if rettypes then -- known return type
      attr.type = rettypes[1]
    end
    node.done = attr.type and blocknode.done and true
  end
end

local function visitor_FuncDef_variable(context, declscope, varnode)
  if declscope == 'global' then
    if not context.scope.is_topscope then
      varnode:raisef("global function can only be declared in top scope")
    end
    varnode.attr.global = true
  end
  if declscope == 'global' or context.scope.is_topscope or declscope then
    varnode.attr.staticstorage = true
  end
  local symbol = context:traverse_node(varnode)
  return symbol
end

local function visitor_function_arguments(context, symbol, selftype, argnodes, checkpoly)
  local funcscope = context.scope

  local ispolyparent = false
  local argattrs = {}

  -- is the function forced to be polymorphic?
  if checkpoly and symbol and symbol.polymorphic then
    ispolyparent = true
  end

  local off = 0

  if selftype then -- inject 'self' type as first argument
    local selfsym = funcscope.selfsym
    if not selfsym then
      selfsym = Symbol{
        name = 'self',
        codename = 'self',
        lvalue = true,
        type = selftype,
        scope = funcscope,
      }
      funcscope.selfsym = selfsym
    end
    argattrs[1] = selfsym
    funcscope:add_symbol(selfsym)
    off = 1
  end

  for i=1,#argnodes do
    local argnode = argnodes[i]
    context:traverse_node(argnode)
    local argattr = argnode.attr
    if argattr._symbol then
      funcscope:add_symbol(argattr)
    end
    local argtype = argattr.type
    if not argtype then
    -- function arguments types must be known ahead, fallbacks to any if untyped
      argtype = primtypes.any
      argattr.type = argtype
    end
    if checkpoly and (argtype.is_polymorphic or argattr.comptime) then
      ispolyparent = true
    end
    argattrs[i+off] = argattr
  end

  return argattrs, ispolyparent
end

local function visitor_function_returns(context, node, retnodes, ispolyparent)
  local funcscope = context.scope
  local rettypes = funcscope.rettypes
  if rettypes then
    return rettypes, not types.are_types_resolved(rettypes)
  end
  local hasauto = false
  local polyret = false
  if retnodes then
    context:push_forked_state{intypeexpr = true}
    for i=1,#retnodes do
      local retnode = retnodes[i]
      if retnode.preprocess then -- must preprocess the return type
        if ispolyparent then
          -- skip parsing nodes that need preprocess in polymorphic function parent
          retnode = nil
          polyret = true
        else
          local ok, err = except.trycall(retnode.preprocess, retnodes, i)
          if not ok then
            if except.isexception(err) then
              except.reraise(err)
            else
              retnode:raisef('error while preprocessing function return node: %s',
                context.ppcontext:translate_error(err))
            end
          end
          retnode = retnodes[i] -- the node may be overwritten
          retnode.preprocess = nil
        end
      end
      if retnode then
        context:traverse_node(retnode)
        if not retnode.attr.value then
          retnode:raisef('in function return %d: invalid type for function return', i)
        end
        if retnode.attr.value.is_auto then
          hasauto = true
        end
      end
    end
    context:pop_state()
  end
  if polyret then
    rettypes = {}
  elseif retnodes and #retnodes > 0 then -- return types is fixed by the user
    rettypes = types.typenodes_to_types(retnodes)
  elseif ispolyparent or node.attr.cimport then
    rettypes = {}
  end
  funcscope.rettypes = rettypes
  return rettypes, hasauto
end

local function visitor_function_annotations(context, node, annotnodes, blocknode, symbol, type, defn)
  if annotnodes then
    context:traverse_nodes(annotnodes, {symbol=symbol})
  end

  local attr = node.attr

  do -- handle attributes and annotations
    -- annotation cimport
    if attr.cimport or (attr.forwarddecl and not defn) then
      if #blocknode ~= 0 then
        blocknode:raisef("body of a function declaration must be empty")
      end
      if attr.codename == 'nelua_main' then
        context.hookmain = attr
      end
    end

    -- annotation sideeffect, the function has side effects unless told otherwise
    if type and attr.nosideeffect then -- explicitly set as nosideeffect
      type.sideeffect = false
    end

    -- annotation entrypoint
    if attr.entrypoint then
      if context.entrypoint and context.entrypoint ~= node then
        node:raisef("cannot have more than one function entrypoint")
      end
      if type and type.is_polyfunction then
        node:raisef('polymorphic functions cannot be an entrypoint')
      end
      if not attr.fixedcodename then
        attr.codename = attr.name
      end
      attr.declname = attr.codename
      context.entrypoint = node
    end

    if type and type.is_polyfunction and attr.alwayspoly then
      type.alwayspoly = true
    end
  end
end

local function visitor_function_sideeffect(attr, functype, funcscope)
  if functype and not attr.nosideeffect then
    -- C imported function has side effects unless told otherwise,
    -- if any side effect call or upvalue assignment is detected the function also has side effects
    if (attr.cimport or attr.forwarddecl) or funcscope.sideeffect then
      functype.sideeffect = true
    else
      functype.sideeffect = false
    end
  end
end

local function visitor_function_polyevals(context, node, symbol, varnode, type)
  local evals = type.evals
  for i=1,#evals do
    local polyeval = evals[i]
    local polynode = polyeval.node
    if not polynode then
      polynode = node:clone()
      polyeval.node = polynode
      local polyargnodes = polynode[3]
      local polyevalargs = polyeval.args
      local nvarargs = 0
      local invarargs = false
      local varargsnodes
      if symbol.type:has_varargs() and not polyeval.varargsnodes then
        varargsnodes = {}
      end
      local ismethod = varnode.is_ColonIndex
      for j=1,#polyevalargs do
        local polyevalarg = polyevalargs[j]
        if ismethod then
          j = j - 1
        end
        local polyargnode = polyargnodes[j]
        if polyargnode and polyargnode.is_VarargsType then
          invarargs = true
        end
        if invarargs then -- replace varargs arguments with IdDecl nodes
          nvarargs = nvarargs + 1
          local polyargtype
          local polyargval
          if traits.is_attr(polyevalarg) then -- should be a type
            assert(polyevalarg.type.is_type)
            polyargtype = polyevalarg.type
            polyargval = polyevalarg.value
          else
            polyargtype = polyevalarg
          end
          local polyargtypesym = Symbol{
            type = primtypes.type,
            value = polyargtype,
          }
          local argname = '__arg'..nvarargs
          polyargnode = aster.IdDecl{argname,
            aster.Id{'auto', pattr={forcesymbol=polyargtypesym}},
            pattr={value=polyargval},
          }
          polyargnodes[j] = polyargnode
          if varargsnodes then
            varargsnodes[nvarargs] = aster.Id{argname, attr=Attr{type=polyargtype, value=polyargval}}
          end
        elseif polyargnode then
          local polyargattr = polyargnode.attr
          if traits.is_attr(polyevalarg) then
            polyargattr.type = polyevalarg.type
            polyargattr.value = polyevalarg.value
            if traits.is_bn(polyargattr.value) then
              polyargattr.value = polyargattr.value:compress()
            end
          else
            polyargattr.type = polyevalarg
          end
          assert(polyargattr.type._type)
        end
      end
      -- remove extra unused argnodes
      while #polyargnodes > #polyevalargs - (ismethod and 1 or 0) do
        polyargnodes[#polyargnodes] = nil
      end
      if varargsnodes then
        polyeval.varargsnodes = varargsnodes
      end
    end
    -- pop node and then push again to fix error message traceback
    context:pop_node()
    context:push_forked_state{inpolyeval=polyeval} -- used to generate error messages
    context:traverse_node(polynode, {polysymbol=symbol})
    context:pop_state()
    context:push_node(node)
    assert(polynode.attr._symbol)
  end
end

local function resolve_function_type(node, symbol, varnode, varsym, decl, argattrs, rettypes, ispolyparent, polysymbol)
  local type
  local attr = node.attr
  if ispolyparent then
    assert(not polysymbol)
    if symbol.forwarddecl then
      node:raisef("polymorphic functions cannot be forward declared")
    end
    type = types.PolyFunctionType(argattrs, rettypes, node)
  else
    type = types.FunctionType(argattrs, rettypes, node)
  end
  type.symbol = symbol
  local vartype = varnode.attr.type
  if varnode.attr.type then -- check if previous symbol declaration is compatible
    local ok, err = vartype:is_convertible_from_type(type)
    if not ok then
      node:raisef("in function definition: %s", err)
    end
  end
  if varsym and not decl then
    varsym:add_possible_type(type, varnode)
  else
    attr.type = type
  end
  attr.ftype = type
  if decl then
    if attr.comptime == nil then
      attr.comptime = true
    end
    attr.value = symbol
  end
  if symbol and symbol.type then
    symbol.scope:finish_symbol_resolution(symbol)
  end
  return type
end

function visitors.FuncDef(context, node, opts)
  local polysymbol = opts and opts.polysymbol
  local declscope, varnode, argnodes, retnodes, annotnodes, blocknode =
        node[1], node[2], node[3], node[4], node[5], node[6]

  local type = node.attr.ftype
  context:push_forked_state{infuncdef = node, inpolydef = polysymbol}
  local varsym = visitor_FuncDef_variable(context, declscope, varnode)
  local attr, symbol
  if varsym then -- symbol may be nil in case of array/dot index
    symbol = varsym
    symbol.scope:add_symbol(symbol)
    symbol:link_node(node)
    attr = node.attr
  else
    attr = node.attr
    if not attr._symbol then -- inside an array/dot index without symbol
      -- we need to create an anonymous symbol
      symbol = Symbol.promote_attr(attr, node)
      symbol.codename = context:choose_codename('anonfunc')
      symbol.anonymous = true
      symbol.used = true
      symbol.scope = context.scope
      symbol.lvalue = true
      symbol.staticstorage = true
    else
      symbol = attr
    end
    symbol.scope:add_symbol(symbol)
  end
  context:pop_state()

  -- we must know if the symbols is going to be polymorphic
  local forwarddecl
  if annotnodes then
    for i=1,#annotnodes do
      local annotname = annotnodes[i][1]
      if annotname == 'polymorphic' or annotname == 'alwayspoly' then
        attr.polymorphic = true
      elseif annotname == 'cimport' then
        attr.cimport = true
      elseif annotname == 'forwarddecl' then
        forwarddecl = true
        attr.forwarddecl = true
      end
    end
  end

  -- detect if is a function declaration/definition
  local decl = (not not declscope or forwarddecl)
  local defn = not (attr.nodecl or attr.cimport or attr.hookmain or forwarddecl)
  if symbol then
    if not forwarddecl and symbol.forwarddecl then
      defn = true
      decl = false
    elseif symbol.metafunc then
      decl = true
    end
    if decl then
      node.funcdecl = true
      symbol.funcdeclared = true
    end
    if defn then
      node.funcdefn = true
      symbol.funcdefined = true
      if not symbol.defnode then -- set defnode only for first definition
        symbol.defnode = node
      elseif symbol.defnode ~= node then -- promote to variable
        symbol.comptime = false
        symbol.staticstorage = false
      end
    end
  end

  -- detect the self type
  local selftype
  if varnode.is_ColonIndex then
    if varsym and varsym.metafunc then
      selftype = varsym.metafuncselftype
    else
      local rectype = varnode[2].attr.type
      if not rectype then -- we need to wait the rectype resolution
        return
      end
      if rectype.is_record then
        selftype = types.PointerType(rectype)
      else
        selftype = rectype
      end
    end
  end

  -- repeat scope to resolve function variables and return types
  local funcscope, argattrs, ispolyparent, rettypes, hasautoret
  repeat
    -- enter in the function scope
    funcscope = context:push_forked_cleaned_scope(node)
    funcscope.funcsym = symbol
    if polysymbol then
      funcscope.polysym = polysymbol
    end
    funcscope.is_function = true
    funcscope.is_resultbreak = true
    context:push_forked_state{funcscope = funcscope}

    -- traverse the function arguments
    argattrs, ispolyparent = visitor_function_arguments(context, symbol, selftype, argnodes, not polysymbol)

    symbol.argattrs = argattrs

    -- traverse the function returns
    rettypes, hasautoret = visitor_function_returns(context, node, retnodes, ispolyparent)

    -- set the function type
    if not type and rettypes and (ispolyparent or not hasautoret) then
      type = resolve_function_type(node, symbol, varnode, varsym, decl,
        argattrs, rettypes, ispolyparent, polysymbol)
    end

    -- traverse annotation nodes
    visitor_function_annotations(context, node, annotnodes, blocknode, symbol, type, defn)
    -- traverse the function block
    if not ispolyparent then -- poly functions never traverse the blocknode by itself
      context:traverse_node(blocknode)
      -- after traversing we should know auto types
      if hasautoret then
        if not type and rettypes and types.are_types_resolved(rettypes) then
          type = resolve_function_type(node, symbol, varnode, varsym, decl,
            argattrs, rettypes, ispolyparent, polysymbol)
        elseif not funcscope.hasreturn then
          node:raisef("a function return is set to 'auto', but the function never returns")
        end
      end

      if defn then
        visitor_function_sideeffect(attr, type, funcscope)
      end
    end

    local resolutions_count = funcscope:resolve()
    context:pop_state()
    context:pop_scope()
  until resolutions_count == 0

  -- type checking for returns
  if type and defn and type.is_function and rettypes and #rettypes > 0 then
    local canbeempty = tabler.iallfield(rettypes, 'is_nilable')
    if not canbeempty and not blocknode:ends_with('Return') then
      node:raisef("a return statement is missing before function end")
    end
  end

  -- traverse poly function nodes
  if ispolyparent then
    visitor_function_polyevals(context, node, symbol, varnode, type)
  end
end

function visitors.Function(context, node)
  local argnodes, retnodes, annotnodes, blocknode =
        node[1], node[2], node[3], node[4]

  local attr = node.attr
  local type = attr.type
  local symbol
  if attr._symbol then
    symbol = attr
  else
    symbol = Symbol.promote_attr(attr, node)
    symbol.codename = context:choose_codename('anonfunc')
    symbol.scope = context.scope
    symbol.lvalue = true
    symbol.used = true
    symbol.staticstorage = true
    symbol.anonfunc = true
    symbol.scope:add_symbol(symbol)
  end

  -- repeat scope to resolve function variables and return types
  local funcscope, argattrs, ispolyparent, rettypes, hasauto
  repeat
    -- enter in the function scope
    funcscope = context:push_forked_cleaned_scope(node)
    funcscope.funcsym = symbol
    funcscope.is_function = true
    funcscope.is_resultbreak = true
    context:push_forked_state{funcscope = funcscope}

    -- traverse the function arguments
    argattrs, ispolyparent = visitor_function_arguments(context, symbol, false, argnodes, true)
    symbol.argattrs = argattrs

    if ispolyparent then -- anonymous functions cannot be polymorphic
      node:raisef("anonymous functions cannot be polymorphic")
    end

    -- traverse the function returns
    rettypes, hasauto = visitor_function_returns(context, node, retnodes)

    if hasauto then
      node:raisef("anonymous functions cannot have 'auto' returns")
    end

    -- set the function type
    if not type and rettypes then
      type = types.FunctionType(argattrs, rettypes, node)
      type.symbol = symbol
      attr.type = type
      attr.comptime = true
      attr.value = symbol
    end

    -- traverse annotation nodes
    visitor_function_annotations(context, node, annotnodes, blocknode, symbol, type, true)

    -- traverse the function block
    context:traverse_node(blocknode)

    visitor_function_sideeffect(attr, type, funcscope)

    local resolutions_count = funcscope:resolve()
    context:pop_state()
    context:pop_scope()
  until resolutions_count == 0

  -- type checking for returns
  if type and rettypes and #rettypes > 0 then
    local canbeempty = tabler.iallfield(rettypes, 'is_nilable')
    if not canbeempty and not blocknode:ends_with('Return') then
      node:raisef("a return statement is missing before function end")
    end
  end
end

local overridable_operators = {
  ['eq'] = true,
  ['ne'] = true,
  ['lt'] = true,
  ['le'] = true,
  ['ge'] = true,
  ['gt'] = true,
  ['bor'] = true,
  ['bxor'] = true,
  ['band'] = true,
  ['shl'] = true,
  ['shr'] = true,
  ['asr'] = true,
  ['concat'] = true,
  ['add'] = true,
  ['sub'] = true,
  ['mul'] = true,
  ['tdiv'] = true,
  ['idiv'] = true,
  ['div'] = true,
  ['pow'] = true,
  ['mod'] = true,
  ['tmod'] = true,
  ['len'] = true,
  ['unm'] = true,
  ['bnot'] = true,
}

local swap_overridable_operators = {
  ['gt'] = 'lt',
  ['ge'] = 'le',
}

local function override_unary_op(context, node, opname, objnode, objtype)
  if not overridable_operators[opname] then return end
  if opname == 'len' then
    -- allow calling len on pointers for arrays/records
    objtype = objtype:implicit_deref_type()
  end
  if not objtype.metafields then return end
  local mtname = '__' .. opname
  local mtsym = objtype.metafields[mtname]
  if not mtsym then
    return
  end

  -- transform into call
  local objsym = objtype.symbol
  context:transform_and_traverse_node(node, aster.Call{
    {objnode},
    aster.DotIndex{mtname, aster.Id{objsym.name, pattr={forcesymbol=objsym}}}
  })
  return true
end

local disallowed_deref_ops = {
  ['ne'] = true,
  ['eq'] = true,
  ['or'] = true,
  ['and'] = true,
  ['not'] = true,
  ['deref'] = true,
  ['ref'] = true,
}


function visitors.UnaryOp(context, node, opts)
  local attr = node.attr
  local opname, argnode = node[1], node[2]
  local desiredtype = opts and opts.desiredtype
  local argopts

  if desiredtype and desiredtype.is_boolean or opname == 'not' then
    argopts = {desiredtype=primtypes.boolean}
  end
  context:traverse_node(argnode, argopts)

  -- quick return for already resolved type
  if attr.type then
    if argnode.done then
      node.done = true
    end
    return
  end

  local argattr = argnode.attr
  local argtype = argattr.type
  local type
  if argtype then
    if argtype.is_pointer and argtype.subtype.is_composite and not disallowed_deref_ops[opname] then
      argtype = argtype.subtype
    end
    if override_unary_op(context, node, opname, argnode, argtype) then
      return
    end
    local value, err
    type, value, err = argtype:unary_operator(opname, argattr)
    if err then
      argnode:raisef("in unary operation `%s`: %s", opname, err)
    end
    if value ~= nil then
      attr.comptime = true
      attr.value = value
      attr.untyped = argattr.untyped or not argattr.comptime
    end
  elseif opname == 'not' then
    type = primtypes.boolean
  end
  if opname == 'ref' then
    if argtype then
      if not argattr.lvalue and argtype.is_aggregate and
        (argnode.attr.calleetype == primtypes.type or argnode.is_InitList) then
        -- allow referencing temporary records/arrays
        argattr.promotelvalue = true
      elseif not argattr.lvalue then
        node:raisef("in unary operation `%s`: cannot reference rvalue of type '%s'", opname, argtype)
      end
      argattr.refed = true
    end
  elseif opname == 'deref' then
    attr.lvalue = true
  end
  if type then
    attr.type = type
    if argnode.done then
      node.done = true
    end
  end
  if argattr.sideeffect then
    attr.sideeffect = true
  end
end

local function override_binary_op(context, node, opname, lnode, rnode, ltype, rtype)
  if not ltype.metafields and not rtype.metafields then return end
  if not overridable_operators[opname] then return end

  local objtype, mtsym, mtname
  local neg
  if swap_overridable_operators[opname] then -- '>=' or '>'
    mtname = '__' .. swap_overridable_operators[opname]
    -- must swap nodes
    lnode, rnode = rnode, lnode
  elseif opname == 'ne' then -- '~='
    mtname = '__eq'
    neg = true
  else
    mtname = '__' .. opname
  end
  if mtname == '__eq' and ltype ~= rtype and ltype.is_stringy ~= rtype.is_stringy then
    -- __eq metamethod is called only for same record types (except for stringy types)
    return
  end
  if ltype.metafields then
    mtsym = ltype.metafields[mtname]
    objtype = ltype
  end
  if not mtsym and rtype.metafields then
    mtsym = rtype.metafields[mtname]
    objtype = rtype
  end
  if not mtsym then
    return
  end

  -- transform into call
  local objsym = objtype.symbol
  local idnode = aster.Id{objsym.name, pattr={forcesymbol=objsym}}
  local newnode = aster.Call{{lnode, rnode}, aster.DotIndex{mtname, idnode}}
  if neg then
    newnode = aster.UnaryOp{'not', newnode}
  end
  context:transform_and_traverse_node(node, newnode)
  return true
end

function visitors.BinaryOp(context, node, opts)
  local lnode, opname, rnode = node[1], node[2], node[3]
  local attr = node.attr
  local isor = opname == 'or'
  local isbinaryconditional = isor or opname == 'and'
  local desiredtype = opts and opts.desiredtype
  local argopts

  local wantsboolean
  if isbinaryconditional and desiredtype and desiredtype.is_boolean then
    argopts = {desiredtype=primtypes.boolean}
    wantsboolean = true
  elseif isor and lnode[2] == 'and' and lnode.is_BinaryOp then
    lnode.attr.ternaryand = true
    attr.ternaryor = true
  end

  context:traverse_node(lnode, argopts)
  context:traverse_node(rnode, argopts)

  -- quick return for already resolved type
  if attr.type then
    if lnode.done and rnode.done then node.done = true end
    return
  end

  local lattr, rattr = lnode.attr, rnode.attr
  local ltype, rtype = lattr.type, rattr.type
  local type
  if ltype and rtype then
    if ltype.is_pointer and rtype.is_pointer and not disallowed_deref_ops[opname] and
       ltype.subtype.is_composite and rtype.subtype.is_composite then
      -- auto dereference for binary operation on pointers
      ltype = ltype.subtype
      rtype = rtype.subtype
    end
    if not wantsboolean and isbinaryconditional and
      (not rtype.is_boolean or not ltype.is_boolean) then
      attr.dynamic_conditional = true
    end
    if override_binary_op(context, node, opname, lnode, rnode, ltype, rtype) then
      return
    end

    local value, err
    type, value, err = ltype:binary_operator(opname, rtype, lattr, rattr)
    if err then
      lnode:raisef("in binary operation `%s`: %s", opname, err)
    end
    if wantsboolean then
      type = primtypes.boolean
    end
    if value ~= nil then
      attr.comptime = true
      attr.value = value
      if (lattr.untyped or not lattr.comptime) and (rattr.untyped or not rattr.comptime) then
        attr.untyped = true
      end
    end
  end
  if attr.ternaryand then
    type = rtype
  end
  if type then
    attr.type = type
    if lnode.done and rnode.done then
      node.done = true
    end
  end
  if lattr.sideeffect or rattr.sideeffect then
    attr.sideeffect = true
  end
end

function analyzer.analyze(context)
  -- save current analyzing context
  local old_current_context = analyzer.current_context
  analyzer.current_context = context
  -- begin tracking analyze time
  local timer
  if config.more_timing then
    timer = nanotimer()
  end
  -- inherit config pragmas
  tabler.update(context.pragmas, config.pragmas)
  -- setup ast filename
  local ast = context.ast
  if ast.src and ast.src.name then
    context.pragmas.unitname = pegger.filename_to_unitname(ast.src.name)
    ast.attr.filename = fs.abspath(ast.src.name)
  end
  context:push_forked_state{funcscope=context.rootscope}
  -- phase 1 traverse: preprocess
  local ppcode = preprocessor.preprocess(context, ast)
  if config.print_ppcode then
    if ppcode then
      console.info(ppcode)
    end
    return
  end
  -- phase 2 traverse: infer and check types
  repeat
    context:traverse_node(ast)
    local resolutions_count = context.rootscope:resolve()
    if config.more_timing then
      console.debugf('analyzed (%.1f ms)', timer:elapsedrestart())
    end
  until resolutions_count == 0
  -- execute after analyze callbacks
  for _,callback in ipairs(context.afteranalyzes) do
    local ok, err = except.trycall(callback.f)
    if not ok then
      callback.node:raisef('error while executing after analyze: %s', err)
    end
  end
  -- phase 3 traverse: infer unset types to 'any' type
  if context.unresolvedcount ~= 0 then
    context:push_forked_state{anyphase=true}
    repeat
      context:traverse_node(ast)
      local resolutions_count = context.rootscope:resolve()
      if config.more_timing then --luacov:disable
        console.debugf('last analyzed (%.1f ms)', timer:elapsedrestart())
      end --luacov:enable
    until resolutions_count == 0
    assert(context.unresolvedcount == 0)
    context:pop_state()
  end
  -- execute after inference callbacks
  for _,callback in ipairs(context.afterinfers) do
    callback()
  end
  context:pop_state()
  -- restore old analyzing context
  analyzer.current_context = old_current_context
  return context
end

return analyzer
