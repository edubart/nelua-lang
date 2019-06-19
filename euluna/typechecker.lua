local iters = require 'euluna.utils.iterators'
local traits = require 'euluna.utils.traits'
local tabler = require 'euluna.utils.tabler'
local stringer = require 'euluna.utils.stringer'
local typedefs = require 'euluna.typedefs'
local Context = require 'euluna.context'
local Symbol = require 'euluna.symbol'
local types = require 'euluna.types'
local bn = require 'euluna.utils.bn'
local preprocessor = require 'euluna.preprocessor'
local config = require 'euluna.configer'.get()

local primtypes = typedefs.primtypes
local visitors = {}

local phases = {
  type_inference = 1,
  any_inference = 2
}

function visitors.Number(context, node, desiredtype)
  local base, int, frac, exp, literal = node:args()
  local value
  if base == 'hex' then
    value = bn.fromhex(int, frac, exp)
  elseif base == 'bin' then
    value = bn.frombin(int, frac, exp)
  else
    value = bn.fromdec(int, frac, exp)
  end
  local floatexp = exp and (stringer.startswith(exp, '-') or value > primtypes.integer.range.max)
  local integral = not (frac or floatexp)
  local type
  local parentnode = context:get_parent_node()
  if parentnode and parentnode.tag == 'UnaryOp' and parentnode:arg(1) == 'neg' then
    value = -value
  end
  if literal then
    type = typedefs.number_literal_types[literal]
    node:assertraisef(type, 'literal suffix "%s" is not defined', literal)
  elseif desiredtype and desiredtype:is_numeric() then
    if integral and desiredtype:is_integral() then
      if desiredtype:is_unsigned() and not value:isneg() then
        -- find smallest unsigned type
        for _,range in ipairs(typedefs.unsigned_ranges) do
          if value >= range.min and value <= range.max then
            type = range.type
            break
          end
        end
      else
      -- find smallest signed type
        for _,range in ipairs(typedefs.signed_ranges) do
          if value >= range.min and value <= range.max then
            type = range.type
            break
          end
        end
      end
    elseif desiredtype:is_float() then
      type = desiredtype
    end
  end
  if not type then
    if integral then
      type = primtypes.integer
    else
      type = primtypes.number
    end
    node.untyped = true
  else
    node.untyped = nil
  end
  if not literal and desiredtype and desiredtype:is_numeric() and desiredtype:is_coercible_from_type(type) then
    type = desiredtype
  end
  if type:is_integral() then
    node:assertraisef(type:is_inrange(value),
      "value %s for integral of type '%s' is out of range, minimum is %s and maximum is %s",
      value:todec(), tostring(type), type.range.min:todec(), type.range.max:todec())
  end
  node.attr.type = type
  node.attr.value = value
  node.attr.integral = integral
  node.attr.compconst = true
end

function visitors.String(_, node)
  if node.attr.type then return end
  local value, literal = node:args()
  node:assertraisef(literal == nil, 'string literals are not supported yet')
  node.attr.value = value
  node.attr.type = primtypes.string
  node.attr.compconst = true
end

function visitors.Boolean(_, node)
  if node.attr.type then return end
  node.attr.value = node:args(1)
  node.attr.type = primtypes.boolean
  node.attr.compconst = true
end

function visitors.Nil(_, node)
  if node.attr.type then return end
  node.attr.type = primtypes.Nil
  node.attr.compconst = true
end

function visitors.Table(context, node, desiredtype)
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
          childnode:assertraisef(subtype:is_coercible_from_node(childnode),
            "in array table literal, subtype '%s' is not coercible with expression at index %d of type '%s'",
            tostring(subtype), i, tostring(childtype))
          if childtype == subtype then
            childnode.attr.initializer = true
          end
        end
      end
      compconst = false
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
          childnode:assertraisef(subtype:is_coercible_from_node(childnode),
            "in array literal, subtype '%s' is not coercible with expression at index %d of type '%s'",
            tostring(subtype), i, tostring(childtype))
          if childtype == subtype then
            childnode.attr.initializer = true
          end
        end
        if not childnode.attr.compconst then
          compconst = false
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
          fieldname, tostring(desiredtype))
        local fieldtype = field.type
        context:traverse(fieldvalnode, fieldtype)
        lastfieldindex = fieldindex
        local fieldvaltype = fieldvalnode.attr.type
        if fieldvaltype then
          fieldvalnode:assertraisef(fieldtype:is_coercible_from_node(fieldvalnode),
            "in record literal, field '%s' of type '%s' is not coercible with expression of type '%s'",
            fieldname, tostring(fieldtype), tostring(fieldvaltype))
          if fieldvaltype == fieldtype then
            fieldvalnode.attr.initializer = true
          end
        end
        childnode.attr.parenttype = desiredtype
        if not fieldvalnode.attr.compconst then
          compconst = false
        end
      end
    else
      node:raisef("in table literal, type '%s' cannot be initialized using a table literal",
        tostring(desiredtype))
    end
    node.attr.type = desiredtype
    if compconst then
      node.attr.compconst = true
    end
  else
    context:traverse(childnodes)
    node.attr.type = primtypes.table
  end
