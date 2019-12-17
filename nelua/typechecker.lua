local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local tabler = require 'nelua.utils.tabler'
local stringer = require 'nelua.utils.stringer'
local typedefs = require 'nelua.typedefs'
local Context = require 'nelua.context'
local Symbol = require 'nelua.symbol'
local types = require 'nelua.types'
local bn = require 'nelua.utils.bn'
local preprocessor = require 'nelua.preprocessor'
local fs = require 'nelua.utils.fs'
local config = require 'nelua.configer'.get()
local typechecker = {}

local primtypes = typedefs.primtypes
local visitors = {}

local phases = {
  type_inference = 1,
  any_inference = 2
}

local function check_implicit_conversion(node, from, totype, message, ...)
  local convok, convreason = totype:is_conversible_from(from)
  if not convok then
    node:raisef('%s, %s', stringer.pformat(message, ...), convreason)
  end
end

function visitors.Number(_, node, desiredtype)
  local attr = node.attr
  if attr.type and (not desiredtype or attr.littype or desiredtype == attr.type) then
    -- type already known, quick return
    return
  end

  if not attr.value then
    local value
    local base, int, frac, exp, literal = node:args()
    if base == 'hex' then
      value = bn.fromhex(int, frac, exp)
    elseif base == 'bin' then
      value = bn.frombin(int, frac, exp)
    else
      value = bn.fromdec(int, frac, exp)
    end
    local floatexp = exp and (stringer.startswith(exp, '-') or value > primtypes.integer.max)
    local integral = not (frac or floatexp)
    if literal then
      attr.littype = typedefs.number_literal_types[literal]
      node:assertraisef(attr.littype, 'literal suffix "%s" is not defined', literal)
    end
    attr.value = value
    attr.integral = integral
    attr.compconst = true
  end

  local type = attr.littype
  if not type and desiredtype and desiredtype:is_arithmetic() then
    if attr.integral and desiredtype:is_integral() then
      if desiredtype:is_unsigned() and not attr.value:isneg() then
        -- find smallest unsigned type
        for _,itype in ipairs(typedefs.unsigned_types) do
          if attr.value >= itype.min and attr.value <= itype.max then
            type = itype
            break
          end
        end
      else
      -- find smallest signed type
        for _,itype in ipairs(typedefs.integral_signed_types) do
          if attr.value >= itype.min and attr.value <= itype.max then
            type = itype
            break
          end
        end
      end
    elseif desiredtype:is_float() then
      type = desiredtype
    end
  end
  if not type then
    type = attr.integral and primtypes.integer or primtypes.number
    node.untyped = true
  else
    node.untyped = nil
  end
  if not attr.littype and desiredtype and
     desiredtype:is_arithmetic() and desiredtype:is_conversible_from_type(type) then
    type = desiredtype
  end
  if attr.type ~= type then
    --TODO: recheck this
    --[[
    if type:is_integral() and not type:is_inrange(attr.value) then
      node:raisef(
        "value %s for integral of type '%s' is out of range, minimum is %s and maximum is %s",
        attr.value:todec(), type, type.min:todec(), type.max:todec())
    end
    ]]
    attr.type = type
  end
end

function visitors.String(_, node)
  local attr = node.attr
  if attr.type then return end
  local value, literal = node:args()
  node:assertraisef(literal == nil, 'string literals are not supported yet')
  attr.value = value
  attr.type = primtypes.string
  attr.compconst = true
end

function visitors.Boolean(_, node)
  local attr = node.attr
  if attr.type then return end
  local value = node:args(1)
  attr.value = value
  attr.type = primtypes.boolean
  attr.compconst = true
end

function visitors.Nil(_, node)
  local attr = node.attr
  if attr.type then return end
  attr.type = primtypes.Nil
  attr.compconst = true
end

