local class = require 'euluna.utils.class'
local metamagic = require 'euluna.utils.metamagic'
local traits = require 'euluna.utils.traits'
local sstream = class()

function sstream:_init(...)
  self:add(...)
end

function sstream:add(...)
  local n = select('#', ...)
  for i=1,n do
    local v = select(i, ...)
    if not traits.is_table(v) or metamagic.hasmetamethod(v, '__tostring') then
      table.insert(self, tostring(v))
    else
      self:addlist(v)
    end
  end
end

function sstream:addln(...)
  self:add(...)
  self:add('\n')
end

function sstream:addlist(list, sep)
  sep = sep or self.sep or ', '
  for i,v in ipairs(list) do
    if i > 1 then
      table.insert(self, sep)
    end
    self:add(v)
  end
end

function sstream:tostring()
  return table.concat(self)
end

sstream.__tostring = sstream.tostring

return sstream