end

function visitors.Pragma(context, node, symbol)
  local name, argnodes = node:args()
  context:traverse(argnodes)
  local pragmashape
  local symboltype
  if symbol then
    symboltype = symbol.attr.type
    if not symboltype then
      -- in the next traversal we will have the type
      return
    end
    if symboltype:is_function() then
      pragmashape = typedefs.function_pragmas[name]
    elseif symboltype:is_type() then
      pragmashape = typedefs.type_pragmas[name]
    else
      pragmashape = typedefs.variable_pragmas[name]
    end
  elseif not symbol then
    pragmashape = typedefs.block_pragmas[name]
  end
  node:assertraisef(pragmashape, "pragma '%s' is not defined in this context", name)
  local params = tabler.imap(argnodes, function(argnode)
    local value = argnode.attr.value
    if traits.is_bignumber(value) then
      return value:tointeger()
    end
    return value
  end)

  if pragmashape == true then
    node:assertraisef(#argnodes == 0, "pragma '%s' takes no arguments", name)
    params = true
  else
    local ok, err = pragmashape(params)
    node:assertraisef(ok, "pragma '%s' arguments are invalid: %s", name, err)
    if #pragmashape.shape == 1 then
      params = params[1]
    end
  end

  local attr, type
  if symboltype and symboltype:is_type() then
    type = symbol.attr.holdedtype
    attr = type
  else
    if symbol then
      attr = symbol.attr
    else
      attr = node.attr
    end
  end
  attr[name] = params

  if name == 'cimport' then
    local cname, header = tabler.unpack(params)
    if cname then
      attr.codename = cname
    elseif type then
      type.codename = symbol.name
    end
    attr.nodecl = header ~= true
    if traits.is_string(header) then
      attr.cinclude = header
    end
  end
  if name == 'strict' then
    config.strict = true
  end
end

function visitors.Id(context, node)
  local name = node:arg(1)
  local type = node.attr.type
  if not type and context.phase == phases.any_inference then
    type = primtypes.any
  end
  local symbol = context.scope:get_symbol(name, node)
  if not symbol then
    symbol = context.scope:add_symbol(Symbol(name, node, type))
  else
    symbol:link_node(node)
  end
  symbol.attr.lvalue = true
  return symbol
end

function visitors.IdDecl(context, node)
  local name, mut, typenode, pragmanodes = node:args()
  node:assertraisef(not (mut and node.mut), "cannot declare mutability twice for '%s'", name)
  mut = mut or node.mut
  node:assertraisef(not mut or typedefs.mutabilities[mut],
    'mutability %s not supported yet', mut)
  local type = node.attr.type
  if typenode then
    context:traverse(typenode)
    type = typenode.attr.holdedtype
  end
  if not type and context.phase == phases.any_inference then
    type = primtypes.any
  end
  local symbol = context.scope:add_symbol(Symbol(name, node, type))
  if mut then
    symbol.attr[mut] = true
  end
  if pragmanodes then
    context:traverse(pragmanodes, symbol)
  end
  symbol.attr.lvalue = true
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
  if node.attr.type then return end
  local tyname = node:arg(1)
  local holdedtype = typedefs.primtypes[tyname]
  if not holdedtype then
    local symbol = context.scope:get_symbol(tyname, node)
    node:assertraisef(symbol and symbol.attr.holdedtype,
      "symbol '%s' is not a valid type", tyname)
    holdedtype = symbol.attr.holdedtype
  end
  node.attr.type = primtypes.type
  node.attr.holdedtype = holdedtype
  node.attr.compconst = true
end

function visitors.TypeInstance(context, node, _, symbol)
  local typenode = node:arg(1)
  context:traverse(typenode)
  -- inherit attributes from inner node
  node.attr = typenode.attr

  if symbol and not node.attr.holdedtype:is_primitive() then
    node.attr.holdedtype:suggest_nick(symbol.name)
  end
end

function visitors.FuncType(context, node)
  if node.attr.type then return end
  local argnodes, retnodes = node:args()
  context:traverse(argnodes)
  context:traverse(retnodes)
  local type = types.FunctionType(node,
    tabler.imap(argnodes, function(argnode) return argnode.attr.holdedtype end),
    tabler.imap(retnodes, function(retnode) return retnode.attr.holdedtype end))
  node.attr.type = primtypes.type
  node.attr.holdedtype = type
  node.attr.compconst = true
end

function visitors.MultipleType(context, node)
  if node.attr.type then return end
  local typenodes = node:args()
  assert(#typenodes > 1)
  context:traverse(typenodes)
  node.attr.type = primtypes.type
  node.attr.holdedtype = types.MultipleType(node,
    tabler.imap(typenodes, function(typenode) return typenode.attr.holdedtype end))
  node.attr.compconst = true
end

function visitors.RecordFieldType(context, node)
  if node.attr.type then return end
  local name, typenode = node:args()
  context:traverse(typenode)
  node.attr.type = typenode.attr.type
  node.attr.holdedtype = typenode.attr.holdedtype
end

function visitors.RecordType(context, node)
  if node.attr.type then return end
  local fieldnodes = node:args()
  context:traverse(fieldnodes)
  local fields = tabler.imap(fieldnodes, function(fieldnode)
    return {name = fieldnode:arg(1), type=fieldnode.attr.holdedtype}
  end)
  local type = types.RecordType(node, fields)
  node.attr.type = primtypes.type
  node.attr.holdedtype = type
  node.attr.compconst = true
end

function visitors.EnumFieldType(context, node, desiredtype)
  local name, numnode = node:args()
  local field = {name = name}
  if numnode then
    context:traverse(numnode, desiredtype)
    local value, numtype = numnode.attr.value, numnode.attr.type
    numnode:assertraisef(numnode.attr.compconst,
      "enum values can only be assigned to const values")
    numnode:assertraisef(numtype:is_integral(),
      "only integral numbers are allowed in enums, but got type '%s'",
      tostring(numtype))
    field.value = value
    numnode:assertraisef(desiredtype:is_coercible_from_node(numnode),
      "enum of type '%s' is not coercible with field '%s' of type '%s'",
      tostring(desiredtype), name, tostring(numtype))
  end
  return field
end

function visitors.EnumType(context, node)
  if node.attr.type then return end
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
        field.value = fields[i-1].value:intadd(1)
      end
    end
    fnode:assertraisef(subtype:is_inrange(field.value),
      "in enum value %s or field '%s' is not in range of type '%s'",
      field.value:todec(), field.name, tostring(subtype))
    fields[i] = field
  end
  local type = types.EnumType(node, subtype, fields)
  node.attr.type = primtypes.type
  node.attr.holdedtype = type
  node.attr.compconst = true
end

function visitors.ArrayTableType(context, node)
  if node.attr.type then return end
  local subtypenode = node:args()
  context:traverse(subtypenode)
  local type = types.ArrayTableType(node, subtypenode.attr.holdedtype)
  node.attr.type = primtypes.type
  node.attr.holdedtype = type
  node.attr.compconst = true
end

function visitors.ArrayType(context, node)
  if node.attr.type then return end
  local subtypenode, lengthnode = node:args()
  context:traverse(subtypenode)
  local subtype = subtypenode.attr.holdedtype
  context:traverse(lengthnode)
  lengthnode:assertraisef(lengthnode.attr.value, 'unknown const value for expression')
  local length = lengthnode.attr.value:tointeger()
  lengthnode:assertraisef(lengthnode.attr.type:is_integral() and length >= 0,
    'expected a valid decimal integral number in the second argument of an "array" type')
  local type = types.ArrayType(node, subtype, length)
  node.attr.type = primtypes.type
  node.attr.holdedtype = type
  node.attr.compconst = true
end

function visitors.PointerType(context, node)
  if node.attr.type then return end
  local subtypenode = node:args()
  local type
  if subtypenode then
    context:traverse(subtypenode)
    assert(subtypenode.attr.holdedtype)
    type = types.PointerType(node, subtypenode.attr.holdedtype)
  else
    type = primtypes.pointer
  end
  node.attr.type = primtypes.type
  node.attr.holdedtype = type
  node.attr.compconst = true
end

local function visitor_FieldIndex(context, node)
  local name, objnode = node:args()
  if node.attr.type then
    local objtype = objnode.attr.type
    if objtype:is_type() then
      objtype = objnode.attr.holdedtype
      if objtype:is_record() then
        return objtype:get_metafield(name)
      end
    end
    return
  end
  local symbol
  context:traverse(objnode)
  local type
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
        tostring(objtype), name)
    elseif objtype:is_type() then
      objtype = objnode.attr.holdedtype
      assert(objtype)
      node.attr.holdedtype = objtype
      if objtype:is_enum() then
        node:assertraisef(objtype:get_field(name),
          'enum "%s" does not have field named "%s"',
          tostring(objtype), name)
        type = objtype
      elseif objtype:is_record() then
        symbol = objtype:get_metafield(name)
        if not symbol then
          if node.infuncdef then
            local symname = objtype.codename .. '_' .. name
            symbol = Symbol(symname, node)
            symbol.attr.const = true
            symbol.attr.metafunc = true
            symbol.attr.metarecordtype = objtype
            objtype:set_metafield(name, symbol)
          else
            node:raisef('cannot index record meta field "%s"', tostring(name))
          end
        end
        if symbol then
          type = symbol.attr.type
        end
      else
        node:raisef('cannot index fields for type "%s"', tostring(objtype))
      end
    elseif not (objtype:is_table() or objtype:is_any()) then
      node:raisef('cannot index field "%s" from variable of type "%s"', name, objtype.name)
    end
  end
  if not type and context.phase == phases.any_inference then
    type = primtypes.any
  end
  if objnode.attr.lvalue then
    node.attr.lvalue = true
  end
  node.attr.type = type
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

    if objtype:is_arraytable() or objtype:is_array() then
      local indextype = indexnode.attr.type
      if indextype then
        indexnode:assertraisef(indextype:is_integral(),
          "in array indexing, trying to index with non integral value '%s'",
          tostring(indextype))
      end
      local indexvalue = indexnode.attr.value
      if indexvalue then
        indexnode:assertraisef(not indexvalue:isneg(),
          "in array indexing, trying to index negative value %s",
          indexvalue:todec())
        if objtype:is_array() then
          indexnode:assertraisef(indexvalue < bn.new(objtype.length),
            "in array indexing, index %s is out of bounds, array maximum index is %d",
              indexvalue:todec(), objtype.length - 1)
        end
      end
      type = objtype.subtype
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
  if lastargnode and lastargnode.tag == 'Call' and calleetype and
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
  if lastargnode and lastargnode.tag == 'Call' and (not calleetype or not calleetype:is_type()) then
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
        node:assertraisef(funcargtypes[1]:is_coercible_from(methodcalleenode),
        "in call, expected argument at index %d of type '%s' but got not coercible type '%s'",
                    1, tostring(funcargtypes[1]), tostring(methodcalleenode.attr.type))
        table.remove(pseudoargtypes, 1)
        attr.pseudoargtypes = pseudoargtypes
      end
      node:assertraisef(#argnodes <= #pseudoargtypes,
        "in call, function '%s' expected at most %d arguments but got %d",
        tostring(calleetype), #pseudoargtypes, #argnodes)
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
            tostring(calleetype), i)
        end
        if funcargtype and argtype then
          node:assertraisef(funcargtype:is_coercible_from(argnode or argtype),
"in call, function argument %d of type '%s' is not coercible with call argument %d of type '%s'",
            i, tostring(funcargtype), i, tostring(argtype))
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
      attr.sideeffect = true
    else
      -- call on invalid types (i.e: numbers)
      node:raisef("attempt to call a non callable variable of type '%s'",
        tostring(calleetype))
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
  local attr = node.attr
  local calleetype = calleenode.attr.type
  if calleetype and calleetype:is_pointer() then
    calleetype = calleetype.subtype
    calleenode:assertraisef(calleetype, 'cannot call from generic pointers')
    attr.pointercall = true
  end
  if calleetype and calleetype:is_type() then
    -- type assertion
    local type = calleenode.attr.holdedtype
    assert(type)
    node:assertraisef(#argnodes == 1,
      "in assertion to type '%s', expected one argument, but got %d",
      tostring(type), #argnodes)
    local argnode = argnodes[1]
    context:traverse(argnode, type)
    local argtype = argnode.attr.type
    if argtype and not (argtype:is_numeric() and type:is_numeric()) then
      argnode:assertraisef(type:is_coercible_from_node(argnode, true),
        "in assertion to type '%s', the type is not coercible with expression of type '%s'",
        tostring(type), tostring(argtype))
    end
    attr.compconst = argnode.attr.compconst
    attr.sideeffect = argnode.attr.sideeffect
    attr.type = type
    attr.calleetype = calleetype
  else
    visitor_Call(context, node, argnodes, calleetype)
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
      node:assertraisef(symbol, 'cannot index record meta field "%s"', tostring(name))
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
        tostring(infunctype))
  end
  context:traverse(inexpnodes)
  context:repeat_scope_until_resolution('loop', function()
    if itvarnodes then
      for i,itvarnode in ipairs(itvarnodes) do
        local itsymbol = context:traverse(itvarnode)
        if infunctype and infunctype:is_function() then
          local fittype = infunctype:get_return_type(i)
          itsymbol:add_possible_type(fittype)
        end
      end
    end
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
      itvarnode:assertraisef(ittype:is_numeric() or (ittype:is_any() and not ittype:is_varanys()),
          "`for` variable must be a number, but got type '%s'",
           tostring(ittype))
      if btype then
        begvalnode:assertraisef(ittype:is_coercible_from_node(begvalnode),
          "`for` variable '%s' of type '%s' is not coercible with begin value of type '%s'",
          itname, tostring(ittype), tostring(btype))
      end
      if etype then
        endvalnode:assertraisef(ittype:is_coercible_from_node(endvalnode),
          "`for` variable '%s' of type '%s' is not coercible with end value of type '%s'",
          itname, tostring(ittype), tostring(etype))
      end
      if stype then
        stepvalnode:assertraisef(ittype:is_coercible_from_node(stepvalnode),
          "`for` variable '%s' of type '%s' is not coercible with increment value of type '%s'",
          itname, tostring(ittype), tostring(stype))
      end
    else
      itsymbol:add_possible_type(btype, true)
      itsymbol:add_possible_type(etype, true)
    end
    context:traverse(blocknode)
  end)
  local fixedstep
  if stype and stype:is_numeric() and stepvalnode.attr.compconst then
    -- constant step
    fixedstep = stepvalnode.attr.value
    stepvalnode:assertraisef(not fixedstep:iszero(), '`for` step cannot be zero')
  elseif not stepvalnode then
    -- default step is '1'
    fixedstep = bn.new(1)
  end
  local fixedend
  if etype and etype:is_numeric() and endvalnode.attr.compconst then
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
  local varscope, mut, varnodes, valnodes = node:args()
  valnodes = valnodes or {}
  node:assertraisef(not mut or typedefs.mutabilities[mut],
    'mutability %s not supported yet', mut)
  node:assertraisef(#varnodes >= #valnodes,
    'too many expressions in declaration, expected at most %d but got %d',
    #varnodes, #valnodes)
  for _,varnode,valnode,valtype in izipargnodes(varnodes, valnodes) do
    assert(varnode.tag == 'IdDecl')
    varnode.mut = mut
    local symbol = context:traverse(varnode)
    assert(symbol)
    local vartype = varnode.attr.type
    if vartype then
      varnode:assertraisef(
        not vartype:is_multipletype() and not vartype:is_void() and not vartype:is_varanys(),
        'variable declaration cannot be of the type "%s"', tostring(vartype))
    end
    assert(symbol.attr.type == vartype)
    varnode.assign = true
    if varnode.attr.compconst or varnode.attr.const then
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
    end
    if valtype then
      varnode:assertraisef(not valtype:is_void(), 'cannot assign to expressions of type void')
      if varnode.attr.compconst then
        -- for consts the type must be known ahead
        vartype = valtype
        symbol.attr.type = valtype
        symbol.attr.value = valnode.attr.value
      elseif valtype:is_type() then
        -- for 'type' types the type must also be known ahead
        vartype = valtype
        symbol.attr.type = valtype
        symbol.attr.compconst = true
      else
        -- lazy type evaluation
        symbol:add_possible_type(valtype)
      end
      if vartype and vartype ~= primtypes.boolean then
        varnode:assertraisef(vartype:is_coercible_from(valnode or valtype),
          "variable '%s' of type '%s' is not coercible with expression of type '%s'",
          symbol.name, tostring(vartype), tostring(valtype))
      end
      if valtype:is_type() then
        assert(valnode and valnode.attr.holdedtype)
        symbol.attr.holdedtype = valnode.attr.holdedtype
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
      varnode:assertraisef(vartype:is_coercible_from(valnode or valtype),
        "variable assignment of type '%s' is not coercible with expression of type '%s'",
        tostring(vartype), tostring(valtype))
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
        (retnode or node):assertraisef(funcrettype:is_coercible_from(retnode or rettype),
          "return at index %d of type '%s' is not coercible with expression of type '%s'",
          i, tostring(funcrettype), tostring(rettype))
      elseif rettype == false and funcrettype then
        node:assertraisef(funcrettype:is_nilable(),
          "missing return expression at index %d of type '%s'",
          i, tostring(funcrettype))
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
  local varscope, varnode, argnodes, retnodes, pragmanodes, blocknode = node:args()
  local symbol, argtypes

  if node.deducedargtypes then
    argtypes = node.deducedargtypes
  else
    for child in varnode:iterate_children() do
      child.infuncdef = true
    end
    if varscope == 'local' and varnode.tag == 'Id' then
      -- function declaration, must create a new symbol
      local name = varnode[1]
      local vartype = varnode.attr.type
      if not vartype and context.phase == phases.any_inference then
        vartype = primtypes.any
      end
      symbol = context.scope:add_symbol(Symbol(name, varnode, vartype))
    elseif varnode.tag == 'Id' then
      symbol = context:traverse(varnode)
    else -- DotIndex or ColumnIndex
      symbol = context:traverse(varnode)
    end
  end

  context:traverse(retnodes)
  local returntypes
  if #retnodes > 0 then
    -- returns types are pre declarated
    returntypes = tabler.imap(retnodes, function(retnode)
      return retnode.attr.holdedtype
    end)

    if #returntypes == 1 and returntypes[1]:is_void() then
      -- single void type means no returns
      returntypes = {}
    end
  elseif node.attr.type then
    -- recover return types from previous traversal
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
    if varscope == 'local' or symbol.attr.metafunc then
      -- new function declaration
      symbol.attr.type = type
    else
      -- check if previous symbol declaration is compatible
      local symboltype = symbol.attr.type
      if symboltype then
        node:assertraisef(symboltype:is_coercible_from_type(type),
          "in function defition, symbol of type '%s' is not coercible with function type '%s'",
          tostring(symboltype), tostring(type))
      else
        symbol:add_possible_type(type)
      end
    end
    symbol:link_node(node)
  else
    node.attr.type = type
  end

  if pragmanodes then
    context:traverse(pragmanodes, symbol)
  end

  if not lazy and not varnode.attr.nodecl and not varnode.attr.cimport then
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
    node:assertraisef(not context.attr.entrypoint or context.attr.entrypoint == node,
      "cannot have more than one function entrypoint")
    varnode.attr.declname = varnode.attr.codename
    context.attr.entrypoint = node
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
  local opname, argnode = node:args()
  if opname == 'not' then
    context:traverse(argnode, primtypes.boolean)
    node.attr.type = primtypes.boolean
  else
    context:traverse(argnode, desiredtype)
    local argtype = argnode.attr.type
    if argtype then
      local type = argtype:get_unary_operator_type(opname)
      argnode:assertraisef(type,
        "unary operation `%s` is not defined for type '%s' of the expression",
        opname, tostring(argtype))
      node.attr.type = type
    end
    if opname == 'neg' and argnode.tag == 'Number' then
      node.attr.value = argnode.attr.value
    end
    if (opname == 'deref' or opname == 'ref') and argnode.tag == 'Id' then
      -- for loops needs to know if an Id symbol could mutate
      argnode.attr.mutate = true
    end
    assert(context.phase ~= phases.any_inference or node.attr.type)
  end
  node.attr.compconst = argnode.attr.compconst
  node.attr.sideeffect = argnode.attr.sideeffect
  local parentnode = context:get_parent_node()
  node.attr.inoperator = parentnode and stringer.endswith(parentnode.tag, 'Op')
end

function visitors.BinaryOp(context, node, desiredtype)
  local opname, lnode, rnode = node:args()
  local type

  if desiredtype == primtypes.boolean then
    if typedefs.binary_conditional_ops[opname] then
      type = primtypes.boolean
      desiredtype = primtypes.boolean
    else
      desiredtype = nil
    end
  end

  local ldesiredtype = desiredtype
  local ternaryand = false
  local parent = context:get_parent_node()
  if opname == 'and' then
    if parent.tag == 'BinaryOp' and parent[1] == 'or' then
      ternaryand = true
      node.attr.ternaryand = true
      parent.attr.ternaryor = true
      ldesiredtype = primtypes.boolean
    end
  end

  context:traverse(rnode, desiredtype)
  context:traverse(lnode, ldesiredtype)
  local ltype, rtype = lnode.attr.type, rnode.attr.type

  if not type then
    -- traverse again trying to coerce untyped child nodes
    if lnode.untyped and rtype then
      context:traverse(lnode, rtype)
      ltype = lnode.attr.type
    elseif rnode.untyped and ltype then
      context:traverse(rnode, ltype)
      rtype = rnode.attr.type
    end

    if typedefs.binary_conditional_ops[opname] then
      if ternaryand then
        local prtype = parent[3].type
        type = typedefs.find_common_type({rtype, prtype})
      else
        type = typedefs.find_common_type({ltype, rtype})
      end
    else
      local ltargettype, rtargettype
      if ltype then
        ltargettype = ltype:get_binary_operator_type(opname)
        lnode:assertraisef(ltargettype,
          "binary operation `%s` is not defined for type '%s' of the left expression",
          opname, tostring(ltype))
      end
      if rtype then
        rtargettype = rtype:get_binary_operator_type(opname)
        rnode:assertraisef(rtargettype,
          "binary operation `%s` is not defined for type '%s' of the right expression",
          opname, tostring(rtype))
      end
      if ltargettype and rtargettype then
        type = typedefs.find_common_type({ltargettype, rtargettype})
        node:assertraisef(type,
          "binary operation `%s` is not defined for different types '%s' and '%s' in the expression",
          opname, tostring(ltargettype), tostring(rtargettype))
      end
      if type then
        if type:is_integral() and (opname == 'div' or opname == 'pow') then
          type = primtypes.number
        elseif opname == 'shl' or opname == 'shr' then
          type = ltargettype
        elseif opname == 'idiv' or opname == 'div' or opname == 'mod' then
          local rvalue = rnode.attr.value
          if rvalue then
            rnode:assertraisef(not rvalue:iszero(), "divizion by zero is not allowed")
          end
        end
      end
    end
  end
  if not type and context.phase == phases.any_inference then
    type = primtypes.any
  end
  if type then
    node.attr.type = type
  end
  if rtype and ltype then
    if typedefs.binary_conditional_ops[opname] and
      (not rtype:is_boolean() or not ltype:is_boolean()) then
      node.attr.dynamic_conditional = true
    elseif lnode.attr.compconst and rnode.attr.compconst then
      node.attr.compconst = true
    end
  end
  if lnode.attr.sideeffect or rnode.attr.sideeffect then
    node.attr.sideeffect = true
  end
  local parentnode = context:get_parent_node()
  node.attr.inoperator = parentnode and stringer.endswith(parentnode.tag, 'Op')
end

local typechecker = {}

function typechecker.analyze(ast, astbuilder)
  local context = Context(visitors, true)
  context.astbuilder = astbuilder

  -- phase 1 traverse: infer and check types
  context.phase = phases.type_inference
  context:repeat_scope_until_resolution('function', function()
    context:traverse(ast)
  end)

  -- phase 2 traverse: infer non set types to 'any' type
  context.phase = phases.any_inference
  context:repeat_scope_until_resolution('function', function()
    context:traverse(ast)
  end)

  return ast, context
end

return typechecker
