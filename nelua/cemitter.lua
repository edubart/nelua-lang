local class = require 'nelua.utils.class'
local Emitter = require 'nelua.emitter'
local traits = require 'nelua.utils.traits'
local typedefs = require 'nelua.typedefs'
local CEmitter = class(Emitter)
local primtypes = typedefs.primtypes

function CEmitter:_init(context, depth)
  Emitter._init(self, context, depth)
end

function CEmitter:add_one(what)
  if traits.is_type(what) then
    self:add_ctype(what)
  else
    Emitter.add_one(self, what)
  end
end

----------------------------------------
-- Return string functions
function CEmitter:zeroinit(type)
  local s
  if type:is_float32() and not self.context.ast.attr.nofloatsuffix then
    s = '0.0f'
  elseif type:is_float() then
    s = '0.0'
  elseif type:is_unsigned() then
    s = '0U'
  elseif type:is_numeric() then
    s = '0'
  elseif type:is_pointer() then
    s = 'NULL'
  elseif type:is_boolean() then
    s = 'false'
  else
    s = '{0}'
  end
  return s
end

-------------------------------------
-- add functions
function CEmitter:add_zeroinit(type)
  self:add(self:zeroinit(type))
end

function CEmitter:add_nodezerotype(node)
  local type = node.attr.type
  if not (type:is_boolean() or type:is_numeric() or type:is_pointer()) then
    self:add_nodectypecast(node)
  end
  self:add(self:zeroinit(type))
end

function CEmitter:add_castedzerotype(type)
  if not (type:is_boolean() or type:is_numeric() or type:is_pointer()) then
    self:add_ctypecast(type)
  end
  self:add(self:zeroinit(type))
end

function CEmitter:add_ctype(type)
  self:add(self.context:ctype(type))
end

function CEmitter:add_ctypecast(type)
  self:add('(')
  self:add_ctype(type)
  self:add(')')
end

function CEmitter:add_nodectypecast(node)
  if node.attr.initializer then
    -- skip casting inside initializers
    return
  end
  self:add('(')
  self:add_ctype(node.attr.type)
  self:add(')')
end

function CEmitter:add_booleanlit(value)
  self:add(value and 'true' or 'false')
end

function CEmitter:add_null()
  self:add('NULL')
end

function CEmitter:add_val2any(val, valtype)
  valtype = valtype or val.attr.type
  assert(not valtype:is_any())
  local runctype = self.context:runctype(valtype)
  local typename = self.context:typename(valtype)
  self:add('(', primtypes.any, ')', '{&', runctype, ', {._', typename, ' = ', val, '}}')
end

function CEmitter:add_val2boolean(val, valtype)
  valtype = valtype or val.attr.type
  assert(not valtype:is_boolean())
  if valtype:is_any() then
    self:add_builtin('nelua_any_to_', typedefs.primtypes.boolean)
    self:add('(', val, ')')
  elseif valtype:is_nil() or valtype:is_nilptr() then
    self:add('false')
  elseif valtype:is_pointer() then
    self:add(val, ' != NULL')
  else
    self:add('true')
  end
end

function CEmitter:add_any2type(type, anyval)
  self.context:ctype(primtypes.any) -- ensure any type
  self:add_builtin('nelua_any_to_', type)
  self:add('(', anyval, ')')
end

function CEmitter:add_string2cstring(val)
  self:add('(', val, ')->data')
end

function CEmitter:add_cstring2string(val)
  --TODO: free allocated strings using reference counting
  self:add_builtin('nelua_cstring2string')
  self:add('(', val, ')')
end

function CEmitter:add_val2type(type, val, valtype)
  if not valtype and traits.is_astnode(val) then
    valtype = val.attr.type
  end

  if val then
    assert(valtype)
    if type == valtype or
      (valtype:is_numeric() and type:is_numeric()) or
      (valtype:is_nilptr() and type:is_pointer()) then
      self:add(val)
    elseif type:is_any() then
      self:add_val2any(val, valtype)
    elseif type:is_boolean() then
      self:add_val2boolean(val, valtype)
    elseif valtype:is_any() then
      self:add_any2type(type, val)
    elseif type:is_cstring() and valtype:is_string() then
      self:add_string2cstring(val)
    elseif type:is_string() and valtype:is_cstring() then
      self:add_cstring2string(val)
    elseif type:is_pointer() and type.subtype == valtype then
      -- automatice reference
      assert(val and val.attr.autoref)
      self:add('&', val)
    elseif valtype:is_pointer() and valtype.subtype == type then
      -- automatic dereference
      self:add('*', val)
    else
      if valtype ~= type then
        self:add_ctypecast(type)
      end
      self:add(val)
    end
  else
    self:add_zeroinit(type)
  end
end

return CEmitter
