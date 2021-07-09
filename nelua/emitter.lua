local class = require 'nelua.utils.class'
local errorer = require 'nelua.utils.errorer'

local Emitter = class()
local INDENT_SPACES = '  '

local indents_mt = {}
local indents = setmetatable({}, indents_mt)

-- Auto generate indent string on demand.
function indents_mt.__index(self, depth)
  local indent = string.rep(INDENT_SPACES, depth)
  self[depth] = indent
  return indent
end

function Emitter:_init(context, depth)
  depth = depth or 0
  self.codes = {}
  self.depth = depth
  self.indent = indents[depth]
  self.context = context
end

function Emitter:inc_indent()
  local depth = self.depth + 1
  self.depth = depth
  self.indent = indents[depth]
end

function Emitter:dec_indent()
  local depth = self.depth - 1
  self.depth = depth
  self.indent = indents[depth]
end

function Emitter:add_one(what)
  local ty = type(what)
  if ty == 'string' then
    if what ~= '' then
      local codes = self.codes
      codes[#codes+1] = what
    end
  elseif ty == 'table' then
    if what._astnode then
      self.context:traverse_node(what, self)
    elseif what._type then
      self:add_type(what)
    elseif what._symbol then
      self:add_one(self.context:declname(what))
    else
      self:add_traversal_list(what)
    end
  elseif ty == 'number' or ty == 'boolean' then
    local codes = self.codes
    codes[#codes+1] = tostring(what)
  else --luacov:disable
    errorer.errorf('emitter cannot add value of type "%s"', ty)
  end  --luacov:enable
end

function Emitter:add_text(text)
  local codes = self.codes
  codes[#codes+1] = text
end

function Emitter:add(...)
  for i=1,select('#', ...) do
    self:add_one((select(i, ...)))
  end
end

function Emitter:add_ln(...)
  if ... then
    self:add(...)
  end
  local codes = self.codes
  codes[#codes+1] = '\n'
end

function Emitter:add_indent(...)
  local codes = self.codes
  local indent = self.indent
  if indent ~= '' then
    codes[#codes+1] = indent
  end
  if ... then
    self:add(...)
  end
end

function Emitter:add_indent_ln(...)
  local codes = self.codes
  local indent = self.indent
  if indent ~= '' then
    codes[#codes+1] = indent
  end
  if ... then
    self:add(...)
  end
  codes[#codes+1] = '\n'
end

function Emitter:add_traversal(node)
  self.context:traverse_node(node, self)
end

function Emitter:add_traversal_list(nodelist, separator)
  if #nodelist == 0 then return end
  separator = separator or ', '
  local context = self.context
  local codes = self.codes
  for i=1,#nodelist do
    if i > 1 and #separator > 0 then codes[#codes+1] = separator end
    context:traverse_node(nodelist[i], self)
  end
end

function Emitter:add_builtin(name, ...)
  local codes = self.codes
  codes[#codes+1] = self.context:ensure_builtin(name, ...)
end

function Emitter:add_type(type)
  local codes = self.codes
  codes[#codes+1] = self.context:typename(type)
end

function Emitter:get_pos()
  return #self.codes
end

function Emitter:is_empty()
  return #self.codes == 0
end

function Emitter:remove_until_pos(pos)
  local table_remove = table.remove
  local codes = self.codes
  while #codes > pos do
    table_remove(codes)
  end
end

function Emitter:generate()
  return table.concat(self.codes)
end

return Emitter
