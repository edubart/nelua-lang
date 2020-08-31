-- Attr
--
-- The Attr class and in short 'attr' is used by the compiler to store many
-- attributes associated to a symbol or a AST node during compilation.
-- Usually the AST nodes are liked to an attr, multiple nodes can be linked
-- to the same attr, this happens for example with variable identifiers.
-- The compiler can promote an attr to a symbol in case it have a named
-- identifier or in case it needs to perform type resolution.

local class = require 'nelua.utils.class'
local tabler = require 'nelua.utils.tabler'

local Attr = class()

-- Used to check if this table is an attr.
Attr._attr = true

-- Initialize an attr from a table of fields.
function Attr:_init(attr)
  if attr then
    tabler.update(self, attr)
  end
end

-- Clone the attr, shallow copying all fields.
function Attr:clone()
  -- getmetatable should be used here because this attr could be a promoted symbol
  -- so we should copy its underlying metatable
  return setmetatable(tabler.copy(self), getmetatable(self) or Attr)
end

-- Merge fields from another attr into this attr.
-- Mostly used when linking new nodes to the same attr.
function Attr:merge(attr)
  for k,v in pairs(attr) do
    if self[k] == nil then -- no collision
      self[k] = v
    else
      -- when the field is already set
      -- the merge is not permitted to overwrite to a new value otherwise
      -- cause bugs on what already have been processed by the compiler
      assert(self[k] == v, 'cannot combine different attrs')
    end
  end
  return self
end

-- Check if this attr is stored in the program static storage.
-- Used for example by the GC to know if a variable should be scanned.
function Attr:is_on_static_storage()
  if self.vardecl and
     self.staticstorage and
     not self.comptime and
     (not self.type or self.type.size > 0)
     then
    return true
  end
  return false
end

-- Check if this attr could be holding a negative arithmetic value.
-- Used by the C generator to optimize operations on non negatives values.
function Attr:is_maybe_negative()
  local type = self.type
  if type and type.is_arithmetic then -- must be an arithmetic to proper check this
    if type.is_unsigned then -- unsigned is never negative
      return false
    end
    if self.comptime and self.value >= 0 then -- comptime positive is never negative
      return false
    end
  end
  -- could be negative if the type is unknown yet, or some union, any..
  return true
end

return Attr
