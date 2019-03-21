local Traverser = require 'euluna.traverser'

local analyzer = Traverser()

local NUM_LITERALS = {
  _integer    = 'integer',
  _number     = 'number',
  _b          = 'byte',     _byte       = 'byte',
  _c          = 'char',     _char       = 'char',
  _i          = 'int',      _int        = 'int',
  _i8         = 'int8',     _int8       = 'int8',
  _i16        = 'int16',    _int16      = 'int16',
  _i32        = 'int32',    _int32      = 'int32',
  _i64        = 'int64',    _int64      = 'int64',
  _u          = 'uint',     _uint       = 'uint',
  _u8         = 'uint',     _uint8      = 'uint',
  _u16        = 'uint',     _uint16     = 'uint',
  _u32        = 'uint',     _uint32     = 'uint',
  _u64        = 'uint',     _uint64     = 'uint',
  _f32        = 'float32',  _float32    = 'float32',
  _f64        = 'float64',  _float64    = 'float64',
  _pointer    = 'pointer',
}

analyzer:register('Number', function(_, ast)
  local numtype, _, literal = ast:args()
  local type
  if literal then
    type = NUM_LITERALS[literal]
    ast:assertf(type, 'literal "%s" is not defined', literal)
  else
    if numtype == 'int' then
      type = 'int'
    elseif numtype == 'dec' then
      type = 'number'
    elseif numtype == 'exp' then
      type = 'number'
    elseif numtype == 'hex' then
      type = 'uint'
    elseif numtype == 'bin' then
      type = 'uint'
    end
  end
  ast.type = type
end)

analyzer:register('String', function(_, ast)
  ast.type = 'string'
end)

analyzer:register('Boolean', function(_, ast)
  ast.type = 'boolean'
end)

analyzer:register('Id', function(_, ast, scope)
  local name = ast:args()
  if scope.vars[name] then
    ast.type = scope.vars[name]
  end
end)

analyzer:register('Type', function(_, ast)
  ast.type = ast:args()
end)

analyzer:register('TypedId', function(context, ast, scope)
  local name, typenode = ast:args()
  local type = '?'
  if typenode then
    context:traverse(typenode, scope)
    type = typenode.type
    ast.type = type
  end
  scope.vars[name] = type
end)

analyzer:register('VarDecl', function(context, ast, scope)
  local varscope, mutability, vars, vals = ast:args()
  ast:assertf(mutability == 'var', 'variable mutability not supported yet')
  for i=1,#vars do
    local var, val = vars[i], vals and vals[i]
    local varname = var[1]
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
end)

analyzer:enable_default_visitor()

function analyzer:analyze(ast)
  local context = self:newContext()
  context:traverse(ast, context.scope)
  return true
end

return analyzer