local class = require 'nelua.utils.class'
local tabler = require 'nelua.utils.tabler'

local Attr = class()

Attr._attr = true

function Attr:_init(attr)
  if attr then
    tabler.update(self, attr)
  end
end

function Attr:clone()
  return setmetatable(tabler.copy(self), getmetatable(self))
end

function Attr:merge(attr)
  for k,v in pairs(attr) do
    if self[k] == nil then
      self[k] = v
    elseif k ~= 'attr' then
      assert(self[k] == v, 'cannot combine different attributes')
    end
  end
  return self
end

function Attr:is_empty()
  return next(self) == nil
end

function Attr:is_static_vardecl()
  if self.vardecl and self.staticstorage and not self.comptime then
    if not self.type or self.type.size > 0 then
      return true
    end
  end
end

return Attr