function visitors.Table(context, node, desiredtype)
  local attr = node.attr
  local childnodes = node:args()
  if desiredtype and desiredtype ~= primtypes.table then
    local compconst = true
    if desiredtype:is_arraytable() then
      local subtype = desiredtype.subtype
      for i, childnode in ipairs(childnodes) do
        childnode:assertraisef(childnode.tag ~= 'Pair',
          "in array table literal value, fields are not allowed")
        context:traverse(childnode, subtype)
        local childtype = childnode.attr.type
        if childtype then
          check_implicit_conversion(childnode, childnode, subtype, 'in array table literal at index %d', i)
          if childtype == subtype then
            childnode.attr.initializer = true
          end
        end
      end
      compconst = nil
    elseif desiredtype:is_array() then
      local subtype = desiredtype.subtype
      node:assertraisef(#childnodes == desiredtype.length or #childnodes == 0,
        " in array literal, expected %d values but got %d",
        desiredtype.length, #childnodes)
      for i, childnode in ipairs(childnodes) do
        childnode:assertraisef(childnode.tag ~= 'Pair',
          "in array literal, fields are not allowed")
        context:traverse(childnode, subtype)
        local childtype = childnode.attr.type
        if childtype then
          childnode:assertraisef(subtype:is_conversible_from_node(childnode),
            "in array literal, subtype '%s' no viable type conversion expression at index %d of type '%s'",
            subtype, i, childtype)
          if childtype == subtype then
            childnode.attr.initializer = true
          end
        end
        if not childnode.attr.compconst then
          compconst = nil
        end
      end
    elseif desiredtype:is_record() then
      local lastfieldindex = 0
      for _, childnode in ipairs(childnodes) do
        local fieldname, fieldvalnode, field, fieldindex
        if childnode.tag == 'Pair' then
          fieldname, fieldvalnode = childnode:args()
          childnode:assertraisef(traits.is_string(fieldname),
            "in record literal, only string literals are allowed in field names")
          field, fieldindex = desiredtype:get_field(fieldname)
        else
          fieldindex = lastfieldindex + 1
          field = desiredtype.fields[fieldindex]
          childnode:assertraisef(field,
            "in record literal, field at index %d is not valid, record has only %d fields",
            fieldindex, #desiredtype.fields)
          fieldname = field.name
          fieldvalnode = childnode
        end
        childnode:assertraisef(field,
          "in record literal, field '%s' is not present in record of type '%s'",
          fieldname, desiredtype)
        local fieldtype = field.type
        context:traverse(fieldvalnode, fieldtype)
        lastfieldindex = fieldindex
        local fieldvaltype = fieldvalnode.attr.type
        if fieldvaltype then
          fieldvalnode:assertraisef(fieldtype:is_conversible_from_node(fieldvalnode),
            "in record literal, field '%s' of type '%s' no viable type conversion expression of type '%s'",
            fieldname, fieldtype, fieldvaltype)
          if fieldvaltype == fieldtype then
            fieldvalnode.attr.initializer = true
          end
        end
        childnode.attr.parenttype = desiredtype
        if not fieldvalnode.attr.compconst then
          compconst = nil
        end
      end
    else
      node:raisef("in table literal, type '%s' cannot be initialized using a table literal",
        desiredtype)
    end
    attr.type = desiredtype
    attr.compconst = compconst
  else
    context:traverse(childnodes)
    attr.type = primtypes.table
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
  if name == 'compconst' then
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
  node:assertraisef(paramshape, "attribute '%s' is not defined in this context", name)
  local params = tabler.imap(argnodes, function(argnode)
    local value = argnode.attr.value
    if traits.is_bignumber(value) then
      return value:tointeger()
    end
    return value
  end)

  if paramshape == true then
    node:assertraisef(#argnodes == 0, "attribute '%s' takes no arguments", name)
    params = true
  else
    local ok, err = paramshape(params)
    node:assertraisef(ok, "attribute '%s' arguments are invalid: %s", name, err)
    if #paramshape.shape == 1 then
      params = params[1]
      if params == nil then
        params = true
      end
    end
  end

  local attr, type
  if symboltype and symboltype:is_type() then
    type = symbol.attr.holdedtype
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
      type = typenode.attr.holdedtype
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
  local holdedtype = typedefs.primtypes[tyname]
  if not holdedtype then
    local symbol = context.scope:get_symbol(tyname, node)
    node:assertraisef(symbol and symbol.attr.holdedtype,
      "symbol '%s' is not a valid type", tyname)
    holdedtype = symbol.attr.holdedtype
  end
  attr.type = primtypes.type
  attr.value = holdedtype
  attr.holdedtype = holdedtype
end

function visitors.TypeInstance(context, node, _, symbol)
  local typenode = node[1]
  context:traverse(typenode)
  -- inherit attributes from inner node
  local attr = typenode.attr
  node.attr = attr

  if symbol and not attr.holdedtype:is_primitive() then
    local prefix
    if context.nohashcodenames then
      prefix = context.modname or context.ast.modname
    end
    attr.holdedtype:suggest_nick(symbol.name, prefix)
  end
end

function visitors.FuncType(context, node)
  local attr = node.attr
  if attr.type then return end
  local argnodes, retnodes = node:args()
  context:traverse(argnodes)
  context:traverse(retnodes)
  local type = types.FunctionType(node,
    tabler.imap(argnodes, function(argnode) return argnode.attr.holdedtype end),
    tabler.imap(retnodes, function(retnode) return retnode.attr.holdedtype end))
  attr.type = primtypes.type
  attr.holdedtype = type
  attr.value = type
end

function visitors.MultipleType(context, node)
  local attr = node.attr
  if attr.type then return end
  local typenodes = node:args()
  assert(#typenodes > 1)
  context:traverse(typenodes)
  attr.type = primtypes.type
  attr.holdedtype = types.MultipleType(node,
    tabler.imap(typenodes, function(typenode) return typenode.attr.holdedtype end))
  attr.value = attr.holdedtype
end

function visitors.RecordFieldType(context, node)
  local attr = node.attr
  if attr.type then return end
  local name, typenode = node:args()
  context:traverse(typenode)
  attr.type = typenode.attr.type
  attr.holdedtype = typenode.attr.holdedtype
  attr.value = typenode.attr.holdedtype
end

function visitors.RecordType(context, node)
  local attr = node.attr
  if attr.type then return end
  local fieldnodes = node:args()
  context:traverse(fieldnodes)
  local fields = tabler.imap(fieldnodes, function(fieldnode)
    return {name = fieldnode[1], type=fieldnode.attr.holdedtype}
  end)
  local type = types.RecordType(node, fields)
  attr.type = primtypes.type
  attr.holdedtype = type
  attr.value = type
end

function visitors.EnumFieldType(context, node, desiredtype)
  local name, numnode = node:args()
  local field = {name = name}
  if numnode then
    context:traverse(numnode, desiredtype)
    local value, numtype = numnode.attr.value, numnode.attr.type
    numnode:assertraisef(numnode.attr.compconst,
      "enum fields can only be assigned to compile time values")
    numnode:assertraisef(numtype:is_integral(),
      "only integral numbers are allowed in enums, but got type '%s'",
      numtype)
    field.value = value
    numnode:assertraisef(desiredtype:is_conversible_from_node(numnode),
      "enum of type '%s' no viable type conversion field '%s' of type '%s'",
      desiredtype, name, numtype)
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
    subtype = typenode.attr.holdedtype
  end
  local fields = {}
  for i,fnode in ipairs(fieldnodes) do
    local field = context:traverse(fnode, subtype)
    if not field.value then
      if i == 1 then
        fnode:raisef('in enum declaration, first field requires a initial value')
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
  local type = types.EnumType(node, subtype, fields)
  attr.type = primtypes.type
  attr.holdedtype = type
  attr.value = type
end

function visitors.ArrayTableType(context, node)
  local attr = node.attr
  if attr.type then return end
  local subtypenode = node:args()
  context:traverse(subtypenode)
  local type = types.ArrayTableType(node, subtypenode.attr.holdedtype)
  attr.type = primtypes.type
  attr.holdedtype = type
  attr.value = type
end

function visitors.SpanType(context, node)
  local attr = node.attr
  if attr.type then return end
  local subtypenode = node:args()
  context:traverse(subtypenode)
  local subtype = subtypenode.attr.holdedtype
  subtypenode:assertraisef(not subtype:is_void(), 'spans cannot be of "void" type')
  local type = types.SpanType(node, subtype)
  attr.type = primtypes.type
  attr.holdedtype = type
  attr.value = type
end

function visitors.RangeType(context, node)
  local attr = node.attr
  if attr.type then return end
  local subtypenode = node:args()
  context:traverse(subtypenode)
  local subtype = subtypenode.attr.holdedtype
  subtypenode:assertraisef(subtype:is_integral(),
    'ranges subtype "%s" is not an integral type', subtype)
  local type = types.RangeType(node, subtype)
  attr.type = primtypes.type
  attr.holdedtype = type
  attr.value = type
end

function visitors.ArrayType(context, node)
  local attr = node.attr
  if attr.type then return end
  local subtypenode, lengthnode = node:args()
  context:traverse(subtypenode)
  local subtype = subtypenode.attr.holdedtype
  context:traverse(lengthnode)
  lengthnode:assertraisef(lengthnode.attr.value, 'unknown const value for expression')
  local length = lengthnode.attr.value:tointeger()
  lengthnode:assertraisef(lengthnode.attr.type:is_integral() and length >= 0,
    'expected a valid decimal integral number in the second argument of an "array" type')
  local type = types.ArrayType(node, subtype, length)
  attr.type = primtypes.type
  attr.holdedtype = type
  attr.value = type
end

function visitors.PointerType(context, node)
  local attr = node.attr
  if attr.type then return end
  local subtypenode = node:args()
  local type
  if subtypenode then
    context:traverse(subtypenode)
    assert(subtypenode.attr.holdedtype)
    type = types.get_pointer_type(subtypenode.attr.holdedtype, node)
  else
    type = primtypes.pointer
  end
  attr.type = primtypes.type
  attr.holdedtype = type
  attr.value = type
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
      objtype = objnode.attr.holdedtype
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
      node:assertraisef(type,
        'record "%s" does not have field named "%s"',
        objtype, name)
    elseif objtype:is_type() then
      objtype = objnode.attr.holdedtype
      assert(objtype)
      if objtype:is_pointer() and objtype.subtype:is_record() then
        -- allow to access method and fields on record pointer types
        objtype = objtype.subtype
      end
      attr.indextype = objtype
      if objtype:is_enum() then
        node:assertraisef(objtype:get_field(name),
          'enum "%s" does not have field named "%s"',
          objtype, name)
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
            node:raisef('cannot index record meta field "%s"', name)
          end
          symbol:link_node(parentnode)
        elseif context.infuncdef or context.inglobaldecl then
          node:assertraisef(symbol.node == node, 'cannot redefine meta type function')
        else
          symbol:link_node(node)
        end
        if symbol then
          type = symbol.attr.type
        end
      else
        node:raisef('cannot index fields for type "%s"', objtype)
      end
    elseif not (objtype:is_table() or objtype:is_any()) then
      node:raisef('cannot index field "%s" on variable of type "%s"', name, objtype.name)
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
            indexnode:assertraisef(not indexvalue:isneg(),
              "in array indexing, trying to index negative value %s",
              indexvalue:todec())
            if objtype:is_array() and objtype.length ~= 0 and not (indexvalue < bn.new(objtype.length)) then
              indexnode:raisef(
                "in array indexing, index %s is out of bounds, array maximum index is %d",
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
      node:raisef('cannot index variable of type "%s"', objtype.name)
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
        node:assertraisef(funcargtypes[1]:is_conversible_from(methodcalleenode),
        "in call, expected argument at index %d of type '%s' but got not coercible type '%s'",
                    1, funcargtypes[1], methodcalleenode.attr.type)
        table.remove(pseudoargtypes, 1)
        attr.pseudoargtypes = pseudoargtypes
      end
      node:assertraisef(#argnodes <= #pseudoargtypes,
        "in call, function '%s' expected at most %d arguments but got %d",
        calleetype, #pseudoargtypes, #argnodes)
      local argtypes = {}
      local knownallargs = true
      for i,funcargtype,argnode,argtype in izipargnodes(pseudoargtypes, argnodes) do
        if argnode then
          context:traverse(argnode, funcargtype)
          argtype = argnode.attr.type
          if argtype then
            argtypes[i] = argtype
          else
            knownallargs = false
          end
        end
        if argtype == false then
          -- argument is missing
          node:assertraisef(funcargtype:is_nilable(),
            "in call, function '%s' expected an argument at index %d but got nothing",
            calleetype, i)
        end
        if funcargtype and argtype then
          node:assertraisef(funcargtype:is_conversible_from(argnode or argtype),
"in call, function argument %d of type '%s' no viable type conversion call argument %d of type '%s'",
            i, funcargtype, i, argtype)
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

local function builtin_call_require(context, node)
  if node.attr.loadedast then
    -- already loaded
    return
  end

  local argnode = node[1][1]
  if not (argnode and
          argnode.attr.type and argnode.attr.type:is_string() and
          argnode.attr.compconst) then
    -- not a compile time require
    node.attr.runtime_require = true
    return
  end

  local modulename = argnode.attr.value
  node.attr.modulename = modulename

  -- load it and parse
  local filepath = fs.findmodulefile(modulename, config.path)
  if not filepath then
    -- maybe it would succeed at runtime
    node.attr.runtime_require = true
    return
  end
  local input = fs.readfile(filepath)
  local ast = context.parser:parse(input, filepath)

  -- analyze it
  typechecker.analyze(ast, context.parser, context)

  node.attr.loadedast = ast
end

function visitors.Call(context, node)
  local argnodes, calleenode, isblockcall = node:args()
  context:traverse(calleenode)
  local attr, caleeattr = node.attr, calleenode.attr
  local calleetype = caleeattr.type
  if calleetype and calleetype:is_pointer() then
    calleetype = calleetype.subtype
    calleenode:assertraisef(calleetype, 'cannot call from generic pointers')
    attr.pointercall = true
  end
  if calleetype and calleetype:is_type() then
    -- type assertion
    local type = caleeattr.holdedtype
    assert(type)
    node:assertraisef(#argnodes == 1,
      "in assertion to type '%s', expected one argument, but got %d",
      type, #argnodes)
    local argnode = argnodes[1]
    context:traverse(argnode, type)
    local argtype = argnode.attr.type
    if argtype then
      argnode:assertraisef(type:is_conversible_from_node(argnode, true),
        "in assertion to type '%s', the type no viable type conversion expression of type '%s'",
        type, argtype)

      if argnode.attr.compconst then
        attr.compconst = argnode.attr.compconst
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

  if caleeattr.builtin and caleeattr.name == 'require' then
    builtin_call_require(context, node)
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
      calleenode:assertraisef(calleetype, 'cannot call from generic pointers')
      attr.pointercall = true
    end

    attr.calleetype = calleetype
    if calleetype:is_record() then
      local symbol = calleetype:get_metafield(name)
      node:assertraisef(symbol, 'cannot index record meta field "%s"', name)
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
    context:traverse(ifcondnode, primtypes.boolean)
    context:traverse(ifblocknode)
  end
  if elsenode then
    context:traverse(elsenode)
  end
end

function visitors.While(context, node)
  local condnode, blocknode = node:args()
  context:traverse(condnode, primtypes.boolean)
  context:traverse(blocknode)
end

function visitors.Repeat(context, node)
  local blocknode, condnode = node:args()
  context:traverse(blocknode, function()
    context:traverse(condnode, primtypes.boolean)
  end)
end

function visitors.ForIn(context, node)
  local itvarnodes, inexpnodes, blocknode = node:args()
  assert(#inexpnodes > 0)
  node:assertraisef(#inexpnodes <= 3, '`in` expression can have at most 3 arguments')
  local infuncnode = inexpnodes[1]
  local infunctype = infuncnode.attr.type
  if infunctype then
    node:assertraisef(infunctype:is_any() or infunctype:is_function(),
      'first argument of `in` expression must be a function, but got type "%s"',
        infunctype)
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
      itvarnode:assertraisef(ittype:is_arithmetic() or (ittype:is_any() and not ittype:is_varanys()),
          "`for` variable must be a number, but got type '%s'",
           ittype)
      if btype then
        begvalnode:assertraisef(ittype:is_conversible_from_node(begvalnode),
          "`for` variable '%s' of type '%s' no viable type conversion begin value of type '%s'",
          itname, ittype, btype)
      end
      if etype then
        endvalnode:assertraisef(ittype:is_conversible_from_node(endvalnode),
          "`for` variable '%s' of type '%s' no viable type conversion end value of type '%s'",
          itname, ittype, etype)
      end
      if stype then
        stepvalnode:assertraisef(ittype:is_conversible_from_node(stepvalnode),
          "`for` variable '%s' of type '%s' no viable type conversion increment value of type '%s'",
          itname, ittype, stype)
      end
    else
      itsymbol:add_possible_type(btype, true)
      itsymbol:add_possible_type(etype, true)
    end
    context:traverse(blocknode)
  end)
  local fixedstep
  if stype and stype:is_arithmetic() and stepvalnode.attr.compconst then
    -- constant step
    fixedstep = stepvalnode.attr.value
    stepvalnode:assertraisef(not fixedstep:iszero(), '`for` step cannot be zero')
  elseif not stepvalnode then
    -- default step is '1'
    fixedstep = bn.new(1)
  end
  local fixedend
  if etype and etype:is_arithmetic() and endvalnode.attr.compconst then
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
  node:assertraisef(#varnodes >= #valnodes,
    'too many expressions in declaration, expected at most %d but got %d',
    #varnodes, #valnodes)
  for _,varnode,valnode,valtype in izipargnodes(varnodes, valnodes) do
    assert(varnode.tag == 'IdDecl')
    if varscope == 'global' then
      varnode:assertraisef(context.scope:is_static_storage(), 'global variables can only be declared in top scope')
      varnode.attr.global = true
    end
    if context.nostatic then
      varnode.attr.nostatic = true
    end
    local symbol = context:traverse(varnode)
    assert(symbol)
    local vartype = varnode.attr.type
    if vartype then
      varnode:assertraisef(
        not vartype:is_multipletype() and not vartype:is_void() and not vartype:is_varanys(),
        'variable declaration cannot be of the type "%s"', vartype)
    end
    assert(symbol.attr.type == vartype)
    varnode.assign = true
    if (varnode.attr.compconst or varnode.attr.const) and not varnode.attr.nodecl then
      varnode:assertraisef(valnode, 'const variables must have an initial value')
    end
    if valnode then
      context:traverse(valnode, vartype, symbol)
      valtype = valnode.attr.type
      if valtype and valtype:is_varanys() then
        -- varanys are always stored as any in variables
        valtype = primtypes.any
      end
      if varnode.attr.compconst then
        varnode:assertraisef(valnode.attr.compconst and valtype,
          'constant variables can only assign to constant expressions')
      end
      varnode:assertraisef(not varnode.attr.cimport or
        (vartype == primtypes.type or (vartype == nil and valtype == primtypes.type)),
        'cannot assign imported variables, only imported types can be assigned')

      if valtype == vartype and valnode.attr.compconst then
        valnode.attr.initializer = true
      end
    else
      if context.noinit then
        varnode.attr.noinit = true
      end
    end
    if valtype then
      varnode:assertraisef(not valtype:is_void(), 'cannot assign to expressions of type void')
      local foundtype = false
      local searchtype = false
      if varnode.attr.compconst then
        -- for consts the type must be known ahead
        foundtype = true
        searchtype = not vartype
        symbol.attr.value = valnode.attr.value
      elseif valtype:is_type() then
        -- for 'type' types the type must also be known ahead
        assert(valnode and valnode.attr.holdedtype)
        foundtype = true
        searchtype = vartype ~= valtype
        symbol.attr.holdedtype = valnode.attr.holdedtype
      end

      if searchtype then
        vartype = valtype
        symbol.attr.type = valtype

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
        check_implicit_conversion(varnode, valnode or valtype, vartype,
          'in variable `%s` declaration', symbol.name)
      end
    else
      -- delay type evaluation
      symbol:add_possible_type(nil)
    end
  end
end


function visitors.Assign(context, node)
  local varnodes, valnodes = node:args()
  node:assertraisef(#varnodes >= #valnodes,
    'too many expressions in assign, expected at most %d but got %d',
    #varnodes, #valnodes)
  for i,varnode,valnode,valtype in izipargnodes(varnodes, valnodes) do
    local symbol = context:traverse(varnode)
    local vartype = varnode.attr.type
    varnode.assign = true
    varnode:assertraisef(not (varnode.attr.const or varnode.attr.compconst),
      "cannot assign a constant variable")
    if valnode then
      context:traverse(valnode, vartype)
      valtype = valnode.attr.type
    end
    if valtype then
      varnode:assertraisef(not valtype:is_void(), 'cannot assign to expressions of type void')
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
      varnode:assertraisef(vartype:is_conversible_from(valnode or valtype),
        "variable assignment of type '%s' no viable type conversion expression of type '%s'",
        vartype, valtype)
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
        (retnode or node):assertraisef(funcrettype:is_conversible_from(retnode or rettype),
          "return at index %d of type '%s' no viable type conversion expression of type '%s'",
          i, funcrettype, rettype)
      elseif rettype == false and funcrettype then
        node:assertraisef(funcrettype:is_nilable(),
          "missing return expression at index %d of type '%s'",
          i, funcrettype)
      elseif rettype then
        node:assertraisef(#retnodes == 0,
          "invalid return expression at index %d", i)
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
      varnode:assertraisef(context.scope:is_static_storage(), 'global function can only be declared in top scope')
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
      return retnode.attr.holdedtype
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

          argnode:assertraisef(symbol,
            'function with multiple types for an argument must have a symbol')
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
        node:assertraisef(symboltype:is_conversible_from_type(type),
          "in function defition, symbol of type '%s' no viable type conversion function type '%s'",
          symboltype, type)
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
        node:raisef('a return statement is missing before function end')
      end
    end
  end

  if varnode.attr.cimport then
    blocknode:assertraisef(#blocknode[1] == 0, 'body of an import function must be empty')
  end

  type.sideeffect = not varnode.attr.nosideeffect

  if varnode.attr.entrypoint then
    node:assertraisef(not context.ast.attr.entrypoint or context.ast.attr.entrypoint == node,
      "cannot have more than one function entrypoint")
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
        if deducedfunctype then
          node.lazytypes[deducedargtypes] = deducedfunctype
          node.lazynodes[deducedargtypes] = funcdefnode
        end
      end
    end
  end
end

function visitors.UnaryOp(context, node, desiredtype)
  local attr = node.attr
  local opname, argnode = node:args()
  local argtype = argnode.attr.type
  local type
  if opname == 'not' then
    desiredtype = primtypes.boolean
    type = primtypes.boolean
  end
  context:traverse(argnode, desiredtype)
  local argattr = argnode.attr
  if attr.type and argattr.type == argtype then
    -- type already resolved, quick return
    return
  end
  argtype = argattr.type
  if argtype then
    local value, err
    type, value, err = argtype:unary_operator(opname, argattr.value)
    argnode:assertraisef(not err,
      "unary operation `%s` on type '%s': %s",
      opname, argtype, err)
    argnode:assertraisef(type,
      "unary operation `%s` is not defined for type '%s' of the expression",
      opname, argtype)
    if value ~= nil then
      attr.compconst = true
      attr.value = value
    end
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
  local parentnode = context:get_parent_node()
  attr.inoperator = parentnode.tag == 'BinaryOp' or parentnode.tag == 'UnaryOp'
end

--TODO: missing operators

function visitors.BinaryOp(context, node, desiredtype)
  local attr = node.attr
  local opname, lnode, rnode = node:args()

  local parentnode = context:get_parent_node()
  local type

  if desiredtype and desiredtype:is_boolean() then
    if typedefs.binary_conditional_ops[opname] then
      type = primtypes.boolean
      desiredtype = type
    else
      desiredtype = nil
    end
  end

  local ldesiredtype = desiredtype
  local ternaryand = false
  if opname == 'and' then
    if parentnode.tag == 'BinaryOp' and parentnode[1] == 'or' and parentnode[2] == node then
      ternaryand = true
      ldesiredtype = primtypes.boolean
    end
  end

  local ltype, rtype = lnode.attr.type, rnode.attr.type

  context:traverse(lnode, ldesiredtype)
  context:traverse(rnode, desiredtype)

  if attr.type and ltype == lnode.attr.type and rtype == rnode.attr.type then
    -- type already resolved, quick return
    return
  end

  if ternaryand then
    attr.ternaryand = true
    parentnode.attr.ternaryor = true
  end

  local lattr, rattr = lnode.attr, rnode.attr
  ltype, rtype = lattr.type, rattr.type

  if not type then
    -- traverse again trying to coerce untyped child nodes
    if lnode.untyped and rtype then
      context:traverse(lnode, rtype)
      ltype = lattr.type
    elseif rnode.untyped and ltype then
      context:traverse(rnode, ltype)
      rtype = rattr.type
    end

    if typedefs.binary_conditional_ops[opname] then
      if ternaryand then
        if rtype then
          -- get type from right 'or' node
          local prnode = parentnode[3]
          context:traverse(prnode, rtype)
          local prtype = prnode.attr.type
          if prtype then
            type = rtype:promote_type(prtype)
          end
        end
      else
        if ltype and rtype then
          type = ltype:promote_type(rtype)
        end
      end
    else
      if ltype and rtype then
        local value, err
        type, value, err = ltype:binary_operator(opname, rtype, lnode.attr.value, rnode.attr.value)
        lnode:assertraisef(not err,
          "binary operation `%s` between types '%s' and '%s': %s",
          opname, ltype, rtype, err)
        lnode:assertraisef(type,
          "binary operation `%s` is not defined between types '%s' and '%s'",
          opname, ltype, rtype)
        if value ~= nil then
          attr.compconst = true
          attr.value = value
        end
      end
    end
  end
  if not type and context.phase == phases.any_inference then
    type = primtypes.any
  end
  if type then
    attr.type = type
  end
  if rtype and ltype then
    if typedefs.binary_conditional_ops[opname] and
      (not rtype:is_boolean() or not ltype:is_boolean()) then
      attr.dynamic_conditional = true
    end
  end
  attr.sideeffect = lattr.sideeffect or rattr.sideeffect
  attr.inoperator = parentnode.tag == 'BinaryOp' or parentnode.tag == 'UnaryOp'
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
