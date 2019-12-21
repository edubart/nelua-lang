local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local tabler = require 'nelua.utils.tabler'
local typedefs = require 'nelua.typedefs'
local Context = require 'nelua.context'
local Symbol = require 'nelua.symbol'
local types = require 'nelua.types'
local bn = require 'nelua.utils.bn'
local preprocessor = require 'nelua.preprocessor'
local builtins = require 'nelua.builtins'
local typechecker = {}

local primtypes = typedefs.primtypes
local visitors = {}

local phases = {
  type_inference = 1,
  any_inference = 2
}

function visitors.Number(_, node)
  local attr = node.attr
  if attr.type then return end
  local base, int, frac, exp, literal = node:args()
  if literal then
    attr.type = typedefs.number_literal_types[literal]
    if not attr.type then
      node:raisef("literal suffix '%s' is not defined", literal)
    end
  else
    attr.untyped = true
    if not (frac or exp) then
      attr.type = primtypes.integer
    else
      attr.type = primtypes.number
    end
  end
  attr.value = bn.frombase(base, int, frac, exp)
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
  attr.type = primtypes.Nil
  attr.comptime = true
end

local function visitor_ArrayTable_literal(context, node, littype)
  local attr = node.attr
  local childnodes = node:args()
  local subtype = littype.subtype
  for i, childnode in ipairs(childnodes) do
    if childnode.tag == 'Pair' then
      childnode:raisef("in array table literal value, fields are not allowed")
    end
    childnode.desiredtype = subtype
    context:traverse(childnode)
    local childtype = childnode.attr.type
    if childtype then
      if childtype == subtype then
        childnode.attr.initializer = true
      else
        local ok, err = subtype:is_conversible_from(childnode.attr)
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
    node:raisef("in array literal, expected %d values but got %d", littype.length, #childnodes)
  end
  for i, childnode in ipairs(childnodes) do
    if childnode.tag == 'Pair' then
      childnode:raisef("in array literal, fields are not allowed")
    end
    childnode.desiredtype = subtype
    context:traverse(childnode)
    local childtype = childnode.attr.type
    if childtype then
      if childtype == subtype then
        childnode.attr.initializer = true
      else
        local ok, err = subtype:is_conversible_from(childnode.attr)
        if not ok then
          childnode:raisef("in array literal of subtype '%s' at index %d: %s", subtype, i, err)
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
        childnode:raisef("in record literal, only string literals are allowed in field names")
      end
      field, fieldindex = littype:get_field(fieldname)
    else
      fieldindex = lastfieldindex + 1
      field = littype.fields[fieldindex]
      if not field then
        childnode:raisef("in record literal, field at index %d is not valid, record has only %d fields",
        fieldindex, #littype.fields)
      end
      fieldname = field.name
      fieldvalnode = childnode
    end
    if not field then
      childnode:raisef("in record literal, field '%s' is not present in record of type '%s'",
      fieldname, littype)
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
        local ok, err = fieldtype:is_conversible_from(fieldvalnode.attr)
        if not ok then
          childnode:raisef("in record literal, field '%s' of type '%s': %s", fieldname, fieldtype, err)
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
    node:raisef("in table literal, type '%s' cannot be initialized using a table literal", desiredtype)
  end
end

function visitors.PragmaSet(context, node)
  local name, value = node:args()
  local pragmashape = typedefs.field_pragmas[name]
  node:assertraisef(pragmashape, "pragma '%s' is not defined", name)
  context[name] = value
  --TODO: check argument types
end

function visitors.PragmaCall(_, node)
  local name, args = node:args()
  local pragmashape = typedefs.call_pragmas[name]
  node:assertraisef(pragmashape, "pragma '%s' is not defined", name)
  --TODO: check argument types
end

function visitors.Attrib(context, node, symbol)
  --TODO: quick return

  local name, argnodes = node:args()
  context:traverse(argnodes)
  assert(symbol)

  local paramshape
  local symboltype
  if name == 'comptime' then
    paramshape = true
  else
    symboltype = symbol.attr.type
    if not symboltype then
      -- in the next traversal we will have the type
      return
    end
    if symboltype:is_function() then
      paramshape = typedefs.function_attribs[name]
    elseif symboltype:is_type() then
      paramshape = typedefs.type_attribs[name]
    else
      paramshape = typedefs.variable_attribs[name]
    end
  end
  if not paramshape then
    node:raisef("attribute '%s' is not defined in this context", name)
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
      node:raisef("attribute '%s' takes no arguments", name)
    end
    params = true
  else
    local ok, err = paramshape(params)
    if not ok then
      node:raisef("attribute '%s' arguments are invalid: %s", name, err)
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
    type = symbol.attr.value
    attr = type
  else
    attr = symbol.attr
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
  local symbol = context.scope:get_symbol(name, node, true)
  if not symbol then
    local type = node.attr.type
    if not type and context.phase == phases.any_inference then
      type = primtypes.any
    end
    symbol = context.scope:add_symbol(Symbol(name, node, type))
  else
    symbol:link_node(node)
  end
  symbol.attr.lvalue = true
  return symbol
end

function visitors.IdDecl(context, node)
  local namenode, typenode, attribnodes = node:args()
  local type = node.attr.type
  if not type then
    if typenode then
      context:traverse(typenode)
      type = typenode.attr.value
    end
    if context.phase == phases.any_inference then
      type = primtypes.any
    end
  end
  local symbol
  if traits.is_string(namenode) then
    symbol = context.scope:add_symbol(Symbol(namenode, node, type))

    if node.attr.global then
      -- globals are always visible in the global root scope too
      context.rootscope:add_symbol(symbol)
    end
  else
    -- global record field
    assert(namenode.tag == 'DotIndex')
    context.inglobaldecl = node
    symbol = context:traverse(namenode)
    context.inglobaldecl = nil
  end
  local attr = symbol.attr
  if type then
    attr.type = type
  end
  if attribnodes then
    context:traverse(attribnodes, symbol)
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
    local symbol = context.scope:get_symbol(tyname, node)
    if not (symbol and symbol.attr.type == primtypes.type and symbol.attr.value) then
      node:raisef("symbol '%s' is not a valid type", tyname)
    end
    value = symbol.attr.value
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
      prefix = context.modname or context.ast.modname
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
  attr.value = type
end

function visitors.MultipleType(context, node)
  local attr = node.attr
  if attr.type then return end
  local typenodes = node:args()
  assert(#typenodes > 1)
  context:traverse(typenodes)
  attr.type = primtypes.type
  attr.value = types.MultipleType(node,
    tabler.imap(typenodes, function(typenode) return typenode.attr.value end))
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
      numnode:raisef("enum fields can only be assigned to compile time values")
    elseif not numtype:is_integral() then
      numnode:raisef("only integral numbers are allowed in enums, but got type '%s'", numtype)
    end
    local ok, err = desiredtype:is_conversible_from(numnode)
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
        fnode:raisef("in enum declaration, first field requires a initial value")
      else
        field.value = fields[i-1].value:add(1)
      end
    end
    if not subtype:is_inrange(field.value) then
      fnode:raisef("in enum value %s or field '%s' is not in range of type '%s'",
        field.value:todec(), field.name, subtype)
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
    subtypenode:raisef("spans cannot be of type '%s' type", subtype)
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
    subtypenode:raisef("ranges subtype '%s' is not an integral type", subtype)
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
  if not (lengthnode.attr.type:is_integral() and length >= 0) then
    lengthnode:raisef("expected a valid decimal integral number in the second argument of an 'array' type")
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
    attr.value = types.get_pointer_type(subtype, node)
    if not attr.value then
      node:raisef("subtype '%s' is not valid for pointer type", subtype)
    end
  else
    attr.value = primtypes.pointer
  end
  attr.type = primtypes.type
end

local function visitor_FieldIndex(context, node)
  local attr = node.attr
  local name, objnode = node:args()
  context:traverse(objnode)
  --[[
  -- TODO: this was disabled because of caching bugs
  if attr.type then
    -- type already known, return early
    local objtype = objnode.attr.type
    if objtype:is_type() then
      objtype = objnode.attr.value
      if objtype:is_record() then
        return objtype:get_metafield(name)
      end
    end
    return
  end
  ]]
  local symbol, type
  local objtype = objnode.attr.type
  if objtype then
    if objtype:is_pointer() then
      objtype = objtype.subtype
    end

    if objtype:is_record() then
      local field = objtype:get_field(name)
      type = field and field.type
      if not type then
        node:raisef("record '%s' does not have field named '%s'", objtype, name)
      end
    elseif objtype:is_type() then
      objtype = objnode.attr.value
      assert(objtype)
      if objtype:is_pointer() and objtype.subtype:is_record() then
        -- allow to access method and fields on record pointer types
        objtype = objtype.subtype
      end
      attr.indextype = objtype
      if objtype:is_enum() then
        local field = objtype:get_field(name)
        if not field then
          node:raisef("enum '%s' does not have field named '%s'", objtype, name)
        end
        attr.comptime = true
        attr.value = field.value
        type = objtype
      elseif objtype:is_record() then
        symbol = objtype:get_metafield(name)
        local parentnode = context:get_parent_node()
        if not symbol then
          local symname = string.format('%s_%s', objtype.codename, name)
          if context.infuncdef == parentnode then
            -- declaration of record global function
            symbol = Symbol(symname, node)
            symbol.attr.const = true
            symbol.attr.metafunc = true
            symbol.attr.metavar = true
            symbol.attr.metarecordtype = types.get_pointer_type(objtype, objnode)
            objtype:set_metafield(name, symbol)
          elseif context.inglobaldecl == parentnode then
            -- declaration of record global variable
            symbol = Symbol(symname, node)
            symbol.attr.metavar = true
            objtype:set_metafield(name, symbol)

            -- add symbol to scope to enable type deduction
            context.scope:add_symbol(symbol)
          else
            node:raisef("cannot index record meta field '%s'", name)
          end
          symbol:link_node(parentnode)
        elseif context.infuncdef or context.inglobaldecl then
          if symbol.node ~= node then
            node:raisef("cannot redefine meta type function")
          end
        else
          symbol:link_node(node)
        end
        if symbol then
          type = symbol.attr.type
        end
      else
        node:raisef("cannot index fields for type '%s'", objtype)
      end
    elseif not (objtype:is_table() or objtype:is_any()) then
      node:raisef("cannot index field '%s' on variable of type '%s'", name, objtype.name)
    end
  end
  if not type and context.phase == phases.any_inference then
    type = primtypes.any
  end
  if objnode.attr.lvalue then
    attr.lvalue = true
  end
  attr.type = type
  return symbol
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
              indexnode:raisef("in array indexing, trying to index negative value %s",
                indexvalue:todec())
            end
            if objtype:is_array() and objtype.length ~= 0 and not (indexvalue < bn.new(objtype.length)) then
              indexnode:raisef("in array indexing, index %s is out of bounds, array maximum index is %d",
                indexvalue:todec(), objtype.length - 1)
            end
          end
          type = objtype.subtype
        elseif indextype:is_range() and (objtype:is_array() or objtype:is_span()) then
          type = types.SpanType(node, objtype.subtype)
        else
          indexnode:raisef("in array indexing, trying to index with value of type '%s'", indextype)
        end
      end
    elseif not (objtype:is_table() or objtype:is_any()) then
      node:raisef("cannot index variable of type '%s'", objtype.name)
    end
  end
  if not type and context.phase == phases.any_inference then
    type = primtypes.any
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
            -- in case it doest not exists, the argtype will be false
            local callretindex = i - lastargindex + 1
            local argtype = calleetype:get_return_type(callretindex) or false
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
      -- in case this is inexistent, set argtype to false
      local argtype
      if argnode then
        argtype = argnode.attr.type
      else
        argtype =false
      end
      return i, var, argnode, argtype
    end
  end
end

local function visitor_Call(context, node, argnodes, calleetype, methodcalleenode)
  local attr = node.attr
  if calleetype then
    attr.calleetype = calleetype

    if calleetype:is_function() then
      -- function call
      local funcargtypes = calleetype.argtypes
      local pseudoargtypes = funcargtypes
      if methodcalleenode then
        pseudoargtypes = tabler.copy(funcargtypes)
        local ok, err = funcargtypes[1]:is_conversible_from(methodcalleenode)
        if not ok then
          node:raisef("in call argument at index %d of expected type '%s': %s",
            1, funcargtypes[1], err)
        end
        table.remove(pseudoargtypes, 1)
        attr.pseudoargtypes = pseudoargtypes
      end
      if #argnodes > #pseudoargtypes then
        node:raisef("in call, function '%s' expected at most %d arguments but got %d",
          calleetype, #pseudoargtypes, #argnodes)
      end
      local argtypes = {}
      local knownallargs = true
      for i,funcargtype,argnode,argtype in izipargnodes(pseudoargtypes, argnodes) do
        if argnode then
          argnode.desiredtype = funcargtype
          context:traverse(argnode)
          argtype = argnode.attr.type
          if argtype then
            argtypes[i] = argtype
          else
            knownallargs = false
          end
        end
        if argtype == false and not funcargtype:is_nilable() then
          node:raisef("in call, function '%s' expected an argument at index %d but got nothing",
            calleetype, i)
        end
        if funcargtype and argtype then
          local ok, err = funcargtype:is_conversible_from(argnode or argtype)
          if not ok then
            node:raisef("in call, function argument at index %d of type '%s': %s", i, funcargtype, err)
          end
        end
      end
      if knownallargs or not calleetype.lazy then
        if methodcalleenode then
          tabler.insert(argtypes, funcargtypes[1])
        end
        attr.type = calleetype:get_return_type_for_argtypes(argtypes, 1)
      end
      assert(calleetype.sideeffect ~= nil)
      attr.sideeffect = calleetype.sideeffect
    elseif calleetype:is_table() then
      -- table call (allowed for tables with metamethod __index)
      context:traverse(argnodes)
      attr.type = primtypes.varanys
      attr.sideeffect = true
    elseif calleetype:is_any() then
      -- call on any values
      context:traverse(argnodes)
      attr.type = primtypes.varanys
      -- builtins usuailly dont do side effects
      attr.sideeffect = not attr.builtin
    else
      -- call on invalid types (i.e: numbers)
      node:raisef("attempt to call a non callable variable of type '%s'",
        calleetype)
    end
  else
    -- callee type is not known yet (will be in known after resolution)
    context:traverse(argnodes)
  end
  --if not node.attr.type and context.phase == phases.any_inference then
  --  node.attr.type = primtypes.any
  --end
  assert(context.phase ~= phases.any_inference or node.attr.type)
end

function visitors.Call(context, node)
  local argnodes, calleenode, isblockcall = node:args()
  context:traverse(calleenode)
  local attr, caleeattr = node.attr, calleenode.attr
  local calleetype = caleeattr.type
  if calleetype and calleetype:is_pointer() then
    calleetype = calleetype.subtype
    assert(calleetype)
    attr.pointercall = true
  end
  if calleetype and calleetype:is_type() then
    -- type assertion
    local type = caleeattr.value
    assert(type)
    if #argnodes ~= 1 then
      node:raisef("in assertion to type '%s', expected one argument, but got %d",
        type, #argnodes)
    end
    local argnode = argnodes[1]
    argnode.desiredtype = type
    context:traverse(argnode)
    local argtype = argnode.attr.type
    if argtype then
      local ok, err = type:is_conversible_from(argnode, true)
      if not ok then
        argnode:raisef("in assertion to type '%s': %s", type, err)
      end
      if argnode.attr.comptime then
        attr.comptime = argnode.attr.comptime
        attr.value = type:normalize_value(argnode.attr.value)
      end
    end
    attr.sideeffect = argnode.attr.sideeffect
    attr.typeassertion = true
    attr.type = type
    attr.calleetype = calleetype
    return
  end

  visitor_Call(context, node, argnodes, calleetype)

  if caleeattr.builtin then
    local builtinfunc = builtins[caleeattr.name]
    if builtinfunc then
      builtinfunc(context, node)
    end
  end
end

function visitors.CallMethod(context, node)
  local name, argnodes, calleenode, isblockcall = node:args()
  local attr = node.attr
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
      local symbol = calleetype:get_metafield(name)
      if not symbol then
        node:raisef("cannot index record meta field '%s'", name)
      end
      calleetype = symbol.attr.type
      attr.symbol = symbol
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
  if not node.processed then
    preprocessor.preprocess(context, node)
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
      "switch expression must be compatible with an integral type, but got type `%s` (non integral)",
      valtype)
  end
  for _,casepart in ipairs(caseparts) do
    local casenode, blocknode = casepart[1], casepart[2]
    context:traverse(casenode)
    if not (casenode.attr.type and casenode.attr.type:is_integral() and
           (casenode.attr.comptime or casenode.attr.cimport)) then
      casenode:raisef("case expression must evaluate to a compile time integral value")
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
    node:raisef("`in` expression can have at most 3 arguments")
  end
  local infuncnode = inexpnodes[1]
  local infunctype = infuncnode.attr.type
  if infunctype and not (infunctype:is_any() or infunctype:is_function()) then
    node:raisef("first argument of `in` expression must be a function, but got type '%s'", infunctype)
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
        local ok, err = ittype:is_conversible_from(begvalnode)
        if not ok then
          begvalnode:raisef("`for` variable '%s' of type '%s': %s", itname, ittype, err)
        end
      end
      if etype then
        local ok, err = ittype:is_conversible_from(endvalnode)
        if not ok then
          endvalnode:raisef("`for` variable '%s' of type '%s': %s", itname, ittype, err)
        end
      end
      if stype then
        local ok, err = ittype:is_conversible_from(stepvalnode)
        if not ok then
          stepvalnode:raisef("`for` variable '%s' of type '%s': %s", itname, ittype, err)
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
    -- we now that the step is a const numeric value
    -- compare operation must be ge ('>=') when step is negative
    compop = fixedstep:isneg() and 'ge' or 'le'
  end
  node.attr.fixedstep = fixedstep
  node.attr.fixedend = fixedend
  node.attr.compop = compop
end

function visitors.VarDecl(context, node)
  local varscope, varnodes, valnodes = node:args()
  valnodes = valnodes or {}
  if #varnodes < #valnodes then
    node:raisef("too many expressions in declaration, expected at most %d but got %d",
    #varnodes, #valnodes)
  end
  for _,varnode,valnode,valtype in izipargnodes(varnodes, valnodes) do
    assert(varnode.tag == 'IdDecl')
    if varscope == 'global' then
      if not context.scope:is_static_storage() then
        varnode:raisef("global variables can only be declared in top scope")
      end
      varnode.attr.global = true
    end
    if context.nostatic then
      varnode.attr.nostatic = true
    end
    local symbol = context:traverse(varnode)
    assert(symbol)
    local vartype = varnode.attr.type
    if vartype and (vartype:is_multipletype() or vartype:is_void() or vartype:is_varanys()) then
      varnode:raisef("variable declaration cannot be of the type '%s'", vartype)
    end
    assert(symbol.attr.type == vartype)
    varnode.assign = true
    if (varnode.attr.comptime or varnode.attr.const) and not varnode.attr.nodecl and not valnode then
      varnode:raisef("const variables must have an initial value")
    end
    if valnode then
      valnode.desiredtype = vartype
      context:traverse(valnode, symbol)
      valtype = valnode.attr.type
      if valtype and valtype:is_varanys() then
        -- varanys are always stored as any in variables
        valtype = primtypes.any
      end
      if varnode.attr.comptime and not (valnode.attr.comptime and valtype) then
        varnode:raisef("constant variables can only assign to constant expressions")
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
    if valtype then
      if valtype:is_void() then
        varnode:raisef('cannot assign to expressions of type void')
      end
      local foundtype = true
      local assignvaltype = false
      if varnode.attr.comptime then
        -- for consts the type must be known ahead
        assignvaltype = not vartype
        symbol.attr.value = valnode.attr.value
      elseif valtype:is_type() then
        -- for 'type' types the type must also be known ahead
        assert(valnode and valnode.attr.value)
        assignvaltype = vartype ~= valtype
        symbol.attr.value = valnode.attr.value
      else
        foundtype = false
      end

      if vartype and vartype:is_auto() then
        assignvaltype = vartype ~= valtype
      end

      if assignvaltype then
        vartype = valtype
        symbol.attr.type = vartype

        local attribnode = varnode[3]
        if attribnode then
          -- must retravese attrib node early once type is found ahead
          context:traverse(attribnode, symbol)
        end
      elseif not foundtype then
        -- lazy type evaluation
        symbol:add_possible_type(valtype)
      end
      if vartype then
        local ok, err = vartype:is_conversible_from(valnode or valtype)
        if not ok then
          varnode:raisef("in variable '%s' declaration: %s", symbol.name, err)
        end
      end
    else
      -- delay type evaluation
      symbol:add_possible_type(nil)
    end
  end
end


function visitors.Assign(context, node)
  local varnodes, valnodes = node:args()
  if #varnodes < #valnodes then
    node:raisef("too many expressions in assign, expected at most %d but got %d", #varnodes, #valnodes)
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
        varnode:raisef("cannot assign to expressions of type void")
      end
      if valtype and valtype:is_varanys() then
        -- varanys are always stored as any in variables
        valtype = primtypes.any
      end
    end
    if symbol then -- symbol may nil in case of array/dot index
      symbol:add_possible_type(valtype)
      symbol.attr.mutate = true
    end
    if vartype and valtype then
      local ok, err = vartype:is_conversible_from(valnode or valtype)
      if not ok then
        varnode:raisef("in variable assignment of type '%s': %s", vartype, err)
      end
    elseif valtype == false then
      varnode:raisef("variable '%s' at index '%d' is assigning to nothing in this expression",
        symbol.name, i)
    end
  end
end

function visitors.Return(context, node)
  local retnodes = node:args()
  context:traverse(retnodes)
  local funcscope = context.scope:get_parent_of_kind('function')
  if funcscope.returntypes then
    for i,funcrettype,retnode,rettype in izipargnodes(funcscope.returntypes, retnodes) do
      if rettype and funcrettype then
        local ok, err = funcrettype:is_conversible_from(retnode or rettype)
        if not ok then
          (retnode or node):raisef("return at index %d of expected type '%s': %s", i, funcrettype, err)
        end
      elseif rettype == false and funcrettype then
        if not funcrettype:is_nilable() then
          node:raisef("missing return expression at index %d of type '%s'", i, funcrettype)
        end
      elseif rettype then
        if #retnodes ~= 0 then
          node:raisef("invalid return expression at index %d", i)
        end
      end
    end
  else
    for i,_,rettype in iargnodes(retnodes) do
      funcscope:add_return_type(i, rettype)
    end
  end
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

function visitors.FuncDef(context, node)
  local varscope, varnode, argnodes, retnodes, attribnodes, blocknode = node:args()
  local symbol, argtypes
  local decl = varscope ~= nil
  if node.deducedargtypes then
    argtypes = node.deducedargtypes
  else
    context.infuncdef = node
    if varscope == 'global' then
      if not context.scope:is_static_storage() then
        varnode:raisef("global function can only be declared in top scope")
      end
      varnode.attr.global = true
    end
    if decl then
      varnode.attr.funcdecl = true
    end
    symbol = context:traverse(varnode)
    context.infuncdef = nil
  end

  context:traverse(retnodes)
  local returntypes
  if #retnodes > 0 then
    -- returns types are pre declared
    returntypes = tabler.imap(retnodes, function(retnode)
      return retnode.attr.value
    end)

    if #returntypes == 1 and returntypes[1]:is_void() then
      -- single void type means no returns
      returntypes = {}
    end
  elseif node.attr.type and not node.attr.type.returntypes.has_unknown then
    -- recover return types from previous traversal only if fully resolved
    returntypes = node.attr.type.returntypes
  end

  -- repeat scope to resolve function variables and return types
  local lazy = false
  local funcscope = context:repeat_scope_until_resolution('function', function(scope)
    scope.returntypes = returntypes
    context:traverse(argnodes)
    if not argtypes then
      argtypes = {}
      for i,argnode in ipairs(argnodes) do
        -- function arguments types must be known ahead, fallbacks to any if untyped
        local argtype = argnode.attr.type or primtypes.any
        argtypes[i] = argtype
        if argtype:is_multipletype() then
          -- multiple possible types for argument, enter lazy mode
          lazy = true
          assert(symbol, "function with multiple types for an argument must have a symbol")
        end
      end

      if varnode.tag == 'ColonIndex' and symbol and symbol.attr.metafunc then
        -- inject 'self' type as first argument
        table.insert(argtypes, 1, symbol.attr.metarecordtype)
      end
    end

    if varnode.tag == 'ColonIndex' and symbol and symbol.attr.metafunc then
      scope:add_symbol(Symbol('self', nil, symbol.attr.metarecordtype))
    end

    if not lazy then
      -- lazy functions never translate the blocknode by itself
      context:traverse(blocknode)
    end
  end)

  if not lazy and not returntypes then
    returntypes = funcscope.resolved_returntypes
  end
  local type = types.FunctionType(node, argtypes, returntypes)

  if symbol then -- symbol may be nil in case of array/dot index
    if decl or symbol.attr.metafunc then
      -- new function declaration
      symbol.attr.type = type
    else
      -- check if previous symbol declaration is compatible
      local symboltype = symbol.attr.type
      if symboltype then
        local ok, err = symboltype:is_conversible_from(type)
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

  if attribnodes then
    context:traverse(attribnodes, symbol)
  end

  if not lazy and node.attr.type and not varnode.attr.nodecl and not varnode.attr.cimport then
    if #returntypes > 0 then
      local canbeempty = tabler.iall(returntypes, function(rettype)
        return rettype:is_nilable()
      end)
      if not canbeempty and not block_endswith_return(blocknode) then
        node:raisef("a return statement is missing before function end")
      end
    end
  end

  if varnode.attr.cimport then
    if #blocknode[1] ~= 0 then
      blocknode:raisef("body of an import function must be empty")
    end
  end

  type.sideeffect = not varnode.attr.nosideeffect

  if varnode.attr.entrypoint then
    if context.ast.attr.entrypoint and context.ast.attr.entrypoint ~= node then
      node:raisef("cannot have more than one function entrypoint")
    end
    varnode.attr.declname = varnode.attr.codename
    context.ast.attr.entrypoint = node
  end

  if node.lazytypes then
    -- traverse deduced types from lazy functions
    assert(lazy)
    for deducedargtypes,deducedfunctype in pairs(node.lazytypes) do
      if not deducedfunctype then
        local funcdefnode = node:clone()
        funcdefnode.deducedargtypes = deducedargtypes
        context:traverse(funcdefnode)
        deducedfunctype = funcdefnode.type
        assert(not deducedfunctype, 'code disabled')
        --[[
        if deducedfunctype then
          node.lazytypes[deducedargtypes] = deducedfunctype
          node.lazynodes[deducedargtypes] = funcdefnode
        end
        ]]
      end
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
      argnode:raisef("unary operation `%s` on type '%s': %s", opname, argtype, err)
    end
    if value ~= nil then
      attr.comptime = true
      attr.value = value
      attr.untyped = argattr.untyped
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
  assert(context.phase ~= phases.any_inference or attr.type)
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
      lnode:raisef("binary operation `%s` between types '%s' and '%s': %s", opname, ltype, rtype, err)
    end
    if value ~= nil then
      attr.comptime = true
      attr.value = value
      attr.untyped = lattr.untyped and rattr.untyped or nil
    end
  end
  if attr.ternaryand then
    type = rtype
  end
  if type then
    attr.type = type
  end
  assert(context.phase ~= phases.any_inference or attr.type)
end

function typechecker.analyze(ast, parser, parentcontext)
  local context = Context(visitors, true, parentcontext)
  context.ast = ast
  context.parser = parser
  context.astbuilder = parser.astbuilder

  -- phase 1 traverse: infer and check types
  context.phase = phases.type_inference
  context:repeat_scope_until_resolution('function', function(scope)
    scope.main = true
    context:traverse(ast)
  end)

  -- phase 2 traverse: infer non set types to 'any' type
  context.phase = phases.any_inference
  context:repeat_scope_until_resolution('function', function(scope)
    scope.main = true
    context:traverse(ast)
  end)

  -- forward global attributes to ast
  if context.nofloatsuffix then
    ast.attr.nofloatsuffix = true
  end

  return ast
end

return typechecker
