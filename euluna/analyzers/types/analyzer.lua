local iters = require 'euluna.utils.iterators'
local tabler = require 'euluna.utils.tabler'
local typedefs = require 'euluna.analyzers.types.definitions'
local typer = require 'euluna.typer'
local TraverseContext = require 'euluna.traversecontext'
local Variable = require 'euluna.variable'
local FunctionType = require 'euluna.functiontype'

local types = typedefs.primitive_types
local visitors = {}

function visitors.Number(_, ast)
  local numtype, value, literal = ast:args()
  if literal then
    ast.type = typedefs.number_literal_types[literal]
    ast:assertraisef(ast.type, 'literal suffix "%s" is not defined', literal)
  else
    ast.type = typedefs.number_default_types[numtype]
    ast:assertf(ast.type, 'invalid number type "%s" for AST Number', numtype)
  end
end

function visitors.String(_, ast)
  ast.type = types.string
end

function visitors.Boolean(_, ast)
  ast.type = types.boolean
end

function visitors.Id(context, ast)
  local name = ast:arg(1)
  local symbol = context.scope:get_symbol(name, ast) or context.scope:add_symbol(Variable(name, ast))
  symbol:link_ast_type(ast)
  return symbol
end

function visitors.Paren(context, ast)
  local what = ast:args()
  context:traverse(what)
  ast.type = what.type
end

function visitors.Type(_, ast)
  local tyname = ast:arg(1)
  local type = types[tyname]
  ast:assertf(type, 'invalid type "%s"', tyname)
  ast.holding_type = type
  ast.type = type.type
  return type
end

function visitors.FuncType(context, ast)
  local argtypes, returntypes = ast:args()
  context:default_visitor(argtypes)
  context:default_visitor(returntypes)
  local type = FunctionType(ast,
    tabler.imap(argtypes, function(n) return n.holding_type end),
    tabler.imap(returntypes, function(n) return n.holding_type end))
  ast.holding_type = type
  ast.type = type.type
  return type
end

function visitors.Call(context, ast)
  local argtypes, args, caller, block_call = ast:args()
  context:default_visitor(args)
  local symbol = context:traverse(caller)
  if symbol and symbol.type then
    caller:assertraisef(symbol.type.name == 'function',
      "attempt to call a non callable variable of type '%s'", symbol.type.name)
    ast.type = symbol.type.return_types[1]
    ast.types = symbol.type.return_types
  end
end

function visitors.IdDecl(context, ast)
  local name, mut, typenode = ast:args()
  local type = typenode and context:traverse(typenode) or ast.type
  local symbol = context.scope:add_symbol(Variable(name, ast, type))
  symbol:link_ast_type(ast)
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

function visitors.Block(context, ast)
  repeat_scope_until_resolution(context, 'block', function()
    context:default_visitor(ast)
  end)
end

function visitors.If(context, ast)
  ast.type = types.boolean
  context:default_visitor(ast)
end

function visitors.While(context, ast)
  ast.type = types.boolean
  context:default_visitor(ast)
end

function visitors.Repeat(context, ast)
  ast.type = types.boolean
  context:default_visitor(ast)
end

function visitors.ForNum(context, ast)
  local itvar, beginval, comp, endval, incrval, block = ast:args()
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
        ast:assertraisef(itvar.type:is_conversible(beginval.type),
          "`for` variable '%s' of type '%s' is not conversible with begin value of type '%s'",
          itvarname, tostring(itvar.type), tostring(beginval.type))
      end
      if endval.type then
        ast:assertraisef(itvar.type:is_conversible(endval.type),
          "`for` variable '%s' of type '%s' is not conversible with end value of type '%s'",
          itvarname, tostring(itvar.type), tostring(endval.type))
      end
      if incrval and incrval.type then
        ast:assertraisef(itvar.type:is_conversible(incrval.type),
          "`for` variable '%s' of type '%s' is not conversible with increment value of type '%s'",
          itvarname, tostring(itvar.type), tostring(incrval.type))
      end
    else
      itsymbol:add_possible_type(beginval.type)
      itsymbol:add_possible_type(endval.type)
    end
    itsymbol:link_ast_type(itvar)
    context:traverse(block)
    context.scope:resolve_symbols_types()
  end)
end

function visitors.VarDecl(context, ast)
  local varscope, mutability, vars, vals = ast:args()
  ast:assertraisef(mutability == 'var', 'variable mutability not supported yet')
  for _,var,val in iters.izip(vars, vals or {}) do
    local symbol = context:traverse(var)
    assert(symbol.type == var.type, 'impossible')
    if val then
      context:traverse(val)
      symbol:add_possible_type(val.type)
      if var.type and val.type and var.type ~= types.boolean then
        ast:assertraisef(var.type:is_conversible(val.type),
          "variable '%s' of type '%s' is not conversible with value of type '%s'",
          symbol.name, tostring(var.type), tostring(val.type))
      end
    end
  end
end

