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
  elseif type.is_niltype or type.is_comptime then
    self.context:ensure_builtin('NLNIL')
    s = 'NLNIL'
  elseif type.is_pointer or type.is_procedure then
    self.context:ensure_builtin('NULL')
    s = 'NULL'
  elseif type.is_boolean then
    self.context:ensure_include('<stdbool.h>')
    s = 'false'
  elseif type.size == 0 then
    s = '{}'
  else -- should initialize almost anything in C
    s = '{0}'
  end
  return s
end

function CEmitter:add_type(type)
  self:add_one(self.context:ctype(type))
end

function CEmitter:add_typecast(type)
  self:add('(',type,')')
end

function CEmitter:add_zeroed_type_init(type)
  self:add_one(self:zeroinit(type))
end

function CEmitter:add_zeroed_type_literal(type)
  if not (type.is_boolean or type.is_arithmetic or type.is_pointer) then
    self:add_typecast(type)
  end
  self:add_one(self:zeroinit(type))
end

function CEmitter:add_boolean_literal(value)
  self.context:ensure_include('<stdbool.h>')
  self:add_one(value and 'true' or 'false')
end

function CEmitter:add_null()
  self.context:ensure_builtin('NULL')
  self:add_one('NULL')
end

function CEmitter:add_val2boolean(val, valtype)
  valtype = valtype or val.attr.type
  if valtype.is_boolean then
    self:add_one(val)
  elseif valtype.is_niltype or valtype.is_nilptr then
    self.context:ensure_include('<stdbool.h>')
    if (traits.is_string(val) and val:match('^[%w_]+$')) or
       (traits.is_astnode(val) and (val.tag == 'Nil' or val.tag == 'Id')) then
      self:add_one('false')
    else -- could have a call
      self:add('({(void)(', val, '); false;})')
    end
  elseif valtype.is_pointer or valtype.is_function then
    self.context:ensure_builtin('NULL')
    self:add('(', val, ' != NULL)')
  else
    self.context:ensure_include('<stdbool.h>')
    if (traits.is_string(val) and val:match('^[%w_]+$')) or
       (traits.is_astnode(val) and (val.tag == 'Nil' or val.tag == 'Id')) then
      self:add_one('true')
    else -- could be a call
      self:add('({(void)(', val, '); true;})')
    end
  end
end

function CEmitter:add_string2cstring(val)
  self:add_builtin('nelua_string2cstring')
  self:add('(', val, ')')
end

