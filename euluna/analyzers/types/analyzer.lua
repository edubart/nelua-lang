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
    ast:assertraisef(type, 'literal suffix "%s" is not defined', literal)
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

function visitors.Id(context, ast)
  local name = ast:arg(1)
  local symbol = context.scope.symbols[name]
  if symbol then
    ast.type = symbol.type
  end
end

function visitors.Paren(context, ast)
  local what = ast:args()
  context:traverse(what)
  ast.type = what.type
end

function visitors.Type(_, ast)
  local tyname = ast:arg(1)
  local type = typedefs.primitive_types[tyname]
  ast:assertf(type, 'invalid type "%s"', tyname)
  ast.holding_type = type
  ast.type = type.type
end

function visitors.TypedId(context, ast)
  local name, typenode = ast:args()
  local type
  if typenode then
    context:traverse(typenode)
    type = typenode.holding_type
  end
  context.scope.symbols[name] = Variable(name, type)
  ast.type = type
end

function visitors.ForNum(context, ast)
  local itvar, beginval, comp, endval, incrval, block = ast:args()
  local itvarname = itvar[1]
  context:traverse(itvar)
  context:traverse(beginval)
  context:traverse(endval)
  if not itvar.type and beginval.type then
    itvar.type = beginval.type
  elseif itvar.type and beginval.type then
    ast:assertraisef(itvar.type:is_conversible(beginval.type),
      "`for` variable '%s' of type '%s' is not conversible with begin value of type '%s'",
      itvarname, tostring(itvar.type), tostring(beginval.type))
    ast:assertraisef(itvar.type:is_conversible(endval.type),
      "`for` variable '%s' of type '%s' is not conversible with end value of type '%s'",
      itvarname, tostring(itvar.type), tostring(endval.type))
  end
  context:traverse(block)
end

function visitors.VarDecl(context, ast)
  local varscope, mutability, vars, vals = ast:args()
  ast:assertraisef(mutability == 'var', 'variable mutability not supported yet')
  for _,var,val in iters.izip(vars, vals or {}) do
    local varname = var:arg(1)
    context:traverse(var)
    if val then
      context:traverse(val)
      if not var.type and val.type then
        var.type = val.type
      elseif var.type and val.type then
        ast:assertraisef(var.type:is_conversible(val.type),
          "variable '%s' of type '%s' is not conversible with value of type '%s'",
          varname, tostring(var.type), tostring(val.type))
      end
    end
    context.scope.symbols[varname] = Variable(varname, var.type)
  end
end

function visitors.UnaryOp(context, ast)
  local opname, arg = ast:args()
  context:traverse(arg)
  local type
  if opname == 'not' then
    type = typedefs.primitive_types.boolean
  else
    if arg.type then
      type = arg.type:get_unary_operator_type(opname)
      ast:assertraisef(type,
        "unary operation `%s` is not defined for type '%s' of the expression",
        opname, tostring(arg.type))
    end
  end
  ast.type = type
end

function visitors.BinaryOp(context, ast)
  local opname, left_arg, right_arg = ast:args()
  context:traverse(left_arg)
  context:traverse(right_arg)
  local ltype, rtype, type
  if typedefs.binary_comparable_ops[opname] then
    type = typedefs.primitive_types.boolean
  else
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
        type = ltype.get_common_type(typedefs.number_types, ltype, rtype)
      end
      ast:assertraisef(type,
        "binary operation `%s` is not defined for different types '%s' and '%s' in the expression",
        opname, tostring(ltype), tostring(rtype))
    else
      type = ltype or rtype
    end
  end
  ast.type = type
end

local analyzer = {}
function analyzer.analyze(ast)
  local context = TraverseContext(visitors, true)
  context:traverse(ast)
  return ast
end

return analyzer
