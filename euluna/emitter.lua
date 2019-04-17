local class = require 'euluna.utils.class'
local traits = require 'euluna.utils.traits'
local errorer = require 'euluna.utils.errorer'
local bn = require 'euluna.utils.bn'

local Emitter = class()

function Emitter:_init(context, depth)
  self.codes = {}
  self.depth = depth or 0
  self.indent = '  '
  self.context = context
end

function Emitter:inc_indent()
  self.depth = self.depth + 1
end

function Emitter:dec_indent()
  self.depth = self.depth - 1
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

function Emitter:add(what, ...)
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
      errorer.errorf('emitter cannot add value of type "%s"', type(what))
    end  --luacov:enable
  end
  local numargs = select('#', ...)
  if numargs > 0 then
    self:add(...)
  end
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

function Emitter:add_composed_number(base, int, frac, exp)
  if base == 'dec' then
    self:add(int)
    if frac then
      self:add('.', frac)
    end
    if exp then
      self:add('e', exp)
    end
  elseif base == 'hex' then
    if not frac and not exp then
      self:add('0x', int)
    else
      local n = bn.fromhex(int)
      if frac then
        local len = frac:gsub('^[+-]', ''):len()
        n = n + (bn.fromhex(frac) / bn.pow(16, len))
      end
      if exp then
        n = n * bn.pow(2, tonumber(exp))
      end
      local nstr
      if n:trunc() == n then
        nstr = string.format('0x%s', n:tohex())
      else
        nstr = n:todec()
      end
      self:add(nstr)
    end
  elseif base == 'bin' then
    int = bn.frombin(int):tohex()
    if frac then
      frac = bn.frombin(frac):tohex()
    end
    self:add_composed_number('hex', int, frac, exp)
  end
end

function Emitter:generate()
  return table.concat(self.codes)
end

return Emitter
