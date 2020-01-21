local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local tabler = require 'nelua.utils.tabler'
local typedefs = require 'nelua.typedefs'
local Context = require 'nelua.context'
local Symbol = require 'nelua.symbol'
local types = require 'nelua.types'
local bn = require 'nelua.utils.bn'
local except = require 'nelua.utils.except'
local preprocessor = require 'nelua.preprocessor'
local builtins = require 'nelua.builtins'
local typechecker = {}

local primtypes = typedefs.primtypes
local visitors = {}

function visitors.Number(_, node)
  local attr = node.attr
  if attr.type then return end
  local base, int, frac, exp, literal = node:args()
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
  attr.base = base
  attr.comptime = true
end

function visitors.String(_, node)
  local attr = node.attr
  if attr.type then return end
  local value, literal = node:args()
  if literal then
    node:raisef("string literals are not supported yet")
  end
  attr.type = primtypes.string
  attr.value = value
  attr.comptime = true
end

function visitors.Boolean(_, node)
  local attr = node.attr
  if attr.type then return end
  local value = node:args(1)
  attr.value = value
  attr.type = primtypes.boolean
  attr.comptime = true
end

function visitors.Nil(_, node)
  local attr = node.attr
  if attr.type then return end
  attr.type = primtypes.nilable
  attr.comptime = true
end

local function visitor_ArrayTable_literal(context, node, littype)
  local attr = node.attr
  local childnodes = node:args()
  local subtype = littype.subtype
  for i, childnode in ipairs(childnodes) do
    if childnode.tag == 'Pair' then
      childnode:raisef("fields are disallowed for array table literal")
    end
    childnode.desiredtype = subtype
    context:traverse(childnode)
    local childtype = childnode.attr.type
    if childtype then
      if childtype == subtype then
        childnode.attr.initializer = true
      else
        local ok, err = subtype:is_convertible_from(childnode.attr)
        if not ok then
          childnode:raisef("in array table literal at index %d: %s", i, err)
        end
      end
    end
  end
  attr.type = littype
end

