local Traverser = require 'euluna.traverser'
local Coder = require 'euluna.coder'
local class = require 'pl.class'

local BultinFunctions = {}
function BultinFunctions.print(context, coder)
  context:add_include("<stdio.h>")
  coder:add("puts")
end

--------------------------------------------------------------------------------
-- Generator Context
--------------------------------------------------------------------------------
local GeneratorContext = class(Traverser.Context)

function GeneratorContext:_init(traverser)
  self:super(traverser)
  self.includes = {}
end

function GeneratorContext:add_include(name)
  local includes = self.includes
  if includes[name] then return end
  includes[name] = true
  self.includes_coder:add_ln(string.format('#include %s', name))
end

function GeneratorContext:get_ctype(tyname)
  if tyname == 'integer' then
    self:add_include('<stdint.h>')
    return 'int64_t'
  end
end

--------------------------------------------------------------------------------
-- Generator
--------------------------------------------------------------------------------
local generator = Traverser()
generator.Context = GeneratorContext

generator:register('Number', function(_, ast, coder)
  local type, value, literal = ast:args()
  ast:assertf(literal == nil, 'literals are not supported in c')
  if type == 'int' or type == 'dec' then
    coder:add(value)
  --elseif type == 'exp' then
  --  coder:add(string.format('%se%s', value[1], value[2]))
  --elseif type == 'hex' then
  --  coder:add(string.format('0x%s', value))
  --elseif type == 'bin' then
  --  coder:add(string.format('%u', tonumber(value, 2)))
  end
end)

generator:register('String', function(_, ast, coder)
  local value, literal = ast:args()
  ast:assertf(literal == nil, 'literals are not supported in c')
  coder:add_double_quoted(value)
end)

generator:register('Boolean', function(context, ast, coder)
  local value = ast:args()
  context:add_include('<stdbool.h>')
  coder:add(tostring(value))
end)

-- identifier and types
generator:register('Id', function(_, ast, coder)
  local name = ast:args()
  coder:add(name)
end)
generator:register('Paren', function(_, ast, coder)
  local what = ast:args()
  coder:add('(', what, ')')
end)
generator:register('Type', function(context, ast, coder)
  local tyname = ast:args()
  local ctyname = context:get_ctype(tyname)
  coder:add(ctyname)
end)
generator:register('TypedId', function(_, ast, coder)
  local name, type = ast:args()
  if type then
    coder:add(type, ' ', name)
  else
    coder:add(name)
  end
end)

-- calls
generator:register('Call', function(context, ast, coder)
  local argtypes, args, caller, block_call = ast:args()
  if block_call then coder:add_indent() end
  if caller.tag == 'Id' then
    local fname = caller[1]
    local builtin = BultinFunctions[fname]
    if builtin then
      builtin(context, coder)
    else
      coder:add(caller)
    end
  else
    coder:add(caller)
  end
  coder:add('(', args, ')')
  if block_call then coder:add_ln(";") end
end)

generator:register('FuncArg', function(_, ast, coder)
  local name, mut, type = ast:args()
  ast:assertf(mut == nil or mut == 'var', "variable mutabilities are not supported yet")
  coder:add(type, ' ', name)
end)

-- block
generator:register('Block', function(context, ast, coder, scope)
  local stats = ast:args()
  local is_top_scope = scope:is_top()
  if is_top_scope then
    coder:inc_indent()
    coder:add_ln("int main() {")
  end
  coder:inc_indent()
  local inner_scope = context:push_scope()
  coder:add_traversal_list(stats, '')
  if inner_scope:is_main() and not inner_scope.has_return then
    -- main() must always return an integer
    coder:add_indent_ln("return 0;")
  end
  context:pop_scope()
  coder:dec_indent()
  if is_top_scope then
    coder:add_ln("}")
    coder:dec_indent()
  end
end)

-- statements
generator:register('Return', function(_, ast, coder, scope)
  scope.has_return = true
  local rets = ast:args()
  coder:add_indent("return")
  if #rets > 0 then
    coder:add_ln(' ', rets, ';')
  else
    if scope:is_main() then
      -- main() must always return an integer
      coder:add(' 0')
    end
    coder:add_ln(';')
  end
end)

