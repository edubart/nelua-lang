local class = require 'nelua.utils.class'
local traits = require 'nelua.utils.traits'
local errorer = require 'nelua.utils.errorer'

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

function Emitter:add_indent(what, ...)
  local depth = math.max(self.depth, 0)
  local indent = string.rep(self.indent, depth)
  self:add(indent, what, ...)
end

function Emitter:add_indent_ln(what, ...)
  self:add_indent()
  self:add_ln(what, ...)
end

function Emitter:add_ln(what, ...)
  self:add(what, ...)
  self:add('\n')
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
  if traits.is_string(what) then
    if #what > 0 then
      table.insert(self.codes, what)
    end
  elseif traits.is_number(what) or traits.is_bignumber(what) then
    table.insert(self.codes, tostring(what))
  elseif traits.is_astnode(what) then
    self:add_traversal(what)
  elseif traits.is_table(what) then
    self:add_traversal_list(what)
  --elseif traits.is_function(what) then
    --what(self)
  else --luacov:disable
    errorer.errorf('emitter cannot add value of type "%s"', type(what))
  end  --luacov:enable
end

function Emitter:add(what, ...)
  if what then
    self:add_one(what)
  end
  local numargs = select('#', ...)
  if numargs > 0 then
    self:add(...)
  end
end

function Emitter:add_builtin(name, ...)
  name = self.context:ensure_runtime_builtin(name, ...)
  self:add(name)
end

function Emitter:add_traversal(node, ...)
  local context = self.context
  context:traverse(node, self, ...)
end

function Emitter:add_traversal_list(nodelist, separator, ...)
  separator = separator or ', '
  for i,node in ipairs(nodelist) do
    if i > 1 then self:add(separator) end
    self:add_traversal(node, ...)
  end
end

function Emitter:add_composed_number(base, int, frac, exp, value)
  if base == 'dec' then
    self:add(int)
    if frac then
      self:add('.', frac)
    end
    if exp then
      self:add('e', exp)
    end
  elseif base == 'hex' or base == 'bin' then
    if value:isintegral() then
      self:add('0x', value:tohex())
    else
      self:add(value:todec())
    end
  end
end

function Emitter:generate()
  return table.concat(self.codes)
end

return Emitter