local function visitor_Array_literal(context, node, littype)
  local attr = node.attr
  local childnodes = node:args()
  local subtype = littype.subtype
  local comptime = true
  if not (#childnodes == littype.length or #childnodes == 0) then
    node:raisef("expected %d values in array literal but got %d", littype.length, #childnodes)
  end
  for i, childnode in ipairs(childnodes) do
    if childnode.tag == 'Pair' then
      childnode:raisef("fields are disallowed for array literals")
    end
    childnode.desiredtype = subtype
    context:traverse(childnode)
    local childtype = childnode.attr.type
    if childtype then
      if childtype == subtype then
        childnode.attr.initializer = true
      else
        local ok, err = subtype:is_convertible_from(childnode.attr)
        if not ok then
          childnode:raisef("in array literal at index %d: %s", i, err)
        end
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
  local childnodes = node:args()
  local comptime = true
  local lastfieldindex = 0
  for _, childnode in ipairs(childnodes) do
    local fieldname, fieldvalnode, field, fieldindex
    if childnode.tag == 'Pair' then
      fieldname, fieldvalnode = childnode:args()
      if not traits.is_string(fieldname) then
        childnode:raisef("only string literals are allowed in record's field names")
      end
      field, fieldindex = littype:get_field(fieldname)
    else
      fieldindex = lastfieldindex + 1
      field = littype.fields[fieldindex]
      if not field then
        childnode:raisef("field at index %d is invalid, record has only %d fields",
          fieldindex, #littype.fields)
      end
      fieldname = field.name
      fieldvalnode = childnode
    end
    if not field then
      childnode:raisef("field '%s' is not present in record '%s'",
      fieldname, littype:prettyname())
    end
    local fieldtype = field.type
    fieldvalnode.desiredtype = fieldtype
    context:traverse(fieldvalnode)
    lastfieldindex = fieldindex
    local fieldvaltype = fieldvalnode.attr.type
    if fieldvaltype then
      if fieldvaltype == fieldtype then
        fieldvalnode.attr.initializer = true
      else
        local ok, err = fieldtype:is_convertible_from(fieldvalnode.attr)
        if not ok then
          childnode:raisef("in record literal field '%s': %s", fieldname, err)
        end
      end
    end
    childnode.attr.parenttype = littype
    if not fieldvalnode.attr.comptime then
      comptime = nil
    end
  end
  attr.type = littype
  attr.comptime = comptime
end


local function visitor_Table_literal(context, node)
  local attr = node.attr
  local childnodes = node:args()
  context:traverse(childnodes)
  attr.type = primtypes.table
end


function visitors.Table(context, node)
  local desiredtype = node.desiredtype
  if not desiredtype or desiredtype:is_table() then
    visitor_Table_literal(context, node)
  elseif desiredtype:is_arraytable() then
    visitor_ArrayTable_literal(context, node, desiredtype)
  elseif desiredtype:is_array() then
    visitor_Array_literal(context, node, desiredtype)
  elseif desiredtype:is_record() then
    visitor_Record_literal(context, node, desiredtype)
  else
    node:raisef("type '%s' cannot be initialized using a table literal", desiredtype:prettyname())
  end
end

function visitors.PragmaCall(context, node)
  local name, args = node:args()
  local pragmashape = typedefs.call_pragmas[name]
  node:assertraisef(pragmashape, "pragma '%s' is undefined", name)

  if name == 'afterinfer' and context.anyinference and not node.attr.afterinfer then
    node.attr.afterinfer = true
    args[1]()
  end
end

function visitors.Annotation(context, node, symbol)
  --TODO: quick return

  local name, argnodes = node:args()
  context:traverse(argnodes)
  assert(symbol)

  local paramshape
  local symboltype
  local atttype
  if name == 'comptime' then
    paramshape = true
  else
    symboltype = symbol.type
    if not symboltype then
      -- in the next traversal we will have the type
      return
    end
    if symboltype:is_function() then
      paramshape = typedefs.function_annots[name]
      atttype = 'functions'
    elseif symboltype:is_type() then
      paramshape = typedefs.type_annots[name]
      atttype = 'types'
    else
      paramshape = typedefs.variable_annots[name]
      atttype = 'variables'
    end
  end
  if not paramshape then
    node:raisef("annotation '%s' is undefined for %s", name, atttype)
  end

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

  local attr, type
  if symboltype and symboltype:is_type() then
    type = symbol.value
    attr = type
  else
    attr = symbol
  end
  attr[name] = params

  if name == 'cimport' then
    if traits.is_string(params) then
      attr.codename = params
    elseif type then
      type.codename = symbol.name
    end
  end
end

function visitors.Id(context, node)
  local name = node[1]
  local symbol = context.scope:get_symbol(name)
  if not symbol and context.strict then
    node:raisef("undeclared symbol '%s'", name)
  end
  if not symbol then
    symbol = Symbol.promote_attr(node.attr, name, node)
    local ok, err = context.scope:add_symbol(symbol)
    assert(ok, err)
    symbol.global = true
    symbol.staticstorage = true
  else
    symbol:link_node(node)
  end
  symbol.lvalue = true
  return symbol
end

function visitors.IdDecl(context, node)
  local namenode, typenode, annotnodes = node:args()
  local type = node.attr.type
  if not type then
    if typenode then
      context:traverse(typenode)
      type = typenode.attr.value
    end
  end
  local symbol
  if traits.is_string(namenode) then
    symbol = Symbol.promote_attr(node.attr, namenode, node)
    local scope
    if node.attr.global then
      scope = context.rootscope
    else
      scope = context.scope
    end
    local ok, err = scope:add_symbol(symbol)
    if not ok then
      node:raisef(err)
    end
  else
    -- global record field
    assert(namenode.tag == 'DotIndex')
    context.inglobaldecl = node
    symbol = context:traverse(namenode)
    context.inglobaldecl = nil
  end
  local attr = symbol
  if type then
    attr.type = type
  end
  if annotnodes then
    context:traverse(annotnodes, symbol)
  end
  attr.lvalue = true
  return symbol
end

function visitors.Paren(context, node, ...)
  local innernode = node:args()
  local ret = context:traverse(innernode, ...)
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
    if not (symbol and symbol.type == primtypes.type and symbol.value) then
      node:raisef("symbol '%s' is an invalid type", tyname)
    end
    value = symbol.value
  end
  attr.type = primtypes.type
  attr.value = value
end

function visitors.TypeInstance(context, node, symbol)
  local typenode = node[1]
  context:traverse(typenode)
  -- inherit attributes from inner node
  local attr = typenode.attr
  node.attr = attr
  if symbol and not attr.value:is_primitive() then
    local prefix
    if context.nohashcodenames then
      prefix = context.modname or context.ast.modname or ''
    end
    attr.value:suggest_nick(symbol.name, prefix)
  end
end

function visitors.FuncType(context, node)
  local attr = node.attr
  if attr.type then return end
  local argnodes, retnodes = node:args()
  context:traverse(argnodes)
  context:traverse(retnodes)
  local type = types.FunctionType(node,
    tabler.imap(argnodes, function(argnode) return argnode.attr.value end),
    tabler.imap(retnodes, function(retnode) return retnode.attr.value end))
  attr.type = primtypes.type
  attr.value = type
end

function visitors.RecordFieldType(context, node)
  local attr = node.attr
  if attr.type then return end
  local name, typenode = node:args()
  context:traverse(typenode)
  attr.type = typenode.attr.type
  attr.value = typenode.attr.value
end

function visitors.RecordType(context, node)
  local attr = node.attr
  if attr.type then return end
  local fieldnodes = node:args()
  context:traverse(fieldnodes)
  local fields = tabler.imap(fieldnodes, function(fieldnode)
    return {name = fieldnode[1], type=fieldnode.attr.value}
  end)
  attr.type = primtypes.type
  attr.value = types.RecordType(node, fields)
end

function visitors.EnumFieldType(context, node)
  local name, numnode = node:args()
  local field = {name = name}
  if numnode then
    local desiredtype = node.desiredtype
    context:traverse(numnode)
    local value, numtype = numnode.attr.value, numnode.attr.type
    if not numnode.attr.comptime then
      numnode:raisef("in enum field '%s': enum fields can only be assigned to compile time values", name)
    elseif not numtype:is_integral() then
      numnode:raisef("in enum field '%s': only integral types are allowed in enums, but got type '%s'",
        name, numtype:prettyname())
    end
    local ok, err = desiredtype:is_convertible_from(numnode)
    if not ok then
      numnode:raisef("in enum field '%s': %s", name, err)
    end
    field.value = value
  end
  return field
end

function visitors.EnumType(context, node)
  local attr = node.attr
  if attr.type then return end
  local typenode, fieldnodes = node:args()
  local subtype = primtypes.integer
  if typenode then
    context:traverse(typenode)
    subtype = typenode.attr.value
  end
  local fields = {}
  for i,fnode in ipairs(fieldnodes) do
    fnode.desiredtype = subtype
    local field = context:traverse(fnode)
    if not field.value then
      if i == 1 then
        fnode:raisef("first enum field requires an initial value", field.name)
      else
        field.value = fields[i-1].value:add(1)
      end
    end
    if not subtype:is_inrange(field.value) then
      fnode:raisef("in enum field '%s': value %s is out of range for type '%s'",
        field.name, field.value:todec(), subtype:prettyname())
    end
    fields[i] = field
  end
  attr.type = primtypes.type
  attr.value = types.EnumType(node, subtype, fields)
end

function visitors.ArrayTableType(context, node)
  local attr = node.attr
  if attr.type then return end
  local subtypenode = node:args()
  context:traverse(subtypenode)
  attr.type = primtypes.type
  attr.value = types.ArrayTableType(node, subtypenode.attr.value)
end

function visitors.SpanType(context, node)
  local attr = node.attr
  if attr.type then return end
  local subtypenode = node:args()
  context:traverse(subtypenode)
  local subtype = subtypenode.attr.value
  if subtype:is_comptime() then
    subtypenode:raisef("spans cannot be of type '%s'", subtype.name)
  end
  attr.type = primtypes.type
  attr.value = types.SpanType(node, subtype)
end

function visitors.RangeType(context, node)
  local attr = node.attr
  if attr.type then return end
  local subtypenode = node:args()
  context:traverse(subtypenode)
  local subtype = subtypenode.attr.value
  if not subtype:is_integral() then
    subtypenode:raisef("range subtype '%s' is not an integral type", subtype:prettyname())
  end
  attr.type = primtypes.type
  attr.value = types.RangeType(node, subtype)
end

function visitors.ArrayType(context, node)
  local attr = node.attr
  if attr.type then return end
  local subtypenode, lengthnode = node:args()
  context:traverse(subtypenode)
  local subtype = subtypenode.attr.value
  context:traverse(lengthnode)
  if not lengthnode.attr.value then
    lengthnode:raisef("unknown comptime value for expression")
  end
  local length = lengthnode.attr.value:tointeger()
  if not lengthnode.attr.type:is_integral() then
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
  local subtypenode = node:args()
  if subtypenode then
    context:traverse(subtypenode)
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

local function visitor_Record_FieldIndex(_, node, objtype, name)
  local field = objtype:get_field(name)
  local type = field and field.type
  if not type then
    node:raisef("cannot index field '%s' on enum '%s'", name, objtype:prettyname())
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
  if not symbol then
    symbol = Symbol.promote_attr(attr, nil, node)
    symbol.metavar = true
    symbol.codename = string.format('%s_%s', objtype.codename, name)
    local parentnode = context:get_parent_node()
    if context.infuncdef == parentnode then
      -- declaration of record global function
      symbol.metafunc = true
      symbol.metarecordtype = types.get_pointer_type(objtype)
    elseif context.inglobaldecl == parentnode then
      -- declaration of record global variable
      symbol.metafield = true
    else
      node:raisef("cannot index record meta field '%s'", name)
    end
    objtype:set_metafield(name, symbol)
    symbol:link_node(parentnode)

    -- add symbol to scope to enable type deduction
    local ok = context.rootscope:add_symbol(symbol)
    assert(ok)
  elseif context.infuncdef or context.inglobaldecl then
    if symbol.node ~= node then
      node:raisef("cannot redefine meta type field '%s'", name)
    end
  else
    symbol:link_node(node)
  end
  return symbol
end

local function visitor_Type_FieldIndex(context, node, objtype, name)
  local attr = node.attr
  if objtype:is_pointer() and objtype.subtype:is_record() then
    -- allow to access method and fields on record pointer types
    objtype = objtype.subtype
  end
  attr.indextype = objtype
  if objtype:is_enum() then
    return visitor_EnumType_FieldIndex(context, node, objtype, name)
  elseif objtype:is_record() then
    return visitor_RecordType_FieldIndex(context, node, objtype, name)
  else
    node:raisef("cannot index fields on type '%s'", objtype:prettyname())
  end
end

local function visitor_FieldIndex(context, node)
  local attr = node.attr
  local name, objnode = node:args()
  context:traverse(objnode)
  local objtype = objnode.attr.type
  local ret
  if objtype then
    if objtype:is_pointer() then
      -- dereference when accessing fields for pointers
      objtype = objtype.subtype
    end
    if objtype:is_record() then
      ret = visitor_Record_FieldIndex(context, node, objtype, name)
    elseif objtype:is_type() then
      ret = visitor_Type_FieldIndex(context, node, objnode.attr.value, name)
    elseif objtype:is_table() or objtype:is_any() then
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

function visitors.DotIndex(context, node)
  return visitor_FieldIndex(context, node)
end

function visitors.ColonIndex(context, node)
  return visitor_FieldIndex(context, node)
end

function visitors.ArrayIndex(context, node)
  local indexnode, objnode = node:args()
  context:traverse(indexnode)
  context:traverse(objnode)
  local type
  local objtype = objnode.attr.type
  if objtype then
    if objtype:is_pointer() then
      objtype = objtype.subtype
    end

    if objtype:is_arraytable() or objtype:is_array() or objtype:is_span() then
      local indextype = indexnode.attr.type
      if indextype then
        if indextype:is_integral() then
          local indexvalue = indexnode.attr.value
          if indexvalue then
            if indexvalue:isneg() then
              indexnode:raisef("cannot index negative value %s", indexvalue:todec())
            end
            if objtype:is_array() and objtype.length ~= 0 and not (indexvalue < bn.new(objtype.length)) then
              indexnode:raisef("index %s is out of bounds, array maximum index is %d",
                indexvalue:todec(), objtype.length - 1)
            end
          end
          type = objtype.subtype
        elseif indextype:is_range() and (objtype:is_array() or objtype:is_span()) then
          type = types.SpanType(node, objtype.subtype)
        else
          indexnode:raisef("cannot index with value of type '%s'", indextype:prettyname())
        end
      end
    elseif objtype:is_table() or objtype:is_any() then
      type = primtypes.any
    else
      node:raisef("cannot index variable of type '%s'", objtype.name)
    end
  end
  if objnode.attr.lvalue then
    node.attr.lvalue = true
  end
  node.attr.type = type
end

local function iargnodes(argnodes)
  local i = 0
  local lastargindex = #argnodes
  local lastargnode = argnodes[#argnodes]
  local calleetype = lastargnode and lastargnode.attr.calleetype
  if lastargnode and lastargnode.tag:sub(1,4) == 'Call' and calleetype and
    not calleetype:is_type() and not calleetype:is_any() then
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
  if lastargnode and lastargnode.tag:sub(1,4) == 'Call' and (not calleetype or not calleetype:is_type()) then
    -- last arg is a runtime call
    if calleetype then
      if calleetype:is_any() then
        -- calling any types makes last arguments always a varanys
        return function()
          local i, var, argnode = iter()
          local argtype = argnode and argnode.attr.type
          if not i then return nil end
          if i == lastargindex then
            assert(argtype and argtype:is_varanys())
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
  if #argnodes ~= 1 then
    node:raisef("assertion to type '%s' expected one argument, but got %d",
      type:prettyname(), #argnodes)
  end
  local argnode = argnodes[1]
  argnode.desiredtype = type
  context:traverse(argnode)
  local argtype = argnode.attr.type
  if argtype then
    local ok, err = type:is_convertible_from(argnode, true)
    if not ok then
      argnode:raisef("in type assertion: %s", err)
    end
    if argnode.attr.comptime then
      attr.comptime = argnode.attr.comptime
      attr.value = type:normalize_value(argnode.attr.value)
    end
  end
  attr.sideeffect = argnode.attr.sideeffect
  attr.typeassertion = true
  attr.type = type
  attr.calleetype = primtypes.type
end

local function visitor_Call(context, node, argnodes, calleetype, methodcalleenode)
  local attr = node.attr
  if calleetype then
    if calleetype:is_function() then
      -- function call
      local funcargtypes = calleetype.argtypes
      local pseudoargtypes = funcargtypes
      if methodcalleenode then
        pseudoargtypes = tabler.copy(funcargtypes)
        local ok, err = funcargtypes[1]:is_convertible_from(methodcalleenode)
        if not ok then
          node:raisef("in call of function '%s' at argument %d: %s",
            calleetype:prettyname(), 1, err)
        end
        table.remove(pseudoargtypes, 1)
        attr.pseudoargtypes = pseudoargtypes
      end
      if #argnodes > #pseudoargtypes then
        node:raisef("in call of function '%s': expected at most %d arguments but got %d",
          calleetype:prettyname(), #pseudoargtypes, #argnodes)
      end
      local argtypes = {}
      local knownallargs = true
      for i,funcargtype,argnode,argtype in izipargnodes(pseudoargtypes, argnodes) do
        if argnode then
          argnode.desiredtype = funcargtype
          context:traverse(argnode)
          argtype = argnode.attr.type
        end
        if argtype and argtype:is_nil() and not funcargtype:is_nilable() then
          node:raisef("in call of function '%s': expected an argument at index %d but got nothing",
            calleetype:prettyname(), i)
        end
        if argtype then
          if funcargtype then
            local ok, err = funcargtype:is_convertible_from(argnode or argtype)
            if not ok then
              node:raisef("in call of function '%s' at argument %d: %s",
                calleetype:prettyname(), i, err)
            end
          end
          argtypes[i] = argtype
        else
          knownallargs = false
        end
      end
      if methodcalleenode then
        tabler.insert(argtypes, funcargtypes[1])
      end
      if calleetype.lazyfunction then
        local lazycalleetype = calleetype
        calleetype = nil
        if knownallargs then
          local lazysym, err = lazycalleetype:eval_lazy_for_argtypes(argtypes)
          if err then --luacov:disable
            --TODO: actually this error is impossible because of the previous check
            node:raisef("in call of function '%s': %s", lazycalleetype:prettyname(), err)
          end --luacov:enable

          if traits.is_attr(lazysym) and lazysym.type then
            calleetype = lazysym.type
            attr.lazysym = lazysym
          else
            lazycalleetype.node.attr.delayresolution = true
          end
        end
      end
      if calleetype then
        attr.type = calleetype:get_return_type(1)
        assert(calleetype.sideeffect ~= nil)
        attr.sideeffect = calleetype.sideeffect
      end
    elseif calleetype:is_table() then
      -- table call (allowed for tables with metamethod __index)
      attr.type = primtypes.varanys
      attr.sideeffect = true
    elseif calleetype:is_any() then
      -- call on any values
      attr.type = primtypes.varanys
      -- builtins usually don't have side effects
      attr.sideeffect = not attr.builtin
    else
      -- call on invalid types (i.e: numbers)
      node:raisef("cannot call type '%s'", calleetype:prettyname())
    end
    attr.calleetype = calleetype
  end
end

function visitors.Call(context, node)
  local attr = node.attr
  local argnodes, calleenode, isblockcall = node:args()

  context:traverse(argnodes)
  context:traverse(calleenode)

  local calleeattr = calleenode.attr
  local calleetype = calleeattr.type
  if calleetype and calleetype:is_pointer() then
    calleetype = calleetype.subtype
    assert(calleetype)
    attr.pointercall = true
  end

  if calleetype and calleetype:is_type() then
    visitor_Call_typeassertion(context, node, argnodes, calleeattr.value)
  else
    visitor_Call(context, node, argnodes, calleetype)

    if calleeattr.builtin then
      local builtinfunc = builtins[calleeattr.name]
      if builtinfunc then
        builtinfunc(context, node)
      end
    end
  end
end

function visitors.CallMethod(context, node)
  local name, argnodes, calleenode, isblockcall = node:args()
  local attr = node.attr

  context:traverse(argnodes)
  context:traverse(calleenode)

  local calleetype = calleenode.attr.type
  if calleetype then
    if calleetype:is_pointer() then
      calleetype = calleetype.subtype
      assert(calleetype)
      attr.pointercall = true
    end

    attr.calleetype = calleetype
    if calleetype:is_record() then
      --TODO: consider lazy functions
      local symbol = calleetype:get_metafield(name)
      if not symbol then
        node:raisef("cannot index record meta field '%s'", name)
      end
      calleetype = symbol.type
      attr.methodsym = symbol
    elseif calleetype:is_string() then
      --TODO: string methods
      calleetype = primtypes.any
    elseif calleetype:is_any() then
      calleetype = primtypes.any
    end
  end

  visitor_Call(context, node, argnodes, calleetype, calleenode)
end

function visitors.Block(context, node, scopecb)
  if node.preprocess then
    local ok, err = except.trycall(function() node:preprocess() end)
    if not ok then
      node:raisef('error while preprocessing block: %s', err)
    end
    node.preprocess = nil
  end
  local statnodes = node:args()
  context:repeat_scope_until_resolution('block', function()
    context:traverse(statnodes)
    if scopecb then
      scopecb()
    end
  end)
end

function visitors.If(context, node)
  local iflist, elsenode = node:args()
  for _,ifpair in ipairs(iflist) do
    local ifcondnode, ifblocknode = ifpair[1], ifpair[2]
    context:traverse(ifcondnode)
    context:traverse(ifblocknode)
  end
  if elsenode then
    context:traverse(elsenode)
  end
end

function visitors.Switch(context, node)
  local valnode, caseparts, elsenode = node:args()
  context:traverse(valnode)
  local valtype = valnode.attr.type
  if valtype and not (valtype:is_any() or valtype:is_integral()) then
    valnode:raisef(
      "`switch` statement must be convertible to an integral type, but got type `%s` (non integral)",
      valtype:prettyname())
  end
  for _,casepart in ipairs(caseparts) do
    local casenode, blocknode = casepart[1], casepart[2]
    context:traverse(casenode)
    if not (casenode.attr.type and casenode.attr.type:is_integral() and
           (casenode.attr.comptime or casenode.attr.cimport)) then
      casenode:raisef("`case` statement must evaluate to a compile time integral value")
    end
    context:traverse(blocknode)
  end
  if elsenode then
    context:traverse(elsenode)
  end
end

function visitors.While(context, node)
  local condnode, blocknode = node:args()
  context:traverse(condnode)
  context:traverse(blocknode)
end

function visitors.Repeat(context, node)
  local blocknode, condnode = node:args()
  context:traverse(blocknode, function()
    context:traverse(condnode)
  end)
end

function visitors.ForIn(context, node)
  local itvarnodes, inexpnodes, blocknode = node:args()
  assert(#inexpnodes > 0)
  if #inexpnodes > 3 then
    node:raisef("`in` statement can have at most 3 arguments")
  end
  local infuncnode = inexpnodes[1]
  local infunctype = infuncnode.attr.type
  if infunctype and not (infunctype:is_any() or infunctype:is_function()) then
    node:raisef("first argument of `in` statement must be a function, but got type '%s'",
      infunctype:prettyname())
  end
  context:traverse(inexpnodes)
  context:repeat_scope_until_resolution('loop', function()
  --[[
  if itvarnodes then
    for i,itvarnode in ipairs(itvarnodes) do
      local itsymbol = context:traverse(itvarnode)
      if infunctype and infunctype:is_function() then
        local fittype = infunctype:get_return_type(i)
        itsymbol:add_possible_type(fittype)
      end
    end
  end
    ]]
  context:traverse(blocknode)
  end)
end

function visitors.ForNum(context, node)
  local itvarnode, begvalnode, compop, endvalnode, stepvalnode, blocknode = node:args()
  local itname = itvarnode[1]
  context:traverse(begvalnode)
  context:traverse(endvalnode)
  local btype, etype = begvalnode.attr.type, endvalnode.attr.type
  local stype
  if stepvalnode then
    context:traverse(stepvalnode)
    stype = stepvalnode.attr.type
  end
  context:repeat_scope_until_resolution('loop', function()
    local itsymbol = context:traverse(itvarnode)
    local ittype = itvarnode.attr.type
    if ittype then
      if not (ittype:is_arithmetic() or (ittype:is_any() and not ittype:is_varanys())) then
        itvarnode:raisef("`for` variable '%s' must be a number, but got type '%s'", itname, ittype)
      end
      if btype then
        local ok, err = ittype:is_convertible_from(begvalnode)
        if not ok then
          begvalnode:raisef("in `for` begin variable '%s': %s", itname, err)
        end
      end
      if etype then
        local ok, err = ittype:is_convertible_from(endvalnode)
        if not ok then
          endvalnode:raisef("in `for` end variable '%s': %s", itname, err)
        end
      end
      if stype then
        local ok, err = ittype:is_convertible_from(stepvalnode)
        if not ok then
          stepvalnode:raisef("in `for` step variable '%s': %s", itname, err)
        end
      end
    else
      itsymbol:add_possible_type(btype, true)
      itsymbol:add_possible_type(etype, true)
    end
    context:traverse(blocknode)
  end)
  local fixedstep
  if stype and stype:is_arithmetic() and stepvalnode.attr.comptime then
    -- constant step
    fixedstep = stepvalnode.attr.value
    if fixedstep:iszero() then
      stepvalnode:raisef("`for` step cannot be zero")
    end
  elseif not stepvalnode then
    -- default step is '1'
    fixedstep = bn.new(1)
  end
  local fixedend
  if etype and etype:is_arithmetic() and endvalnode.attr.comptime then
    fixedend = endvalnode.attr.value
  end
  if not compop and fixedstep then
    -- we now that the step is a constant numeric value
    -- compare operation must be `ge` ('>=') when step is negative
    compop = fixedstep:isneg() and 'ge' or 'le'
  end
  node.attr.fixedstep = fixedstep
  node.attr.fixedend = fixedend
  node.attr.compop = compop
end

function visitors.VarDecl(context, node)
  local varscope, varnodes, valnodes = node:args()
  local assigning = not not valnodes
  valnodes = valnodes or {}
  if #varnodes < #valnodes then
    node:raisef("extra expressions in declaration, expected at most %d but got %d",
    #varnodes, #valnodes)
  end
  for _,varnode,valnode,valtype in izipargnodes(varnodes, valnodes) do
    assert(varnode.tag == 'IdDecl')
    if varscope == 'global' then
      if not context.scope:is_topscope() then
        varnode:raisef("global variables can only be declared in top scope")
      end
      varnode.attr.global = true
    end
    if varscope == 'global' or context.scope:is_topscope() then
      varnode.attr.staticstorage = true
    end
    if context.nostatic then
      varnode.attr.nostatic = true
    end
    local symbol = context:traverse(varnode)
    assert(symbol)
    local vartype = varnode.attr.type
    if vartype and (vartype:is_void() or vartype:is_varanys()) then
      varnode:raisef("variable declaration cannot be of the type '%s'", vartype:prettyname())
    end
    assert(symbol.type == vartype)
    varnode.assign = true
    if (varnode.attr.comptime or varnode.attr.const) and not varnode.attr.nodecl and not valnode then
      varnode:raisef("const variables must have an initial value")
    end
    if valnode then
      valnode.desiredtype = vartype
      context:traverse(valnode, symbol)
      valtype = valnode.attr.type
      if valtype then
        if valtype:is_varanys() then
          -- varanys are always stored as any in variables
          valtype = primtypes.any
        elseif not vartype and valtype:is_nil() then
          -- untyped variables assigned to nil always store as any type
          valtype = primtypes.any
        end
      end
      if varnode.attr.comptime and not (valnode.attr.comptime and valtype) then
        varnode:raisef("compile time variables can only assign to compile time expressions")
      elseif vartype and not valtype and vartype:is_auto() then
        valnode:raisef("auto variables must be assigned to expressions where type is known ahead")
      elseif varnode.attr.cimport and not
        (vartype == primtypes.type or (vartype == nil and valtype == primtypes.type)) then
        varnode:raisef("cannot assign imported variables, only imported types can be assigned")
      end

      if valtype == vartype and valnode.attr.comptime then
        valnode.attr.initializer = true
      end
    else
      if context.noinit then
        varnode.attr.noinit = true
      end
    end
    if assigning and valtype then
      if valtype:is_void() then
        varnode:raisef("cannot assign to expressions of type 'void'")
      end
      local foundtype = true
      local assignvaltype = false
      if varnode.attr.comptime then
        -- for comptimes the type must be known ahead
        assert(valnode)
        assignvaltype = not vartype
        symbol.value = valnode.attr.value
      elseif valtype:is_type() then
        -- for 'type' types the type must also be known ahead
        assert(valnode and valnode.attr.value)
        assignvaltype = vartype ~= valtype
        symbol.value = valnode.attr.value
      else
        foundtype = false
      end

      if vartype and vartype:is_auto() then
        assignvaltype = vartype ~= valtype
      end

      if assignvaltype then
        vartype = valtype
        symbol.type = vartype

        local annotnode = varnode[3]
        if annotnode then
          -- must traverse again annotation node early once type is found ahead
          context:traverse(annotnode, symbol)
        end
      elseif not foundtype then
        -- lazy type evaluation
        symbol:add_possible_type(valtype)
      end
      if vartype and assigning then
        local ok, err = vartype:is_convertible_from(valnode or valtype)
        if not ok then
          varnode:raisef("in variable '%s' declaration: %s", symbol.name, err)
        end
      end
    end
  end
end

function visitors.Assign(context, node)
  local varnodes, valnodes = node:args()
  if #varnodes < #valnodes then
    node:raisef("extra expressions in assign, expected at most %d but got %d", #varnodes, #valnodes)
  end
  for i,varnode,valnode,valtype in izipargnodes(varnodes, valnodes) do
    local symbol = context:traverse(varnode)
    local vartype = varnode.attr.type
    varnode.assign = true
    if varnode.attr.const or varnode.attr.comptime then
      varnode:raisef("cannot assign a constant variable")
    end
    if valnode then
      valnode.desiredtype = vartype
      context:traverse(valnode)
      valtype = valnode.attr.type
    end
    if valtype then
      if valtype:is_void() then
        varnode:raisef("cannot assign to expressions of type 'void'")
      end
      if valtype and valtype:is_varanys() then
        -- varanys are always stored as any in variables
        valtype = primtypes.any
      end
    end
    if symbol then -- symbol may nil in case of array/dot index
      symbol:add_possible_type(valtype)
      symbol.mutate = true
    end
    if not valnode and valtype and valtype:is_nil() then
      varnode:raisef("variable assignment at index '%d' is assigning to nothing in the expression", i)
    end
    if vartype and valtype then
      local ok, err = vartype:is_convertible_from(valnode or valtype)
      if not ok then
        varnode:raisef("in variable assignment: %s", err)
      end
    end
  end
end

function visitors.Return(context, node)
  local retnodes = node:args()
  context:traverse(retnodes)
  local funcscope = context.scope:get_parent_of_kind('function')
  if funcscope.returntypes then
    for i,funcrettype,retnode,rettype in izipargnodes(funcscope.returntypes, retnodes) do
      if rettype then
        if funcrettype then
          if rettype:is_nil() and not funcrettype:is_nilable() then
            node:raisef("missing return expression at index %d of type '%s'", i, funcrettype:prettyname())
          end
          local ok, err = funcrettype:is_convertible_from(retnode or rettype)
          if not ok then
            (retnode or node):raisef("return at index %d: %s", i, err)
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

local function resolve_function_argtypes(symbol, varnode, argnodes, scope)
  local islazyparent = false
  local argtypes = {}

  for i,argnode in ipairs(argnodes) do
    local argattr = argnode.attr
    -- function arguments types must be known ahead, fallbacks to any if untyped
    local argtype = argattr.type or primtypes.any
    if argtype.lazyable or argattr.comptime then
      islazyparent = true
    end
    argtypes[i] = argtype
  end

  if varnode.tag == 'ColonIndex' and symbol and symbol.metafunc then
    -- inject 'self' type as first argument
    table.insert(argtypes, 1, symbol.metarecordtype)
    local selfsym = Symbol()
    selfsym:init('self')
    selfsym.type = symbol.metarecordtype
    local ok, err = scope:add_symbol(selfsym)
    if not ok then
      varnode:raisef(err)
    end
  end

  return argtypes, islazyparent
end

local function block_endswith_return(blocknode)
  assert(blocknode.tag == 'Block')
  local statnodes = blocknode[1]
  local laststat = statnodes[#statnodes]
  if not laststat then return false end
  if laststat.tag == 'Return' then
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
  if not functype or functype.lazyfunction or attr.nodecl or attr.cimport then
    return
  end
  if #returntypes > 0 then
    local canbeempty = tabler.iall(returntypes, function(rettype)
      return rettype:is_nilable()
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
  if context.nostatic then
    varnode.attr.nostatic = true
  end
  local symbol = context:traverse(varnode)
  if symbol and symbol.metafunc then
    decl = true
  end
  return symbol, decl
end

local function visitor_FuncDef_returns(context, functype, retnodes)
  local returntypes
  context:traverse(retnodes)
  if #retnodes > 0 then
    -- returns types are predeclared
    returntypes = tabler.imap(retnodes, function(retnode)
      return retnode.attr.value
    end)

    if #returntypes == 1 and returntypes[1]:is_void() then
      -- single void type means no returns
      returntypes = {}
    end
  elseif functype and not functype.returntypes.has_unknown then
    -- use return types from previous traversal only if fully resolved
    returntypes = functype.returntypes
  end
  return returntypes
end

function visitors.FuncDef(context, node, lazysymbol)
  local varscope, varnode, argnodes, retnodes, annotnodes, blocknode = node:args()

  context.infuncdef = node
  context.inlazydef = lazysymbol
  local symbol, decl = visitor_FuncDef_variable(context, varscope, varnode)
  context.infuncdef = nil
  context.inlazyfuncdef = nil

  local returntypes = visitor_FuncDef_returns(context, node.attr.type, retnodes)

  -- repeat scope to resolve function variables and return types
  local islazyparent, argtypes
  local funcscope = context:repeat_scope_until_resolution('function', function(scope)
    scope.returntypes = returntypes
    context:traverse(argnodes)
    argtypes, islazyparent = resolve_function_argtypes(symbol, varnode, argnodes, scope)

    if not islazyparent then
      -- lazy functions never traverse the blocknode by itself
      context:traverse(blocknode)
    end
  end)

  if not islazyparent and not returntypes then
    returntypes = funcscope.resolved_returntypes
  end

  -- set the function type
  local type = node.attr.type
  if islazyparent then
    assert(not lazysymbol)
    if not type then
      type = types.LazyFunctionType(node, argtypes, returntypes)
    end
  elseif not returntypes.has_unknown then
    type = types.FunctionType(node, argtypes, returntypes)
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
    context:traverse(annotnodes, symbol)
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
    end

    -- annotation sideeffect, the function has side effects unless told otherwise
    if type then
      type.sideeffect = not attr.nosideeffect
    end

    -- annotation entrypoint
    if attr.entrypoint then
      if context.ast.attr.entrypoint and context.ast.attr.entrypoint ~= node then
        node:raisef("cannot have more than one function entrypoint")
      end
      attr.declname = attr.codename
      context.ast.attr.entrypoint = node
    end
  end

  -- traverse lazy function nodes
  if islazyparent then
    for i,lazy in ipairs(node.lazys) do
      local lazysym, lazyargtypes, lazynode
      if traits.is_attr(lazy) then
        lazysym = lazy
      else
        lazyargtypes = lazy
      end
      if not lazysym then
        lazynode = node:clone()
        lazynode.attr.lazynode = lazynode
        lazynode.attr.lazyargtypes = lazyargtypes
        local lazyargnodes = lazynode[3]
        for j,lazyargtype in ipairs(lazyargtypes) do
          lazyargnodes[j].attr.type = lazyargtype
        end
      else
        lazynode = lazysym.lazynode
      end
      context:traverse(lazynode, symbol)
      assert(lazynode.attr._symbol)
      node.lazys[i] = lazynode.attr
    end
  end
end

function visitors.UnaryOp(context, node)
  local attr = node.attr
  local opname, argnode = node:args()

  context:traverse(argnode)

  -- quick return for already resolved type
  if attr.type then return end

  local argattr = argnode.attr
  argattr.inoperator = true
  local argtype = argattr.type
  local type
  if argtype then
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
  if type then
    attr.type = type
  end
  attr.sideeffect = argattr.sideeffect
end

function visitors.BinaryOp(context, node)
  local opname, lnode, rnode = node:args()
  local attr = node.attr

  if opname == 'or' and lnode.tag == 'BinaryOp' and lnode[1] == 'and' then
    lnode.attr.ternaryand = true
    attr.ternaryor = true
  end

  context:traverse(lnode)
  context:traverse(rnode)

  -- quick return for already resolved type
  if attr.type then return end

  local lattr, rattr = lnode.attr, rnode.attr
  local ltype, rtype = lattr.type, rattr.type

  lattr.inoperator = true
  rattr.inoperator = true

  local isbinaryconditional = opname == 'or' or opname == 'and'
  if rtype and ltype and isbinaryconditional and (not rtype:is_boolean() or not ltype:is_boolean()) then
    attr.dynamic_conditional = true
  end
  attr.sideeffect = lattr.sideeffect or rattr.sideeffect or nil

  local type
  if ltype and rtype then
    local value, err
    type, value, err = ltype:binary_operator(opname, rtype, lattr, rattr)
    if err then
      lnode:raisef("in binary operation `%s`: %s", opname, err)
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

function typechecker.analyze(ast, parser, parentcontext)
  local context = Context(visitors, parentcontext)
  context.ast = ast
  context.parser = parser
  context.astbuilder = parser.astbuilder

  local mainscope = context:push_scope('function')
  mainscope.main = true
  preprocessor.preprocess(context, ast)
  context:pop_scope()

  local function analyze_ast()
    mainscope = context:repeat_scope_until_resolution('function', function(scope)
      scope.main = true
      context:traverse(ast)
    end)
    context.rootscope:resolve()
  end

  -- phase 1 traverse: infer and check types
  analyze_ast()

  -- phase 2 traverse: infer unset types to 'any' type
  context.anyinference = true
  analyze_ast()

  -- forward global attributes to ast
  if context.nofloatsuffix then
    ast.attr.nofloatsuffix = true
  end

  -- used when calling
  context.scope = mainscope

  return ast
end

return typechecker
