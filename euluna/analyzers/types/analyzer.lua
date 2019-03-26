local iters = require 'euluna.utils.iterators'
local tabler = require 'euluna.utils.tabler'
local typedefs = require 'euluna.analyzers.types.definitions'
local TraverseContext = require 'euluna.traversecontext'
local Variable = require 'euluna.variable'
local typer = require 'euluna.typer'

local types = typedefs.primitive_types
local visitors = {}

function visitors.Number(_, ast)
  local numtype, value, literal = ast:args()
  local type
  if literal then
    type = typedefs.number_literal_types[literal]
    ast:assertraisef(type, 'literal suffix "%s" is not defined', literal)
  else
    type = typedefs.number_default_types[numtype]
    ast:assertf(type, 'invalid number type "%s" for AST Number', numtype)
  end
  ast.type = type
end

function visitors.String(_, ast)
  ast.type = types.string
end

function visitors.Boolean(_, ast)
  ast.type = types.boolean
end

function visitors.Id(context, ast)
  local name = ast:arg(1)
  local symbol = context.scope.symbols[name]
  if not symbol then
    symbol = Variable(name, ast)
    context.scope.symbols[name] = symbol
  elseif symbol.type then
    ast.type = symbol.type
  end
  if not ast.type then
    symbol:add_ast_reference(ast)
  end
  return symbol
end

function visitors.Paren(context, ast)
  local what = ast:args()
  context:traverse(what)
  ast.type = what.type
end

function visitors.Type(_, ast)
  if not ast.type then
    local tyname = ast:arg(1)
    local type = types[tyname]
    ast:assertf(type, 'invalid type "%s"', tyname)
    ast.holding_type = type
    ast.type = type.type
  end
end

local function visit_id_decl(context, ast, name, typenode)
  local type = ast.type
  if typenode then
    context:traverse(typenode)
    type = typenode.holding_type
  end
  local symbol = Variable(name, ast, type)
  context.scope.symbols[name] = symbol
  if type then
    ast.type = type
  else
    symbol:add_ast_reference(ast)
  end
  return symbol
end

function visitors.Call(context, ast)
  context:default_visitor(ast)
  local _, args, caller = ast:args()
  --TODO: check types on other nodes too
  if caller.tag == 'Id' then
    local funcname = caller:arg(1)
    local symbol = context.scope.symbols[funcname]
    if symbol and symbol.type then
      --TODO: check multiple returns
      caller:assertraisef(symbol.type.name == 'function',
        "attempt to call a non callable variable of type '%s'", symbol.type.name)
      ast.type = symbol.type.return_types[1]
    end
  end
end

function visitors.IdDecl(context, ast)
  local name, typenode = ast:args()
  return visit_id_decl(context, ast, name, typenode)
end

function visitors.FuncArg(context, ast)
  local name, mut, typenode = ast:args()
  return visit_id_decl(context, ast, name, typenode)
end

local function repeat_scope_until_resolution(context, scope_kind, after_push, before_pop)
  local resolutions_count = 0
  repeat
    local last_resolutions_count = resolutions_count
    context:push_scope(scope_kind)
    after_push()
    resolutions_count = context.scope:resolve_symbols_types()
    if before_pop then
      before_pop()
    end
    context:pop_scope()
  until resolutions_count == last_resolutions_count
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
    local itsymbol = Variable(itvarname, itvar, itvar.type)
    context.scope.symbols[itvarname] = itsymbol
    if not itvar.type then
      itsymbol:add_ast_reference(itvar)
    end
    if not itvar.type and beginval.type then
      itsymbol:add_possible_type(beginval.type)
    end
    if not itvar.type and endval.type then
      itsymbol:add_possible_type(endval.type)
    end
    if itvar.type and beginval.type then
      ast:assertraisef(itvar.type:is_conversible(beginval.type),
        "`for` variable '%s' of type '%s' is not conversible with begin value of type '%s'",
        itvarname, tostring(itvar.type), tostring(beginval.type))
    end
    if itvar.type and endval.type then
      ast:assertraisef(itvar.type:is_conversible(endval.type),
        "`for` variable '%s' of type '%s' is not conversible with end value of type '%s'",
        itvarname, tostring(itvar.type), tostring(endval.type))
    end
    --TODO: check incrval type compability with itvar
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
      if not var.type and val.type then
        symbol:add_possible_type(val.type)
      elseif var.type and val.type and var.type ~= types.boolean then
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
    if varsymbol then
      if varsymbol.type then
        var.type = varsymbol.type
      else
        varsymbol:add_ast_reference(var)
      end
    end
    if val then
      context:traverse(val)
      if not var.type and val.type then
        if varsymbol then
          varsymbol:add_possible_type(val.type)
        end
      elseif var.type and val.type then
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
  local func_scope = context.scope:get_parent_of_kind('function')
  assert(func_scope, 'impossible')
  for i,ret in ipairs(rets) do
    func_scope:add_return_type(i, ret.type)
  end
end

function visitors.FuncDef(context, ast)
  repeat_scope_until_resolution(context, 'function', function()
    context:default_visitor(ast)
  end, function()
    local varscope, varnode, argnodes, retnodes, blocknode = ast:args()
    local returntypes = context.scope:resolve_return_types()
    local argtypes = tabler.imap(argnodes, function(n) return {id=n:arg(1), type=n.type} end)
    local type = typedefs.dynamic_types.Function(ast, argtypes, returntypes)
    ast.type = type

    if varnode.tag == 'Id' then
      local name = varnode:arg(1)
      local symbol = Variable(name, ast, type)
      context.scope.parent.symbols[name] = symbol
    --TODO: check definition on other nodes
    end

    -- check return types
    for i,rtype in pairs(returntypes) do
      local retnode = retnodes[i]
      if not retnode then
        retnode = context.aster:create('Type', tostring(rtype))
        retnode.type = types.type
        retnode.holding_type = rtype
        retnodes[i] = retnode
      else
        ast:assertraisef(retnode.holding_type:is_conversible(rtype),
          "return variable at index %d of type '%s' is not conversible with value of type '%s'",
          i, tostring(retnode.holding_type), tostring(rtype))
      end
    end
  end)
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
