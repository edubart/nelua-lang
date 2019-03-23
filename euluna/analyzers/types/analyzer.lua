local iters = require 'euluna.utils.iterators'
local typedefs = require 'euluna.analyzers.types.definitions'
local TraverseContext = require 'euluna.traversecontext'

local visitors = {}

function visitors.Number(_, ast)
  local numtype, value, literal = ast:args()
  local type
  if literal then
    type = typedefs.NUM_LITERALS[literal]
    ast:assertraisef(type, 'literal "%s" is not defined', literal)
  else
    type = typedefs.NUM_DEF_TYPES[numtype]
    ast:assertf(type, 'invalid number type "%s" for AST Number', numtype)
  end
  ast.type = type
end

function visitors.String(_, ast)
  ast.type = 'string'
end

function visitors.Boolean(_, ast)
  ast.type = 'boolean'
end

function visitors.Id(_, ast, scope)
  local name = ast:arg(1)
  if scope.vars[name] then
    ast.type = scope.vars[name]
  end
end

function visitors.Type(_, ast)
  ast.type = ast:arg(1)
end

function visitors.TypedId(context, ast, scope)
  local name, typenode = ast:args()
  local type = '?'
  if typenode then
    context:traverse(typenode, scope)
    type = typenode.type
    ast.type = type
  end
  scope.vars[name] = type
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
        --TODO: check if types are compatible
        var.type = val.type
      end
    end
    scope.vars[varname] = var.type or '?'
  end
end

local analyzer = {}
function analyzer.analyze(ast)
  local context = TraverseContext(visitors, true)
  context:traverse(ast, context.scope)
  return ast
end

return analyzer
