local class = require 'pl.class'
local re = require 'relabel'
local Coder = class()

function Coder:_init()
  self.codes = {}
  self.depth = -1
  self.ident = '  '
end

function Coder:inc_indent()
  self.depth = self.depth + 1
end

function Coder:dec_indent()
  self.depth = self.depth - 1
end

function Coder:add_indent(code, ...)
  self:add(string.rep(self.ident, math.max(self.depth, 0)), code, ...)
end

function Coder:add_indent_ln(code, ...)
  self:add_indent()
  self:add_ln(code, ...)
end

function Coder:add_ln(code, ...)
  self:add(code, ...)
  self:add('\n')
end

function Coder:add(code, ...)
  if not code then return end
  table.insert(self.codes, code)
  self:add(...)
end

function Coder:add_traversal_list(traversor, scope, list, separator)
  separator = separator or ', '
  for i,node in ipairs(list) do
    if i > 1 then self:add(separator) end
    traversor:traverse(node, self, scope)
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

function Coder:add_single_quoted(str)
  local quoted = single_quoter:match(str)
  self:add("'")
  self:add(quoted)
  self:add("'")
end

function Coder:add_double_quoted(str)
  local quoted = double_quoter:match(str)
  self:add('"')
  self:add(quoted)
  self:add('"')
end

function Coder:generate()
  return table.concat(self.codes)
end

return Coder