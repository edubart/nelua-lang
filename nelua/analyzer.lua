local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local tabler = require 'nelua.utils.tabler'
local pegger = require 'nelua.utils.pegger'
local typedefs = require 'nelua.typedefs'
local AnalyzerContext = require 'nelua.analyzercontext'
local Attr = require 'nelua.attr'
local Symbol = require 'nelua.symbol'
local types = require 'nelua.types'
local bn = require 'nelua.utils.bn'
local except = require 'nelua.utils.except'
local preprocessor = require 'nelua.preprocessor'
local builtins = require 'nelua.builtins'
local config = require 'nelua.configer'.get()
local analyzer = {}

local primtypes = typedefs.primtypes
local visitors = {}

function visitors.Number(context, node)
  local attr = node.attr
  if attr.type then return end
  local base, int, frac, exp, literal = node[1], node[2], node[3], node[4], node[5]
  attr.value = bn.frombase(base, int, frac, exp)
  if literal then
    attr.type = typedefs.number_literal_types[literal]
    if not attr.type then
      node:raisef("literal suffix '%s' is undefined", literal)
    end
    if not attr.type:is_inrange(attr.value) then
      node:raisef("value `%s` for literal type `%s` is out of range, "..
        "the minimum is `%s` and maximum is `%s`",
        attr.value:todec(), attr.type, attr.type.min:todec(), attr.type.max:todec())
    end
  else
    attr.untyped = true
    if not (frac or exp) then
      if primtypes.integer:is_inrange(attr.value) or base ~= 'dec' then
        attr.type = primtypes.integer
      else
        attr.type = primtypes.number
      end
    else
      attr.type = primtypes.number
    end
  end
  if context.pragmas.nofloatsuffix then
    attr.nofloatsuffix = true
  end
  attr.base = base
  attr.literal = true
  attr.comptime = true
end

function visitors.String(_, node)
  local attr = node.attr
  if attr.type then return end
  local value, literal = node[1], node[2]
  if literal then
    node:raisef("custom string literals are not supported yet")
  end
  attr.type = primtypes.stringview
  attr.value = value
  attr.literal = true
  attr.comptime = true
end

function visitors.Boolean(_, node)
  local attr = node.attr
  if attr.type then return end
  local value = node:args(1)
  attr.value = value
  attr.type = primtypes.boolean
  attr.comptime = true
  attr.literal = true
end

function visitors.Nil(_, node)
  local attr = node.attr
  if attr.type then return end
  attr.type = primtypes.nilable
  attr.comptime = true
  attr.literal = true
end

local function visitor_convert(context, parent, parentindex, vartype, valnode, valtype)
  if not vartype or not valtype then
    return valnode, valtype
  end
  local objsym
  local mtname
  local varobjtype = vartype:auto_deref_type()
  local valobjtype = valtype:auto_deref_type()
  local objtype
  if valobjtype.is_record then
    if vartype.is_cstring then
      objtype = valobjtype
      mtname = '__tocstring'
    elseif vartype.is_string then
      objtype = valobjtype
      mtname = '__tostring'
    elseif vartype.is_stringview then
      objtype = valobjtype
      mtname = '__tostringview'
    end
  end
  if not objtype then
    objtype = varobjtype
    mtname = '__convert'
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
  local mtsym = objtype:get_metafield(mtname)
  if not mtsym then
    return valnode, valtype
  end
  objsym = objtype.symbol
  assert(objsym)
  local n = context.parser.astbuilder.aster
  local idnode = n.Id{objsym.name}
  local pattr = Attr{foreignsymbol=objsym}
  idnode.attr:merge(pattr)
  idnode.pattr = pattr
  local newvalnode = n.Call{{valnode}, n.DotIndex{mtname, idnode}}
  newvalnode.srcname = valnode.srcname
  newvalnode.src = valnode.src
  newvalnode.pos = valnode.pos
  parent[parentindex] = newvalnode
  context:traverse_node(newvalnode)
  return newvalnode, newvalnode.attr.type
end


