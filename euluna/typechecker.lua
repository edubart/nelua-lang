local iters = require 'euluna.utils.iterators'
local tabler = require 'euluna.utils.tabler'
local stringer = require 'euluna.utils.stringer'
local typedefs = require 'euluna.typedefs'
local Context = require 'euluna.context'
local Variable = require 'euluna.variable'
local types = require 'euluna.types'

local primtypes = typedefs.primtypes
local visitors = {}

local phases = {
  type_inference = 1,
  any_inference = 2
}

function visitors.Number(_, node)
  local numtype, int, frac, exp, literal = node:args()
  if literal then
    node.type = typedefs.number_literal_types[literal]
    node:assertraisef(node.type, 'literal suffix "%s" is not defined', literal)
  else
    if frac or (exp and stringer.startswith(exp, '-')) then
      node.type = primtypes.number
    else
      node.type = primtypes.integer
    end
  end
end

function visitors.String(_, node)
  node.type = primtypes.string
end

function visitors.Boolean(_, node)
  node.type = primtypes.boolean
end

function visitors.Id(context, node)
  local name = node:arg(1)
  local type = node.type
  if not type and context.phase == phases.any_inference then
    type = primtypes.any
  end
  local symbol = context.scope:get_symbol(name, node) or context.scope:add_symbol(Variable(name, node, type))
  symbol:link_node_type(node)
  return symbol
end

function visitors.Paren(context, node)
  local what = node:args()
  context:traverse(what)
  node.type = what.type
end

function visitors.Type(_, node)
  local tyname = node:arg(1)
  local type = primtypes[tyname]
  node:assertraisef(type, 'invalid type "%s"', tyname)
  node.type = type
  return type
end

function visitors.FuncType(context, node)
  local argtypes, returntypes = node:args()
  context:default_visitor(argtypes)
  context:default_visitor(returntypes)
  local type = types.FunctionType(node,
    tabler.imap(argtypes, function(n) return n.type end),
    tabler.imap(returntypes, function(n) return n.type end))
  node.type = type
  return type
end