function visitors.Assign(context, ast)
  local vars, vals = ast:args()
  for _,var,val in iters.izip(vars, vals) do
    local varsymbol = context:traverse(var)
    if val then
      context:traverse(val)
      if varsymbol then
        varsymbol:add_possible_type(val.type)
      end
      if var.type and val.type then
        ast:assertraisef(var.type:is_conversible(val.type),
          "variable assignment of type '%s' is not conversible with value of type '%s'",
          tostring(var.type), tostring(val.type))
      end
    end
  end
end

function visitors.Return(context, ast)
  context:default_visitor(ast)
  local rets = ast:args()
  local funcscope = context.scope:get_parent_of_kind('function')
  assert(funcscope, 'impossible')
  for i,ret in ipairs(rets) do
    funcscope:add_return_type(i, ret.type)
  end
end

function visitors.FuncDef(context, ast)
  local varscope, varnode, argnodes, retnodes, blocknode = ast:args()
  local symbol = context:traverse(varnode)

  -- try to resolver function return types
  local funcscope = repeat_scope_until_resolution(context, 'function', function()
    context:default_visitor(argnodes)
    context:default_visitor(retnodes)
    context:traverse(blocknode)
  end)

  local argtypes = tabler.imap(argnodes, function(n) return n.type end)
  local returntypes = funcscope:resolve_return_types()

  -- populate function return types
  for i,retnode in ipairs(retnodes) do
    local rtype = returntypes[i]
    if rtype then
      ast:assertraisef(retnode.holding_type:is_conversible(rtype),
        "return variable at index %d of type '%s' is not conversible with value of type '%s'",
        i, tostring(retnode.holding_type), tostring(rtype))
    else
      returntypes[i] = retnode.holding_type
    end
  end

  -- populate return type nodes
  for i,rtype in pairs(returntypes) do
    local retnode = retnodes[i]
    if not retnode then
      retnode = context.aster:create('Type', tostring(rtype))
      retnode.type = types.type
      retnode.holding_type = rtype
      retnodes[i] = retnode
    end
  end

  -- build function type
  local type = typedefs.dynamic_types.Function(ast, argtypes, returntypes)

  if symbol then
    if varscope == 'local' then
      -- new function declaration
      symbol.type = type
    else
      -- check if previous symbol declaration is compatible
      if symbol.type then
        ast:assertraisef(symbol.type:is_conversible(type),
          "in function defition, symbol of type '%s' is not conversible with function type '%s'",
          tostring(symbol.type), tostring(type))
      else
        symbol:add_possible_type(type)
      end
    end
    symbol:link_ast_type(ast)
  else
    ast.type = type
  end
end

function visitors.UnaryOp(context, ast)
  local opname, arg = ast:args()
  if opname == 'not' then
    ast.type = types.boolean
    context:traverse(arg)
  else
    context:traverse(arg)
    local type
    if arg.type then
      type = arg.type:get_unary_operator_type(opname)
      ast:assertraisef(type,
        "unary operation `%s` is not defined for type '%s' of the expression",
        opname, tostring(arg.type))
    end
    if type then
      ast.type = type
    end
  end
end

function visitors.BinaryOp(context, ast)
  local opname, left_arg, right_arg = ast:args()
  local skip = false

  if typedefs.binary_equality_ops[opname] then
    ast.type = types.boolean
    skip = true
  elseif typedefs.binary_conditional_ops[opname] then
    local parent_ast = context:get_parent_ast_if(function(a) return a.tag ~= 'Paren' end)
    if parent_ast.type == types.boolean then
      ast.type = types.boolean
      skip = true
    end
  end

  context:traverse(left_arg)
  context:traverse(right_arg)

  if skip then return end

  if typedefs.binary_conditional_ops[opname] then
    local type
    if left_arg.type == right_arg.type then
      type = left_arg.type
    else
      type = typer.find_common_type_between(typedefs.number_types, left_arg.type, right_arg.type)
    end
    if type then
      ast.type = type
    end
  else
    local type, ltype, rtype
    if left_arg.type then
      ltype = left_arg.type:get_binary_operator_type(opname)
      ast:assertraisef(ltype,
        "binary operation `%s` is not defined for type '%s' of the left expression",
        opname, tostring(left_arg.type))
    end
    if right_arg.type then
      rtype = right_arg.type:get_binary_operator_type(opname)
      ast:assertraisef(rtype,
        "binary operation `%s` is not defined for type '%s' of the right expression",
        opname, tostring(right_arg.type))
    end
    if ltype and rtype then
      if ltype == rtype then
        type = ltype
      else
        type = typer.find_common_type_between(typedefs.number_types, ltype, rtype)
      end
      ast:assertraisef(type,
        "binary operation `%s` is not defined for different types '%s' and '%s' in the expression",
        opname, tostring(ltype), tostring(rtype))
    else
      type = ltype or rtype
    end
    if type then
      ast.type = type
    end
  end
end

local analyzer = {}
function analyzer.analyze(ast, aster)
  local context = TraverseContext(visitors, true)
  context.aster = aster
  repeat_scope_until_resolution(context, 'function', function()
    context:traverse(ast)
  end)
  return ast
end

return analyzer
