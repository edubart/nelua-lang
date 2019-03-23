local class = require 'euluna.utils.class'
local traits = require 'euluna.utils.traits'
local errorer = require 'euluna.utils.errorer'

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
  local depth = math.max(self.depth, 0)
  local indent = string.rep(self.indent, depth)
  self:add(indent, what, ...)
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
    if traits.is_string(what) then
      table.insert(self.codes, what)
    elseif traits.is_number(what) then
      table.insert(self.codes, tostring(what))
    elseif traits.is_astnode(what) then
      self:add_traversal(what)
    elseif traits.is_table(what) then
      self:add_traversal_list(what)
    else --luacov:disable
      errorer.errorf('coder cannot add value of type "%s"', type(what))
    end  --luacov:enable
  end
  local numargs = select('#', ...)
  if numargs > 0 then
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

function Coder:generate()
  return table.concat(self.codes)
end

return Coder
