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

function visitors.Number(_, node, desiredtype)
  local base, int, frac, exp, literal = node:args()
  local value
  if base == 'hex' then
    value = bn.fromhex(int, frac, exp)
  elseif base == 'bin' then
    value = bn.frombin(int, frac, exp)
  else
    value = bn.fromdec(int, frac, exp)
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
  if desiredtype and desiredtype:is_numeric() and desiredtype:is_coercible_from(type) then
    type = desiredtype
  end
  node.type = type
  node.value = value
  node.literal = true
end

function visitors.String(_, node)
  node.type = primtypes.string
  node.literal = true
end

function visitors.Boolean(_, node)
  node.type = primtypes.boolean
  node.literal = true
end

function visitors.Nil(_, node)
  node.type = primtypes.Nil
  node.literal = true
end

function visitors.Table(context, node, desiredtype)
  local childnodes = node:args()
  if desiredtype and desiredtype ~= primtypes.table then
    if desiredtype:is_arraytable() then
      local subtype = desiredtype.subtype
      for i, childnode in ipairs(childnodes) do
        childnode:assertraisef(childnode.tag ~= 'Pair',
          "in array table literal value, fields are not allowed")
        context:traverse(childnode, subtype)
        if childnode.type then
          childnode:assertraisef(subtype:is_coercible_from(childnode.type),
            "in array table literal, subtype '%s' is not coercible with expression at index %d of type '%s'",
            tostring(subtype), i, tostring(childnode.type))
        end
      end
    elseif desiredtype:is_array() then
      local subtype = desiredtype.subtype
      node:assertraisef(#childnodes == desiredtype.length,
        " in array literal, expected %d values but got %d",
        desiredtype.length, #childnodes)
      for i, childnode in ipairs(childnodes) do
        childnode:assertraisef(childnode.tag ~= 'Pair',
          "in array literal, fields are not allowed")
        context:traverse(childnode, subtype)
        if childnode.type then
          childnode:assertraisef(subtype:is_coercible_from(childnode.type),
            "in array literal, subtype '%s' is not coercible with expression at index %d of type '%s'",
            tostring(subtype), i, tostring(childnode.type))
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
        if fieldvalnode.type then
          fieldvalnode:assertraisef(fieldtype:is_coercible_from(fieldvalnode.type),
            "in record literal, field '%s' of type '%s' is not coercible with expression of type '%s'",
            fieldname, tostring(fieldtype), tostring(fieldvalnode.type))
        end
      end
    else
      node:raisef("in table literal, type '%s' cannot be initialized using a table literal",
        tostring(desiredtype))
    end
    node.type = desiredtype
  else
    context:traverse(childnodes)
    node.type = primtypes.table
  end
  node.literal = true
end

function visitors.Id(context, node)
  local name = node:arg(1)
  local type = node.type
  if not type and context.phase == phases.any_inference then
    type = primtypes.any
  end
  local symbol = context.scope:get_symbol(name, node) or context.scope:add_symbol(Symbol(name, node, type))
  symbol:link_node_type(node)
  return symbol
end

function visitors.Paren(context, node, ...)
  local innernode = node:args()
  local ret = context:traverse(innernode, ...)
  node.type = innernode.type
  return ret
end

function visitors.Type(context, node)
  local tyname = node:arg(1)
  local symbol = typedefs.primsymbols[tyname]
  if not symbol then
    symbol = context.scope:get_symbol(tyname, node)
    node:assertraisef(symbol and symbol.holding_type, "symbol '%s' is not a valid type", tyname)
  end
  node.type = symbol.holding_type
  return symbol
end

function visitors.TypeInstance(context, node)
  local typenode = node:arg(1)
  local symbol = context:traverse(typenode)
  node.type = primtypes.type
  return symbol
end

function visitors.FuncType(context, node)
  local argnodes, returnnodes = node:args()
  context:traverse(argnodes)
  context:traverse(returnnodes)
  local type = types.FunctionType(node,
    tabler.imap(argnodes, function(n) return n.type end),
    tabler.imap(returnnodes, function(n) return n.type end))
  node.type = type
  return Symbol(nil, node, primtypes.type, type)
end

function visitors.RecordFieldType(context, node)
  local name, typenode = node:args()
  context:traverse(typenode)
  local type = typenode.type
  node.type = type
end

function visitors.RecordType(context, node)
  local fieldnodes = node:args()
  context:traverse(fieldnodes)
  local fields = tabler.imap(fieldnodes, function(n)
    return {name = n:arg(1), type=n.type}
  end)
  local type = types.RecordType(node, fields)
  node.type = type
  return Symbol(nil, node, primtypes.type, type)
end

function visitors.EnumFieldType(context, node, desiredtype)
  local name, numnode = node:args()
  local field = {name = name}
  if numnode then
    context:traverse(numnode)
    local value = numnode.value
    assert(numnode.tag == 'Number')
    numnode:assertraisef(numnode.type:is_integral(),
      "only integral numbers are allowed in enums")
    field.value = value
    numnode:assertraisef(desiredtype:is_coercible_from(numnode.type),
      "enum of type '%s' is not coercible with field '%s' of type '%s'",
      tostring(desiredtype), name, tostring(numnode.type))
  end
  return field
end

function visitors.EnumType(context, node)
  local typenode, fieldnodes = node:args()
  local subtype = primtypes.integer
  if typenode then
    context:traverse(typenode)
    subtype = typenode.type
  end
  local fields = {}
  local haszero = false
  for i,fnode in ipairs(fieldnodes) do
    local field = context:traverse(fnode, subtype)
    if not field.value then
      if i == 1 then
        fnode:raisef('in enum declaration, first field requires a initial value')
      else
        field.value = fields[i-1].value
      end
    end
    if field.value:iszero() then
      haszero = true
    end
    fields[i] = field
  end
  node:assertraisef(haszero, 'in enum declaration, a field with value 0 is always required')
  local type = types.EnumType(node, subtype, fields)
  node.type = type
  return Symbol(nil, node, primtypes.type, type)
end

function visitors.ArrayTableType(context, node)
  local subtypenode = node:args()
  context:traverse(subtypenode)
  local type = types.ArrayTableType(node, subtypenode.type)
  node.type = type
  return Symbol(nil, node, primtypes.type, type)
end

function visitors.ArrayType(context, node)
  local subtypenode, lengthnode = node:args()
  context:traverse(subtypenode)
  local subtype = subtypenode.type
  context:traverse(lengthnode)
  assert(lengthnode.tag == 'Number')
  local length = lengthnode.value:tointeger()
  lengthnode:assertraisef(lengthnode.type:is_integral() and length > 0,
    'expected a valid decimal integral number in the second argument of an "array" type')
  local type = types.ArrayType(node, subtype, length)
  node.type = type
  return Symbol(nil, node, primtypes.type, type)
end

function visitors.PointerType(context, node)
  local subtypenode = node:args()
  local type
  local symbol
  if subtypenode then
    context:traverse(subtypenode)
    assert(subtypenode.type)
    type = types.PointerType(node, subtypenode.type)
    symbol = Symbol(nil, node, type.type, type)
  else
    type = primtypes.pointer
    symbol = typedefs.primsymbols.pointer
  end
  node.type = type
  return symbol
end

function visitors.DotIndex(context, node)
  local name, objnode = node:args()
  local symbol = context:traverse(objnode)
  local type
  local objtype = objnode.type
  if objtype then
    if objtype:is_record() then
      type = objtype:get_field_type(name)
      node:assertraisef(type,
        'record "%s" does not have field named "%s"',
        tostring(objtype), name)
    elseif objtype:is_type() then
      assert(symbol)
      assert(symbol.holding_type)
      objtype = symbol.holding_type
      node.holding_type = objtype
      if objtype:is_enum() then
        node:assertraisef(objtype:get_field(name),
          'enum "%s" does not have field named "%s"',
          tostring(objtype), name)
        type = objtype
      else
        node:raisef('cannot index object of type "%s"', tostring(objtype))
      end
    end
  end
  if not type and context.phase == phases.any_inference then
    type = primtypes.any
  end
  node.type = type
end

function visitors.ColonIndex(context, node)
  context:default_visitor(node)
  --TODO: detect better types
  node.type = primtypes.any
end

function visitors.ArrayIndex(context, node)
  context:default_visitor(node)
  local index, obj = node:args()
  local type
  if obj.type then
    --TODO: check negative literal values
    --TODO: check if index type is an integral
    if obj.type:is_arraytable() then
      type = obj.type.subtype
    elseif obj.type:is_array() then
      type = obj.type.subtype
    end
  end
  if not type and context.phase == phases.any_inference then
    type = primtypes.any
  end
  node.type = type
end

function visitors.Call(context, node)
  local argnodes, calleenode, block_call = node:args()
  local symbol = context:traverse(calleenode)
  if symbol and symbol.type then
    node.callee_type = symbol.type
    if symbol.type:is_type() then
      local type = symbol.holding_type
      assert(type)
      node:assertraisef(#argnodes == 1,
        "in value creation of type '%s', expected one argument, but got %d",
        tostring(type), #argnodes)
      local argnode = argnodes[1]
      context:traverse(argnode, type)
      if argnode.type then
        argnode:assertraisef(type:is_coercible_from(argnode.type),
          "in value creation, type '%s' is not coercible with argument of type '%s'",
          tostring(type), tostring(argnode.type))
      end
      node.type = type
    elseif symbol.type:is_function() then
      local argtypes = symbol.type.argtypes
      node:assertraisef(#argnodes <= #argtypes,
        "in call, function '%s' expected at most %d arguments but got %d",
        tostring(symbol.type), #argtypes, #argnodes)
      for i,argtype,argnode in iters.izip(symbol.type.argtypes, argnodes) do
        if argnode then
          context:traverse(argnode, argtype)
        elseif argtype then
          node:assertraisef(argtype:is_nilable(),
            "in call, function '%s' expected an argument at index %d but got nothing",
            tostring(symbol.type), i)
        end
        if argtype and argnode and argnode.type then
          argnode:assertraisef(argtype:is_coercible_from(argnode.type),
            "in call, function argument %d of type '%s' is not coercible with call argument %d of type '%s'",
            i, tostring(argtype), i, tostring(argnode.type))
        end
      end

      --TODO: check multiple returns

      node.type = symbol.type.returntypes[1] or primtypes.void
      node.types = symbol.type.returntypes
    elseif not symbol.type:is_any() then
      context:traverse(argnodes)
      calleenode:raisef("attempt to call a non callable variable of type '%s'", tostring(symbol.type))
    else
      context:traverse(argnodes)
    end
  else
    context:traverse(argnodes)
  end
  if not node.callee_type and context.phase == phases.any_inference then
    node.callee_type = primtypes.any
  end
  if not node.type and context.phase == phases.any_inference then
    node.type = primtypes.any
  end
end

function visitors.IdDecl(context, node)
  local name, mut, typenode = node:args()
  local type = node.type
  if typenode then
    context:traverse(typenode)
    type = typenode.type
  end
  if not type and context.phase == phases.any_inference then
    type = primtypes.any
  end
  local symbol = context.scope:add_symbol(Symbol(name, node, type))
  symbol:link_node_type(node)
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
  node.type = primtypes.boolean
  context:default_visitor(node)
end

function visitors.While(context, node)
  node.type = primtypes.boolean
  context:default_visitor(node)
end

function visitors.Repeat(context, node)
  node.type = primtypes.boolean
  context:default_visitor(node)
end

function visitors.ForNum(context, node)
  local itvar, beginval, comp, endval, incrval, block = node:args()
  local itvarname = itvar[1]
  context:traverse(beginval)
  context:traverse(endval)
  if incrval then
    context:traverse(incrval)
  end
  repeat_scope_until_resolution(context, 'loop', function()
    context:traverse(itvar)
    local itsymbol = context.scope:add_symbol(Symbol(itvarname, itvar, itvar.type))
    if itvar.type then
      if beginval.type then
        itvar:assertraisef(itvar.type:is_coercible_from(beginval.type),
          "`for` variable '%s' of type '%s' is not coercible with begin value of type '%s'",
          itvarname, tostring(itvar.type), tostring(beginval.type))
      end
      if endval.type then
        itvar:assertraisef(itvar.type:is_coercible_from(endval.type),
          "`for` variable '%s' of type '%s' is not coercible with end value of type '%s'",
          itvarname, tostring(itvar.type), tostring(endval.type))
      end
      if incrval and incrval.type then
        itvar:assertraisef(itvar.type:is_coercible_from(incrval.type),
          "`for` variable '%s' of type '%s' is not coercible with increment value of type '%s'",
          itvarname, tostring(itvar.type), tostring(incrval.type))
      end
    else
      itsymbol:add_possible_type(beginval.type, true)
      itsymbol:add_possible_type(endval.type, true)
    end
    itsymbol:link_node_type(itvar)
    context:traverse(block)
  end)
end

function visitors.VarDecl(context, node)
  local varscope, mutability, vars, vals = node:args()
  vals = vals or {}
  node:assertraisef(mutability == 'var', 'variable mutability not supported yet')
  node:assertraisef(#vars >= #vals,
    'too many expressions in declaration, expected at most %d but got %d',
    #vars, #vals)
  for _,var,val in iters.izip(vars, vals) do
    local symbol = context:traverse(var)
    assert(symbol.type == var.type)
    var.assign = true
    if val then
      local valsymbol = context:traverse(val, var.type)
      if val.type then
        symbol:add_possible_type(val.type)
        if var.type and var.type ~= primtypes.boolean then
          var:assertraisef(var.type:is_coercible_from(val.type),
            "variable '%s' of type '%s' is not coercible with expression of type '%s'",
            symbol.name, tostring(var.type), tostring(val.type))
        end
        if val.type:is_type() then
          assert(valsymbol and valsymbol.holding_type)
          symbol.holding_type = valsymbol.holding_type
        end
      end
    end
  end
end

function visitors.Assign(context, node)
  local vars, vals = node:args()
  node:assertraisef(#vars >= #vals,
    'too many expressions in assign, expected at most %d but got %d',
    #vars, #vals)
  for _,var,val in iters.izip(vars, vals) do
    local symbol = context:traverse(var)
    var.assign = true
    if val then
      context:traverse(val, var.type)
      if symbol then
        symbol:add_possible_type(val.type)
      end
      if var.type and val.type then
        var:assertraisef(var.type:is_coercible_from(val.type),
          "variable assignment of type '%s' is not coercible with expression of type '%s'",
          tostring(var.type), tostring(val.type))
      end
    end
  end
end

function visitors.Return(context, node)
  context:default_visitor(node)
  local rets = node:args()
  local funcscope = context.scope:get_parent_of_kind('function')
  assert(funcscope)
  for i,ret in ipairs(rets) do
    funcscope:add_return_type(i, ret.type)
  end
end

function visitors.FuncDef(context, node)
  local varscope, varnode, argnodes, retnodes, blocknode = node:args()
  local symbol = context:traverse(varnode)

  -- try to resolver function return types
  local funcscope = repeat_scope_until_resolution(context, 'function', function()
    context:traverse(argnodes)
    context:traverse(retnodes)
    context:traverse(blocknode)
  end)

  local argtypes = tabler.imap(argnodes, function(n) return n.type or primtypes.any end)
  local returntypes = funcscope:resolve_returntypes()

  -- populate function return types
  for i,retnode in ipairs(retnodes) do
    local rtype = returntypes[i]
    if rtype then
      retnode:assertraisef(retnode.type:is_coercible_from(rtype),
        "return variable at index %d of type '%s' is not coercible with expression of type '%s'",
        i, tostring(retnode.type), tostring(rtype))
    else
      returntypes[i] = retnode.type
    end
  end

  -- populate return type nodes
  for i,rtype in pairs(returntypes) do
    local retnode = retnodes[i]
    if not retnode then
      retnode = context.astbuilder:create('Type', tostring(rtype))
      retnode.type = rtype
      retnodes[i] = retnode
    end
  end

  -- build function type
  local type = types.FunctionType(node, argtypes, returntypes)

  if symbol then
    if varscope == 'local' then
      -- new function declaration
      symbol:set_type(type)
    else
      -- check if previous symbol declaration is compatible
      if symbol.type then
        node:assertraisef(symbol.type:is_coercible_from(type),
          "in function defition, symbol of type '%s' is not coercible with function type '%s'",
          tostring(symbol.type), tostring(type))
      else
        symbol:add_possible_type(type)
      end
    end
    symbol:link_node_type(node)
  else
    node.type = type
  end
end

function visitors.UnaryOp(context, node, desiredtype)
  local opname, argnode = node:args()
  if opname == 'not' then
    -- must set to boolean type before traversing
    -- in case we are inside a if/while/repeat statement
    node.type = primtypes.boolean
    context:traverse(argnode, primtypes.boolean)
  else
    context:traverse(argnode, desiredtype)
    if argnode.type then
      local type = argnode.type:get_unary_operator_type(opname)
      argnode:assertraisef(type,
        "unary operation `%s` is not defined for type '%s' of the expression",
        opname, tostring(argnode.type))
      node.type = type
    end
    assert(context.phase ~= phases.any_inference or node.type)
  end
end

function visitors.BinaryOp(context, node, desiredtype)
  local opname, lnode, rnode = node:args()

  -- evaluate conditional operators to boolean type before traversing
  -- in case we are inside a if/while/repeat statement
  if typedefs.binary_conditional_ops[opname] then
    -- TODO: use desiredtype instead of this check
    local parent_node = context:get_parent_node_if(function(a) return a.tag ~= 'Paren' end)
    if parent_node.type == primtypes.boolean then
      node.type = primtypes.boolean
      context:traverse(lnode, primtypes.boolean)
      context:traverse(rnode, primtypes.boolean)
      return
    end
  end

  context:traverse(lnode, desiredtype)
  context:traverse(rnode, desiredtype)

  -- traverse again trying to coerce untyped child nodes
  if lnode.untyped and rnode.type then
    context:traverse(lnode, rnode.type)
  elseif rnode.untyped and lnode.type then
    context:traverse(rnode, lnode.type)
  end

  local type
  if typedefs.binary_conditional_ops[opname] then
    type = typedefs.find_common_type({lnode.type, rnode.type})
  else
    local ltype, rtype
    if lnode.type then
      ltype = lnode.type:get_binary_operator_type(opname)
      lnode:assertraisef(ltype,
        "binary operation `%s` is not defined for type '%s' of the left expression",
        opname, tostring(lnode.type))
    end
    if rnode.type then
      rtype = rnode.type:get_binary_operator_type(opname)
      rnode:assertraisef(rtype,
        "binary operation `%s` is not defined for type '%s' of the right expression",
        opname, tostring(rnode.type))
    end
    if ltype and rtype then
      type = typedefs.find_common_type({ltype, rtype})
      node:assertraisef(type,
        "binary operation `%s` is not defined for different types '%s' and '%s' in the expression",
        opname, tostring(ltype), tostring(rtype))
    end
    if type then
      if type:is_float() and opname == 'idiv' then
        type = primtypes.integer
      elseif type:is_integral() and opname == 'pow' then
        type = primtypes.number
      elseif opname == 'shl' or opname == 'shr' then
        type = ltype
      end
    end
  end
  if type then
    node.type = type
  end
  assert(context.phase ~= phases.any_inference or node.type)
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
