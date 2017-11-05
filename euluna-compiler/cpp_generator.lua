local class = require 'pl.class'
local tablex = require 'pl.tablex'
local util = require 'euluna-compiler/util'
local builtin_generator = require 'euluna-compiler/cpp_builtin_generator'
local builtin_functions = require 'euluna-compiler/cpp_builtin_functions'
local Scope = class()
local Context = class()
local fmt = string.format

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
    table.insert(allcode, fmt('namespace %s {\n\n', self.namespace))
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
  ['add'] = '+',
  ['sub'] = '-',
  ['mul'] = '*',
  ['div'] = '/',
  ['mod'] = '%',
  ['not'] = '!',
  ['neg'] = '-',
  ['bnot'] = '~',
  -- manually implemented: concat, pow, len
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
    return '\\x' .. fmt('%.2x', string.byte(s))
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

function Scope:traverse_len(expr)
  self:add_include('<iterator>')
  self:add('std::size(')
  self:traverse_expr(expr, true)
  self:add(')')
end

function Scope:traverse_tostring(expr)
  local convert = expr.tag ~= 'string' and expr.literal == nil
  if convert then
    self:add_bulitin_code('to_string')
    self:add('euluna::to_string(')
  end
  self:traverse_expr(expr, not convert)
  if convert then
    self:add(')')
  end
end

function Scope:traverse_unaryop(expr)
  local op = expr[1]
  local opexpr = expr[2]
  if op == 'len' then
    self:traverse_len(opexpr)
  elseif op == 'tostring' then
    self:traverse_tostring(opexpr)
  else
    self:add(translate_op(op))

    local parenthesis = false
    -- convert double negation from `--i` to `-(-i)`
    if op == 'neg' and opexpr and opexpr[1] == 'neg' then
      parenthesis = true
    end

    if parenthesis then self:add('(') end
    self:traverse_expr(opexpr, true)
    if parenthesis then self:add(')') end
  end
end

function Scope:traverse_concat(lhs, rhs)
  self:traverse_tostring(lhs)
  self:add(' + ')
  self:traverse_tostring(rhs)
end

function Scope:traverse_pow(lhs, rhs)
  self:add_include('<cmath>')
  self:add('std::pow(')
  self:traverse_expr(lhs)
  self:add(', ')
  self:traverse_expr(rhs)
  self:add(')')
end

function Scope:traverse_binaryop(expr)
  local op = expr[1]
  local lhs = expr[2]
  local rhs = expr[3]
  if op == 'concat' then
    self:traverse_concat(lhs, rhs)
  elseif op == 'pow' then
    self:traverse_pow(lhs, rhs)
  else
    self:traverse_expr(lhs, true)
    self:add(' ')
    self:add(translate_op(op))
    self:add(' ')
    self:traverse_expr(rhs, true)
  end
end

function Scope:traverse_ternaryif(lhs, mid, rhs)
  self:traverse_expr(mid)
  self:add(' ? ')
  self:traverse_expr(lhs)
  self:add(' : ')
  self:traverse_expr(rhs)
end

function Scope:traverse_ternaryop(expr)
  local op = expr[1]
  local lhs = expr[2]
  local mid = expr[3]
  local rhs = expr[4]
  if op == 'if' then
    self:traverse_ternaryif(lhs, mid, rhs)
  else
    error('unknown ternary operation ' .. op)
  end
end

function Scope:traverse_id(expr)
  local name = expr[1]
  self:add(name)
end

function Scope:traverse_boolean(expr)
  self:add(tostring(expr.value))
end

function Scope:traverse_expr(expr, parenthesis)
  local tag = expr.tag
  if tag == 'Nil' then
    self:add('nullptr')
  elseif tag == 'number' then
    self:traverse_number(expr)
  elseif tag == 'UnaryOp' then
    self:traverse_unaryop(expr)
  elseif tag == 'BinaryOp' then
    if parenthesis then self:add('(') end
    self:traverse_binaryop(expr)
    if parenthesis then self:add(')') end
  elseif tag == 'TernaryOp' then
    if parenthesis then self:add('(') end
    self:traverse_ternaryop(expr)
    if parenthesis then self:add(')') end
  elseif tag == 'Id' then
    self:traverse_id(expr)
  elseif tag == 'string' then
    self:traverse_string(expr)
  elseif tag == 'boolean' then
    self:traverse_boolean(expr)
  elseif tag == 'Call' then
    self:traverse_inline_call(expr)
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
  local ifs = statement[1]
  local elseblock = statement[2]

  for i,ifstat in ipairs(ifs) do
    local cond = ifstat[1]
    local block = ifstat[2]

    if i==1 then
      self:add_indent('if(')
    else
      self:add_indent('} else if(')
    end

    self:traverse_expr(cond)
    self:add_ln(') {')

    self:traverse_scoped_block(block)
  end

  if elseblock then
    self:add_indent_ln('} else {')
    self:traverse_scoped_block(elseblock)
  end

  self:add_indent_ln('}')
