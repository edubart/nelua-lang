local class = require 'nelua.utils.class'
local Emitter = require 'nelua.emitter'
local traits = require 'nelua.utils.traits'
local typedefs = require 'nelua.typedefs'
local errorer = require 'nelua.utils.errorer'
local pegger = require 'nelua.utils.pegger'
local bn = require 'nelua.utils.bn'
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
  if type.is_float32 and not self.context.pragmas.nofloatsuffix then
    s = '0.0f'
  elseif type.is_float then
    s = '0.0'
  elseif type.is_unsigned then
    s = '0U'
  elseif type.is_arithmetic then
    s = '0'
  elseif type.is_comptime or type.is_niltype then
    self.context:ensure_runtime_builtin('NLNIL')
    s = 'NLNIL'
  elseif type.is_pointer or type.is_procedure then
    s = 'NULL'
  elseif type.is_boolean then
    s = 'false'
  elseif type.size > 0 then
    s = '{0}'
  else
    s = '{}'
  end
  return s
end

-------------------------------------
-- add functions
function CEmitter:add_zeroinit(type)
  self:add(self:zeroinit(type))
end

function CEmitter:add_ctyped_zerotype(type)
  if not (type.is_boolean or type.is_arithmetic or type.is_pointer) then
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

function CEmitter:add_booleanlit(value)
  assert(type(value) == 'boolean')
  self:add(value and 'true' or 'false')
end

function CEmitter:add_null()
  self:add('NULL')
end

function CEmitter:add_val2any(val, valtype)
  valtype = valtype or val.attr.type
  assert(not valtype.is_any)
  self:add('((', primtypes.any, ')')
  if valtype.is_niltype then
    self:add('{0})')
  else
    local runctype = self.context:runctype(valtype)
    local typename = self.context:typename(valtype)
    self:add('{&', runctype, ', {._', typename, ' = ', val, '}})')
  end
end

function CEmitter:add_val2boolean(val, valtype)
  valtype = valtype or val.attr.type
  if valtype.is_boolean then
    self:add(val)
  elseif valtype.is_any then
    self:add_builtin('nlany_to_', typedefs.primtypes.boolean)
    self:add('(', val, ')')
  elseif valtype.is_niltype or valtype.is_nilptr then
    if traits.is_astnode(val) and (val.tag == 'Nil' or val.tag == 'Id') then
      self:add('false')
    else -- could be a call
      self:add('({(void)(', val, '); false;})')
    end
  elseif valtype.is_pointer or valtype.is_function then
    self:add('(', val, ' != NULL)')
  else
    if traits.is_astnode(val) and (val.tag == 'Nil' or val.tag == 'Id') then
      self:add('true')
    else -- could be a call
      self:add('({(void)(', val, '); true;})')
    end
  end
end

function CEmitter:add_any2type(type, anyval)
  self.context:ctype(primtypes.any) -- ensure any type
  self:add_builtin('nlany_to_', type)
  self:add('(', anyval, ')')
end

function CEmitter:add_stringview2cstring(val)
  self:add('((char*)(', val, '.data', '))')
end

function CEmitter:add_cstring2stringview(val)
  self:add_builtin('nelua_cstring2stringview')
  self:add('(', val, ')')
end

function CEmitter:add_val2type(type, val, valtype, checkcast)
  if type.is_comptime then
    self:add_builtin('NLNIL')
    return
  end

  if traits.is_astnode(val) then
    if not valtype then
      valtype = val.attr.type
    end
    checkcast = val.checkcast
  end

  if val then
    assert(valtype)

    if type == valtype then
      self:add(val)
    elseif valtype.is_arithmetic and type.is_arithmetic and
           (type.is_float or valtype.is_integral) and
           traits.is_astnode(val) and val.attr.comptime then
      self:add_numeric_literal(val.attr, type)
    elseif valtype.is_nilptr and type.is_pointer then
      self:add(val)
    elseif type.is_any then
      self:add_val2any(val, valtype)
    elseif type.is_boolean then
      self:add_val2boolean(val, valtype)
    elseif valtype.is_any then
      self:add_any2type(type, val)
    elseif valtype.is_stringview and (type.is_cstring or type:is_pointer_of(primtypes.byte)) then
      self:add_stringview2cstring(val)
    elseif type.is_stringview and valtype.is_cstring then
      self:add_cstring2stringview(val)
    elseif type.is_pointer and traits.is_astnode(val) and val.attr.autoref then
      -- automatic reference
      self:add('&', val)
    elseif valtype.is_pointer and valtype.subtype == type and
           (type.is_record or type.is_array) then
      -- automatic dereference
      self:add('*')
      if checkcast then
        self:add_builtin('nelua_assert_deref_', valtype)
        self:add('(', val, ')')
      else
        self:add(val)
      end
    else
      if checkcast and type.is_integral and valtype.is_arithmetic and
        not type:is_type_inrange(valtype) then
        self:add_builtin('nelua_narrow_cast_', type, valtype)
        self:add('(', val, ')')
      else
        local innertype = type.is_pointer and type.subtype or type
        local surround = innertype.is_composite or innertype.is_array
        if surround then self:add('(') end
        self:add_ctypecast(type)
        self:add(val)
        if surround then self:add(')') end
      end
    end
  else
    self:add_zeroinit(type)
  end
