local class = require 'nelua.utils.class'
local errorer = require 'nelua.utils.errorer'
local bn = require 'nelua.utils.bn'

local Emitter = class()
local INDENT_SPACES = '  '

function Emitter:_init(context, depth)
  depth = depth or 0
  self.codes = {}
  self.depth = depth
  self.indent = string.rep(INDENT_SPACES, depth)
  self.context = context
end

function Emitter:inc_indent(count)
  self.depth = self.depth + (count or 1)
  self.indent = string.rep(INDENT_SPACES, self.depth)
end

function Emitter:dec_indent(count)
  self.depth = self.depth - (count or 1)
  self.indent = string.rep(INDENT_SPACES, self.depth)
end

function Emitter:add_one(what)
  local ty = type(what)
  if ty == 'string' then
    if what ~= '' then
      local codes = self.codes
      codes[#codes+1] = what
    end
  elseif ty == 'number' or ty == 'boolean' then
    local codes = self.codes
    codes[#codes+1] = tostring(what)
  elseif ty == 'table' then
    if what._type then
      self:add_type(what)
    elseif what._astnode then
      self:add_traversal(what)
    else
      self:add_traversal_list(what)
    end
  else --luacov:disable
    errorer.errorf('emitter cannot add value of type "%s"', ty)
  end  --luacov:enable
end

function Emitter:add(...)
  for i=1,select('#', ...) do
    self:add_one((select(i, ...)))
  end
end

function Emitter:add_ln(...)
  local codes = self.codes
  self:add(...)
  codes[#codes+1] = '\n'
end

function Emitter:add_indent(...)
  local codes = self.codes
  codes[#codes+1] = self.indent
  self:add(...)
end

function Emitter:add_indent_ln(...)
  local codes = self.codes
  codes[#codes+1] = self.indent
  self:add(...)
  codes[#codes+1] = '\n'
end

function Emitter:add_traversal(node)
  self.context:traverse_node(node, self)
end

function Emitter:add_traversal_list(nodelist, separator)
  separator = separator or ', '
  for i=1,#nodelist do
    if i > 1 then self:add_one(separator) end
    self:add_traversal(nodelist[i])
  end
end

function Emitter:add_builtin(name, ...)
  self:add_one(self.context:ensure_builtin(name, ...))
end

function Emitter.add_type()
end

function Emitter:add_composed_number(base, int, frac, exp, value)
  if base == 'dec' then
    self:add_one(int)
    if frac then
      self:add('.', frac)
    end
    if exp then
      self:add('e', exp)
    end
  elseif base == 'hex' or base == 'bin' then
    if bn.isintegral(value) and not bn.isneg(value) then
      self:add('0x', bn.tohex(value))
    else
      self:add_one(bn.todecsci(value))
    end
  end
end

function Emitter:get_pos()
  return #self.codes
end

function Emitter:is_empty()
  return #self.codes == 0
end

local table_remove = table.remove
function Emitter:remove_until_pos(pos)
  local codes = self.codes
  while #codes > pos do
    table_remove(codes)
  end
end

function Emitter:generate()
  return table.concat(self.codes)
end

return Emitter
