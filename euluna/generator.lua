local class = require 'pl.class'
local re = require 'relabel'
local Traverser = require 'euluna.traverser'
local GeneratorContext = class(Traverser.Context)

function GeneratorContext:_init(traverser)
  self.codes = {}
  self.depth = -1
  self:super(traverser)
end

function GeneratorContext:inc_indent()
  self.depth = self.depth + 1
end

function GeneratorContext:dec_indent()
  self.depth = self.depth - 1
end

function GeneratorContext:add_indent(what, ...)
  self:add(string.rep(self.traverser.indent, math.max(self.depth, 0)), what, ...)
end

function GeneratorContext:add_indent_ln(what, ...)
  self:add_indent()
  self:add_ln(what, ...)
end

function GeneratorContext:add_ln(what, ...)
  self:add(what, ...)
  self:add('\n')
end

function GeneratorContext:add(what, ...)
  if not what then return end
  local typewhat = type(what)
  assert(typewhat == 'string' or typewhat == 'table', 'cannot add this value')
  if typewhat == 'string' then
    table.insert(self.codes, what)
  elseif typewhat == 'table' and what.is_astnode then
    self:add_traversal(what)
  elseif typewhat == 'table' and #what > 0 then
    self:add_traversal_list(what)
  end
  self:add(...)
end

function GeneratorContext:add_traversal(ast)
  self.traverser:traverse(ast, self, self.scope)
end

function GeneratorContext:add_traversal_list(ast_list, separator)
  separator = separator or ', '
  for i,ast in ipairs(ast_list) do
    if i > 1 then self:add(separator) end
    self:add_traversal(ast)
  end
end

local quotes_defs = {
  to_special_character = function(s)
    return '\\x' .. string.format('%.2x', string.byte(s))
  end
}
local quote_patt_begin =  "\
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
"
local quote_patt_end = "\
  ('??' {[=/'%(%)!<>%-]}) -> '?\\?%1' / -- C trigraphs \
  [^%g%s] -> to_special_character -- other special characters \
"
local single_quoter = re.compile(
  quote_patt_begin ..
  "\"\'\" -> \"\\'\" /  -- single quote \n" ..
  quote_patt_end, quotes_defs)
local double_quoter = re.compile(
  quote_patt_begin ..
  "'\"' -> '\\\"' /  -- double quote \"" ..
  quote_patt_end, quotes_defs)

function GeneratorContext:add_single_quoted(str)
  local quoted = single_quoter:match(str)
  self:add("'", quoted, "'")
end

function GeneratorContext:add_double_quoted(str)
  local quoted = double_quoter:match(str)
  self:add('"', quoted, '"')
end

function GeneratorContext:generate_code()
  return table.concat(self.codes)
end

local Generator = class(Traverser)

function Generator:_init()
  self.indent = '  '
  self:super()
end

function Generator:set_indent(indent)
  self.indent = indent
end

function Generator:generate(ast)
  local context = GeneratorContext(self)
  local builtin_context = GeneratorContext(self)

  context.builtin_context = builtin_context
  context:add_traversal(ast)

  local code = context:generate_code(ast)

  local builtin_code = builtin_context:generate_code()
  if builtin_code ~= '' then
    code = builtin_code .. code
  end

  return code
end

Generator.Context = GeneratorContext

return Generator
