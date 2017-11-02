local class = require 'pl.class'
local tablex = require 'pl.tablex'
local util = require 'euluna-compiler/util'
local builtin_generator = require 'euluna-compiler/cpp_builtin_generator'
local builtin_functions = require 'euluna-compiler/cpp_builtin_functions'
local Scope = class()
local Context = class()

-- Scope
function Scope:_init(parent)
  if parent:is_a(Scope) then
    self.parent = parent
    self.level = parent.level + 1
    self.context = parent.context
  else
    assert(parent:is_a(Context))
    self.context = parent
    self.level = 0
  end
end

function Scope:add_indent_ln(code)
  self:add_indent()
  self:add_ln(code)
end

function Scope:add_indent(code)
  if self.level > 0 then
    table.insert(self.context.code, string.rep(' ', self.level * 4))
  end
  if code and #code > 0 then
    table.insert(self.context.code, code)
  end
end

function Scope:add_ln(code)
  if code and #code > 0 then
    table.insert(self.context.code, code)
  end
  table.insert(self.context.code, '\n')
end

function Scope:add(code)
  table.insert(self.context.code, code)
end

function Scope:add_include(name)
  local includes = self.context.includes
  if not tablex.find(includes, name) then
    table.insert(includes, name)
  end
end

function Scope:add_bulitin_code(name)
  local builtin_scope = self.context.builtin_scope
  local builtins = builtin_scope.context.builtins
  if not builtins[name] then
    builtin_generator[name](builtin_scope)
    builtins[name] = true
  end
end

-- Context
function Context:_init(args)
  self.args = args
  self.includes = {}
  self.code = {}
end

function Context:generate_code()
  if #self.code == 0 then return '' end

  local include_code =
    tablex.imap(function(v) return '#include ' .. v .. '\n' end, self.includes)

  local allcode = {}
  table.insert(allcode, table.concat(include_code))
  table.insert(allcode, '\n')

  if self.namespace then
    table.insert(allcode, string.format('namespace %s {\n\n', self.namespace))
  end
  table.insert(allcode, table.concat(self.code))
  if self.namespace then
    table.insert(allcode, '\n}\n')
  end

  return table.concat(allcode)
end

-- BuiltinContext
local BuiltinContext = class(Context)
function BuiltinContext:_init(args)
  self:super(args)
  self.builtins = {}
  self.namespace = 'euluna'
end

-- Generator
local cpp_ops = {
  ['or'] = '||',
  ['and'] = '&&',
  ['ne'] = '!=',
  ['eq'] = '==',
  ['le'] = '<=',
  ['ge'] = '>=',
  ['lt'] = '<',
  ['gt'] = '>',
  ['bor'] = '|',
  ['bxor'] = '^',
  ['band'] = '&',
  ['shl'] = '<<',
  ['shr'] = '>>',
  --['concat'] = '+',
  ['add'] = '+',
  ['sub'] = '-',
  ['mul'] = '*',
  ['div'] = '/', -- TODO: should we promote integer division to floats?
  ['idiv'] = '/',
  ['mod'] = '%',
  ['not'] = '!',
  ['neg'] = '-',
  ['bnot'] = '~',
  -- TODO: what about these?
  -- pow
  -- len
}

local function translate_op(opname)
  local op = cpp_ops[opname]
  if not op then
    error('unknown binary op ' .. opname)
  end
  return op
end

