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

function Attr:is_static_vardecl()
  if self.vardecl and self.staticstorage and not self.comptime then
    if not self.type or self.type.size > 0 then
      return true
    end
  end
end

function Attr:is_maybe_negative()
  local type = self.type
  if type and type.is_arithmetic then
    if type.is_unsigned then
      return false
    end
    if self.comptime and self.value >= 0 then
      return false
    end
  end
  return true
end

return Attr