function CEmitter:add_cstring2string(val)
  self:add_builtin('nelua_cstring2string')
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
      self:add_one(val)
    elseif valtype.is_arithmetic and type.is_arithmetic and
           (type.is_float or valtype.is_integral) and
           traits.is_astnode(val) and val.attr.comptime then
      self:add_numeric_literal(val.attr, type)
    elseif valtype.is_nilptr and type.is_pointer then
      self:add_one(val)
    elseif type.is_boolean then
      self:add_val2boolean(val, valtype)
    elseif valtype.is_string and (type.is_cstring or type:is_pointer_of(primtypes.byte)) then
      self:add_string2cstring(val)
    elseif type.is_string and valtype.is_cstring then
      self:add_cstring2string(val)
    elseif type.is_pointer and traits.is_astnode(val) and val.attr.autoref then
      -- automatic reference
      self:add('&', val)
    elseif valtype.is_pointer and valtype.subtype == type and
           (type.is_record or type.is_array) then
      -- automatic dereference
      self:add_one('*')
      if checkcast then
        self:add_builtin('nelua_assert_deref_', valtype)
        self:add('(', val, ')')
      else
        self:add_one(val)
      end
    else
      if checkcast and type.is_integral and valtype.is_arithmetic and
        not type:is_type_inrange(valtype) then
        self:add_builtin('nelua_narrow_cast_', type, valtype)
        self:add('(', val, ')')
      else
        local innertype = type.is_pointer and type.subtype or type
        local surround = innertype.is_composite or innertype.is_array
        if surround then self:add_one('(') end
        self:add_typecast(type)
        if type.is_integral and valtype.is_pointer and type.size ~= valtype.size then
          self:add('(', primtypes.usize, ')')
        end
        self:add_one(val)
        if surround then self:add_one(')') end
      end
    end
  else
    self:add_zeroed_type_init(type)
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
        self:add_one('(0.0f/0.0f)')
      else
        self:add_one('(0.0/0.0)')
      end
      return
    elseif bn.isinfinite(val) then
      self.context:ensure_include('<math.h>')
      if val < 0 then
        self:add_one('-')
      end
      if valtype.is_float32 then
        self:add_one('HUGE_VALF')
      else
        self:add_one('HUGE_VAL')
      end
      return
    else
      local valstr = bn.todecsci(val, valtype.maxdigits)
      self:add_one(valstr)

      -- make sure it has decimals
      if valstr:match('^-?[0-9]+$') then
        self:add_one('.0')
      end
    end
  else
    if valtype.is_integral and valtype.is_signed and val == valtype.min then
      -- workaround C warning `integer constant is so large that it is unsigned`
      minusone = true
      val = val + 1
    end

    if not base or base == 'dec' or val:isneg() then
      self:add_one(bn.todec(val))
    else
      self:add('0x', bn.tohex(val))
    end
  end

  -- suffixes
  if valtype.is_float32 and not valattr.nofloatsuffix then
    self:add_one('f')
  elseif valtype.is_unsigned then
    self:add_one('U')
  end

  if minusone then
    self:add_one('-1')
  end
end

function CEmitter.cstring_literal(_, s)
  return pegger.double_quote_c_string(s), #s
end

function CEmitter:add_string_literal_inlined(val, ascstring)
  local quotedliterals = self.context.quotedliterals
  local quoted_value = quotedliterals[val]
  if not quoted_value then
    quoted_value = pegger.double_quote_c_string(val)
    quotedliterals[val] = quoted_value
  end
  if ascstring then
    self:add(quoted_value)
  else
    if not self.context.state.ininitializer then
      self:add_one('(')
      self:add_typecast(primtypes.string)
    end
    self:add('{(uint8_t*)', quoted_value, ', ', #val, '}')
    if not self.context.state.ininitializer then
      self:add_one(')')
    end
  end
end

function CEmitter:add_string_literal(val, ascstring)
  if #val < 80 then
    return self:add_string_literal_inlined(val, ascstring)
  end
  local size = #val
  local varname = self.context.stringliterals[val]
  if varname then
    if ascstring then --luacov:disable
      self:add_one(varname)
    else --luacov:enable
      if not self.context.state.ininitializer then
        self:add_one('(')
        self:add_typecast(primtypes.string)
      end
      self:add('{(uint8_t*)', varname, ', ', size, '}')
      if not self.context.state.ininitializer then
        self:add_one(')')
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
  if ascstring then --luacov:disable
    self:add_one(varname)
  else --luacov:enable
    if not self.context.state.ininitializer then
      self:add_one('(')
      self:add_typecast(primtypes.string)
    end
    self:add('{(uint8_t*)', varname, ', ', size, '}')
    if not self.context.state.ininitializer then
      self:add_one(')')
    end
  end
end

function CEmitter:add_literal(valattr)
  local valtype = valattr.type
  if valtype.is_boolean then
    self:add_boolean_literal(valattr.value)
  elseif valtype.is_arithmetic then
    self:add_numeric_literal(valattr)
  elseif valtype.is_string then
    self:add_string_literal(valattr.value, valattr.is_cstring)
  elseif valtype.is_niltype then
    self:add_builtin('NLNIL')
  else --luacov:disable
    errorer.errorf('not implemented: `CEmitter:add_literal` for valtype `%s`', valtype)
  end --luacov:enable
end

return CEmitter