local function visitor_Array_literal(context, node, littype)
  local attr = node.attr
  local childnodes = node[1]
  local subtype = littype.subtype
  local comptime = true
  if not (#childnodes == littype.length or #childnodes == 0) then
    node:raisef("expected %d values in array literal but got %d", littype.length, #childnodes)
  end
  for i,childnode in ipairs(childnodes) do
    if childnode.tag == 'Pair' then
      childnode:raisef("fields are disallowed for array literals")
    end
    childnode.desiredtype = subtype
    context:traverse_node(childnode)
    local childtype = childnode.attr.type
    childnode, childtype = visitor_convert(context, childnodes, i, subtype, childnode, childtype)
    if childtype then
      if not childtype:is_initializable_from_attr(childnode.attr) then
        comptime = nil
      end
      local ok, err = subtype:is_convertible_from(childnode.attr)
      if not ok then
        childnode:raisef("in array literal at index %d: %s", i, err)
      end
      if not context.pragmas.nochecks and subtype ~= childtype then
        childnode.checkcast = true
      end
    end
    if not childnode.attr.comptime then
      comptime = nil
    end
  end
  attr.type = littype
  attr.comptime = comptime
end

local function visitor_Record_literal(context, node, littype)
  local attr = node.attr
  local childnodes = node[1]
  local comptime = true
  local lastfieldindex = 0
  for i, childnode in ipairs(childnodes) do
    local parent, parentindex
    local fieldname, fieldvalnode, field, fieldindex
    if childnode.tag == 'Pair' then
      fieldname, fieldvalnode = childnode[1], childnode[2]
      if not traits.is_string(fieldname) then
        childnode:raisef("only string literals are allowed in record's field names")
      end
      field, fieldindex = littype:get_field(fieldname)
      parent = childnode
      parentindex = 2
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
      childnode:raisef("field '%s' is not present in record '%s'",
      fieldname, littype:prettyname())
    end
    local fieldtype = field.type
    fieldvalnode.desiredtype = fieldtype
    context:traverse_node(fieldvalnode)
    local fieldvaltype = fieldvalnode.attr.type
    fieldvalnode, fieldvaltype = visitor_convert(context, parent, parentindex, fieldtype, fieldvalnode, fieldvaltype)
    lastfieldindex = fieldindex
    if fieldvaltype then
      if not fieldvaltype:is_initializable_from_attr(fieldvalnode.attr) then
        comptime = nil
      end
      local ok, err = fieldtype:is_convertible_from(fieldvalnode.attr)
      if not ok then
        childnode:raisef("in record literal field '%s': %s", fieldname, err)
      end
      if not context.pragmas.nochecks and fieldtype ~= fieldvaltype then
        fieldvalnode.checkcast = true
      end
    end
    if not fieldvalnode.attr.comptime then
      comptime = nil
    end
    childnode.parenttype = littype
    childnode.fieldname = fieldname
  end
  attr.type = littype
  attr.comptime = comptime
end

local function visitor_Table_literal(context, node)
  local attr = node.attr
  local childnodes = node[1]
  context:traverse_nodes(childnodes)
  attr.type = primtypes.table
  attr.node = node
end

function visitors.Table(context, node)
  local desiredtype = node.desiredtype
  node.attr.literal = true
  if desiredtype then
    local objtype = desiredtype:auto_deref_type()
    if objtype.is_record and desiredtype.choose_braces_type then
      desiredtype = desiredtype.choose_braces_type(node)
    end
  end
  if not desiredtype or (desiredtype.is_table or desiredtype.is_lazyable) then
    visitor_Table_literal(context, node)
  elseif desiredtype.is_array then
    visitor_Array_literal(context, node, desiredtype)
  elseif desiredtype.is_record then
    visitor_Record_literal(context, node, desiredtype)
  else
    node:raisef("type '%s' cannot be initialized using a table literal", desiredtype:prettyname())
  end
end

function visitors.PragmaCall(context, node)
  local name, args = node[1], node[2]
  local pragmashape = typedefs.call_pragmas[name]
  node:assertraisef(pragmashape, "pragma '%s' is undefined", name)

  if name == 'afterinfer' and context.state.anyphase and not node.attr.afterinfer then
    node.attr.afterinfer = true
    args[1]()
  end
end

function visitors.Annotation(context, node, symbol)
  local attr = node.attr
  if attr.parsed then return end

  assert(symbol)

  local name = node[1]

  local paramshape
  local symboltype
  if name == 'comptime' then
    paramshape = true
  else
    symboltype = symbol.type
    if not symboltype then
      -- in the next traversal we will have the type
      return
    end
    local annotype
    if symboltype.is_function then
      paramshape = typedefs.function_annots[name]
      annotype = 'functions'
    elseif symboltype.is_type then
      paramshape = typedefs.type_annots[name]
      annotype = 'types'
    else
      paramshape = typedefs.variable_annots[name]
      annotype = 'variables'
    end
    if not paramshape then
      node:raisef("annotation '%s' is undefined for %s", name, annotype)
    end
  end

  local argnodes = node[2]
  context:traverse_nodes(argnodes)

  local params = tabler.imap(argnodes, function(argnode)
    local value = argnode.attr.value
    if traits.is_bignumber(value) then
      return value:tointeger()
    end
    return value
  end)

  if paramshape == true then
    if #argnodes ~= 0 then
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
  if symboltype and symboltype.is_type then
    objattr = symbol.value
  else
    objattr = symbol
  end
  objattr[name] = params

  if name == 'cimport' then
    if traits.is_string(params) then
      objattr.codename = params
    else
      objattr.codename = symbol.name
    end
  end

  attr.parsed = true
end

function visitors.Id(context, node)
  local name = node[1]
  if node.attr.foreignsymbol then
    local symbol = node.attr.foreignsymbol
    symbol:link_node(node)
    return symbol
  end
  local symbol = context.scope:get_symbol(name)
  if not symbol then
    node:raisef("undeclared symbol '%s'", name)
  end
  symbol:link_node(node)
  return symbol
end

function visitors.IdDecl(context, node)
  local namenode, typenode, annotnodes = node[1], node[2], node[3]
  local attr = node.attr
  local type = attr.type
  if not type and typenode then
    context:traverse_node(typenode)
    type = typenode.attr.value
    attr.type = type
    if type.is_void then
      node:raisef("variable declaration cannot be of the empty type '%s'", type)
    end
  end
  local symbol
  if traits.is_string(namenode) then
    symbol = Symbol.promote_attr(attr, namenode, node)
    local scope
    if symbol.global then
      scope = context.rootscope
    else
      scope = context.scope
    end
    if not symbol.codename then
      if symbol.staticstorage then
        symbol.codename = context:choose_codename(namenode)
      else
        symbol.codename = namenode
      end
    end
    symbol.scope = scope
  else
    -- global record field
    assert(namenode.tag == 'DotIndex')
    local state = context:push_state()
    state.inglobaldecl = node
    symbol = context:traverse_node(namenode)
    attr = symbol
    context:pop_state()
    symbol.scope = context.rootscope
  end
  if annotnodes then
    context:traverse_nodes(annotnodes, symbol)
  end
  attr.lvalue = true
  return symbol
end

function visitors.Paren(context, node, ...)
  local innernode = node[1]
  innernode.desiredtype = node.desiredtype
  local ret = context:traverse_node(innernode, ...)
  -- inherit attributes from inner node
  node.attr = innernode.attr
  -- forward anything from inner node traverse
  return ret
end

function visitors.Type(context, node)
  local attr = node.attr
  if attr.type then return end
  local tyname = node[1]
  local value = typedefs.primtypes[tyname]
  if not value then
    local symbol = context.scope:get_symbol(tyname)
    if not (symbol and symbol.type == primtypes.type) then
      node:raisef("symbol '%s' is an invalid type", tyname)
    end
    value = symbol.value
    assert(value)
  end
  attr.type = primtypes.type
  attr.value = value
end

function visitors.TypeInstance(context, node, symbol)
  local typenode = node[1]
  if node.attr.type then return end
  context:traverse_node(typenode, symbol)
  -- inherit attributes from inner node
  local attr = typenode.attr
  node.attr = attr
  if symbol then
    attr.value:suggest_nick(symbol.name, symbol.staticstorage and symbol.codename)
    attr.value.symbol = symbol
  end
end

function visitors.FuncType(context, node)
  local attr = node.attr
  if attr.type then return end
  local argnodes, retnodes = node[1], node[2]
  context:traverse_nodes(argnodes)
  context:traverse_nodes(retnodes)
  local type = types.FunctionType(node,
    tabler.imap(argnodes, function(argnode) return Attr{type = argnode.attr.value} end),
    tabler.imap(retnodes, function(retnode) return retnode.attr.value end))
  type.sideeffect = true
  attr.type = primtypes.type
  attr.value = type
end

function visitors.RecordFieldType(context, node, recordtype)
  local attr = node.attr
  if attr.type then return end
  local name, typenode = node[1], node[2]
  context:traverse_node(typenode)
  attr.type = typenode.attr.type
  attr.value = typenode.attr.value
  recordtype:add_field(name, typenode.attr.value)
end

function visitors.RecordType(context, node, symbol)
  local attr = node.attr
  if attr.type then return end
  local recordtype = types.RecordType(node)
  attr.type = primtypes.type
  attr.value = recordtype
  if symbol then
    -- must populate this type symbol early in case its used in the records fields
    assert((not symbol.type or symbol.type == primtypes.type) and not symbol.value)
    symbol.type = primtypes.type
    symbol.value = recordtype
    recordtype:suggest_nick(symbol.name, symbol.staticstorage and symbol.codename)
    recordtype.symbol = symbol
  end
  local fieldnodes = node[1]
  context:traverse_nodes(fieldnodes, recordtype)
end

function visitors.EnumFieldType(context, node)
  local name, numnode = node[1], node[2]
  local field = Attr{name = name}
  if numnode then
    local desiredtype = node.desiredtype
    context:traverse_node(numnode)
    local numattr = numnode.attr
    local numtype = numattr.type
    if not numattr.comptime then
      numnode:raisef("in enum field '%s': enum fields can only be assigned to compile time values", name)
    elseif not numtype.is_integral then
      numnode:raisef("in enum field '%s': only integral types are allowed in enums, but got type '%s'",
        name, numtype:prettyname())
    end
    local ok, err = desiredtype:is_convertible_from_attr(numattr)
    if not ok then
      numnode:raisef("in enum field '%s': %s", name, err)
    end
    field.value = numnode.attr.value
    field.comptime = true
    field.type = desiredtype
  end
  return field
end

function visitors.EnumType(context, node)
  local attr = node.attr
  if attr.type then return end
  local typenode, fieldnodes = node[1], node[2]
  local subtype = primtypes.integer
  if typenode then
    context:traverse_node(typenode)
    subtype = typenode.attr.value
  end
  local fields = {}
  for i,fnode in ipairs(fieldnodes) do
    fnode.desiredtype = subtype
    local field = context:traverse_node(fnode)
    if not field.value then
      if i == 1 then
        fnode:raisef("first enum field requires an initial value", field.name)
      else
        field.value = fields[i-1].value:add(1)
        field.comptime = true
        field.type = subtype
      end
    end
    if not subtype:is_inrange(field.value) then
      fnode:raisef("in enum field '%s': value %s is out of range for type '%s'",
        field.name, field.value:todec(), subtype:prettyname())
    end
    assert(field.name)
    fields[i] = field
  end
  attr.type = primtypes.type
  attr.value = types.EnumType(node, subtype, fields)
end

function visitors.RangeType(context, node)
  local attr = node.attr
  if attr.type then return end
  local subtypenode = node[1]
  context:traverse_node(subtypenode)
  local subtype = subtypenode.attr.value
  if not subtype.is_integral then
    subtypenode:raisef("range subtype '%s' is not an integral type", subtype:prettyname())
  end
  attr.type = primtypes.type
  attr.value = types.RangeType(node, subtype)
end

function visitors.ArrayType(context, node)
  local attr = node.attr
  if attr.type then return end
  local subtypenode, lengthnode = node[1], node[2]
  context:traverse_node(subtypenode)
  local subtype = subtypenode.attr.value
  context:traverse_node(lengthnode)
  if not lengthnode.attr.value then
    lengthnode:raisef("unknown comptime value for expression")
  end
  local length = lengthnode.attr.value:tointeger()
  if not lengthnode.attr.type.is_integral then
    lengthnode:raisef("cannot have non integral type '%s' for array size",
      lengthnode.attr.type:prettyname())
  elseif length < 0 then
    lengthnode:raisef("cannot have negative array size %d", length)
  end
  attr.type = primtypes.type
  attr.value = types.ArrayType(node, subtype, length)
end

function visitors.PointerType(context, node)
  local attr = node.attr
  if attr.type then return end
  local subtypenode = node[1]
  if subtypenode then
    context:traverse_node(subtypenode)
    local subtype = subtypenode.attr.value
    attr.value = types.get_pointer_type(subtype)
    if not attr.value then
      node:raisef("subtype '%s' is invalid for 'pointer' type", subtype:prettyname())
    end
  else
    attr.value = primtypes.pointer
  end
  attr.type = primtypes.type
end

function visitors.GenericType(context, node)
  local attr = node.attr
  local name, argnodes = node[1], node[2]
  if attr.type then return end
  local symbol = context.scope:get_symbol(name)
  if not symbol or not symbol.type or not symbol.type.is_type or not symbol.value.is_generic then
    node:raisef("symbol '%s' doesn't hold a generic type", name)
  end
  local params = {}
  for i=1,#argnodes do
    local argnode = argnodes[i]
    context:traverse_node(argnode)
    local argattr = argnode.attr
    if not (argattr.comptime or argattr.type.is_comptime) then
      node:raisef("in generic '%s': argument #%d isn't a compile time value", name, i)
    end
    local value = argattr.value
    if traits.is_bignumber(value) then
      value = value:tonumber()
    elseif not (traits.is_type(value) or
                traits.is_string(value) or
                traits.is_boolean(value) or
                traits.is_bignumber(value)) then
      node:raisef("in generic '%s': argument #%d of type '%s' is invalid for generics",
        name, i, argattr.type:prettyname())
    end
    params[i] = value
  end
  local type, err = symbol.value:eval_type(params)
  if err then
    if except.isexception(err) then
      except.reraise(err)
    else
      node:raisef('error in generic instantiation: %s', err)
    end
  end
  attr.type = primtypes.type
  attr.value = type
end

local function iargnodes(argnodes)
  local i = 0
  local lastargindex = #argnodes
  local lastargnode = argnodes[#argnodes]
  local calleetype = lastargnode and lastargnode.attr.calleetype
  if lastargnode and lastargnode.tag:sub(1,4) == 'Call' and calleetype and
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
        if callretindex > 1 then
          -- mark node as multiple returns for usage later
          lastargnode.attr.multirets = true
        end
        return i, nil, argtype, callretindex
      end
    end
  end
  return function()
    i = i + 1
    local argnode = argnodes[i]
    if not argnode then return nil end
    return i, argnode, argnode.attr.type
  end
end

local function izipargnodes(vars, argnodes)
  local iter = iters.izip(vars, argnodes)
  local lastargindex = #argnodes
  local lastargnode = argnodes[#argnodes]
  local calleetype = lastargnode and lastargnode.attr.calleetype
  if lastargnode and lastargnode.tag:sub(1,4) == 'Call' and (not calleetype or not calleetype.is_type) then
    -- last arg is a runtime call
    if calleetype then
      if calleetype.is_any then
        -- calling any types makes last arguments always a varanys
        return function()
          local i, var, argnode = iter()
          local argtype = argnode and argnode.attr.type
          if not i then return nil end
          if i == lastargindex then
            assert(argtype and argtype.is_varanys)
          end
          return i, var, argnode, argtype
        end
      else
        -- we know the callee type
        return function()
          local i, var, argnode = iter()
          if not i then return nil end
          if i >= lastargindex then
            -- argnode does not exists, fill with multiple returns type
            -- in case it doest not exists, the argtype will be nil type
            local callretindex = i - lastargindex + 1
            local argtype = calleetype:get_return_type(callretindex) or primtypes.nilable
            if callretindex > 1 then
              lastargnode.attr.multirets = true
            end
            return i, var, argnode, argtype, callretindex
          else
            return i, var, argnode, argnode.attr.type, nil
          end
        end
      end
    else
      -- call type is now known yet, argtype will be nil
      return function()
        local i, var, argnode = iter()
        if not i then return end
        return i, var, argnode, argnode and argnode.attr.type
      end
    end
  else
    -- no calls from last argument
    return function()
      local i, var, argnode = iter()
      if not i then return end
      -- in case this is inexistent, set argtype to nil type
      local argtype
      if argnode then
        argtype = argnode.attr.type
      else
        argtype = primtypes.nilable
      end
      return i, var, argnode, argtype
    end
  end
end

local function visitor_Call_typeassertion(context, node, argnodes, type)
  local attr = node.attr
  assert(type)
  if type.is_generic then
    node:raisef("assertion to generic '%s': cannot do assertion on generics", type:prettyname())
  end
  if #argnodes > 1 then
    node:raisef("assertion to type '%s': expected at most 1 argument, but got %d",
      type:prettyname(), #argnodes)
  end
  local argnode = argnodes[1]
  if argnode then
    argnode.desiredtype = type
    context:traverse_node(argnode)
    local argtype = argnode.attr.type
    if argtype then
      local ok, err = type:is_convertible_from(argnode, true)
      if not ok then
        argnode:raisef("in type assertion: %s", err)
      end
      if argnode.attr.comptime then
        attr.value = type:normalize_value(argnode.attr.value)
        if attr.value or argtype == type then
          attr.comptime = true
        end
      end
    end
    attr.sideeffect = argnode.attr.sideeffect
  end
  attr.typeassertion = true
  attr.type = type
  attr.calleetype = primtypes.type
end

local function visitor_Call(context, node, argnodes, calleetype, calleesym, calleeobjnode)
  local attr = node.attr
  if calleetype then
    if calleetype.is_function then
      -- function call
      local funcargtypes = calleetype.argtypes
      local funcargattrs = calleetype.argattrs or calleetype.args
      local pseudoargtypes = funcargtypes
      local pseudoargattrs = funcargattrs
      if calleeobjnode then
        pseudoargtypes = tabler.copy(funcargtypes)
        pseudoargattrs = tabler.copy(funcargattrs)
        local ok, err = funcargtypes[1]:is_convertible_from(calleeobjnode)
        if not ok then
          node:raisef("in call of function '%s' at argument %d: %s",
            calleetype:prettyname(), 1, err)
        end
        table.remove(pseudoargtypes, 1)
        table.remove(pseudoargattrs, 1)
        attr.pseudoargtypes = pseudoargtypes
        attr.pseudoargattrs = pseudoargtypes
      end
      if #argnodes > #pseudoargattrs then
        node:raisef("in call of function '%s': expected at most %d arguments but got %d",
          calleetype:prettyname(), #pseudoargattrs, #argnodes)
      end
      local lazyargs = {}
      local knownallargs = true
      for i,funcarg,argnode,argtype in izipargnodes(pseudoargattrs, argnodes) do
        local arg
        local funcargtype
        if traits.is_type(funcarg) then funcargtype = funcarg else
          funcargtype = funcarg.type
        end
        if argnode then
          argnode.desiredtype = argnode.desiredtype or funcargtype
          context:traverse_node(argnode)
          argtype = argnode.attr.type
          argnode, argtype = visitor_convert(context, argnodes, i, funcargtype, argnode, argtype)
          if argtype then
            arg = argnode.attr
          end
        else
          arg = argtype
        end

        if argtype and argtype.is_nil and not funcargtype.is_nilable then
          node:raisef("in call of function '%s': expected an argument at index %d but got nothing",
            calleetype:prettyname(), i)
        end
        if arg then
          local argattr = arg
          if traits.is_type(arg) then
            argattr = Attr{type=arg}
          end
          local wantedtype, err = funcargtype:is_convertible_from_attr(argattr)
          if not wantedtype then
            node:raisef("in call of function '%s' at argument %d: %s",
              calleetype:prettyname(), i, err)
          end

          if funcargtype ~= wantedtype and argnode then
            -- new type suggested, need to traverse again
            argnode.desiredtype = wantedtype
            context:traverse_node(argnode)
          end
          funcargtype = wantedtype

          -- check again the new type
          wantedtype, err = funcargtype:is_convertible_from_attr(argattr)
          if not wantedtype then
            node:raisef("in call of function '%s' at argument %d: %s",
              calleetype:prettyname(), i, err)
          end

          if not context.pragmas.nochecks and funcargtype ~= argtype and argnode then
            argnode.checkcast = true
          end
        else
          knownallargs = false
        end

        if calleetype.is_lazyfunction then
          if funcargtype.is_lazyable then
            lazyargs[i] = arg
          else
            lazyargs[i] = funcargtype
          end
        end

        if calleeobjnode and argtype and pseudoargtypes[i].is_lazyable then
          pseudoargtypes[i] = argtype
        end
      end
      if calleeobjnode then
        tabler.insert(lazyargs, 1, funcargtypes[1])
      end
      if calleetype.is_lazyfunction then
        local lazycalleetype = calleetype
        calleetype = nil
        calleesym = nil
        if knownallargs then
          local lazyeval = lazycalleetype:eval_lazy_for_args(lazyargs)
          if lazyeval and lazyeval.node and lazyeval.node.attr.type then
            calleesym = lazyeval.node.attr
            calleetype = lazyeval.node.attr.type
          else
            -- must traverse the lazy function scope again to infer types for assignment to this call
            context.rootscope:delay_resolution()
          end
        end
      end
      attr.calleesym = calleesym
      if calleetype then
        attr.type = calleetype:get_return_type(1)
        assert(calleetype.sideeffect ~= nil)
        attr.sideeffect = calleetype.sideeffect
      end
    elseif calleetype.is_table then
      context:traverse_nodes(argnodes)
      -- table call (allowed for tables with metamethod __index)
      attr.type = primtypes.varanys
      attr.sideeffect = true
    elseif calleetype.is_any then
      context:traverse_nodes(argnodes)
      -- call on any values
      attr.type = primtypes.varanys
      -- builtins usually don't have side effects
      attr.sideeffect = not attr.builtin
    else
      -- call on invalid types (i.e: numbers)
      node:raisef("cannot call type '%s'", calleetype:prettyname())
    end
    attr.calleetype = calleetype
  else
    context:traverse_nodes(argnodes)
  end
end

function visitors.Call(context, node)
  local attr = node.attr
  local argnodes, calleenode = node[1], node[2]

  context:traverse_node(calleenode)

  local calleeattr = calleenode.attr
  local calleetype = calleeattr.type
  local calleesym
  if traits.is_symbol(calleeattr) then
    calleesym = calleeattr
  end
  if calleetype and calleetype.is_pointer then
    calleetype = calleetype.subtype
    assert(calleetype)
    attr.pointercall = true
  end

  if calleetype and calleetype.is_type then
    visitor_Call_typeassertion(context, node, argnodes, calleeattr.value)
  else
    visitor_Call(context, node, argnodes, calleetype, calleesym)

    if calleeattr.builtin then
      local builtinfunc = builtins[calleeattr.name]
      if builtinfunc then
        builtinfunc(context, node)
      end
    end
  end
end

function visitors.CallMethod(context, node)
  local name, argnodes, calleeobjnode = node[1], node[2], node[3]
  local attr = node.attr

  context:traverse_nodes(argnodes)
  context:traverse_node(calleeobjnode)

  local calleetype = calleeobjnode.attr.type
  local calleesym = nil
  if calleetype then
    if calleetype.is_pointer then
      calleetype = calleetype.subtype
      assert(calleetype)
      attr.pointercall = true
    end

    if calleetype.is_record then
      calleesym = calleetype:get_metafield(name)
      if not calleesym then
        node:raisef("cannot index record meta field '%s'", name)
      end
      calleetype = calleesym.type
    elseif calleetype.is_any then
      calleetype = primtypes.any
    end
  end

  visitor_Call(context, node, argnodes, calleetype, calleesym, calleeobjnode)
end

local function visitor_Record_FieldIndex(_, node, objtype, name)
  local field = objtype:get_field(name)
  local type = field and field.type
  if not type then
    node:raisef("cannot index field '%s' on record '%s'", name, objtype:prettyname())
  end
  node.attr.type = type
end

local function visitor_EnumType_FieldIndex(_, node, objtype, name)
  local attr = node.attr
  local field = objtype:get_field(name)
  if not field then
    node:raisef("cannot index field '%s' on enum '%s'", name, objtype:prettyname())
  end
  attr.comptime = true
  attr.value = field.value
  attr.type = objtype
end

local function visitor_RecordType_FieldIndex(context, node, objtype, name)
  local attr = node.attr
  local symbol = objtype:get_metafield(name)
  local parentnode = context:get_parent_node()
  local infuncdef = context.state.infuncdef == parentnode
  local inglobaldecl = context.state.inglobaldecl == parentnode
  local inlazydef = context.state.inlazydef and symbol == context.state.inlazydef
  if inlazydef then
    assert(infuncdef)
    if traits.is_symbol(attr) then
      symbol = attr
    else
      symbol = nil
    end
  end
  if not symbol then
    local symname = string.format('%s.%s', objtype.name, name)
    symbol = Symbol.promote_attr(attr, symname, node)
    symbol.codename = string.format('%s_%s', objtype.codename, name)
    symbol:link_node(parentnode)
    if infuncdef then
      -- declaration of record global function
      symbol.metafunc = true
      if node.tag == 'ColonIndex' then
        symbol.metafuncselftype = types.get_pointer_type(objtype)
      end
    elseif inglobaldecl then
      -- declaration of record global variable
      symbol.metafield = true
    else
      node:raisef("cannot index record meta field '%s'", name)
    end
    if not inlazydef then
      objtype:set_metafield(name, symbol)
    else
      symbol.shadows = true
    end
    symbol.annonymous = true
    symbol.scope = context.rootscope
  elseif infuncdef or inglobaldecl then
    if symbol.node ~= node then
      node:raisef("cannot redefine meta type field '%s'", name)
    end
  else
    symbol:link_node(node)
  end
  return symbol
end

local function visitor_Type_FieldIndex(context, node, objtype, name)
  objtype = objtype:auto_deref_type()
  node.indextype = objtype
  if objtype.is_enum then
    return visitor_EnumType_FieldIndex(context, node, objtype, name)
  elseif objtype.is_record then
    return visitor_RecordType_FieldIndex(context, node, objtype, name)
  else
    node:raisef("cannot index fields on type '%s'", objtype:prettyname())
  end
end

local function visitor_FieldIndex(context, node)
  local attr = node.attr
  local name, objnode = node[1], node[2]
  context:traverse_node(objnode)
  local objtype = objnode.attr.type
  local ret
  if objtype then
    objtype = objtype:auto_deref_type()
    if objtype.is_record then
      ret = visitor_Record_FieldIndex(context, node, objtype, name)
    elseif objtype.is_type then
      ret = visitor_Type_FieldIndex(context, node, objnode.attr.value, name)
    elseif objtype.is_table or objtype.is_any then
      attr.type = primtypes.any
    else
      node:raisef("cannot index field '%s' on type '%s'", name, objtype.name)
    end
  end
  if objnode.attr.lvalue then
    attr.lvalue = true
  end
  return ret
end

visitors.DotIndex = visitor_FieldIndex
visitors.ColonIndex = visitor_FieldIndex

local function visitor_Record_ArrayIndex(context, node, objtype, objnode, indexnode)
  local attr = node.attr
  local indexsym = objtype:get_metafield('__index')
  local indexretype
  if not indexsym then
    indexsym = objtype:get_metafield('__atindex')
    if indexsym and indexsym.type then
      indexretype = indexsym.type:get_return_type(1)
      if indexretype and not indexretype.is_pointer then
        indexsym.node:raisef("metamethod `__atindex` must return a pointer, but got type '%s'",
          indexretype:prettyname())
      else
        indexretype = indexretype.subtype
        attr.lvalue = true
      end
    end
  end
  if indexsym then
    visitor_Call(context, node, {indexnode}, indexsym.type, indexsym, objnode)
    node.attr.type = indexretype
  else
    node:raisef("cannot index record of type '%s': no `__index` or `__atindex` metamethod found", objtype:prettyname())
  end
end

function visitors.ArrayIndex(context, node)
  local indexnode, objnode = node[1], node[2]
  context:traverse_node(indexnode)
  context:traverse_node(objnode)
  local type = node.attr.type
  if type then return end
  local objtype = objnode.attr.type
  if objtype then
    objtype = objtype:auto_deref_type()
    if objtype.is_array then
      local indextype = indexnode.attr.type
      local checked = false
      if indextype then
        if indextype.is_integral then
          local indexvalue = indexnode.attr.value
          if indexvalue then
            if indexvalue:isneg() then
              indexnode:raisef("cannot index negative value %s", indexvalue:todec())
            end
            if objtype.is_array and objtype.length ~= 0 and not (indexvalue < bn.new(objtype.length)) then
              indexnode:raisef("index %s is out of bounds, array maximum index is %d",
                indexvalue:todec(), objtype.length - 1)
            end
            checked = true
          end
          type = objtype.subtype
        else
          indexnode:raisef("cannot index with value of type '%s'", indextype:prettyname())
        end
      end
      if not context.pragmas.nochecks and not checked and objtype.length > 0 then
        node.attr.checkbounds = true
      end
      if objnode.attr.lvalue then
        node.attr.lvalue = true
      end
    elseif objtype.is_record then
      visitor_Record_ArrayIndex(context, node, objtype, objnode, indexnode)
    elseif objtype.is_table or objtype.is_any then
      type = primtypes.any
    else
      node:raisef("cannot index variable of type '%s'", objtype.name)
    end
  end
  if type then
    node.attr.type = type
  end
end

function visitors.Block(context, node)
  if node.preprocess then
    local scope = context:push_forked_cleaned_scope('block', node)

    local ok, err = except.trycall(function()
      node:preprocess()
    end)
    if not ok then
      if except.isexception(err) then
        except.reraise(err)
      else
        node:raisef('error while preprocessing block: %s', err)
      end
    end
    node.preprocess = nil

    local resolutions_count = scope:resolve()
    context:pop_scope()
    if resolutions_count == 0 then
      return
    end
  end
  local statnodes = node[1]

  local scope
  repeat
    scope = context:push_forked_cleaned_scope('block', node)
    context:traverse_nodes(statnodes)
    local resolutions_count = scope:resolve()
    context:pop_scope()
  until resolutions_count == 0
end

function visitors.If(context, node)
  local iflist, elsenode = node[1], node[2]
  for _,ifpair in ipairs(iflist) do
    local ifcondnode, ifblocknode = ifpair[1], ifpair[2]
    ifcondnode.desiredtype = primtypes.boolean
    ifcondnode.attr.inconditional = true
    context:traverse_node(ifcondnode)
    context:traverse_node(ifblocknode)
  end
  if elsenode then
    context:traverse_node(elsenode)
  end
end

function visitors.Switch(context, node)
  local valnode, caseparts, elsenode = node[1], node[2], node[3]
  context:traverse_node(valnode)
  local valtype = valnode.attr.type
  if valtype and not (valtype.is_any or valtype.is_integral) then
    valnode:raisef(
      "`switch` statement must be convertible to an integral type, but got type `%s` (non integral)",
      valtype:prettyname())
  end
  for _,casepart in ipairs(caseparts) do
    local casenode, blocknode = casepart[1], casepart[2]
    context:traverse_node(casenode)
    if not (casenode.attr.type and casenode.attr.type.is_integral and
           (casenode.attr.comptime or casenode.attr.cimport)) then
      casenode:raisef("`case` statement must evaluate to a compile time integral value")
    end
    context:traverse_node(blocknode)
  end
  if elsenode then
    context:traverse_node(elsenode)
  end
end

function visitors.While(context, node)
  local condnode, blocknode = node[1], node[2]
  condnode.desiredtype = primtypes.boolean
  condnode.attr.inconditional = true
  context:traverse_node(condnode)
  context:traverse_node(blocknode)
end

function visitors.Repeat(context, node)
  local blocknode, condnode = node[1], node[2]
  condnode.desiredtype = primtypes.boolean
  condnode.attr.inconditional = true
  context:traverse_node(blocknode)

  context:push_scope(blocknode.scope)
  context:traverse_node(condnode)
  context:pop_scope()
end

function visitors.ForIn(context, node)
  local _, inexpnodes, blocknode = node[1], node[2], node[3]
  assert(#inexpnodes > 0)
  if #inexpnodes > 3 then
    node:raisef("`in` statement can have at most 3 arguments")
  end
  local infuncnode = inexpnodes[1]
  local infunctype = infuncnode.attr.type
  if infunctype and not (infunctype.is_any or infunctype.is_function) then
    node:raisef("first argument of `in` statement must be a function, but got type '%s'",
      infunctype:prettyname())
  end
  context:traverse_nodes(inexpnodes)

  repeat
    local scope = context:push_forked_cleaned_scope('loop', node)
  --[[
  if itvarnodes then
    for i,itvarnode in ipairs(itvarnodes) do
      local itsymbol = context:traverse_node(itvarnode)
      if infunctype and infunctype.is_function then
        local fittype = infunctype:get_return_type(i)
        itsymbol:add_possible_type(fittype)
      end
    end
  end
    ]]
    context:traverse_node(blocknode)

    local resolutions_count = scope:resolve()
    context:pop_scope()
  until resolutions_count == 0
end

function visitors.ForNum(context, node)
  local itvarnode, begvalnode, compop, endvalnode, stepvalnode, blocknode =
        node[1], node[2], node[3], node[4], node[5], node[6]
  local itname = itvarnode[1]
  context:traverse_node(begvalnode)
  context:traverse_node(endvalnode)
  local btype, etype = begvalnode.attr.type, endvalnode.attr.type
  local sattr, stype
  if stepvalnode then
    context:traverse_node(stepvalnode)
    sattr = stepvalnode.attr
    stype = sattr.type
  end

  repeat
    local scope = context:push_forked_cleaned_scope('loop', node)

    local itsymbol = context:traverse_node(itvarnode)
    local itattr = itvarnode.attr
    local ittype = itattr.type
    if ittype then
      if not (ittype.is_arithmetic or (ittype.is_any and not ittype.is_varanys)) then
        itvarnode:raisef("`for` variable '%s' must be a number, but got type '%s'", itname, ittype)
      end
      if btype then
        local ok, err = ittype:is_convertible_from(begvalnode)
        if not ok then
          begvalnode:raisef("in `for` begin variable '%s': %s", itname, err)
        end
        if not context.pragmas.nochecks and ittype ~= btype then
          begvalnode.checkcast = true
        end
      end
      if etype then
        local ok, err = ittype:is_convertible_from(endvalnode)
        if not ok then
          endvalnode:raisef("in `for` end variable '%s': %s", itname, err)
        end
        if not context.pragmas.nochecks and ittype ~= etype then
          endvalnode.checkcast = true
        end
      end
      if stype then
        local optype, _, err = ittype:binary_operator('add', stype, itattr, sattr)
        if stype.is_float and ittype.is_integral then
          err = 'cannot have fractional step for an integral iterator'
        end
        if err then
          stepvalnode:raisef("in `for` step variable '%s': %s", itname, err)
        end
      end
    else
      itsymbol:add_possible_type(btype)
      itsymbol:add_possible_type(etype)
    end
    itsymbol.scope:add_symbol(itsymbol)
    context:traverse_node(blocknode)

    local resolutions_count = scope:resolve()
    context:pop_scope()
  until resolutions_count == 0

  local fixedstep
  local stepvalue
  if stype and stype.is_arithmetic and stepvalnode.attr.comptime then
    -- constant step
    fixedstep = stepvalnode
    stepvalue = stepvalnode.attr.value
    if stepvalue:iszero() then
      stepvalnode:raisef("`for` step cannot be zero")
    end
  elseif not stepvalnode then
    -- default step is '1'
    stepvalue = bn.new(1)
    fixedstep = '1'
  end
  local fixedend
  if etype and etype.is_arithmetic and endvalnode.attr.comptime then
    fixedend = true
  end
  if not compop and stepvalue then
    -- we now that the step is a constant numeric value
    -- compare operation must be `ge` ('>=') when step is negative
    compop = stepvalue:isneg() and 'ge' or 'le'
  end
  node.attr.fixedstep = fixedstep
  node.attr.fixedend = fixedend
  node.attr.compop = compop
end

function visitors.VarDecl(context, node)
  local varscope, varnodes, valnodes = node[1], node[2], node[3]
  local assigning = not not valnodes
  valnodes = valnodes or {}
  if #varnodes < #valnodes then
    node:raisef("extra expressions in declaration, expected at most %d but got %d",
    #varnodes, #valnodes)
  end
  for i,varnode,valnode,valtype in izipargnodes(varnodes, valnodes) do
    assert(varnode.tag == 'IdDecl')
    varnode.attr.vardecl = true
    if varscope == 'global' then
      if not context.scope:is_topscope() then
        varnode:raisef("global variables can only be declared in top scope")
      end
      varnode.attr.global = true
    end
    if varscope == 'global' or context.scope:is_topscope() then
      varnode.attr.staticstorage = true
    end
    if context.pragmas.nostatic then
      varnode.attr.nostatic = true
    end
    local symbol = context:traverse_node(varnode)
    assert(symbol)
    local inscope = false
    if valnode and valnode.tag == 'TypeInstance' then
      symbol.scope:add_symbol(symbol)
      inscope = true
    end
    local vartype = varnode.attr.type
    if vartype and vartype.is_nolvalue then
      varnode:raisef("variable declaration cannot be of the type '%s'", vartype:prettyname())
    end
    assert(symbol.type == vartype)
    varnode.assign = true
    if (varnode.attr.comptime or varnode.attr.const) and not varnode.attr.nodecl and not valnode then
      varnode:raisef("const variables must have an initial value")
    end
    if valnode then
      valnode.desiredtype = valnode.desiredtype or vartype
      context:traverse_node(valnode, symbol)
      valtype = valnode.attr.type
      valnode, valtype = visitor_convert(context, valnodes, i, vartype, valnode, valtype)

      if valtype then
        if valtype.is_varanys then
          -- varanys are always stored as any in variables
          valtype = primtypes.any
        elseif not vartype and valtype.is_nil then
          -- untyped variables assigned to nil always store as any type
          valtype = primtypes.any
        end
      end
      if varnode.attr.comptime and not (valnode.attr.comptime and valtype) then
        varnode:raisef("compile time variables can only assign to compile time expressions")
      elseif vartype and not valtype and vartype.is_auto then
        varnode:raisef("auto variables must be assigned to expressions where type is known ahead")
      elseif varnode.attr.cimport and not
        (vartype == primtypes.type or (vartype == nil and valtype == primtypes.type)) then
        varnode:raisef("cannot assign imported variables, only imported types can be assigned")
      end
    else
      if context.pragmas.noinit then
        varnode.attr.noinit = true
      end
    end
    if not inscope then
      symbol.scope:add_symbol(symbol)
    end
    if assigning and valtype then
      if valtype.is_void then
        varnode:raisef("cannot assign to expressions of type 'void'")
      end
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
        symbol.value:suggest_nick(symbol.name, symbol.staticstorage and symbol.codename)
        symbol.value.symbol = symbol
      end

      if vartype and vartype.is_auto then
        assignvaltype = vartype ~= valtype
      end

      if assignvaltype then
        vartype = valtype
        symbol.type = vartype

        local annotnode = varnode[3]
        if annotnode then
          -- must traverse again annotation node early once type is found ahead
          context:traverse_node(annotnode, symbol)
        end
      end
      if vartype then
        if valnode and vartype:is_initializable_from_attr(valnode.attr) then
          valnode.attr.initializer = true
        end
        local ok, err = vartype:is_convertible_from(valnode or valtype)
        if not ok then
          varnode:raisef("in variable '%s' declaration: %s", symbol.name, err)
        end
        if not context.pragmas.nochecks and valnode and vartype ~= valtype then
          valnode.checkcast = true
          varnode.checkcast = true
        end
      end
    end
    if assigning then
      symbol:add_possible_type(valtype)
    end
  end
end

function visitors.Assign(context, node)
  local varnodes, valnodes = node[1], node[2]
  if #varnodes < #valnodes then
    node:raisef("extra expressions in assign, expected at most %d but got %d", #varnodes, #valnodes)
  end
  for i,varnode,valnode,valtype in izipargnodes(varnodes, valnodes) do
    local symbol = context:traverse_node(varnode)
    local vartype = varnode.attr.type
    local varattr = varnode.attr
    varnode.assign = true
    if varattr.const or varattr.comptime then
      varnode:raisef("cannot assign a constant variable")
    end
    if valnode then
      valnode.desiredtype = vartype
      context:traverse_node(valnode)
      valtype = valnode.attr.type
      valnode, valtype = visitor_convert(context, valnodes, i, vartype, valnode, valtype)
    end
    if valtype then
      if valtype.is_void then
        varnode:raisef("cannot assign to expressions of type 'void'")
      end
      if valtype and valtype.is_varanys then
        -- varanys are always stored as any in variables
        valtype = primtypes.any
      end
    end
    if symbol then -- symbol may nil in case of array/dot index
      symbol:add_possible_type(valtype)
      symbol.mutate = true
    end
    if not valnode and valtype and valtype.is_nil then
      varnode:raisef("variable assignment at index '%d' is assigning to nothing in the expression", i)
    end
    if vartype and valtype then
      local from = valnode or valtype
      local ok, err = vartype:is_convertible_from(from)
      if not ok then
        varnode:raisef("in variable assignment: %s", err)
      end
      if not context.pragmas.nochecks and valnode and vartype ~= valtype then
        valnode.checkcast = true
        varnode.checkcast = true
      end
    end
  end
end

function visitors.Return(context, node)
  local retnodes = node[1]
  context:traverse_nodes(retnodes)
  local funcscope = context.scope:get_parent_of_kind('function') or context.rootscope
  if funcscope.returntypes then
    for i,funcrettype,retnode,rettype in izipargnodes(funcscope.returntypes, retnodes) do
      if rettype then
        if funcrettype then
          if rettype.is_nil and not funcrettype.is_nilable then
            node:raisef("missing return expression at index %d of type '%s'", i, funcrettype:prettyname())
          end
          if retnode and rettype then
            retnode, rettype = visitor_convert(context, retnodes, i, funcrettype, retnode, rettype)
          end
          if rettype then
            local ok, err = funcrettype:is_convertible_from(retnode or rettype)
            if not ok then
              (retnode or node):raisef("return at index %d: %s", i, err)
            end
            if not context.pragmas.nochecks and retnode and funcrettype ~= rettype then
              retnode.checkcast = true
            end
          end
        else
          if #retnodes ~= 0 then
            node:raisef("invalid return expression at index %d", i)
          end
        end
      end
    end
  else
    for i,_,rettype in iargnodes(retnodes) do
      funcscope:add_return_type(i, rettype)
    end
  end
end

local function resolve_function_argtypes(symbol, varnode, argnodes, scope, checklazy)
  local islazyparent = false
  local argattrs = {}
  local argtypes = {}

  for i,argnode in ipairs(argnodes) do
    local argattr = argnode.attr
    local argtype = argattr.type
    if not argtype then
    -- function arguments types must be known ahead, fallbacks to any if untyped
      argtype = primtypes.any
      argattr.type = argtype
    end
    if checklazy and argtype.is_lazyable then
      islazyparent = true
    end
    argtypes[i] = argtype
    argattrs[i] = argattr
  end

  if varnode.tag == 'ColonIndex' and symbol and symbol.metafunc then
    -- inject 'self' type as first argument
    local selfsym = symbol.selfsym
    if not selfsym then
      selfsym = Symbol()
      selfsym:init('self')
      selfsym.codename = 'self'
      selfsym.lvalue = true
      selfsym.type = symbol.metafuncselftype
      symbol.selfsym = selfsym
    end
    table.insert(argtypes, 1, symbol.metafuncselftype)
    table.insert(argattrs, 1, selfsym)
    scope:add_symbol(selfsym)
  end

  return argattrs, argtypes, islazyparent
end

local function block_endswith_return(blocknode)
  assert(blocknode.tag == 'Block')
  local statnodes = blocknode[1]
  local laststat = statnodes[#statnodes]
  if not laststat then return false end
  if laststat.tag == 'Return' then
    blocknode.attr.returnending = true
    return true
  elseif laststat.tag == 'Do' then
    return block_endswith_return(laststat[1])
  elseif laststat.tag == 'Switch' or laststat.tag == 'If' then
    for _,pair in ipairs(laststat[laststat.nargs-1]) do
      if not block_endswith_return(pair[2]) then
        return false
      end
    end
    local elseblock = laststat[laststat.nargs]
    if elseblock then
      return block_endswith_return(elseblock)
    end
  end
  return false
end

local function check_function_returns(node, returntypes, blocknode)
  local attr = node.attr
  local functype = attr.type
  if not functype or functype.is_lazyfunction or attr.nodecl or attr.cimport or attr.hookmain then
    return
  end
  if #returntypes > 0 then
    local canbeempty = tabler.iall(returntypes, function(rettype)
      return rettype.is_nilable
    end)
    if not canbeempty and not block_endswith_return(blocknode) then
      node:raisef("a return statement is missing before function end")
    end
  end
end

local function visitor_FuncDef_variable(context, varscope, varnode)
  local decl = varscope ~= nil
  if varscope == 'global' then
    if not context.scope:is_topscope() then
      varnode:raisef("global function can only be declared in top scope")
    end
    varnode.attr.global = true
  end
  if varscope == 'global' or context.scope:is_topscope() then
    varnode.attr.staticstorage = true
  end
  if decl then
    varnode.attr.funcdecl = true
  end
  if context.pragmas.nostatic then
    varnode.attr.nostatic = true
  end
  local symbol = context:traverse_node(varnode)
  if symbol and symbol.metafunc then
    decl = true
  end
  return symbol, decl
end

local function visitor_FuncDef_returns(context, functype, retnodes)
  local returntypes
  context:traverse_nodes(retnodes)
  if #retnodes > 0 then
    -- returns types are predeclared
    returntypes = tabler.imap(retnodes, function(retnode)
      return retnode.attr.value
    end)

    if #returntypes == 1 and returntypes[1].is_void then
      -- single void type means no returns
      returntypes = {}
    end
  elseif functype and functype.is_function and not functype.returntypes.has_unknown then
    -- use return types from previous traversal only if fully resolved
    returntypes = functype.returntypes
  end
  return returntypes
end

function visitors.FuncDef(context, node, lazysymbol)
  local varscope, varnode, argnodes, retnodes, annotnodes, blocknode =
        node[1], node[2], node[3], node[4], node[5], node[6]

  local state = context:push_state()
  state.infuncdef = node
  state.inlazydef = lazysymbol
  local symbol, decl = visitor_FuncDef_variable(context, varscope, varnode)
  if symbol then
    symbol.scope:add_symbol(symbol)
  end
  context:pop_state()

  local returntypes = visitor_FuncDef_returns(context, node.attr.type, retnodes)

  -- repeat scope to resolve function variables and return types
  local islazyparent, argtypes, argattrs

  local funcscope
  repeat
    funcscope = context:push_forked_cleaned_scope('function', node)

    funcscope.returntypes = returntypes
    context:traverse_nodes(argnodes)
    for _,argnode in ipairs(argnodes) do
      if argnode.attr.scope then
        argnode.attr.scope:add_symbol(argnode.attr)
      end
    end
    argattrs, argtypes, islazyparent = resolve_function_argtypes(symbol, varnode, argnodes, funcscope, not lazysymbol)

    if not islazyparent then
      -- lazy functions never traverse the blocknode by itself
      context:traverse_node(blocknode)
    end

    local resolutions_count = funcscope:resolve()
    context:pop_scope()
  until resolutions_count == 0

  if not islazyparent and not returntypes then
    returntypes = funcscope.resolved_returntypes
  end

  -- set the function type
  local type = node.attr.type
  if islazyparent then
    assert(not lazysymbol)
    if not type then
      type = types.LazyFunctionType(node, argattrs, returntypes)
    end
  elseif not returntypes.has_unknown then
    type = types.FunctionType(node, argattrs, returntypes)
  end

  if symbol then -- symbol may be nil in case of array/dot index
    if decl then
      -- declaration always set the type
      symbol.type = type
    else
      -- check if previous symbol declaration is compatible
      local symboltype = symbol.type
      if symboltype then
        local ok, err = symboltype:is_convertible_from(type)
        if not ok then
          node:raisef("in function definition: %s", err)
        end
      else
        symbol:add_possible_type(type)
      end
    end
    symbol:link_node(node)
  else
    node.attr.type = type
  end

  -- once the type is know we can traverse annotation nodes
  if annotnodes then
    context:traverse_nodes(annotnodes, symbol)
  end

  -- type checking for returns
  check_function_returns(node, returntypes, blocknode)

  do -- handle attributes and annotations
    local attr = node.attr

    -- annotation cimport
    if attr.cimport then
      if #blocknode[1] ~= 0 then
        blocknode:raisef("body of an import function must be empty")
      end
      if attr.codename == 'nelua_main' then
        context.hookmain = true
      end
    end

    -- annotation sideeffect, the function has side effects unless told otherwise
    if type then
      type.sideeffect = not attr.nosideeffect
    end

    -- annotation entrypoint
    if attr.entrypoint then
      if context.entrypoint and context.entrypoint ~= node then
        node:raisef("cannot have more than one function entrypoint")
      end
      attr.codename = attr.name
      attr.declname = attr.name
      context.entrypoint = node
    end
  end

  -- traverse lazy function nodes
  if islazyparent then
    for _,lazyeval in ipairs(type.evals) do
      local lazynode = lazyeval.node
      if not lazynode then
        lazynode = node:clone()
        lazyeval.node = lazynode
        local lazyargnodes = lazynode[3]
        for j,lazyarg in ipairs(lazyeval.args) do
          if varnode.tag == 'ColonIndex' then
            j = j - 1
          end
          if lazyargnodes[j] then
            local lazyargattr = lazyargnodes[j].attr
            if traits.is_attr(lazyarg) then
              lazyargattr.type = lazyarg.type
              if lazyarg.type.is_comptime then
                lazyargattr.value = lazyarg.value
              end
            else
              lazyargattr.type = lazyarg
            end
            assert(traits.is_type(lazyargattr.type))
          end
        end
      end
      context:traverse_node(lazynode, symbol)
      assert(traits.is_symbol(lazynode.attr))
    end
  end
end

local overridable_operators = {
  ['eq'] = true,
  ['lt'] = true,
  ['le'] = true,
  ['bor'] = true,
  ['bxor'] = true,
  ['band'] = true,
  ['shl'] = true,
  ['shr'] = true,
  ['concat'] = true,
  ['add'] = true,
  ['sub'] = true,
  ['mul'] = true,
  ['idiv'] = true,
  ['div'] = true,
  ['pow'] = true,
  ['mod'] = true,
  ['len'] = true,
  ['unm'] = true,
  ['bnot'] = true,
}

local function override_unary_op(context, node, opname, objnode, objtype)
  objtype = objtype:auto_deref_type()
  if not overridable_operators[opname] or not objtype.is_record then return end
  local mtname = '__' .. opname
  local mtsym = objtype:get_metafield(mtname)
  if not mtsym then
    return
  end

  -- transform into call
  local n = context.parser.astbuilder.aster
  local objsym = objtype.symbol
  assert(objsym)
  local idnode = n.Id{objsym.name}
  local pattr = Attr{foreignsymbol=objsym}
  idnode.attr:merge(pattr)
  idnode.pattr = pattr
  local newnode = n.Call{{objnode}, n.DotIndex{mtname, idnode}}
  node:transform(newnode)
  context:traverse_node(node)
  return true
end

function visitors.UnaryOp(context, node)
  local attr = node.attr
  local opname, argnode = node[1], node[2]

  if node.desiredtype == primtypes.boolean or opname == 'not' then
    argnode.desiredtype = primtypes.boolean
  end
  context:traverse_node(argnode)

  -- quick return for already resolved type
  if attr.type then return end

  local argattr = argnode.attr
  argattr.inoperator = true
  local argtype = argattr.type
  local type
  if argtype then
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
  if argnode.tag == 'Id' and opname == 'ref' then
    -- for loops needs to know if an Id symbol could mutate
    argattr.mutate = true
  end
  if opname == 'deref' then
    attr.lvalue = true
  end
  if type then
    attr.type = type
  end
  attr.sideeffect = argattr.sideeffect
end

local function override_binary_op(context, node, opname, lnode, rnode, ltype, rtype)
  if not overridable_operators[opname] then return end
  local objtype, objnode, argnode, mtsym
  local mtname = '__' .. opname
  if ltype.is_record then
    mtsym = ltype:get_metafield(mtname)
    objtype, objnode, argnode = ltype, lnode, rnode
  end
  if not mtsym and rtype.is_record then
    mtsym = rtype:get_metafield(mtname)
    objtype, objnode, argnode = rtype, rnode, lnode
  end
  if not mtsym then
    return
  end

  -- transform into call
  local n = context.parser.astbuilder.aster
  local objsym = objtype.symbol
  assert(objsym)
  local idnode = n.Id{objsym.name}
  local pattr = Attr{foreignsymbol=objsym}
  idnode.attr:merge(pattr)
  idnode.pattr = pattr
  local newnode = n.Call{{objnode, argnode}, n.DotIndex{mtname, idnode}}
  node:transform(newnode)
  context:traverse_node(node)
  return true
end

function visitors.BinaryOp(context, node)
  local opname, lnode, rnode = node[1], node[2], node[3]
  local attr = node.attr
  local isbinaryconditional = opname == 'or' or opname == 'and'

  local wantsboolean
  if isbinaryconditional and node.desiredtype == primtypes.boolean then
    lnode.desiredtype = primtypes.boolean
    rnode.desiredtype = primtypes.boolean
    wantsboolean =  true
  elseif opname == 'or' and lnode.tag == 'BinaryOp' and lnode[1] == 'and' then
    lnode.attr.ternaryand = true
    attr.ternaryor = true
  end

  context:traverse_node(lnode)
  context:traverse_node(rnode)

  -- quick return for already resolved type
  if attr.type then return end

  local lattr, rattr = lnode.attr, rnode.attr
  local ltype, rtype = lattr.type, rattr.type

  lattr.inoperator = true
  rattr.inoperator = true

  if not wantsboolean and isbinaryconditional and rtype and ltype and
    (not rtype.is_boolean or not ltype.is_boolean) then
    attr.dynamic_conditional = true
  end
  attr.sideeffect = lattr.sideeffect or rattr.sideeffect or nil

  local type
  if ltype and rtype then
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
  end
end

function analyzer.analyze(ast, parser, context)
  if not context then
    context = AnalyzerContext(visitors, parser)
  end

  if config.pragma then
    tabler.update(context.pragmas, config.pragma)
  end
  context:push_pragmas()

  if ast.srcname then
    context.pragmas.unitname = pegger.filename_to_unitname(ast.srcname)
  end

  -- phase 1 traverse: preprocess
  preprocessor.preprocess(context, ast)

  -- phase 2 traverse: infer and check types
  repeat
    context:traverse_node(ast)
    local resolutions_count = context.rootscope:resolve()
  until resolutions_count == 0

  for _,cb in ipairs(context.afteranalyze) do
    local ok, err = except.trycall(function()
      cb.f()
    end)
    if not ok then
      cb.node:raisef('error while executing after analyze: %s', err)
    end
  end

  -- phase 3 traverse: infer unset types to 'any' type
  local state = context:push_state()
  state.anyphase = true
  repeat
    context:traverse_node(ast)
    local resolutions_count = context.rootscope:resolve()
  until resolutions_count == 0
  context:pop_state()

  context:pop_pragmas()

  return context
end

return analyzer
