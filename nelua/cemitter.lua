local class = require 'nelua.utils.class'
local Emitter = require 'nelua.emitter'
local traits = require 'nelua.utils.traits'
local typedefs = require 'nelua.typedefs'
local errorer = require 'nelua.utils.errorer'
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
  elseif type:is_arithmetic() then
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
  if not (type:is_boolean() or type:is_arithmetic() or type:is_pointer()) then
    self:add_nodectypecast(node)
  end
  self:add(self:zeroinit(type))
end

function CEmitter:add_castedzerotype(type)
  if not (type:is_boolean() or type:is_arithmetic() or type:is_pointer()) then
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
  assert(type(value) == 'boolean')
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
      (valtype:is_arithmetic() and type:is_arithmetic()) or
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
      -- automatic reference
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

function CEmitter:add_numeric_literal(val, valtype, base)
  assert(traits.is_bignumber(val))

  local minusone = false
  if valtype:is_integral() and valtype:is_signed() and val == valtype.min then
    -- workaround C warning `integer constant is so large that it is unsigned`
    minusone = true
    val = val:add(1)
  end

  if valtype:is_float() then
    local valstr = val:todecsci(valtype.maxdigits)
    self:add(valstr)

    -- make sure it has decimals
    if valstr:match('^-?[0-9]+$') then
      self:add('.0')
    end
  else
    if base == 'hex' or base == 'bin' then
      self:add('0x', val:tohex())
    else
      self:add(val:todec())
    end
  end

  -- suffixes
  if valtype:is_float32() and not self.context.ast.attr.nofloatsuffix then
    self:add('f')
  elseif valtype:is_unsigned() then
    self:add('U')
  end

  if minusone then
    self:add('-1')
  end
end

function CEmitter:add_literal(valattr)
  local valtype = valattr.type
  if valtype:is_boolean() then
    self:add_booleanlit(valattr.value)
  elseif valtype:is_arithmetic() then
    self:add_numeric_literal(valattr.value, valtype)
  --elseif valtype:is_record() then
    --self:add(valattr)
  else --luacov:disable
    errorer.errorf('not implemented: `CEmitter:add_literal` for valtype `%s`', valtype)
  end --luacov:enable
end

return CEmitter
