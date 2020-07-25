local class = require 'nelua.utils.class'
local metamagic = require 'nelua.utils.metamagic'
local sstream = class()

function sstream:_init(...)
  self:add(...)
end

function sstream:add(...)
  for i=1,select('#', ...) do
    local v = select(i, ...)
    if type(v) ~= 'table' or metamagic.hasmetamethod(v, '__tostring') then
      self[#self+1] = tostring(v)
    else
      self:addlist(v)
    end
  end
end

function sstream:addlist(list, sep)
  sep = sep or self.sep or ', '
  for i=1,#list do
    if i > 1 then
      self[#self+1] = sep
    end
    self:add(list[i])
  end
end

function sstream:tostring()
  return table.concat(self)
end

sstream.__tostring = sstream.tostring

return sstream