end

function Scope:traverse_switch(statement)
  local what = statement[1]
  local cases = statement[2]
  local elseblock = statement[3]

  self:add_indent('switch(')
  self:traverse_expr(what)
  self:add_ln(') {')

  for i,casestat in ipairs(cases) do
    local cond = casestat[1]
    local block = casestat[2]
    self:add_indent('case ')
    self:traverse_expr(cond)
    self:add_ln(': {')
    local scope = self:traverse_scoped_block(block)
    scope:add_indent_ln('break;')
    self:add_indent_ln('}')
  end

  if elseblock then
    self:add_indent_ln('default: {')
    local scope = self:traverse_scoped_block(elseblock)
    scope:add_indent_ln('break;')
    self:add_indent_ln('}')
  end

  self:add_indent_ln('}')
end


function Scope:traverse_try(statement)
  local tryblock = statement[1]
  local catches = statement[2]
  local catchall_block = statement[3]
  local finally_block = statement[4]

  local tryscope = self
  if finally_block then
    self:add_indent_ln('{')
    tryscope = Scope(self)
    tryscope:traverse_defer(finally_block)
  end

  tryscope:add_indent_ln('try {')

  tryscope:traverse_scoped_block(tryblock)

  if #catches > 0 then
    -- TODO
  end

  if catchall_block then
    tryscope:add_indent_ln('} catch(...) {')
    tryscope:traverse_scoped_block(catchall_block)
  end

  tryscope:add_indent_ln('}')

  if finally_block then
    self:add_indent_ln('}')
  end
end

function Scope:traverse_throw(statement)
  local expr = statement[1]
  self:add_indent('throw ')
  self:traverse_expr(expr)
  self:add_ln(';')
end

function Scope:traverse_do(statement)
  self:add_indent_ln('{')
  self:traverse_scoped_block(statement)
  self:add_indent_ln('}')
end

function Scope:traverse_while(statement)
  local cond_expr = statement[1]
  local block = statement[2]
  self:add_indent('while(')
  self:traverse_expr(cond_expr)
  self:add_ln(') {')
  self:traverse_scoped_block(block)
  self:add_indent_ln('}')
end

function Scope:traverse_repeat(statement)
  local block = statement[1]
  local cond_expr = statement[2]
  self:add_indent_ln('do {')
  self:traverse_scoped_block(block)
  self:add_indent('} while (!(')
  self:traverse_expr(cond_expr)
  self:add_ln('));')
end

function Scope:traverse_fornum(statement)
  local name = statement[1]
  local begin_expr = statement[2]
  local cmp_op = statement[3]
  local end_expr = statement[4]
  local step_expr = statement[5]
  local block = statement[6]

  local complex_step_expr = step_expr ~= nil and step_expr.tag ~= 'number'
  local complex_end_expr = end_expr.tag ~= 'number'
  self:add_indent(fmt('for(auto %s = ', name))
  self:traverse_expr(begin_expr)
  if complex_end_expr then
    self:add(fmt(', __end_%s = ', name))
    self:traverse_expr(end_expr)
  end
  if complex_step_expr then
    self:add(fmt(', __step_%s = ', name))
    self:traverse_expr(step_expr)
  end

  local op = translate_op(cmp_op)
  self:add(fmt('; %s %s ', name, op))

  if complex_end_expr then
    self:add(fmt('__end_%s', name))
  else
    self:traverse_expr(end_expr)
  end
  self:add(fmt('; %s', name))
  if complex_step_expr then
    self:add(fmt(' += __step_%s', name))
  else
    if step_expr then
      self:add(' += ')
      self:traverse_expr(step_expr)
    else
      self:add('++')
    end
  end
  self:add_ln(') {')

  self:traverse_scoped_block(block)
  self:add_indent_ln('}')
end


