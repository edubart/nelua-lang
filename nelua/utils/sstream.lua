local class = require 'nelua.utils.class'
local metamagic = require 'nelua.utils.metamagic'
local traits = require 'nelua.utils.traits'
local sstream = class()

function sstream:_init(...)
  self:add(...)
end

function sstream:add(...)
  for i=1,select('#', ...) do
    local v = select(i, ...)
    if not traits.is_table(v) or metamagic.hasmetamethod(v, '__tostring') then
      table.insert(self, tostring(v))
    else
      self:addlist(v)
    end
  end
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
