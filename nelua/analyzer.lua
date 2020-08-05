local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local tabler = require 'nelua.utils.tabler'
local pegger = require 'nelua.utils.pegger'
local typedefs = require 'nelua.typedefs'
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
analyzer.visitors = visitors

function visitors.Number(context, node)
  local attr = node.attr
  local base, int, frac, exp, literal = node[1], node[2], node[3], node[4], node[5]
  local value = bn.from(base, int, frac, exp)
  if not literal then
    local desiredtype = node.desiredtype
    -- if the parent node needs an unsigned or float type, we want to use it
    if desiredtype and
       (desiredtype.is_unsigned or desiredtype.is_float) and
       desiredtype:is_inrange(value) then
      attr.type = desiredtype
    else
      attr.untyped = true
      if not (frac or exp) then -- no exponents or fractional part
        if base ~= 'dec' then
          -- the value may still be out range here, but will be wrapped later
          attr.type = primtypes.integer
        elseif primtypes.integer:is_inrange(value) then
          attr.type = primtypes.integer
        else
          attr.type = primtypes.number
        end
      else
        attr.type = primtypes.number
      end
    end
  else
    local type = typedefs.number_literal_types[literal]
    if not type then
      node:raisef("literal suffix '%s' is undefined for numbers", literal)
    end
    if not type:is_inrange(value) then
      node:raisef("value `%s` for literal type `%s` is out of range, "..
        "the minimum is `%s` and maximum is `%s`",
        value:todec(), type, type.min:todec(), type.max:todec())
    end
    attr.type = type
  end
  if context.pragmas.nofloatsuffix then
    attr.nofloatsuffix = true
  end
  attr.value = value
  attr.base = base
  attr.literal = true
  attr.comptime = true
  node.done = true
end

function visitors.String(_, node)
  local attr = node.attr
  local value, literal = node[1], node[2]
  if literal then
    local type = typedefs.string_literals_types[literal]
    if not type then
      node:raisef("literal suffix '%s' is undefined for strings", literal)
    end
    if #value ~= 1 then
      node:raisef("literal suffix '%s' expects a string of length 1")
    end
    attr.type = type
    value = bn.new(string.byte(value))
  else
    if node.desiredtype and node.desiredtype.is_cstring then
      attr.type = primtypes.cstring
    else
      attr.type = primtypes.stringview
    end
  end
  attr.value = value
  attr.comptime = true
  attr.literal = true
  node.done = true
end

function visitors.Boolean(_, node)
  local attr = node.attr
  attr.value = node[1]
  attr.type = primtypes.boolean
  attr.comptime = true
  attr.literal = true
  node.done = true
end

function visitors.Nil(_, node)
  local attr = node.attr
  attr.type = primtypes.niltype
  attr.comptime = true
  attr.literal = true
  node.done = true
end

function visitors.Varargs(_, node)
  node.done = true
end

local function visitor_convert(context, parent, parentindex, vartype, valnode, valtype, conceptargs)
  if not vartype or not valtype then
    -- convert possible only when types are known
    return valnode, valtype
  end
  if vartype.is_concept then
    vartype = vartype:is_convertible_from_attr(valnode.attr, nil, conceptargs)
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
    if vartype.is_stringview or vartype.is_cstring or
       (vartype.is_string and not valtype.is_stringy) then
      -- __convert not allowed on stringy types
      -- because we have __tocstring, __tostring, __tostringview
      return valnode, valtype
    end
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
  newvalnode.src = valnode.src
  newvalnode.pos = valnode.pos
  parent[parentindex] = newvalnode
  context:traverse_node(newvalnode)
  if newvalnode.attr.type then
    if mtname == '__convert' then
      assert(newvalnode.attr.type == objtype)
    else
      assert(vartype == newvalnode.attr.type)
    end
  end
  return newvalnode, newvalnode.attr.type
end