function Scope:traverse_break(statement)
  self:add_indent_ln('break;')
end

function Scope:traverse_continue(statement)
  self:add_indent_ln('continue;')
end

function Scope:traverse_label(statement)
  local label = statement[1]
  self:add_ln(fmt('%s:', label))
end

function Scope:traverse_goto(statement)
  local label = statement[1]
  self:add_indent_ln(fmt('goto %s;', label))
end

function Scope:traverse_defer(statement)
  self:add_bulitin_code('make_deferrer')
  self:add_indent_ln(fmt('auto __defer_%d = euluna::make_deferrer([&]() {', statement.pos))
  self:traverse_scoped_block(statement)
  self:add_indent_ln('});')
end

function Scope:traverse_return(statement)
  local expr = statement[1]
  if expr then
    self:add_indent('return ')
    self:traverse_exprlist(expr)
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

function Scope:traverse_lambda_function_def(statement)
  local scope = statement[1]
  local name = statement[2]
  local args = statement[3]
  local body = statement[4]
  self:add_indent('auto ')
  self:add(name)
  self:add(' = [&](')
  for i,arg in ipairs(args) do
    if i > 1 then
      self:add(', ')
    end
    self:add('auto ')
    self:add(arg)
  end
  self:add_ln(') {')
  self:traverse_scoped_block(body)
  self:add_indent_ln('};')
end

function Scope:traverse_vardecl(statement)
  local vartype = statement[1]
  local vars = statement[2]
  local assigns = statement[3]
  if assigns then
    assert(#vars == #assigns)
  end
  -- TODO: deduced declarations
  for varid, vardef in izip(vars, assigns) do
    self:add_indent('auto ')
    self:add(varid)
    self:add(' = ')
    self:traverse_expr(vardef)
    self:add_ln(';')
  end
end

function Scope:traverse_assign(statement)
  local vars = statement[1]
  local assigns = statement[2]
  assert(#vars == #assigns)
  for varexpr, vardef in izip(vars, assigns) do
    self:add_indent()
    self:traverse_expr(varexpr)
    self:add(' = ')
    self:traverse_expr(vardef)
    self:add_ln(';')
  end
end

function Scope:traverse_inline_call(statement)
  local what = statement[1]
  local args = statement[2]

  -- try builit functions first
  if what.tag == 'Id' then
    local name = what[1]
    local func = builtin_functions[name]
    if func then
      func(self, args)
      return
    end
  end

  -- proceed as a normal function
  self:traverse_expr(what)
  self:add('(')
  local numargs = #args
  for i,arg in pairs(args) do
    self:traverse_expr(arg)
    if i < numargs then
      self:add(', ')
    end
  end
  self:add(')')
end

function Scope:traverse_call(statement)
  self:add_indent()
  self:traverse_inline_call(statement)
  self:add_ln(';')
end

function Scope:traverse_block(block)
  for _,statement in ipairs(block) do
    local tag = statement.tag
    if tag == 'If' then
      self:traverse_if(statement)
    elseif tag == 'Switch' then
      self:traverse_switch(statement)
    elseif tag == 'Try' then
      self:traverse_try(statement)
    elseif tag == 'Throw' then
      self:traverse_throw(statement)
    elseif tag == 'Do' then
      self:traverse_do(statement)
    elseif tag == 'While' then
      self:traverse_while(statement)
    elseif tag == 'Repeat' then
      self:traverse_repeat(statement)
    elseif tag == 'ForNum' then
      self:traverse_fornum(statement)
    elseif tag== 'Break' then
      self:traverse_break(statement)
    elseif tag== 'Continue' then
      self:traverse_continue(statement)
    elseif tag== 'Defer' then
      self:traverse_defer(statement)
    elseif tag== 'Label' then
      self:traverse_label(statement)
    elseif tag== 'Goto' then
      self:traverse_goto(statement)
    elseif tag == 'VarDecl' then
      self:traverse_vardecl(statement)
    elseif tag == 'FunctionDef' then
      self:traverse_lambda_function_def(statement)
    elseif tag == 'Call' then
      self:traverse_call(statement)
    elseif tag == 'Assign' then
      self:traverse_assign(statement)
    elseif tag == 'Return' then
      self:traverse_return(statement)
    else
      error('unknown statement "' .. tag .. '"')
    end
  end
end

function Scope:traverse_scoped_block(block)
  local scope = Scope(self)
  scope:traverse_block(block)
  return scope
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
