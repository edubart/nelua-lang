local class = require 'pl.class'
local tablex = require 'pl.tablex'
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

function Scope:add_code(code, skip_newline)
  self:add_indent()
  if code and #code > 0 then
    table.insert(self.context.code, code)
  end
  if not skip_newline then
    table.insert(self.context.code, '\n')
  end
end

function Scope:add_indent()
  if self.level > 0 then
    table.insert(self.context.code, string.rep(' ', self.level * 4))
  end
end

function Scope:add_newline()
  table.insert(self.context.code, '\n')
end

function Scope:inline_code(code)
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
  elseif opname == 'add' then
    return '+'
  elseif opname == 'sub' then
    return 'sub'
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

function Scope:traverse_expr(expr, first)
  local tag = expr.tag
  if tag == 'nil' then
    self:inline_code('nullptr')
  elseif tag == 'number' then
    self:inline_code(expr.value)
  elseif tag == 'unary_op' then
    self:inline_code(' ')
    self:inline_code(translate_unary_op(expr.op))
    self:traverse_expr(expr.expr)
  elseif tag == 'binary_op' then
    if not first then
      self:inline_code('(')
    end
    self:traverse_expr(expr.lhs)
    self:inline_code(' ')
    self:inline_code(translate_binary_op(expr.op), true)
    self:inline_code(' ')
    self:traverse_expr(expr.rhs)
    if not first then
      self:inline_code(')')
    end
  elseif tag == 'identifier' then
    self:inline_code(expr.name)
  elseif tag == 'string' then
    self:inline_code('"')
    self:inline_code(expr.value)
    self:inline_code('"')
  else
    error('uknown expression ' .. tag)
  end
end

function Scope:traverse_exprlist(exprlist)
  if exprlist.tag == 'exprlist' then
    for _,expr in ipairs(exprlist) do
      self:traverse_expr(expr, true)
    end
  else
    self:traverse_expr(exprlist, true)
  end
end

function Scope:traverse_return(statement)
  if statement.expr then
    self:add_code('return ', true)
    self:traverse_exprlist(statement.expr)
    self:inline_code(';')
    self:add_newline()
  else
    if self.main then
      -- main always return an int
      self:add_code('return 0;')
    else
      self:add_code('return;')
    end
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
  self:inline_code('(')
  for _,arg in pairs(statement.args) do
    self:traverse_expr(arg)
  end
  self:inline_code(');')
  self:add_newline()
end

function Scope:traverse_block(block)
  for _,statement in ipairs(block) do
    local tag = statement.tag
    if tag == 'Return' then
      self:traverse_return(statement)
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
  self:add_code('int main() {')
  scope:traverse_block(block)

  -- default return
  local last_statement = block[#block]
  if not last_statement or last_statement.tag ~= 'Return' then
    scope:add_code('return 0;')
  end

  self:add_code('}')
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