local function visitor_Array_literal(context, node, littype)
  local attr = node.attr
  local childnodes = node[1]
  local subtype = littype.subtype
  if not (#childnodes == littype.length or #childnodes == 0) then
    node:raisef("expected %d values in array literal but got %d", littype.length, #childnodes)
  end
  local comptime = true
  local done = true
  for i=1,#childnodes do
    local childnode = childnodes[i]
    if childnode.tag == 'Pair' then
      childnode:raisef("fields are disallowed for array literals")
    end
    childnode.desiredtype = subtype
    context:traverse_node(childnode)
    local childtype = childnode.attr.type
    childnode, childtype = visitor_convert(context, childnodes, i, subtype, childnode, childtype)
    local childattr = childnode.attr
    if childtype then
      if not childtype:is_initializable_from_attr(childattr) then
        comptime = nil
      end
      local ok, err = subtype:is_convertible_from_attr(childattr)
      if not ok then
        childnode:raisef("in array literal at index %d: %s", i, err)
      end
      if not context.pragmas.nochecks and subtype ~= childtype then
        childnode.checkcast = true
      end
    end
    if not childattr.comptime then
      comptime = nil
    end
    if not childnode.done then
      done = nil
    end
  end
  attr.type = littype
  attr.comptime = comptime
  node.done = done
end

local function visitor_Record_literal(context, node, littype)
  local attr = node.attr
  local childnodes = node[1]
  local comptime = true
  local lastfieldindex = 0
  local done = true
  for i=1,#childnodes do
    local childnode = childnodes[i]
    local parent, parentindex
    local fieldname, fieldvalnode, field, fieldindex
    if childnode.tag == 'Pair' then
      fieldname, fieldvalnode = childnode[1], childnode[2]
      if not traits.is_string(fieldname) then
        childnode:raisef("only string literals are allowed in record's field names")
      end
      field = littype:get_field(fieldname)
      fieldindex = field and field.index or nil
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
      childnode:raisef("field '%s' is not present in record '%s'", fieldname, littype)
    end
    local fieldtype = field.type
    fieldvalnode.desiredtype = fieldtype
    context:traverse_node(fieldvalnode)
    local fieldvaltype = fieldvalnode.attr.type
    fieldvalnode, fieldvaltype = visitor_convert(context, parent, parentindex, fieldtype, fieldvalnode, fieldvaltype)
    local fieldvalattr = fieldvalnode.attr
    lastfieldindex = fieldindex
    if fieldvaltype then
      if not fieldvaltype:is_initializable_from_attr(fieldvalattr) then
        comptime = nil
      end
      local ok, err = fieldtype:is_convertible_from_attr(fieldvalattr)
      if not ok then
        childnode:raisef("in record literal field '%s': %s", fieldname, err)
      end
      if not context.pragmas.nochecks and fieldtype ~= fieldvaltype then
        fieldvalnode.checkcast = true
      end
    end
    if not fieldvalattr.comptime then
      comptime = nil
    end
    childnode.parenttype = littype
    childnode.fieldname = fieldname
    if not fieldvalnode.done then
      done = nil
    end
  end
  attr.type = littype
  attr.comptime = comptime
  node.done = done
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
    if objtype.is_record and objtype.choose_braces_type then
      local err
      desiredtype, err = objtype.choose_braces_type(node[1])
      if not traits.is_type(desiredtype) then
        node:raisef("failed initialize record '%s' from braces: %s",
          objtype, err or 'choose_braces_type failed')
      end
    end
  end
  if not desiredtype or (desiredtype.is_table or desiredtype.is_lazyable) then
    visitor_Table_literal(context, node)
  elseif desiredtype.is_array then
    visitor_Array_literal(context, node, desiredtype)
  elseif desiredtype.is_record then
    visitor_Record_literal(context, node, desiredtype)
  else
    node:raisef("type '%s' cannot be initialized using a table literal", desiredtype)
  end
end

function visitors.PragmaCall(_, node)
  local name = node[1]
  local pragmashape = typedefs.call_pragmas[name]
  node:assertraisef(pragmashape, "pragma '%s' is undefined", name)
  node.done = true
end

local function choose_type_symbol_names(context, symbol)
  local type = symbol.value
  if type:suggest_nickname(symbol.name) then
    if symbol.staticstorage and symbol.codename then
      type:set_codename(symbol.codename)
    else
      local codename = context:choose_codename(symbol.name)
      type:set_codename(codename)
    end
  end
end

function visitors.Annotation(context, node, symbol)
  assert(symbol)
  local name = node[1]

  local paramshape
  local symboltype
  if name == 'comptime' then
    paramshape = true
  else
    symboltype = symbol.type
    if not symboltype or (symboltype.is_type and not symbol.value) then
      if name == 'cimport' and context.state.anyphase then
        node:raisef('imported variables from C must have an explicit type')
      end
      -- in the next traversal we will have the type
      return
    end
    local annotype
    if symboltype.is_procedure then
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

  local params = {}
  for i=1,#argnodes do
    local param = argnodes[i].attr.value
    if bn.isnumeric(param) then
      param = param:tointeger()
    end
    params[i] = param
  end

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
    objattr.cimport = true
    if traits.is_string(params) then
      objattr.codename = params
    else
      objattr.codename = symbol.name
    end
  elseif name == 'nickname' then
    assert(objattr._type and not objattr.is_primitive)
    local type, nickname = objattr, params
    local codename = context:choose_codename(nickname)
    symbol.codename = codename
    type:set_codename(codename)
  end

  node.done = true
end

function visitors.Id(context, node)
  local name = node[1]
  local symbol
  if not node.attr.foreignsymbol then
    symbol = context.scope.symbols[name]
    if not symbol then
      node:raisef("undeclared symbol '%s'", name)
    end
  else
    symbol = node.attr.foreignsymbol
  end
  symbol:link_node(node)
  node.done = symbol
  return symbol
end

function visitors.IdDecl(context, node)
  local namenode, typenode, annotnodes = node[1], node[2], node[3]
  local attr = node.attr
  if not attr.type and typenode then
    context:traverse_node(typenode)
    local type = typenode.attr.value
    attr.type = type
    if type.is_void then
      node:raisef("variable declaration cannot be of the empty type '%s'", type)
    end
  end
  local symbol
  if traits.is_string(namenode) then
    if attr._symbol then
      symbol = attr
      symbol:clear_possible_types()
    else
      symbol = Symbol.promote_attr(attr, namenode, node)
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
  else
    -- global record field
    assert(namenode.tag == 'DotIndex')
    local state = context:push_state()
    state.inglobaldecl = node
    symbol = context:traverse_node(namenode)
    context:pop_state()
    symbol.scope = context.rootscope
    symbol.lvalue = true
    symbol.globalfield = true
  end
  if annotnodes then
    context:traverse_nodes(annotnodes, symbol)
  end
  return symbol
end

function visitors.Paren(context, node, ...)
  local innernode = node[1]
  innernode.desiredtype = node.desiredtype
  local ret = context:traverse_node(innernode, ...)
  -- inherit attributes from inner node
  node.attr = innernode.attr
  node.done = innernode.done
  -- forward anything from inner node traverse
  return ret
end

function visitors.Type(context, node)
  local attr = node.attr
  if attr.type then
    assert(traits.is_type(attr.value))
    node.done = true
    return
  end
  local tyname = node[1]
  local value = typedefs.primtypes[tyname]
  if not value then
    local symbol = context.scope.symbols[tyname]
    if not (symbol and symbol.type == primtypes.type) then
      node:raisef("symbol '%s' is an invalid type", tyname)
    end
    value = symbol.value
    assert(value)
  end
  attr.type = primtypes.type
  attr.value = value
  node.done = true
end

function visitors.TypeInstance(context, node, symbol)
  local typenode = node[1]
  context:traverse_node(typenode, symbol)
  -- inherit attributes from inner node
  local attr = typenode.attr
  node.attr = attr
  if symbol then
    local type = attr.value
    symbol.value = type
    choose_type_symbol_names(context, symbol)
    type.symbol = symbol
  end
  node.done = true
end

local function retnodes_to_rettypes(retnodes)
  local rettypes = {}
  for i=1,#retnodes do
    rettypes[i] = retnodes[i].attr.value
  end
  return rettypes
end

function visitors.FuncType(context, node)
  local attr = node.attr
  local argnodes, retnodes = node[1], node[2]
  context:traverse_nodes(argnodes)
  context:traverse_nodes(retnodes)
  local argattrs = {}
  for i=1,#argnodes do
    local argnode = argnodes[i]
    if argnode.tag == 'IdDecl' then
      argattrs[i] = argnode.attr
    else
      assert(argnode.attr.type.is_type)
      argattrs[i] = Attr{type = argnode.attr.value}
    end
  end
  local rettypes = retnodes_to_rettypes(retnodes)
  local type = types.FunctionType(argattrs, rettypes, node)
  type.sideeffect = true
  attr.type = primtypes.type
  attr.value = type
  attr.done = true
end

function visitors.RecordFieldType(context, node, recordtype)
  local attr = node.attr
  local name, typenode = node[1], node[2]
  context:traverse_node(typenode)
  local typeattr = typenode.attr
  attr.type = typeattr.type
  attr.value = typeattr.value
  recordtype:add_field(name, typeattr.value)
  node.done = true
end

function visitors.RecordType(context, node, symbol)
  local attr = node.attr
  local recordtype = types.RecordType({}, node)
  attr.type = primtypes.type
  attr.value = recordtype
  if symbol then
    -- must populate this type symbol early in case its used in the records fields
    assert((not symbol.type or symbol.type == primtypes.type) and not symbol.value)
    symbol.type = primtypes.type
    symbol.value = recordtype
    choose_type_symbol_names(context, symbol)
    recordtype.symbol = symbol
  end
  local fieldnodes = node[1]
  context:traverse_nodes(fieldnodes, recordtype)
  node.done = true
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
        name, numtype)
    end
    local ok, err = desiredtype:is_convertible_from_attr(numattr)
    if not ok then
      numnode:raisef("in enum field '%s': %s", name, err)
    end
    field.value = numnode.attr.value
    field.comptime = true
    field.type = desiredtype
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
  end
  local fields = {}
  for i=1,#fieldnodes do
    local fnode = fieldnodes[i]
    fnode.desiredtype = subtype
    local field = context:traverse_node(fnode)
    if not field.value then
      if i == 1 then
        fnode:raisef("first enum field requires an initial value", field.name)
      else
        field.value = fields[i-1].value + 1
        field.comptime = true
        field.type = subtype
      end
    end
    if not subtype:is_inrange(field.value) then
      fnode:raisef("in enum field '%s': value %s is out of range for type '%s'",
        field.name, field.value:todec(), subtype)
    end
    assert(field.name)
    fields[i] = field
  end
  attr.type = primtypes.type
  local type = types.EnumType(subtype, fields)
  type.node = node
  attr.value = type
  node.done = true
end

function visitors.ArrayType(context, node)
  local attr = node.attr
  local subtypenode, lengthnode = node[1], node[2]
  context:traverse_node(subtypenode)
  local subtype = subtypenode.attr.value
  context:traverse_node(lengthnode)
  if not lengthnode.attr.value then
    lengthnode:raisef("unknown comptime value for expression")
  end
  local length = bn.tointeger(lengthnode.attr.value)
  if not lengthnode.attr.type.is_integral then
    lengthnode:raisef("cannot have non integral type '%s' for array size",
      lengthnode.attr.type)
  elseif length < 0 then
    lengthnode:raisef("cannot have negative array size %d", length)
  end
  attr.type = primtypes.type
  local type = types.ArrayType(subtype, length)
  type.node = node
  attr.value = type
  node.done = true
end

function visitors.PointerType(context, node)
  local attr = node.attr
  local subtypenode = node[1]
  if subtypenode then
    context:traverse_node(subtypenode)
    local subtype = subtypenode.attr.value
    attr.value = types.get_pointer_type(subtype)
    if not attr.value then
      node:raisef("subtype '%s' is invalid for 'pointer' type", subtype)
    end
  else
    attr.value = primtypes.pointer
  end
  attr.type = primtypes.type
  node.done = true
end

function visitors.GenericType(context, node)
  local attr = node.attr
  local name, argnodes = node[1], node[2]
  local symbol = context.scope.symbols[name]
  if not symbol or not symbol.type or not symbol.type.is_type or not symbol.value.is_generic then
    node:raisef("symbol '%s' not defined or not a generic type", name)
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
    if bn.isnumeric(value) then
      value = bn.tonumber(value)
    elseif not (traits.is_type(value) or
                traits.is_string(value) or
                traits.is_boolean(value) or
                bn.isnumeric(value)) then
      node:raisef("in generic '%s': argument #%d of type '%s' is invalid for generics",
        name, i, argattr.type)
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
  node.done = true
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
        if callretindex > 1 and not argtype.is_niltype then
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
  local lastargnode = argnodes[lastargindex]
  local lastcalleetype = lastargnode and lastargnode.attr.calleetype
  if lastargnode and lastargnode.tag:sub(1,4) == 'Call' and
     (not lastcalleetype or not lastcalleetype.is_type) then
    -- last arg is a runtime call
    return function()
      local i, var, argnode = iter()
      if not i then return nil end
      -- NOTE: the calletype may change while iterating
      local calleetype = argnodes[lastargindex].attr.calleetype
      if calleetype then
        if calleetype.is_any then
          -- calling any types makes last arguments always a varanys
          local argtype = argnode and argnode.attr.type
          if i == lastargindex then
            assert(argtype and argtype.is_varanys)
          end
          return i, var, argnode, argtype
        else
          -- we know the callee type
          if i >= lastargindex then
            -- argnode does not exists, fill with multiple returns type
            -- in case it doest not exists, the argtype will be nil type
            local callretindex = i - lastargindex + 1
            local argtype = calleetype:get_return_type(callretindex) or primtypes.niltype
            if callretindex > 1 and not argtype.is_niltype then
              lastargnode.attr.multirets = true
            end
            return i, var, argnode, argtype, callretindex
          else
            return i, var, argnode, argnode.attr.type, nil
          end
        end
      else
        -- call type is now known yet, argtype will be nil
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
        argtype = primtypes.niltype
      end
      return i, var, argnode, argtype
    end
  end
end

local function visitor_Call_typeassertion(context, node, argnodes, type)
  local attr = node.attr
  assert(type)
  if type.is_generic then
    node:raisef("type assertion to generic '%s': cannot do assertion on generics", type)
  end
  if #argnodes > 1 then
    node:raisef("type assertion to type '%s': expected at most 1 argument, but got %d",
      type, #argnodes)
  end
  local argnode = argnodes[1]
  local done = true
  if argnode then
    argnode.desiredtype = type
    context:traverse_node(argnode)
    local argattr = argnode.attr
    local argtype = argattr.type
    if argtype then
      local ok, err = type:is_convertible_from_attr(argattr, true)
      if not ok then
        argnode:raisef("in type assertion: %s", err)
      end
      if argattr.comptime then
        attr.value = type:normalize_value(argattr.value)
        if attr.value or argtype == type then
          attr.comptime = true
        end
      end
    end
    attr.sideeffect = argnode.attr.sideeffect
    if not argnode.done then
      done = nil
    end
  end
  attr.typeassertion = true
  attr.type = type
  attr.calleetype = primtypes.type
  node.done = done
end

local function visitor_Call(context, node, argnodes, calleetype, calleesym, calleeobjnode)
  local attr = node.attr
  if calleetype then
    if calleetype.is_procedure then
      -- function call
      local argattrs = {}
      for i=1,#argnodes do
        argattrs[i] = argnodes[i].attr
      end
      local calleename = calleesym and calleesym.name or calleetype
      local funcargtypes = calleetype.argtypes
      local funcargattrs = calleetype.argattrs or calleetype.args
      local pseudoargtypes = funcargtypes
      local pseudoargattrs = funcargattrs
      if calleeobjnode then
        pseudoargtypes = tabler.icopy(funcargtypes)
        pseudoargattrs = tabler.icopy(funcargattrs)
        local ok, err = funcargtypes[1]:is_convertible_from_attr(calleeobjnode.attr, nil, argattrs)
        if not ok then
          node:raisef("in call of function '%s' at argument %d: %s",
            calleetype, 1, err)
        end
        table.remove(pseudoargtypes, 1)
        table.remove(pseudoargattrs, 1)
        attr.pseudoargtypes = pseudoargtypes
        attr.pseudoargattrs = pseudoargtypes
      end
      if #argnodes > #pseudoargattrs then
        node:raisef("in call of function '%s': expected at most %d arguments but got %d",
          calleename, #pseudoargattrs, #argnodes)
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
          argnode, argtype = visitor_convert(context, argnodes, i, funcargtype, argnode, argtype, argattrs)
          if argtype then
            arg = argnode.attr
          end
        else
          arg = argtype
        end

        if argtype and argtype.is_niltype and not funcargtype.is_nilable then
          node:raisef("in call of function '%s': expected an argument at index %d but got nothing",
            calleename, i)
        end
        if arg then
          local argattr = arg
          if traits.is_type(arg) then
            argattr = Attr{type=arg}
          end
          local wantedtype, err = funcargtype:is_convertible_from_attr(argattr, nil, argattrs)
          if not wantedtype then
            node:raisef("in call of function '%s' at argument %d: %s",
              calleename, i, err)
          end

          if funcargtype ~= wantedtype and argnode then
            -- new type suggested, need to traverse again
            argnode.desiredtype = wantedtype
            context:traverse_node(argnode)
          end
          funcargtype = wantedtype

          -- check again the new type
          wantedtype, err = funcargtype:is_convertible_from_attr(argattr, nil, argattrs)
          if not wantedtype then
            node:raisef("in call of function '%s' at argument %d: %s",
              calleename, i, err)
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
      node:raisef("cannot call type '%s'", calleetype)
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
        node:raisef("cannot index meta field '%s' in record '%s'", name, calleetype)
      end
      calleetype = calleesym.type
    elseif calleetype.is_any then
      calleetype = primtypes.any
    end

    if calleetype and calleetype.is_procedure then
      -- convert callee object if needed
      calleeobjnode = visitor_convert(context, node, 3,
        calleetype.argtypes[1], calleeobjnode, calleeobjnode.attr.type)
    end
  end

  visitor_Call(context, node, argnodes, calleetype, calleesym, calleeobjnode)
end

local function visitor_Record_FieldIndex(_, node, objtype, name)
  local attr = node.attr
  local field = objtype:get_field(name)
  local type = field and field.type
  if not type then
    node:raisef("cannot index field '%s' on record '%s'", name, objtype)
  end
  attr.type = type
  node.checked = true
  -- return true
end

local function visitor_EnumType_FieldIndex(_, node, objtype, name)
  local attr = node.attr
  local field = objtype:get_field(name)
  if not field then
    node:raisef("cannot index field '%s' on enum '%s'", name, objtype)
  end
  attr.comptime = true
  attr.value = field.value
  attr.type = objtype
  node.checked = true
  -- return true
end

local function visitor_RecordType_FieldIndex(context, node, objtype, name)
  local attr = node.attr
  local symbol = objtype:get_metafield(name)
  local parentnode = context:get_parent_node()
  local infuncdef = context.state.infuncdef == parentnode
  local inglobaldecl = context.state.inglobaldecl == parentnode
  local inlazydef = context.state.inlazydef and symbol == context.state.inlazydef
  if inlazydef then
    symbol = attr._symbol and attr or nil
  end
  if not symbol then
    local symname = string.format('%s.%s', objtype.nickname or objtype.name, name)
    symbol = Symbol.promote_attr(attr, symname, node)
    symbol.codename = context:choose_codename(string.format('%s_%s', objtype.codename, name))
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
      node:raisef("cannot index meta field '%s' in record '%s'", name, objtype)
    end
    if not inlazydef then
      objtype:set_metafield(name, symbol)
    end
    symbol.annonymous = true
    symbol.scope = context.rootscope
  elseif infuncdef or inglobaldecl then
    if symbol.node ~= node then
      node:raisef("cannot redefine meta type field '%s' in record '%s'", name, objtype)
    end
  else
    symbol:link_node(node)
  end
  -- cannot uncomment this yet
  --node.checked = true
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
    node:raisef("cannot index fields on type '%s'", objtype)
  end
end

local function visitor_FieldIndex(context, node)
  local name, objnode = node[1], node[2]
  context:traverse_node(objnode)
  if node.checked then return end
  local objattr = objnode.attr
  local objtype = objattr.type
  local ret
  if objtype then
    local attr = node.attr
    objtype = objtype:auto_deref_type()
    if objtype.is_record then
      ret = visitor_Record_FieldIndex(context, node, objtype, name)
    elseif objtype.is_type then
      ret = visitor_Type_FieldIndex(context, node, objattr.value, name)
    elseif objtype.is_table or objtype.is_any then
      attr.type = primtypes.any
    else
      node:raisef("cannot index field '%s' on type '%s'", name, objtype.name)
    end
    if objattr.lvalue then
      attr.lvalue = true
    end
    if ret and objnode.done then
      node.done = ret
    end
  end
  return ret
end

visitors.DotIndex = visitor_FieldIndex
visitors.ColonIndex = visitor_FieldIndex

local function visitor_Array_ArrayIndex(context, node, objtype, objnode, indexnode)
  local attr = node.attr
  local indexattr = indexnode.attr
  local indextype = indexattr.type
  local checked = false
  if indextype then
    if indextype.is_integral then
      local indexvalue = indexattr.value
      if indexvalue then
        if bn.isneg(indexvalue) then
          indexnode:raisef("cannot index negative value %s", bn.todec(indexvalue))
        end
        if objtype.is_array and objtype.length ~= 0 and not (indexvalue < bn.new(objtype.length)) then
          indexnode:raisef("index %s is out of bounds, array maximum index is %d",
            indexvalue:todec(), objtype.length - 1)
        end
        checked = true
      end
      attr.type = objtype.subtype
    else
      indexnode:raisef("cannot index with value of type '%s'", indextype)
    end
  end
  if not context.pragmas.nochecks and not checked and objtype.length > 0 then
    attr.checkbounds = true
  end
  if objnode.attr.lvalue then
    attr.lvalue = true
  end
end

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
          indexretype)
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
    node:raisef("cannot index record of type '%s': no `__index` or `__atindex` metamethod found", objtype)
  end
end

function visitors.ArrayIndex(context, node)
  local indexnode, objnode = node[1], node[2]
  context:traverse_node(indexnode)
  context:traverse_node(objnode)
  local attr = node.attr
  if attr.type then
    if indexnode.done and objnode.done then node.done = true end
    return
  end
  if node.checked then return end
  local objtype = objnode.attr.type
  if objtype then
    objtype = objtype:auto_deref_type()
    if objtype.is_array then
      visitor_Array_ArrayIndex(context, node, objtype, objnode, indexnode)
    elseif objtype.is_record then
      visitor_Record_ArrayIndex(context, node, objtype, objnode, indexnode)
    elseif objtype.is_table or objtype.is_any then
      attr.type = primtypes.any
    else
      node:raisef("cannot index variable of type '%s'", objtype.name)
    end
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
    local scope = context:push_forked_cleaned_scope('block', node)

    local ok, err = except.trycall(node.preprocess, node)
    if not ok then
      if except.isexception(err) then
        except.reraise(err)
      else
        node:raisef('error while preprocessing block: %s', err)
      end
    end
    node.preprocess = nil
    -- node.preprocessed = true

    local resolutions_count = scope:resolve()
    context:pop_scope()
    if resolutions_count == 0 then
      return
    end
  end

  local statnodes = node[1]

  if #statnodes > 0 or not node.scope then
    local scope
    repeat
      scope = context:push_forked_cleaned_scope('block', node)
      context:traverse_nodes(statnodes)
      local resolutions_count = scope:resolve()
      context:pop_scope()
    until resolutions_count == 0
  end

  -- preprocessed blocks can never be done
  -- because new statements may be injected at anytime
  -- TODO: improve this later
  -- if not node.preprocessed then
  --   local done = true
  --   for i=1,#statnodes do
  --     if not statnodes[i].done then
  --       done = nil
  --       break
  --     end
  --   end
  --   if done then
  --     node.done = true
  --   end
  -- end
end

function visitors.If(context, node)
  local ifpairs, elsenode = node[1], node[2]
  for i=1,#ifpairs do
    local ifpair = ifpairs[i]
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
      valtype)
  end
  for i=1,#caseparts do
    local casepart = caseparts[i]
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
  context:push_forked_cleaned_scope('loop', node)
  context:traverse_node(blocknode)
  context:pop_scope()
end

function visitors.Repeat(context, node)
  local blocknode, condnode = node[1], node[2]
  condnode.desiredtype = primtypes.boolean
  condnode.attr.inconditional = true
  context:push_forked_cleaned_scope('loop', node)
  context:traverse_node(blocknode)
  context:push_scope(blocknode.scope)
  context:traverse_node(condnode)
  context:pop_scope()
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
  if infunctype and not (infunctype.is_any or infunctype.is_procedure) then
    node:raisef("first argument of `in` statement must be a function, but got type '%s'",
      infunctype)
  end
  context:traverse_nodes(inexpnodes)

  repeat
    local scope = context:push_forked_cleaned_scope('loop', node)
  --[[
  if itvarnodes then
    for i,itvarnode in ipairs(itvarnodes) do
      local itsymbol = context:traverse_node(itvarnode)
      if infunctype and infunctype.is_procedure then
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
    local scope = context:push_forked_cleaned_scope('loop', node)

    local itsymbol = context:traverse_node(itvarnode)
    itsymbol.scope:add_symbol(itsymbol)
    ittype = itsymbol.type
    if not ittype then
      itsymbol:add_possible_type(btype, begvalnode)
      itsymbol:add_possible_type(etype, endvalnode)
      if btype and etype then
        scope:resolve_symbol(itsymbol)
        ittype = itsymbol.type
      end
    end
    if ittype and not node.checked then
      if not (ittype.is_arithmetic or (ittype.is_any and not ittype.is_varanys)) then
        itvarnode:raisef("`for` variable '%s' must be a number, but got type '%s'", itname, ittype)
      end
      if btype then
        local ok, err = ittype:is_convertible_from_attr(battr)
        if not ok then
          begvalnode:raisef("in `for` begin variable '%s': %s", itname, err)
        end
        if not context.pragmas.nochecks and ittype ~= btype then
          begvalnode.checkcast = true
        end
      end
      if etype then
        local ok, err = ittype:is_convertible_from_attr(eattr)
        if not ok then
          endvalnode:raisef("in `for` end variable '%s': %s", itname, err)
        end
        if not context.pragmas.nochecks and ittype ~= etype then
          endvalnode.checkcast = true
        end
      end
      if stype then
        local optype, _, err = ittype:binary_operator('add', stype, itsymbol, sattr)
        if stype.is_float and ittype.is_integral then
          err = 'cannot have fractional step for an integral iterator'
        end
        if err then
          stepvalnode:raisef("in `for` step variable '%s': %s", itname, err)
        end
      end
    end
    context:traverse_node(blocknode)

    local resolutions_count = scope:resolve()
    context:pop_scope()
  until resolutions_count == 0

  -- early return
  if node.checked then return end

  local fixedstep
  local stepvalue
  if stype and stype.is_arithmetic and sattr.comptime then
    -- constant step
    fixedstep = stepvalnode
    stepvalue = sattr.value
    if bn.iszero(stepvalue) then
      stepvalnode:raisef("`for` step cannot be zero")
    end
  elseif not stepvalnode then
    -- default step is '1'
    stepvalue = bn.one()
    fixedstep = '1'
  end
  local fixedend
  if etype and etype.is_arithmetic and eattr.comptime then
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

function visitors.Break(context, node)
  if not context.scope:get_parent_of_kind('loop') then
    node:raisef("`break` statement is not inside a loop")
  end
  node.done = true
end

function visitors.Continue(context, node)
  if not context.scope:get_parent_of_kind('loop') then
    node:raisef("`continue` statement is not inside a loop")
  end
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
  local label = context.scope:find_label(labelname)
  if not label then
    local funcscope = context.scope:get_parent_of_kind('function') or context.rootscope
    if not funcscope.resolved_once then
      -- we should find it in the next traversal
      funcscope:delay_resolution()
      return
    end
    node:raisef("no visible label '%s' found for `goto`", labelname)
  end
  node.attr.label = label
  node.done = true
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
      varnode:raisef("variable declaration cannot be of the type '%s'", vartype)
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
        elseif not vartype and valtype.is_niltype then
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
        choose_type_symbol_names(context, symbol)
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
        if vartype.is_lazyfunction then
          -- skip declaration for lazy function aliases
          varnode.attr.nodecl = true
        end
      end
    end
    if assigning then
      symbol:add_possible_type(valtype, varnode)
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
      symbol:add_possible_type(valtype, varnode)
      symbol.mutate = true
    end
    if not valnode and valtype and valtype.is_niltype then
      varnode:raisef("variable assignment at index '%d' is assigning to nothing in the expression", i)
    end
    if vartype and valtype then
      local ok, err = vartype:is_convertible_from(valnode or valtype)
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
          if rettype.is_niltype and not funcrettype.is_nilable then
            node:raisef("missing return expression at index %d of type '%s'", i, funcrettype)
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

  for i=1,#argnodes do
    local argnode = argnodes[i]
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
    local laststatpairs = laststat[laststat.nargs-1]
    for i=1,#laststatpairs do
      local pair = laststatpairs[i]
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
    local canbeempty = tabler.iall(returntypes, 'is_nilable')
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
    -- returns types are pre declared
    returntypes = retnodes_to_rettypes(retnodes)

    if #returntypes == 1 and returntypes[1].is_void then
      -- single void type means no returns
      returntypes = {}
    end
  elseif functype and functype.is_procedure and not functype.returntypes.has_unknown then
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
    for i=1,#argnodes do
      local argnode = argnodes[i]
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
      type = types.LazyFunctionType(argattrs, returntypes, node)
    end
  elseif not returntypes.has_unknown then
    type = types.FunctionType(argattrs, returntypes, node)
  end

  if symbol then -- symbol may be nil in case of array/dot index
    symbol.funcdef = true
    if decl then
      -- declaration always set the type
      symbol.type = type
    else
      -- check if previous symbol declaration is compatible
      local symboltype = symbol.type
      if symboltype then
        local ok, err = symboltype:is_convertible_from_type(type)
        if not ok then
          node:raisef("in function definition: %s", err)
        end
      else
        symbol:add_possible_type(type, varnode)
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
    local evals = type.evals
    for i=1,#evals do
      local lazyeval = evals[i]
      local lazynode = lazyeval.node
      if not lazynode then
        lazynode = node:clone()
        lazyeval.node = lazynode
        local lazyargnodes = lazynode[3]
        local lazyargs = lazyeval.args
        for j=1,#lazyargs do
          local lazyarg = lazyargs[j]
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
  if not overridable_operators[opname] then return end
  if opname == 'len' then
    -- allow calling len on pointers for arrays/records
    objtype = objtype:auto_deref_type()
  end
  if not objtype.is_record then return end
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
  if attr.type then
    if argnode.done then
      node.done = true
    end
    return
  end

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
  if opname == 'ref' and argnode.tag == 'Id' then
    -- for loops needs to know if an Id symbol could mutate
    argattr.mutate = true
  elseif opname == 'deref' then
    attr.lvalue = true
    if not context.pragmas.nochecks then
      argnode.checkderef = true
    end
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
  if not overridable_operators[opname] then return end
  local objtype, mtsym
  local mtname = '__' .. opname
  if ltype.is_record then
    mtsym = ltype:get_metafield(mtname)
    objtype = ltype
  end
  if not mtsym and rtype.is_record then
    mtsym = rtype:get_metafield(mtname)
    objtype = rtype
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
  local newnode = n.Call{{lnode, rnode}, n.DotIndex{mtname, idnode}}
  node:transform(newnode)
  context:traverse_node(node)
  return true
end

function visitors.BinaryOp(context, node)
  local opname, lnode, rnode = node[1], node[2], node[3]
  local attr = node.attr
  local isor = opname == 'or'
  local isbinaryconditional = isor or opname == 'and'

  local wantsboolean
  if isbinaryconditional and node.desiredtype == primtypes.boolean then
    lnode.desiredtype = primtypes.boolean
    rnode.desiredtype = primtypes.boolean
    wantsboolean =  true
  elseif isor and lnode[1] == 'and' and lnode.tag == 'BinaryOp' then
    lnode.attr.ternaryand = true
    attr.ternaryor = true
  end

  context:traverse_node(lnode)
  context:traverse_node(rnode)

  -- quick return for already resolved type
  if attr.type then
    if lnode.done and rnode.done then node.done = true end
    return
  end

  local lattr, rattr = lnode.attr, rnode.attr
  local ltype, rtype = lattr.type, rattr.type
  local type
  if ltype and rtype then
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
  lattr.inoperator = true
  rattr.inoperator = true
  if lattr.sideeffect or rattr.sideeffect then
    attr.sideeffect = true
  end
end

function analyzer.analyze(context)
  local ast = context.ast
  analyzer.current_context = context
  context.analyzing = true

  if config.pragma then
    tabler.update(context.pragmas, config.pragma)
  end
  context:push_pragmas()

  if ast.src and ast.src.name then
    context.pragmas.unitname = pegger.filename_to_unitname(ast.src.name)
  end

  -- phase 1 traverse: preprocess
  preprocessor.preprocess(context, ast)

  -- phase 2 traverse: infer and check types
  repeat
    context:traverse_node(ast)
    local resolutions_count = context.rootscope:resolve()
  until resolutions_count == 0

  for _,cb in ipairs(context.afteranalyze) do
    local ok, err = except.trycall(cb.f)
    if not ok then
      cb.node:raisef('error while executing after analyze: %s', err)
    end
  end

  -- phase 3 traverse: infer unset types to 'any' type
  if context.unresolvedcount ~= 0 then
    local state = context:push_state()
    state.anyphase = true
    repeat
      context:traverse_node(ast)
      local resolutions_count = context.rootscope:resolve()
    until resolutions_count == 0
    assert(context.unresolvedcount == 0)
    context:pop_state()
  end

  -- execute after inferance callbacks
  for _,f in ipairs(context.afterinfers) do
    f()
  end

  context:pop_pragmas()

  context.analyzing = nil
  return context
end

return analyzer
