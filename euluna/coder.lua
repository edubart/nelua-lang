local class = require 'pl.class'
local Coder = class()

function Coder:_init()
  self.codes = {}
  self.depth = 0
  self.ident = '  '
end

function Coder:inc_indent()
  self.depth = self.depth + 1
end

function Coder:dec_indent()
  self.depth = self.depth - 1
end

function Coder:add_indent(code)
  if self.depth > 0 then
    table.insert(self.codes, string.rep(self.ident, self.depth))
  end
  if code and #code > 0 then
    table.insert(self.codes, code)
  end
end

function Coder:add_indent_ln(code)
  self:add_indent()
  self:add_ln(code)
end

function Coder:add_ln(code)
  if code and #code > 0 then
    table.insert(self.codes, code)
  end
  table.insert(self.codes, '\n')
end

function Coder:add(code)
  table.insert(self.codes, code)
end

function Coder:generate()
  return table.concat(self.codes)
end

return Coder