end

function CEmitter:add_nil_literal()
  self:add_builtin('NLNIL')
end

function CEmitter:add_numeric_literal(valattr, valtype)
  assert(bn.isnumeric(valattr.value))

  valtype = valtype or valattr.type
  local val, base = valattr.value, valattr.base

  if valtype.is_integral then
    if bn.isneg(val) and valtype.is_unsigned then
      val = valtype:wrap_value(val)
    elseif not valtype:is_inrange(val) then
      val = valtype:wrap_value(val)
    end
  end

  local minusone = false
  if valtype.is_float then
    if bn.isnan(val) then
      if valtype.is_float32 then
        self:add('(0.0f/0.0f)')
      else
        self:add('(0.0/0.0)')
      end
      return
    elseif bn.isinfinite(val) then
      self.context:add_include('<math.h>')
      if val < 0 then
        self:add('-')
      end
      if valtype.is_float32 then
        self:add('HUGE_VALF')
      else
        self:add('HUGE_VAL')
      end
      return
    else
      local valstr = bn.todecsci(val, valtype.maxdigits)
      self:add(valstr)

      -- make sure it has decimals
      if valstr:match('^-?[0-9]+$') then
        self:add('.0')
      end
    end
  else
    if valtype.is_integral and valtype.is_signed and val == valtype.min then
      -- workaround C warning `integer constant is so large that it is unsigned`
      minusone = true
      val = val + 1
    end

    if not base or base == 'dec' or val:isneg() then
      self:add(bn.todec(val))
    else
      self:add('0x', bn.tohex(val))
    end
  end

  -- suffixes
  if valtype.is_float32 and not valattr.nofloatsuffix then
    self:add('f')
  elseif valtype.is_unsigned then
    self:add('U')
  end

  if minusone then
    self:add('-1')
  end
end

function CEmitter:add_string_literal(val, ascstring)
  local size = #val
  local varname = self.context.stringliterals[val]
  if varname then
    if ascstring then
      self:add(varname)
    else
      if not self.context.state.ininitializer then
        self:add('(')
        self:add_ctypecast(primtypes.stringview)
      end
      self:add('{(uint8_t*)', varname, ', ', size, '}')
      if not self.context.state.ininitializer then
        self:add(')')
      end
    end
    return
  end
  varname = self.context:genuniquename('strlit')
  self.context.stringliterals[val] = varname
  local decemitter = CEmitter(self.context)
  local quoted_value = pegger.double_quote_c_string(val)
  decemitter:add_indent_ln('static char ', varname, '[', size+1, '] = ', quoted_value, ';')
  self.context:add_declaration(decemitter:generate(), varname)
  if ascstring then
    self:add(varname)
  else
    if not self.context.state.ininitializer then
      self:add('(')
      self:add_ctypecast(primtypes.stringview)
    end
    self:add('{(uint8_t*)', varname, ', ', size, '}')
    if not self.context.state.ininitializer then
      self:add(')')
    end
  end
end

function CEmitter:add_literal(valattr)
  local valtype = valattr.type
  if valtype.is_boolean then
    self:add_booleanlit(valattr.value)
  elseif valtype.is_arithmetic then
    self:add_numeric_literal(valattr)
  elseif valtype.is_stringview then
    self:add_string_literal(valattr.value, valattr.is_cstring)
  elseif valtype.is_niltype then
    self:add_builtin('NLNIL')
  --elseif valtype.is_record then
    --self:add(valattr)
  else --luacov:disable
    errorer.errorf('not implemented: `CEmitter:add_literal` for valtype `%s`', valtype)
  end --luacov:enable
end

return CEmitter
