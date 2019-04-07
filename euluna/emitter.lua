local class = require 'euluna.utils.class'
local traits = require 'euluna.utils.traits'
local errorer = require 'euluna.utils.errorer'

local Emitter = class()

function Emitter:_init(context, indent, depth)
  self.codes = {}
  self.depth = depth or -1
  self.indent = indent or '  '
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

function Emitter:add_traversal(node)
  local context = self.context
  context:traverse(node, self)
end

function Emitter:add_traversal_list(nodelist, separator)
  separator = separator or ', '
  for i,node in ipairs(nodelist) do
    if i > 1 then self:add(separator) end
    self:add_traversal(node)
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
    --FIXME: overflow for uint64
    if not frac and not exp then
      self:add('0x', int)
    else
      local n = tonumber(int, 16)
      if frac then
        local len = frac:gsub('^[+-]', ''):len()
        local f = tonumber(frac, 16) / math.pow(16, len)
        n = n + f
      end
      if exp then
        local factor = math.pow(2, tonumber(exp))
        n = n * factor
      end
      local nstr
      if n % 1 == 0 then
        nstr = string.format('0x%x', n)
      else
        nstr = string.format('%.15f', n):gsub('0+$', '')
      end
      self:add(nstr)
    end
  elseif base == 'bin' then
    int = string.format('%x', tonumber(int, 2))
    if frac then
      frac = string.format('%x', tonumber(frac, 2))
    end
    self:add_composed_number('hex', int, frac, exp)
  end
end

function Emitter:generate()
  return table.concat(self.codes)
end

return Emitter
