local iters = require 'euluna.utils.iterators'
local typedefs = require 'euluna.analyzers.types.definitions'
local TraverseContext = require 'euluna.traversecontext'
local Variable = require 'euluna.variable'

local visitors = {}

function visitors.Number(_, ast)
  local numtype, value, literal = ast:args()
  local type
  if literal then
    type = typedefs.number_literal_types[literal]
    ast:assertraisef(type, 'literal "%s" is not defined', literal)
  else
    type = typedefs.number_default_types[numtype]
    ast:assertf(type, 'invalid number type "%s" for AST Number', numtype)
  end
  ast.type = type
end

function visitors.String(_, ast)
  ast.type = typedefs.primitive_types.string
end

function visitors.Boolean(_, ast)
  ast.type = typedefs.primitive_types.boolean
end

function visitors.Id(_, ast, scope)
  local name = ast:arg(1)
  local symbol = scope.symbols[name]
  if symbol then
    ast.type = symbol.type
  end
end

function visitors.Type(_, ast)
  local tyname = ast:arg(1)
  local type = typedefs.primitive_types[tyname]
  ast:assertf(type, 'invalid type "%s"', tyname)
  ast.holding_type = type
  ast.type = type.type
end

function visitors.TypedId(context, ast, scope)
  local name, typenode = ast:args()
  local type = nil
  if typenode then
    context:traverse(typenode, scope)
    ast.type = typenode.holding_type
  end
  scope.symbols[name] = Variable(name, type)
end

function visitors.ForNum(context, ast, scope)
  local itvar, beginval, comp, endval, incrval, block = ast:args()
  local itvarname = itvar[1]
  context:traverse(itvar, scope)
  context:traverse(beginval, scope)
  context:traverse(endval, scope)
  if not itvar.type and beginval.type then
    itvar.type = beginval.type
  elseif itvar.type and beginval.type then
    ast:assertraisef(itvar.type:is_conversible(beginval.type),
      "in `for` variable '%s': variable of type '%s' is not conversible with begin value of type '%s'",
      itvarname, tostring(itvar.type), tostring(beginval.type))
    ast:assertraisef(itvar.type:is_conversible(endval.type),
      "in `for` variable '%s': variable of type '%s' is not conversible with end value of type '%s'",
      itvarname, tostring(itvar.type), tostring(endval.type))
  end
  context:traverse(block, scope)
end

function visitors.VarDecl(context, ast, scope)
  local varscope, mutability, vars, vals = ast:args()
  ast:assertraisef(mutability == 'var', 'variable mutability not supported yet')
  for _,var,val in iters.izip(vars, vals or {}) do
    local varname = var:arg(1)
    context:traverse(var, scope)
    if val then
      context:traverse(val, scope)
      if not var.type and val.type then
        var.type = val.type
      elseif var.type and val.type then
        ast:assertraisef(var.type:is_conversible(val.type),
          "in variable declaration '%s': variable of type '%s' is not conversible with value of type '%s'",
          varname, tostring(var.type), tostring(val.type))
      end
    end
    scope.symbols[varname] = Variable(varname, var.type)
  end
end

local analyzer = {}
function analyzer.analyze(ast)
  local context = TraverseContext(visitors, true)
  context:traverse(ast, context.scope)
  return ast
end

return analyzer
