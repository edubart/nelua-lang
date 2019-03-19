local class = require 'pl.class'
local re = require 'relabel'

local Coder = class()

function Coder:_init(context, indent, depth)
  self.codes = {}
  self.depth = depth or -1
  self.indent = indent or '  '
  self.context = context
end

function Coder:inc_indent()
  self.depth = self.depth + 1
end

function Coder:dec_indent()
  self.depth = self.depth - 1
end

function Coder:add_indent(what, ...)
  self:add(string.rep(self.indent, math.max(self.depth, 0)), what, ...)
end

function Coder:add_indent_ln(what, ...)
  self:add_indent()
  self:add_ln(what, ...)
end

function Coder:add_ln(what, ...)
  self:add(what, ...)
  self:add('\n')
end

function Coder:add(what, ...)
  if what then
    local typewhat = type(what)
    assert(typewhat == 'string' or typewhat == 'table', 'cannot add non string or table value')
    if typewhat == 'string' then
      table.insert(self.codes, what)
    elseif typewhat == 'table' and what.is_astnode then
      self:add_traversal(what)
    elseif typewhat == 'table' and #what > 0 then
      self:add_traversal_list(what)
    end
  end
  if select('#', ...) > 0 then
    self:add(...)
  end
end

function Coder:add_traversal(ast)
  local context = self.context
  context:traverse(ast, self, context.scope)
end

function Coder:add_traversal_list(ast_list, separator)
  separator = separator or ', '
  for i,ast in ipairs(ast_list) do
    if i > 1 then self:add(separator) end
    self:add_traversal(ast)
  end
end

local quotes_defs = {
  to_special_character = function(s)
    return '\\' .. string.byte(s)
  end
}
local quote_patt_begin =  "\
quote <- {~ (quotechar / .)* ~} \
quotechar <- \
  '\\' -> '\\\\' /  -- backslash \
  '\a' -> '\\a' /   -- audible bell \
  '\b' -> '\\b' /   -- backspace \
  '\f' -> '\\f' /   -- form feed \
  %nl  -> '\\n' /  -- line feed \
  '\r' -> '\\r' /   -- carriege return \
  '\t' -> '\\t' /   -- horizontal tab \
  '\v' -> '\\v' /   -- vertical tab \
"
local quote_patt_end = "\
  -- ('??' {[=/'%(%)!<>%-]}) -> '?\\?%1' / -- C trigraphs \
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

function Coder:add_single_quoted(str)
  local quoted = single_quoter:match(str)
  self:add("'", quoted, "'")
end

function Coder:add_double_quoted(str)
  local quoted = double_quoter:match(str)
  self:add('"', quoted, '"')
end

function Coder:generate()
  return table.concat(self.codes)
end

return Coder