function visitors.ComposedType(context, node)
  local name, subtypenodes = node:args()
  context:default_visitor(subtypenodes)
  local type
  if name == 'table' then
    local subtypes = tabler.imap(subtypenodes, function(n) return n.type end)
    node:assertraisef(#subtypes <= 2, 'tables can have at most 2 subtypes')
    type = types.ArrayTableType(node, subtypes)
  end
  node.type = type
  return type
end

function visitors.DotIndex(context, node)
  context:default_visitor(node)
  --TODO: detect better types
  node.type = primtypes.any
end

function visitors.ColonIndex(context, node)
  context:default_visitor(node)
  --TODO: detect better types
  node.type = primtypes.any
end

function visitors.ArrayIndex(context, node)
  context:default_visitor(node)
  local index, obj = node:args()
  if obj.type and obj.type:is_arraytable() then
    node.type = obj.type.subtypes[1]
  else
    node.type = primtypes.any
  end
end

function visitors.Call(context, node)
  local argtypes, args, callee, block_call = node:args()
  context:default_visitor(args)
  local symbol = context:traverse(callee)
  if symbol and symbol.type then
    callee:assertraisef(symbol.type:is_function() or symbol.type:is_any(),
      "attempt to call a non callable variable of type '%s'", symbol.type.name)
    node.callee_type = symbol.type
    if symbol.type:is_function() then
      -- check function argument types
      for i,argtype,argnode in iters.izip(symbol.type.argtypes, args) do
        if argtype and argnode and argnode.type then
          node:assertraisef(argtype:is_conversible(argnode.type),
            "in call function argument %d of type '%s' is not conversible with call argument %d of type '%s'",
            i, tostring(argtype), i, tostring(argnode.type))
        end
      end

      --TODO: check multiple returns

      node.type = symbol.type.returntypes[1] or primtypes.void
      node.types = symbol.type.returntypes
    end
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
  local type = typenode and context:traverse(typenode) or node.type
  if not type and context.phase == phases.any_inference then
    type = primtypes.any
  end
  local symbol = context.scope:add_symbol(Variable(name, node, type))
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
    local itsymbol = context.scope:add_symbol(Variable(itvarname, itvar, itvar.type))
    if itvar.type then
      if beginval.type then
        node:assertraisef(itvar.type:is_conversible(beginval.type),
          "`for` variable '%s' of type '%s' is not conversible with begin value of type '%s'",
          itvarname, tostring(itvar.type), tostring(beginval.type))
      end
      if endval.type then
        node:assertraisef(itvar.type:is_conversible(endval.type),
          "`for` variable '%s' of type '%s' is not conversible with end value of type '%s'",
          itvarname, tostring(itvar.type), tostring(endval.type))
      end
      if incrval and incrval.type then
        node:assertraisef(itvar.type:is_conversible(incrval.type),
          "`for` variable '%s' of type '%s' is not conversible with increment value of type '%s'",
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
  node:assertraisef(mutability == 'var', 'variable mutability not supported yet')
  for _,var,val in iters.izip(vars, vals or {}) do
    local symbol = context:traverse(var)
    assert(symbol.type == var.type, 'impossible')
    var.assign = true
    if val then
      context:traverse(val)
      symbol:add_possible_type(val.type)
      if var.type and val.type and var.type ~= primtypes.boolean then
        node:assertraisef(var.type:is_conversible(val.type),
          "variable '%s' of type '%s' is not conversible with value of type '%s'",
          symbol.name, tostring(var.type), tostring(val.type))
      end
    end
  end
end

function visitors.Assign(context, node)
  local vars, vals = node:args()
  for _,var,val in iters.izip(vars, vals) do
    local symbol = context:traverse(var)
    var.assign = true
    if val then
      context:traverse(val)
      if symbol then
        symbol:add_possible_type(val.type)
      end
      if var.type and val.type then
        node:assertraisef(var.type:is_conversible(val.type),
          "variable assignment of type '%s' is not conversible with value of type '%s'",
          tostring(var.type), tostring(val.type))
      end
    end
  end
end

function visitors.Return(context, node)
  context:default_visitor(node)
  local rets = node:args()
  local funcscope = context.scope:get_parent_of_kind('function')
  assert(funcscope, 'impossible')
  for i,ret in ipairs(rets) do
    funcscope:add_return_type(i, ret.type)
  end
end

function visitors.FuncDef(context, node)
  local varscope, varnode, argnodes, retnodes, blocknode = node:args()
  local symbol = context:traverse(varnode)

  -- try to resolver function return types
  local funcscope = repeat_scope_until_resolution(context, 'function', function()
    context:default_visitor(argnodes)
    context:default_visitor(retnodes)
    context:traverse(blocknode)
  end)

  local argtypes = tabler.imap(argnodes, function(n) return n.type or primtypes.any end)
  local returntypes = funcscope:resolve_returntypes()

  -- populate function return types
  for i,retnode in ipairs(retnodes) do
    local rtype = returntypes[i]
    if rtype then
      node:assertraisef(retnode.type:is_conversible(rtype),
        "return variable at index %d of type '%s' is not conversible with value of type '%s'",
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
        node:assertraisef(symbol.type:is_conversible(type),
          "in function defition, symbol of type '%s' is not conversible with function type '%s'",
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

function visitors.UnaryOp(context, node)
  local opname, arg = node:args()
  if opname == 'not' then
    -- must set to boolean type before traversing
    -- in case we are inside a if/while/repeat statement
    node.type = primtypes.boolean
    context:traverse(arg)
  else
    context:traverse(arg)
    if arg.type then
      local type = arg.type:get_unary_operator_type(opname)
      node:assertraisef(type,
        "unary operation `%s` is not defined for type '%s' of the expression",
        opname, tostring(arg.type))
      node.type = type
    end
    assert(context.phase ~= phases.any_inference or node.type, 'impossible')
  end
end

function visitors.BinaryOp(context, node)
  local opname, lnode, rnode = node:args()

  -- evaluate conditional operators to boolean type before traversing
  -- in case we are inside a if/while/repeat statement
  if typedefs.binary_conditional_ops[opname] then
    local parent_node = context:get_parent_node_if(function(a) return a.tag ~= 'Paren' end)
    if parent_node.type == primtypes.boolean then
      node.type = primtypes.boolean
      context:traverse(lnode)
      context:traverse(rnode)
      return
    end
  end

  context:traverse(lnode)
  context:traverse(rnode)

  local type
  if typedefs.binary_conditional_ops[opname] then
    if lnode.type == rnode.type then
      type = lnode.type
    elseif lnode.type and rnode.type then
      type = typedefs.find_common_type({lnode.type, rnode.type})
    end
  else
    local ltype, rtype
    if lnode.type then
      ltype = lnode.type:get_binary_operator_type(opname)
      node:assertraisef(ltype,
        "binary operation `%s` is not defined for type '%s' of the left expression",
        opname, tostring(lnode.type))
    end
    if rnode.type then
      rtype = rnode.type:get_binary_operator_type(opname)
      node:assertraisef(rtype,
        "binary operation `%s` is not defined for type '%s' of the right expression",
        opname, tostring(rnode.type))
    end
    if ltype and rtype then
      if ltype == rtype then
        type = ltype
      else
        type = typedefs.find_common_type({ltype, rtype})
      end
      node:assertraisef(type,
        "binary operation `%s` is not defined for different types '%s' and '%s' in the expression",
        opname, tostring(ltype), tostring(rtype))
    end
    if type then
      if type:is_real() and opname == 'idiv' then
        type = primtypes.integer
      elseif type:is_integral() and opname == 'pow' then
        type = primtypes.number
      end
    end
  end
  if type then
    node.type = type
  end
  assert(context.phase ~= phases.any_inference or node.type, 'impossible')
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
