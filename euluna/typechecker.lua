local iters = require 'euluna.utils.iterators'
local traits = require 'euluna.utils.traits'
local tabler = require 'euluna.utils.tabler'
local stringer = require 'euluna.utils.stringer'
local typedefs = require 'euluna.typedefs'
local Context = require 'euluna.context'
local Symbol = require 'euluna.symbol'
local types = require 'euluna.types'
local bn = require 'euluna.utils.bn'

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
  local parentnode = context:get_parent_node()
  if parentnode and parentnode.tag == 'UnaryOp' and parentnode:arg(1) == 'neg' then
    value = -value
  end
  local integral = not (frac or (exp and stringer.startswith(exp, '-')))
  local type
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
  node.attr.const = true
end

function visitors.String(_, node)
  if node.attr.type then return end
  local value, literal = node:args()
  node:assertraisef(literal == nil, 'literals are not supported yet')
  node.attr.value = value
  node.attr.type = primtypes.string
  node.attr.const = true
end

function visitors.Boolean(_, node)
  if node.attr.type then return end
  node.attr.value = node:args(1)
  node.attr.type = primtypes.boolean
  node.attr.const = true
end

function visitors.Nil(_, node)
  if node.attr.type then return end
  node.attr.type = primtypes.Nil
  node.attr.const = true
end

