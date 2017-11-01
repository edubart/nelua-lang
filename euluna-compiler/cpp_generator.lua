local class = require 'pl.class'
local tablex = require 'pl.tablex'
local util = require 'euluna-compiler/util'
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

-- Context
function Context:_init(args)
  self.args = args
  self.includes = {}
  self.code = {}
end

function Context:generate_code()
  local include_code =
    tablex.imap(function(v) return '#include ' .. v .. '\n' end, self.includes)

  local heading = table.concat(include_code)
  local code = table.concat(self.code)
  return heading .. '\n' .. code
end

-- Generator
local function translate_binary_op(opname)
  if opname == 'or' then
    return '||'
  elseif opname == 'and' then
    return '&&'
  elseif opname == 'eq' then
    return '=='
  elseif opname == 'add' then
    return '+'
  elseif opname == 'sub' then
    return '-'
  elseif opname == 'mul' then
    return '*'
  elseif opname == 'div' then
    return '/'
  else
    error('unknown binary op ' .. opname)
  end
end

local function translate_unary_op(opname)
  if opname == 'neg' then
    return '-'
  else
    error('unknown unary op ' .. opname)
  end
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

function Scope:traverse_expr(expr, parenthesis)
  local tag = expr.tag
  if tag == 'nil' then
    self:add('nullptr')
  elseif tag == 'number' then
    self:traverse_number(expr)
  elseif tag == 'UnaryOp' then
    self:add(' ')
    self:add(translate_unary_op(expr.op))
    self:traverse_expr(expr.expr, true)
  elseif tag == 'BinaryOp' then
    if parenthesis then
      self:add('(')
    end
    self:traverse_expr(expr.lhs, true)
    self:add(' ')
    self:add(translate_binary_op(expr.op), true)
    self:add(' ')
    self:traverse_expr(expr.rhs, true)
    if parenthesis then
      self:add(')')
    end
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
  main_scope:traverse_main_block(ast)
  local code = context:generate_code()
  return code
end

return cpp_generator
