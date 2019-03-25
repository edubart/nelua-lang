local class = require 'euluna.utils.class'
local metamagic = require 'euluna.utils.metamagic'
local typer = require 'euluna.typer'
local tabler = require 'euluna.utils.tabler'

local Scope = class()

function Scope:_init(parent, kind)
  self.kind = kind
  self.parent = parent
  self.symbols = {}
  self.returns_types = {}
  if parent then
    metamagic.setmetaindex(self.symbols, parent.symbols)
  end
end

function Scope:fork(kind)
  return Scope(self, kind)
end

function Scope:is_top()
  return not self.parent
end

function Scope:is_main()
  return self.parent and not self.parent.parent
end

function Scope:get_parent_of_kind(kind)
  local parent = self
  repeat
    parent = parent.parent
  until (not parent or parent.kind == kind)
  return parent
end

function Scope:resolve_symbols_types()
  local count = 0
  for _,symbol in pairs(self.symbols) do
    if symbol:resolve_type() then
      count = count + 1
    end
  end
  return count
end

function Scope:add_return_type(index, type)
  local return_types = self.returns_types[index]
  if not return_types then
    return_types = {}
    self.returns_types[index] = return_types
  elseif tabler.find(return_types, type) then
    return
  end
  table.insert(return_types, type)
end

function Scope:resolve_returns_type()
  local resolved_types = {}
  for i,return_types in pairs(self.returns_types) do
    resolved_types[i] = typer.find_common_type(return_types)
  end
  return resolved_types
end

return Scope