function Scope:traverse_number(num)
  if num.literal then
    local l = num.literal
    if l == 'u64' or l == 'uint64' then
      self:add_include('<cstdint>')
      self:add('uint64_t(') self:add(num.value) self:add(')')
    elseif l == 'u32' or l == 'uint32' then
      self:add_include('<cstdint>')
      self:add('uint32_t(') self:add(num.value) self:add(')')
    elseif l == 'u16' or l == 'uint16' then
      self:add_include('<cstdint>')
      self:add('uint16_t(') self:add(num.value) self:add(')')
    elseif l == 'u8' or l == 'uint8' then
      self:add_include('<cstdint>')
      self:add('uint8_t(') self:add(num.value) self:add(')')
    elseif l == 'i64' or l == 'int64' then
      self:add_include('<cstdint>')
      self:add('int64_t(') self:add(num.value) self:add(')')
    elseif l == 'i32' or l == 'int32' then
      self:add_include('<cstdint>')
      self:add('int32_t(') self:add(num.value) self:add(')')
    elseif l == 'i16' or l == 'int16' then
      self:add_include('<cstdint>')
      self:add('int16_t(') self:add(num.value) self:add(')')
    elseif l == 'i8' or l == 'int8' then
      self:add_include('<cstdint>')
      self:add('int8_t(') self:add(num.value) self:add(')')
    elseif l == 'f32' or l == 'f' or l == 'float32' or l == 'float' then
      if num.type == 'decimal' then
        self:add(num.value) self:add('f')
      else
        self:add('float(') self:add(num.value) self:add(')')
      end
    elseif l == 'f64' or l == 'd' or l == 'float64' or l == 'double' then
      if num.type == 'decimal' then
        self:add(num.value)
      else
        self:add('double(') self:add(num.value) self:add(')')
      end
    elseif l == 'c' or l == 'char' then
      self:add('char(') self:add(num.value) self:add(')')
    elseif l == 'i' or l == 'int' then
      self:add(num.value)
    elseif l == 'u' or l == 'uint' then
      self:add(num.value) self:add('u')
    else
      error('unknown number literal ' .. l)
    end
  else
    self:add(num.value)
  end
end

local re = require 'relabel'
local quoter = re.compile(" \
  quote <- {~ (quotechar / .)* ~} \
  quotechar <- \
    '\\' -> '\\\\' /  -- backslash \
    '\a' -> '\\a' /   -- audible bell \
    '\b' -> '\\b' /   -- backspace \
    '\f' -> '\\f' /   -- form feed \
    [%nl] -> '\\n' /  -- line feed \
    '\r' -> '\\r' /   -- carriege return \
    '\t' -> '\\t' /   -- horizontal tab \
    '\v' -> '\\v' /   -- vertical tab \
    \"\'\" -> \"\\'\" /  -- single quote \
    '\"' -> '\\\"' /  -- double quote \
    ('??' {[=/'%(%)!<>%-]}) -> '?\\?%1' / -- C trigraphs \
    [^%g%s] -> to_special_character -- other special characters \
", {
  to_special_character = function(s)
    return '\\x' .. string.format('%.2x', string.byte(s))
  end
})

local function quote_string(str)
  --TODO: automatically break long strings
  return quoter:match(str)
end

function Scope:traverse_string(stat)
  self:add_include('<string>')
  self:add('std::string("')
  self:add(quote_string(stat.value))
  self:add('")')
end

function Scope:traverse_binaryop(expr, parenthesis)
  if parenthesis then
    self:add('(')
  end
  local op = expr.op
  if op == 'concat' then
    local convert_lhs = expr.lhs.tag ~= 'string' and expr.lhs.literal == nil
    local convert_rhs = expr.rhs.tag ~= 'string' and expr.lhs.literal == nil
    if convert_lhs then
      self:add_bulitin_code('to_string')
      self:add('euluna::to_string(')
    end
    self:traverse_expr(expr.lhs, true)
    if convert_lhs then
      self:add(')')
    end
    self:add(' + ')
    if convert_rhs then
      self:add_bulitin_code('to_string')
      self:add('euluna::to_string(')
    end
    self:traverse_expr(expr.rhs, true)
    if convert_rhs then
      self:add(')')
    end
  else
    self:traverse_expr(expr.lhs, true)
    self:add(' ')
    self:add(translate_op(expr.op))
    self:add(' ')
    self:traverse_expr(expr.rhs, true)
  end
  if parenthesis then
    self:add(')')
  end
end

function Scope:traverse_expr(expr, parenthesis)
  local tag = expr.tag
  if tag == 'nil' then
    self:add('nullptr')
  elseif tag == 'number' then
    self:traverse_number(expr)
  elseif tag == 'UnaryOp' then
    self:add(' ')
    self:add(translate_op(expr.op))
    self:traverse_expr(expr.expr, true)
  elseif tag == 'BinaryOp' then
    self:traverse_binaryop(expr, parenthesis)
  elseif tag == 'identifier' then
    self:add(expr.name)
  elseif tag == 'string' then
    self:traverse_string(expr)
  elseif tag == 'boolean' then
    self:add('"')
    self:add(tostring(expr.value))
    self:add('"')
  else
    error('unknown expression ' .. tag)
  end
end

