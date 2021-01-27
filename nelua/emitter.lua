local class = require 'nelua.utils.class'
local errorer = require 'nelua.utils.errorer'
local bn = require 'nelua.utils.bn'

local Emitter = class()

function Emitter:_init(context, depth)
  self.codes = {}
  self.depth = depth or 0
  self.indent = '  '
  self.context = context
end

function Emitter:inc_indent(count)
  if not count then
    count = 1
  end
  self.depth = self.depth + count
end

function Emitter:dec_indent(count)
  if not count then
    count = 1
  end
  self.depth = self.depth - count
end

local string_rep = string.rep
function Emitter:add_indent(...)
  self:add(string_rep(self.indent, self.depth), ...)
end

function Emitter:add_indent_ln(...)
  self:add_ln(string_rep(self.indent, self.depth), ...)
end

function Emitter:add_ln(...)
  self:add(...)
  local codes = self.codes
  codes[#codes+1] = '\n'
end

function Emitter:get_pos()
  return #self.codes
end

function Emitter:is_empty()
  return #self.codes == 0
end

function Emitter:remove_until_pos(pos)
  while #self.codes > pos do
    table.remove(self.codes)
  end
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
    -- elseif what._bn then
    --   codes[#codes+1] = tostring(what)
    else
      self:add_traversal_list(what)
    end
  --elseif traits.is_function(what) then
    --what(self)
  else --luacov:disable
    errorer.errorf('emitter cannot add value of type "%s"', type(what))
  end  --luacov:enable
end

function Emitter:add(...)
  for i=1,select('#', ...) do
    local what = (select(i, ...))
    if what ~= nil then
      self:add_one(what)
    end
  end
end

function Emitter.add_type()
end

function Emitter:add_builtin(name, ...)
  name = self.context:ensure_runtime_builtin(name, ...)
  self:add_one(name)
end

function Emitter:add_traversal(node, ...)
  local context = self.context
  context:traverse_node(node, self, ...)
end

function Emitter:add_traversal_list(nodelist, separator, ...)
  separator = separator or ', '
  for i=1,#nodelist do
    if i > 1 then self:add(separator) end
    self:add_traversal(nodelist[i], ...)
  end
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
    if bn.isintegral(value) and not value.isneg(value) then
      self:add('0x', bn.tohex(value))
    else
      self:add(bn.todecsci(value))
    end
  end
end

function Emitter:generate()
  return table.concat(self.codes)
end

return Emitter