function visitors.Table(context, node, desiredtype)
  local childnodes = node:args()
  if desiredtype and desiredtype ~= primtypes.table then
    local const = true
    if desiredtype:is_arraytable() then
      local subtype = desiredtype.subtype
      for i, childnode in ipairs(childnodes) do
        childnode:assertraisef(childnode.tag ~= 'Pair',
          "in array table literal value, fields are not allowed")
        context:traverse(childnode, subtype)
        if childnode.attr.type then
          childnode:assertraisef(subtype:is_coercible_from_node(childnode),
            "in array table literal, subtype '%s' is not coercible with expression at index %d of type '%s'",
            tostring(subtype), i, tostring(childnode.attr.type))
          if childnode.attr.type == subtype then
            childnode.attr.initializer = true
          end
        end
      end
      const = false
    elseif desiredtype:is_array() then
      local subtype = desiredtype.subtype
      node:assertraisef(#childnodes == desiredtype.length or #childnodes == 0,
        " in array literal, expected %d values but got %d",
        desiredtype.length, #childnodes)
      for i, childnode in ipairs(childnodes) do
        childnode:assertraisef(childnode.tag ~= 'Pair',
          "in array literal, fields are not allowed")
        context:traverse(childnode, subtype)
        if childnode.attr.type then
          childnode:assertraisef(subtype:is_coercible_from_node(childnode),
            "in array literal, subtype '%s' is not coercible with expression at index %d of type '%s'",
            tostring(subtype), i, tostring(childnode.attr.type))
          if childnode.attr.type == subtype then
            childnode.attr.initializer = true
          end
        end
        if not childnode.attr.const then
          const = false
        end
      end
    elseif desiredtype:is_record() then
      for _, childnode in ipairs(childnodes) do
        childnode:assertraisef(childnode.tag == 'Pair',
          "in record literal, only named fields are allowed")
        local fieldname, fieldvalnode = childnode:args()
        childnode:assertraisef(traits.is_string(fieldname),
          "in record literal, only string literals are allowed in field names")
        local fieldtype = desiredtype:get_field_type(fieldname)
        childnode:assertraisef(fieldtype,
          "in record literal, field '%s' is not present in record of type '%s'",
          fieldname, tostring(desiredtype))
        context:traverse(fieldvalnode, fieldtype)
        if fieldvalnode.attr.type then
          fieldvalnode:assertraisef(fieldtype:is_coercible_from_node(fieldvalnode),
            "in record literal, field '%s' of type '%s' is not coercible with expression of type '%s'",
            fieldname, tostring(fieldtype), tostring(fieldvalnode.attr.type))
          if fieldvalnode.attr.type == fieldtype then
            fieldvalnode.attr.initializer = true
          end
        end
        childnode.attr.parenttype = desiredtype
        if not fieldvalnode.attr.const then
          const = false
        end
      end
    else
      node:raisef("in table literal, type '%s' cannot be initialized using a table literal",
        tostring(desiredtype))
    end
    node.attr.type = desiredtype
    if const then
      node.attr.const = true
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
  if symbol then
    if not symbol.attr.type then
      -- in the next traversal we will have the type
      return
    end
    if symbol.attr.type:is_function() then
      pragmashape = typedefs.function_pragmas[name]
    elseif not symbol.attr.type:is_type() then
      pragmashape = typedefs.variable_pragmas[name]
    end
  elseif not symbol then
    pragmashape = typedefs.block_pragmas[name]
  end
  node:assertraisef(pragmashape, "pragma '%s' is not defined in this context", name)
  local params = tabler.imap(argnodes, function(argnode)
    if traits.is_bignumber(argnode.attr.value) then
      return argnode.attr.value:tointeger()
    end
    return argnode.attr.value
  end)

  local attr
  if symbol then
    attr = symbol.attr
  else
    attr = node.attr
  end
  attr.haspragma = true

  if pragmashape == true then
    node:assertraisef(#argnodes == 0, "pragma '%s' takes no arguments", name)
    attr[name] = true
  else
    local ok, err = pragmashape(params)
    node:assertraisef(ok, "pragma '%s' arguments are invalid: %s", name, err)
    if #pragmashape.shape == 1 then
      params = params[1]
    end
    attr[name] = params
  end

  if name == 'cimport' then
    local cname, header = tabler.unpack(params)
    if cname then
      attr.codename = cname
    end
    attr.nodecl = header ~= true
    if traits.is_string(header) then
      attr.cinclude = header
    end
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
    if name == primtypes.Nilptr.name then
      type = primtypes.Nilptr
    end
    symbol = context.scope:add_symbol(Symbol(name, node, 'var', type))
  else
    symbol:link_node(node)
  end
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
  node.attr.const = true
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
  node.attr.const = true
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
  node.attr.const = true
end

function visitors.EnumFieldType(context, node, desiredtype)
  local name, numnode = node:args()
  local field = {name = name}
  if numnode then
    context:traverse(numnode, desiredtype)
    local value = numnode.attr.value
    numnode:assertraisef(numnode.attr.const,
      "enum values can only be assigned to const values")
    numnode:assertraisef(numnode.attr.type:is_integral(),
      "only integral numbers are allowed in enums, but got type '%s'",
      tostring(numnode.attr.type))
    field.value = value
    numnode:assertraisef(desiredtype:is_coercible_from_node(numnode),
      "enum of type '%s' is not coercible with field '%s' of type '%s'",
      tostring(desiredtype), name, tostring(numnode.attr.type))
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
      "in enum value %s or field '%s' is not in range of type '%s'", field.value:todec(), field.name, tostring(subtype))
    fields[i] = field
  end
  local type = types.EnumType(node, subtype, fields)
  node.attr.type = primtypes.type
  node.attr.holdedtype = type
  node.attr.const = true
end

function visitors.ArrayTableType(context, node)
  if node.attr.type then return end
  local subtypenode = node:args()
  context:traverse(subtypenode)
  local type = types.ArrayTableType(node, subtypenode.attr.holdedtype)
  node.attr.type = primtypes.type
  node.attr.holdedtype = type
  node.attr.const = true
end

function visitors.ArrayType(context, node)
  if node.attr.type then return end
  local subtypenode, lengthnode = node:args()
  context:traverse(subtypenode)
  local subtype = subtypenode.attr.holdedtype
  context:traverse(lengthnode)
  assert(lengthnode.attr.value, 'not implemented yet')
  local length = lengthnode.attr.value:tointeger()
  lengthnode:assertraisef(lengthnode.attr.type:is_integral() and length > 0,
    'expected a valid decimal integral number in the second argument of an "array" type')
  local type = types.ArrayType(node, subtype, length)
  node.attr.type = primtypes.type
  node.attr.holdedtype = type
  node.attr.const = true
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
  node.attr.const = true
end

function visitors.DotIndex(context, node)
  if node.attr.type then return end
  local name, objnode = node:args()
  context:traverse(objnode)
  local type
  local objtype = objnode.attr.type
  if objtype then
    if objtype:is_pointer() then
      objtype = objtype.subtype
    end

    if objtype:is_record() then
      type = objtype:get_field_type(name)
      node:assertraisef(type,
        'record "%s" does not have field named "%s"',
        tostring(objtype), name)
    elseif objtype:is_type() then
      assert(objnode.attr.holdedtype)
      objtype = objnode.attr.holdedtype
      node.attr.holdedtype = objtype
      if objtype:is_enum() then
        node:assertraisef(objtype:get_field(name),
          'enum "%s" does not have field named "%s"',
          tostring(objtype), name)
        type = objtype
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
  node.attr.type = type
end

function visitors.ColonIndex(context, node)
  context:default_visitor(node)
  --TODO: detect better types
  node.attr.type = primtypes.any
end

function visitors.ArrayIndex(context, node)
  context:default_visitor(node)
  local indexnode, objnode = node:args()
  local type
  local objtype = objnode.attr.type
  if objtype then
    if objtype:is_pointer() then
      objtype = objtype.subtype
    end

    if objtype:is_arraytable() or objtype:is_array() then
      if indexnode.attr.type then
        indexnode:assertraisef(indexnode.attr.type:is_integral(),
          "in array indexing, trying to index with non integral value '%s'",
          tostring(indexnode.attr.type))
      end
      if indexnode.attr.value then
        indexnode:assertraisef(not indexnode.attr.value:isneg(),
          "in array indexing, trying to index negative value %s",
          indexnode.attr.value:todec())
        if objtype:is_array() then
          indexnode:assertraisef(indexnode.attr.value < bn.new(objtype.length),
            "in array indexing, index %s is out of bounds, array maximum index is %d",
              indexnode.attr.value:todec(), objtype.length - 1)
        end
      end
      type = objtype.subtype
    end
  end
  if not type and context.phase == phases.any_inference then
    type = primtypes.any
  end
  node.attr.type = type
end

local function izipvarargs(vars, argnodes)
  local iter = iters.izip(vars, argnodes)
  local lastargnode = argnodes[#argnodes]
  if lastargnode and lastargnode.tag == 'Call' and lastargnode.callee_type ~= primtypes.type then
    -- last arg is a call
    if lastargnode.callee_type then
      -- we know call type
      local returntypes = lastargnode.callee_type.returntypes
      local returnindex = 2
      return function()
        local i, var, argnode = iter()
        local argtype = false
        -- argtype will be false this function is missing the return
        if not argnode then
          argtype = returntypes[returnindex] or false
          returnindex = returnindex + 1
        end
        return i, var, argnode, argtype
      end
    else
      -- call type is now known yet, argtype will be 'nil'
      return iter
    end
  else
    -- no calls from last argument
    return function()
      local i, var, argnode = iter()
      local argtype
      if not argnode then
        -- we are sure this argument have no type, set argtype to 'false'
        argtype = false
      end
      return i, var, argnode, argtype
    end
  end
end

function visitors.Call(context, node)
  local argnodes, calleenode, block_call = node:args()
  context:traverse(calleenode)
  node.attr.sideeffect = true
  if calleenode.attr.type then
    node.callee_type = calleenode.attr.type
    if calleenode.attr.type:is_type() then
      -- type assertion
      local type = calleenode.attr.holdedtype
      assert(type)
      node:assertraisef(#argnodes == 1,
        "in assertion to type '%s', expected one argument, but got %d",
        tostring(type), #argnodes)
      local argnode = argnodes[1]
      context:traverse(argnode, type)
      if argnode.attr.type and not (argnode.attr.type:is_numeric() and type:is_numeric()) then
        argnode:assertraisef(type:is_coercible_from_node(argnode, true),
          "in assertion to type '%s', the type is not coercible with expression of type '%s'",
          tostring(type), tostring(argnode.attr.type))
      end
      node.attr.const = argnode.attr.const
      node.attr.sideeffect = argnode.attr.sideeffect
      node.attr.type = type
    elseif calleenode.attr.type:is_function() then
      -- function call
      local funcargtypes = calleenode.attr.type.argtypes
      node:assertraisef(#argnodes <= #funcargtypes,
        "in call, function '%s' expected at most %d arguments but got %d",
        tostring(calleenode.attr.type), #funcargtypes, #argnodes)
      for i,funcargtype,argnode,argtype in izipvarargs(funcargtypes, argnodes) do
        if argnode then
          context:traverse(argnode, funcargtype)
          argtype = argnode.attr.type
        end
        if funcargtype and argtype == false then
          node:assertraisef(funcargtype:is_nilable(),
            "in call, function '%s' expected an argument at index %d but got nothing",
            tostring(calleenode.attr.type), i)
        end
        if funcargtype and argtype then
          calleenode:assertraisef(funcargtype:is_coercible_from(argnode or argtype),
"in call, function argument %d of type '%s' is not coercible with call argument %d of type '%s'",
            i, tostring(funcargtype), i, tostring(argtype))
        end
      end

      node.attr.type = calleenode.attr.type.returntypes[1] or primtypes.void
      node.attr.types = calleenode.attr.type.returntypes
    elseif calleenode.attr.type:is_table() then
      -- table call (allowed for tables with metamethod __index)
      node.attr.type = primtypes.any
    elseif not calleenode.attr.type:is_any() then
      context:traverse(argnodes)
      calleenode:raisef("attempt to call a non callable variable of type '%s'",
        tostring(calleenode.attr.type))
    else
      context:traverse(argnodes)
    end
  else
    context:traverse(argnodes)
  end
  if not node.attr.type and context.phase == phases.any_inference then
    node.attr.type = primtypes.any
  end
end

function visitors.IdDecl(context, node, declmut)
  local name, mut, typenode, pragmanodes = node:args()
  node:assertraisef(not (mut and declmut), "cannot declare mutability twice for '%s'", name)
  mut = mut or declmut or 'var'
  node:assertraisef(typedefs.mutabilities[mut],
    'mutability %s not supported yet', mut)
  local type = node.attr.type
  if typenode then
    context:traverse(typenode)
    type = typenode.attr.holdedtype
  end
  if not type and context.phase == phases.any_inference then
    type = primtypes.any
  end
  local symbol = context.scope:add_symbol(Symbol(name, node, mut, type))
  if pragmanodes then
    context:traverse(pragmanodes, symbol)
  end
  return symbol
end

local function repeat_scope_until_resolution(context, scope_kind, after_push)
  local resolutions_count = 0
  local scope
  repeat
    local last_resolutions_count = resolutions_count
    scope = context:push_scope(scope_kind)
    after_push()
    resolutions_count = context.scope:resolve_symbols_types()
    context:pop_scope()
  until resolutions_count == last_resolutions_count
  return scope
end

function visitors.Block(context, node)
  repeat_scope_until_resolution(context, 'block', function()
    context:default_visitor(node)
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
  context:traverse(blocknode)
  context:traverse(condnode, primtypes.boolean)
end

function visitors.ForNum(context, node)
  local itvarnode, beginvalnode, comp, endvalnode, incvalnode, blocknode = node:args()
  local itname = itvarnode[1]
  context:traverse(beginvalnode)
  context:traverse(endvalnode)
  if incvalnode then
    context:traverse(incvalnode)
  end
  repeat_scope_until_resolution(context, 'loop', function()
    local itsymbol = context:traverse(itvarnode)
    if itvarnode.attr.type then
      if beginvalnode.attr.type then
        itvarnode:assertraisef(itvarnode.attr.type:is_coercible_from_node(beginvalnode),
          "`for` variable '%s' of type '%s' is not coercible with begin value of type '%s'",
          itname, tostring(itvarnode.attr.type), tostring(beginvalnode.attr.type))
      end
      if endvalnode.attr.type then
        itvarnode:assertraisef(itvarnode.attr.type:is_coercible_from_node(endvalnode),
          "`for` variable '%s' of type '%s' is not coercible with end value of type '%s'",
          itname, tostring(itvarnode.attr.type), tostring(endvalnode.attr.type))
      end
      if incvalnode and incvalnode.attr.type then
        itvarnode:assertraisef(itvarnode.attr.type:is_coercible_from_node(incvalnode),
          "`for` variable '%s' of type '%s' is not coercible with increment value of type '%s'",
          itname, tostring(itvarnode.attr.type), tostring(incvalnode.attr.type))
      end
    else
      itsymbol:add_possible_type(beginvalnode.attr.type, true)
      itsymbol:add_possible_type(endvalnode.attr.type, true)
    end
    context:traverse(blocknode)
  end)
end

function visitors.VarDecl(context, node)
  local varscope, mut, varnodes, valnodes = node:args()
  valnodes = valnodes or {}
  node:assertraisef(not mut or typedefs.mutabilities[mut],
    'mutability %s not supported yet', mut)
  node:assertraisef(#varnodes >= #valnodes,
    'too many expressions in declaration, expected at most %d but got %d',
    #varnodes, #valnodes)
  for _,varnode,valnode,valtype in izipvarargs(varnodes, valnodes) do
    assert(varnode.tag == 'IdDecl')
    local symbol = context:traverse(varnode, mut)
    assert(symbol)
    local vartype = varnode.attr.type
    assert(symbol.attr.type == vartype)
    varnode.assign = true
    if varnode.attr.const then
      varnode:assertraisef(valnode, 'const variables must have an initial value')
    end
    if valnode then
      context:traverse(valnode, vartype, symbol)
      valtype = valnode.attr.type
      if varnode.attr.const then
        varnode:assertraisef(valnode.attr.const and valtype,
          'const variables can only assign to typed const expressions')
      end
      varnode:assertraisef(not varnode.attr.cimport or
        (vartype == primtypes.type or (vartype == nil and valtype == primtypes.type)),
        'cannot assign imported variables, only imported types can be assigned')
    end
    if valtype then
      if varnode.attr.const then
        -- for consts the type must be known ahead
        symbol.attr.type = valtype
        symbol.attr.value = valnode.attr.value
      elseif valtype:is_type() then
        -- for 'type' types the type must also be known ahead
        symbol.attr.type = valtype
        symbol.attr.const = true
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
    end
  end
end

function visitors.Assign(context, node)
  local varnodes, valnodes = node:args()
  node:assertraisef(#varnodes >= #valnodes,
    'too many expressions in assign, expected at most %d but got %d',
    #varnodes, #valnodes)
  for _,varnode,valnode,valtype in izipvarargs(varnodes, valnodes) do
    local symbol = context:traverse(varnode)
    local vartype = varnode.attr.type
    varnode.assign = true
    varnode:assertraisef(not typedefs.readonly_mutabilities[varnode.attr.mut],
      "cannot assign a read only variable of mutability '%s'", varnode.attr.mut)
    if valnode then
      context:traverse(valnode, vartype)
      valtype = valnode.attr.type
    end
    if symbol then -- symbol may nil in case of array/dot index
      symbol:add_possible_type(valtype)
    end
    if vartype and valtype then
      varnode:assertraisef(vartype:is_coercible_from(valnode or valtype),
        "variable assignment of type '%s' is not coercible with expression of type '%s'",
        tostring(vartype), tostring(valtype))
    end
  end
end

function visitors.Return(context, node)
  context:default_visitor(node)
  local retnodes = node:args()
  local funcscope = context.scope:get_parent_of_kind('function')
  assert(funcscope)
  for i,retnode in ipairs(retnodes) do
    funcscope:add_return_type(i, retnode.attr.type)
  end
end

function visitors.FuncDef(context, node)
  local varscope, varnode, argnodes, retnodes, pragmanodes, blocknode = node:args()
  local symbol = context:traverse(varnode)

  -- try to resolver function return types
  local funcscope = repeat_scope_until_resolution(context, 'function', function()
    context:traverse(argnodes)
    context:traverse(retnodes)
    context:traverse(blocknode)
  end)

  local argtypes = tabler.imap(argnodes, function(argnode)
    return argnode.attr.type or primtypes.any
  end)
  local returntypes = funcscope:resolve_returntypes()

  -- populate function return types
  for i,retnode in ipairs(retnodes) do
    local rtype = returntypes[i]
    if rtype then
      retnode:assertraisef(retnode.attr.holdedtype:is_coercible_from_type(rtype),
        "return variable at index %d of type '%s' is not coercible with expression of type '%s'",
        i, tostring(retnode.attr.holdedtype), tostring(rtype))
    else
      returntypes[i] = retnode.attr.holdedtype
    end
  end

  -- populate return type nodes
  for i,rtype in pairs(returntypes) do
    local retnode = retnodes[i]
    if not retnode then
      retnode = context.astbuilder:create('Type', '<dummy>')
      retnode.attr.type = primtypes.type
      retnode.attr.holdedtype = rtype
      retnode.attr.const = true
      retnodes[i] = retnode
    end
  end

  -- build function type
  local type = types.FunctionType(node, argtypes, returntypes)

  if symbol then -- symbol may be nil in case of array/dot index
    if varscope == 'local' then
      -- new function declaration
      symbol.attr.type = type
    else
      -- check if previous symbol declaration is compatible
      if symbol.attr.type then
        node:assertraisef(symbol.attr.type:is_coercible_from_type(type),
          "in function defition, symbol of type '%s' is not coercible with function type '%s'",
          tostring(symbol.attr.type), tostring(type))
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

  if varnode.attr.cimport then
    blocknode:assertraisef(#blocknode[1] == 0, 'body of an import function must be empty')
  end
end

local function is_in_operator(context)
  local parent_node = context:get_parent_node()
  if not parent_node then return false end
  local parent_node_tag = parent_node.tag
  return
    parent_node_tag == 'UnaryOp' or
    parent_node_tag == 'BinaryOp'
end

function visitors.UnaryOp(context, node, desiredtype)
  local opname, argnode = node:args()
  if opname == 'not' then
    context:traverse(argnode, primtypes.boolean)
    node.attr.type = primtypes.boolean
  else
    context:traverse(argnode, desiredtype)
    if argnode.attr.type then
      local type = argnode.attr.type:get_unary_operator_type(opname)
      argnode:assertraisef(type,
        "unary operation `%s` is not defined for type '%s' of the expression",
        opname, tostring(argnode.attr.type))
      node.attr.type = type
    end
    if opname == 'neg' and argnode.tag == 'Number' then
      node.attr.value = argnode.attr.value
    end
    assert(context.phase ~= phases.any_inference or node.attr.type)
  end
  argnode.attr.const = node.attr.const
  argnode.attr.sideeffect = node.attr.sideeffect
  node.attr.inoperator = is_in_operator(context)
end

function visitors.BinaryOp(context, node, desiredtype)
  local opname, lnode, rnode = node:args()
  local type

  if desiredtype == primtypes.boolean then
    if typedefs.binary_conditional_ops[opname] then
      type = primtypes.boolean
      context:traverse(lnode, primtypes.boolean)
      context:traverse(rnode, primtypes.boolean)
    else
      desiredtype = nil
    end
  end

  if not type then
    context:traverse(lnode, desiredtype)
    context:traverse(rnode, desiredtype)

    -- traverse again trying to coerce untyped child nodes
    if lnode.untyped and rnode.attr.type then
      context:traverse(lnode, rnode.attr.type)
    elseif rnode.untyped and lnode.attr.type then
      context:traverse(rnode, lnode.attr.type)
    end

    if typedefs.binary_conditional_ops[opname] then
      type = typedefs.find_common_type({lnode.attr.type, rnode.attr.type})
    else
      local ltype, rtype
      if lnode.attr.type then
        ltype = lnode.attr.type:get_binary_operator_type(opname)
        lnode:assertraisef(ltype,
          "binary operation `%s` is not defined for type '%s' of the left expression",
          opname, tostring(lnode.attr.type))
      end
      if rnode.attr.type then
        rtype = rnode.attr.type:get_binary_operator_type(opname)
        rnode:assertraisef(rtype,
          "binary operation `%s` is not defined for type '%s' of the right expression",
          opname, tostring(rnode.attr.type))
      end
      if ltype and rtype then
        type = typedefs.find_common_type({ltype, rtype})
        node:assertraisef(type,
          "binary operation `%s` is not defined for different types '%s' and '%s' in the expression",
          opname, tostring(ltype), tostring(rtype))
      end
      if type then
        if type:is_integral() and (opname == 'div' or opname == 'pow') then
          type = primtypes.number
        elseif opname == 'shl' or opname == 'shr' then
          type = ltype
        end

        if rnode.attr.value and (opname == 'idiv' or opname == 'div' or opname == 'mod') then
          rnode:assertraisef(not rnode.attr.value:iszero(), "divizion by zero is not allowed")
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
  if rnode.attr.type and lnode.attr.type then
    if typedefs.binary_conditional_ops[opname] and
      (not rnode.attr.type:is_boolean() or not lnode.attr.type:is_boolean()) then
      node.attr.dynamic_conditional = true
    elseif lnode.attr.const and rnode.attr.const then
      node.attr.const = true
    end
  end
  if lnode.attr.sideeffect or rnode.attr.sideeffect then
    node.attr.sideeffect = true
  end
  node.attr.inoperator = is_in_operator(context)
end

local typechecker = {}
function typechecker.analyze(ast, astbuilder)
  local context = Context(visitors, true)
  context.astbuilder = astbuilder

  -- phase 1 traverse: infer and check types
  context.phase = phases.type_inference
  repeat_scope_until_resolution(context, 'function', function()
    context:traverse(ast)
  end)

  -- phase 2 traverse: infer non set types to 'any' type
  context.phase = phases.any_inference
  repeat_scope_until_resolution(context, 'function', function()
    context:traverse(ast)
  end)

  return ast
end

return typechecker