function Scope:traverse_exprlist(exprlist)
  if exprlist.tag == 'exprlist' then
    for _,expr in ipairs(exprlist) do
      self:traverse_expr(expr)
    end
  else
    self:traverse_expr(exprlist)
  end
end

function Scope:traverse_if(statement)
  for i,ifstat in ipairs(statement.ifs) do
    if i==1 then
      self:add_indent('if(')
    else
      self:add_indent('} else if(')
    end

    self:traverse_expr(ifstat.cond)
    self:add_ln(') {')

    local scope = Scope(self)
    scope:traverse_block(ifstat.block)
  end

  if statement.elseblock then
    self:add_indent_ln('} else {')
    local scope = Scope(self)
    scope:traverse_block(statement.elseblock)
  end

  self:add_indent_ln('}')
end

function Scope:traverse_fornum(statement)
  local name = statement.id.name
  self:add_indent(string.format('for(auto %s = ', name))
  self:traverse_expr(statement.begin_expr)
  self:add(string.format(', __end_%s = ', name))
  self:traverse_expr(statement.end_expr)
  local op = translate_op(statement.cmp_op)
  self:add(string.format('; %s %s __end_%s; %s += ', name, op, name, name))
  if add_expr then
    self:traverse_expr(statement.add_expr)
  else
    self:add('1')
  end
  self:add_ln(') {')

  local scope = Scope(self)
  scope:traverse_block(statement.block)
  self:add_indent_ln('}')
end

function Scope:traverse_return(statement)
  if statement.expr then
    self:add_indent('return ')
    self:traverse_exprlist(statement.expr)
    self:add_ln(';')
  else
    if self.main then
      -- main always return an int
      self:add_indent_ln('return 0;')
    else
      self:add_indent_ln('return;')
    end
  end
end

function Scope:traverse_assign_def(statement)
  assert(#statement.vars == #statement.assigns)
  for i=1,#statement.vars do
    local varid = statement.vars[i]
    local vardef = statement.assigns[i]
    self:add_indent('auto ')
    self:add(varid)
    self:add(' = ')
    self:traverse_expr(vardef)
    self:add_ln(';')
  end
end

function Scope:traverse_assign(statement)
  assert(#statement.vars == #statement.assigns)
  for i=1,#statement.vars do
    local varexpr = statement.vars[i]
    local vardef = statement.assigns[i]
    self:add_indent()
    self:traverse_expr(varexpr)
    self:add(' = ')
    self:traverse_expr(vardef)
    self:add_ln(';')
  end
end

function Scope:traverse_call(statement)
  self:add_indent()

  local what = statement.what

  -- try builit functions first
  if what.tag == 'identifier' then
    local func = builtin_functions[what.name]
    if func then
      func(self, statement.args)
      return
    end
  end

  -- proceed as a normal function
  self:traverse_expr(what)
  self:add('(')
  for _,arg in pairs(statement.args) do
    self:traverse_expr(arg)
  end
  self:add_ln(');')
end

function Scope:traverse_block(block)
  for _,statement in ipairs(block) do
    local tag = statement.tag
    if tag == 'If' then
      self:traverse_if(statement)
    elseif tag == 'ForNum' then
      self:traverse_fornum(statement)
    elseif tag == 'Return' then
      self:traverse_return(statement)
    elseif tag == 'AssignDef' then
      self:traverse_assign_def(statement)
    elseif tag == 'Assign' then
      self:traverse_assign(statement)
    elseif tag == 'Call' then
      self:traverse_call(statement)
    else
      error('unknown statement "' .. tag .. '"')
    end
  end
end

function Scope:traverse_main_block(block)
  local scope = Scope(self)
  scope.main = true
  self:add_indent_ln('int main() {')
  scope:traverse_block(block)

  -- default return
  local last_statement = block[#block]
  if not last_statement or last_statement.tag ~= 'Return' then
    scope:add_indent_ln('return 0;')
  end

  self:add_indent_ln('}')
end

local cpp_generator = {}

function cpp_generator.generate(ast, args)
  assert(type(ast) == "table")
  local context = Context(args)
  local main_scope = Scope(context)

  local builtin_context = BuiltinContext(args)
  local builtin_scope = Scope(builtin_context)
  context.builtin_scope = builtin_scope

  main_scope:traverse_main_block(ast)

  local code = builtin_context:generate_code() .. context:generate_code()

  return code
end

return cpp_generator