generator:register('If', function(_, ast, coder)
  local ifparts, elseblock = ast:args()
  for i,ifpart in ipairs(ifparts) do
    local cond, block = ifpart[1], ifpart[2]
    if i == 1 then
      coder:add_indent("if(")
      coder:add(cond)
      coder:add_ln(") {")
    else
      coder:add_indent("} else if(")
      coder:add(cond)
      coder:add_ln(") {")
    end
    coder:add(block)
  end
  if elseblock then
    coder:add_indent_ln("} else {")
    coder:add(elseblock)
  end
  coder:add_indent_ln("}")
end)

generator:register('Do', function(_, ast, coder)
  local block = ast:args()
  coder:add_indent_ln("{")
  coder:add(block)
  coder:add_indent_ln("}")
end)

generator:register('While', function(_, ast, coder)
  local cond, block = ast:args()
  coder:add_indent_ln("while(", cond, ') {')
  coder:add(block)
  coder:add_indent_ln("}")
end)

generator:register('Repeat', function(_, ast, coder)
  local block, cond = ast:args()
  coder:add_indent_ln("do {")
  coder:add(block)
  coder:add_indent_ln('} while(!(', cond, '));')
end)

generator:register('ForNum', function(_, ast, coder)
  local itvar, beginval, comp, endval, incrval, block  = ast:args()
  ast:assertf(comp == 'le', 'for comparator not supported yet')
  local itname = itvar[1]
  coder:add_indent("for(", itvar, ' = ', beginval, '; ', itname, ' <= ', endval, '; ')
  if incrval then
    coder:add(itname, ' += ', incrval)
  else
    coder:add('++', itname)
  end
  coder:add_ln(') {')
  coder:add(block)
  coder:add_indent_ln("}")
end)

-- ForIn

generator:register('Break', function(_, _, coder)
  coder:add_indent_ln('break;')
end)

generator:register('Continue', function(_, _, coder)
  coder:add_indent_ln('continue;')
end)

generator:register('Label', function(_, ast, coder)
  local name = ast:args()
  coder:add_indent_ln(name, ':')
end)

generator:register('Goto', function(_, ast, coder)
  local labelname = ast:args()
  coder:add_indent_ln('goto ', labelname, ';')
end)

generator:register('VarDecl', function(_, ast, coder)
  local varscope, mutability, vars, vals = ast:args()
  ast:assertf(mutability == 'var', 'variable mutability not supported yet')
  ast:assertf(varscope == 'local', 'global variables not supported yet')
  for i=1,#vars do
    local var, val = vars[i], vals and vals[i]
    coder:add_indent(var)
    if val then
      coder:add(' = ', val)
    end
    coder:add_ln(';')
  end
end)

-- Assign

generator:register('FuncDef', function(context, ast)
  local varscope, name, args, rets, block = ast:args()
  ast:assertf(#rets <= 1, 'multiple returns not supported yet')
  ast:assertf(varscope == 'local', 'non local scope for functions not supported yet')
  local coder = context.declarations_coder
  if #rets == 0 then
    coder:add_indent('void ')
  else
    local ret = rets[1]
    ast:assertf(ret.tag == 'Type')
    coder:add_indent(ret, ' ')
  end
  coder:add_ln(name, '(', args, ') {')
  coder:add(block)
  coder:add_indent_ln('}')
end)

-- operators

function generator:generate(ast)
  local context = self:newContext()
  local indent = '    '

  context.includes_coder = Coder(context, indent, 0)
  context.declarations_coder = Coder(context, indent, 0)
  context.definitions_coder = Coder(context, indent, 0)
  context.main_coder = Coder(context, indent)

  context.main_coder:add_traversal(ast)

  local code = table.concat({
    context.includes_coder:generate(),
    context.declarations_coder:generate(),
    context.definitions_coder:generate(),
    context.main_coder:generate()
  })

  return code
end

generator.compiler = require('euluna.compilers.c_compiler')

return generator
