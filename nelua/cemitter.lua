--[[
C emitter class.

This class extends the emitter class with utilities to assist generating C code.
]]

local class = require 'nelua.utils.class'
local traits = require 'nelua.utils.traits'
local errorer = require 'nelua.utils.errorer'
local pegger = require 'nelua.utils.pegger'
local bn = require 'nelua.utils.bn'
local Emitter = require 'nelua.emitter'
local typedefs = require 'nelua.typedefs'
local primtypes = typedefs.primtypes

-- The C emitter class.
local CEmitter = class(Emitter)
-- Used to quickly check whether a table is an C emitter.
CEmitter._cemitter = true

-- Helper to check if value `val` should be evaluated at runtime.
local function needs_evaluation(val)
  if traits.is_string(val) then
    if val:match('^[%w_]+$') then
      return false
    end
  elseif traits.is_astnode(val) then
    if val.tag == 'Nil' or val.tag == 'Nilptr' or val.tag == 'Id' then
      return false
    end
  end
  return true -- lets evaluate it, it could be a call
end

--[[
Adds literal for type `type` initialized to zeros.
If `typed` is `true` then a type cast will precede its literal.
]]
function CEmitter:add_zeroed_type_literal(type, typed)
  if typed and not (type.is_boolean or type.is_scalar or type.is_pointer) then
    self:add('(', type, ')')
  end
  local s
  if type.is_float32 and not self.context.pragmas.nofloatsuffix then
    s = '0.0f'
  elseif type.is_float then
    s = '0.0'
  elseif type.is_unsigned then
    s = '0U'
  elseif type.is_scalar then
    s = '0'
  elseif type.is_niltype or type.is_comptime then
    s = self.context:ensure_builtin('NLNIL')
  elseif type.is_pointer or type.is_procedure then
    s = self.context:ensure_builtin('NULL')
  elseif type.is_boolean then
    s = self.context:ensure_builtin('false')
  elseif type.is_empty then
    s = '{}'
  else -- should initialize almost anything in C
    s = '{0}'
  end
  self:add_text(s)
end

--[[
Adds `val` of type `valtype` converted to a boolean.
If `valtype` is unset then the type automatically detected from `val`.
All types can be converted to a boolean.
]]
function CEmitter:add_val2boolean(val, valtype)
  valtype = valtype or val.attr.type
  if valtype.is_boolean then
    self:add_value(val)
  elseif valtype.is_pointer or valtype.is_function then
    self:add('(', val, ' != ') self:add_null() self:add_text(')')
  else
    local status = not (valtype.is_niltype or valtype.is_nilptr)
    if needs_evaluation(val) then -- we need to evaluate
      self:add('((void)(',val,'), ',status,')')
    else
      self:add_value(status)
    end
  end
end

--[[
Adds a value of type `string` converted to a `cstring`.
The conversion may be check.
]]
function CEmitter:add_text2cstring(val)
  local check = not self.context.pragmas.nochecks and
                not (traits.is_astnode(val) and val.attr.comptime)
  self:add_builtin('nelua_string2cstring_', check) self:add('(', val, ')')
end

-- Adds a value of type `cstring` converted to a `string`.
function CEmitter:add_cstring2string(val)
  self:add_builtin('nelua_cstring2string') self:add('(', val, ')')
end

--[[
Adds dereference of `val` of type `valtype` (which must be a pointer type).
If `valtype` is unset then the type automatically detected from `val`.
The dereference may be check.
]]
function CEmitter:add_deref(val, valtype)
  valtype = valtype or val.attr.type
  assert(valtype.is_pointer)
  local valsubtype = valtype.subtype
  self:add_text('*')
  if valsubtype.is_array and valsubtype.length == 0 then
    -- use pointer to the actual subtype structure, because its type may have been simplified
    self:add('(',valsubtype,'*)')
  end
  if not self.context.pragmas.nochecks then -- check
    self:add_builtin('nelua_assert_deref_', valtype) self:add_text('(')
    if valtype.subtype.length == 0 then
      self:add('(', valtype, ')')
    end
    self:add(val, ')')
  else
    self:add_value(val)
  end
end

--[[
Adds `val` of type `valtype` casted to `type` (via explicit C casting).
If `valtype` is unset then the type automatically detected from `val`.
In case `check` is true then checks for underflow/overflow is performed.
]]
function CEmitter:add_typed_val(type, val, valtype, check)
  if check and not self.context.pragmas.nochecks and type.is_integral and valtype.is_scalar and
    not type:is_type_inrange(valtype) then
    self:add_builtin('nelua_assert_narrow_', type, valtype) self:add('(', val, ')')
  else
    local innertype = type.is_pointer and type.subtype or type
    local surround = innertype.is_aggregate
    if surround then self:add_text('(') end
    self:add('(', type, ')')
    if type.is_integral and valtype.is_pointer and type.size ~= valtype.size then
      self:add('(', primtypes.usize, ')')
    end
    self:add_value(val)
    if surround then self:add_text(')') end
  end
end

--[[
Adds  `val` of type `valtype` converted to `type`.
If `valtype` is unset then the type automatically detected from `val`.
In case `explicit` is true then checks for underflow/overflow is skipped.
]]
function CEmitter:add_converted_val(type, val, valtype, explicit)
  if type.is_comptime then
    self:add_nil_literal()
    return
  end
  if val then
    local valattr = traits.is_astnode(val) and val.attr or {}
    valtype = valtype or valattr.type
    assert(valtype)
    if type == valtype then -- no conversion needed
      self:add_value(val)
    elseif type.is_boolean then -- ? -> boolean
      self:add_val2boolean(val, valtype)
    elseif type.is_pointer and valtype.is_string and type.subtype.size == 1 then -- cstring -> string
      self:add_text2cstring(val)
    elseif type.is_string and valtype.is_cstring then -- string -> cstring
      self:add_cstring2string(val)
    elseif valattr.comptime and type.is_scalar and valtype.is_scalar and
           (type.is_float or valtype.is_integral) then -- comptime scalar -> scalar
      self:add_scalar_literal(valattr, type)
    elseif type.is_pointer and valtype.is_aggregate and valtype == type.subtype then -- auto ref
      self:add('&', val)
    elseif type.is_aggregate and valtype.is_pointer and valtype.subtype == type then -- auto deref
      self:add_deref(val, valtype)
    else -- cast
      self:add_typed_val(type, val, valtype, not explicit)
    end
  else
    self:add_zeroed_type_literal(type)
  end
end

-- Adds boolean literal `value`.
function CEmitter:add_boolean(value)
  self:add_builtin(tostring(not not value))
end

-- Adds the NULL literal (used for `nilptr`).
function CEmitter:add_null()
  self:add_builtin('NULL')
end

-- Adds the `nil` literal.
function CEmitter:add_nil_literal()
  self:add_builtin('NLNIL')
end

--[[
Adds a `string` literal, or a `cstring` literal if `ascstring` is true.
Intended for short strings, because it uses just one line.
]]
function CEmitter:add_short_string_literal(val, ascstring)
  local context = self.context
  local quotedliterals = context.quotedliterals
  local quoted_value = quotedliterals[val]
  if not quoted_value then
    quoted_value = pegger.double_quote_c_string(val)
    quotedliterals[val] = quoted_value
  end
  if ascstring then
    self:add(quoted_value)
  else
    local ininitializer = context.state.ininitializer
    if not ininitializer then
      self:add_text('(')
      self:add('(', primtypes.string, ')')
    end
    self.context:ensure_type(primtypes.uint8)
    self:add('{(uint8_t*)', quoted_value, ', ', #val, '}')
    if not ininitializer then
      self:add_text(')')
    end
  end
end

--[[
Adds a `string` literal, or a `cstring` literal if `ascstring` is true.
Intended for long strings, because it may use multiple lines.
]]
function CEmitter:add_long_string_literal(val, ascstring)
  local context = self.context
  local ininitializer = context.state.ininitializer
  local stringliterals = context.stringliterals
  local varname = stringliterals[val]
  local size = #val
  if varname then
    if ascstring then
      self:add_text(varname)
    else
      if not ininitializer then
        self:add('((', primtypes.string, ')')
      end
      self.context:ensure_type(primtypes.uint8)
      self:add('{(uint8_t*)', varname, ', ', size, '}')
      if not ininitializer then
        self:add_text(')')
      end
    end
    return
  end
  varname = context:genuniquename('strlit')
  stringliterals[val] = varname
  local decemitter = CEmitter(context)
  decemitter:add_indent('static char ', varname, '[', size+1, '] = ')
  if val:find("[^%g%s\a\b\x1b]") then -- binary string
    decemitter:add('{')
    for i=1,size do
      if i % 32 == 1 then
        decemitter:add_ln()
        decemitter:add_indent()
      end
      decemitter:add(string.format('0x%02x,', string.byte(val:sub(i,i))))
    end
    decemitter:add('0x00')
    decemitter:add_ln('};')
  else -- text string
    decemitter:add_ln(pegger.double_quote_c_string(val), ';')
  end
  context:add_declaration(decemitter:generate(), varname)
  if ascstring then
    self:add_text(varname)
  else
    if not ininitializer then
      self:add_text('(')
      self:add('(', primtypes.string, ')')
    end
    self.context:ensure_type(primtypes.uint8)
    self:add('{(uint8_t*)', varname, ', ', size, '}')
    if not ininitializer then
      self:add_text(')')
    end
  end
end

-- Adds a `string` literal, or a `cstring` literal if `ascstring` is true.
function CEmitter:add_string_literal(val, ascstring)
  if #val < 80 then
    return self:add_short_string_literal(val, ascstring)
  end
  return self:add_long_string_literal(val, ascstring)
end

-- Adds a scalar literal from attr `valattr`, with appropriate suffix for `valtype`.
function CEmitter:add_scalar_literal(valattr, valtype)
  valtype = valtype or valattr.type
  local num, base = valattr.value, valattr.base
  -- wrap values out of range
  if valtype.is_integral and ((valtype.is_unsigned and bn.isneg(num)) or
                              not valtype:is_inrange(num)) then
    num = valtype:wrap_value(num)
  end
  local minusone = false
  -- add number literal
  if valtype.is_float then -- float
    if bn.isnan(num) then -- not a number
      self:add_builtin('NLNAN_', valtype)
      return
    elseif bn.isinfinite(num) then -- infinite
      if num < 0 then
        self:add_text('-')
      end
      self:add_builtin('NLINF_', valtype)
      return
    else -- a number
      self:add_text(bn.todecsci(num, valtype.maxdigits, true))
    end
  else -- integral
    if valtype.is_integral and valtype.is_signed and num == valtype.min then
      -- workaround C warning `integer constant is so large that it is unsigned`
      minusone = true
      num = num + 1
    end
    if not base or base == 10 or num:isneg() then -- use decimal base
      self:add_text(bn.todecint(num))
    else -- use hexadeciaml base
      self:add('0x', bn.tohexint(num))
    end
  end
  -- add suffixes
  if valtype.is_float32 and not self.context.pragmas.nofloatsuffix then
    self:add_text('f')
  elseif valtype.is_unsigned then
    self:add_text('U')
  end
  if minusone then
    self:add_text('-1')
  end
end

-- Adds a literal from attr `valattr`.
function CEmitter:add_literal(valattr)
  local valtype = valattr.type
  assert(valattr.comptime or valtype.is_comptime)
  if valtype.is_boolean then
    self:add_boolean(valattr.value)
  elseif valtype.is_scalar then
    self:add_scalar_literal(valattr)
  elseif valtype.is_string then
    self:add_string_literal(valattr.value, false)
  elseif valtype.is_cstring then
    self:add_string_literal(valattr.value, true)
  elseif valtype.is_procedure then
    self:add_text(self.context:declname(valattr.value))
  elseif valtype.is_niltype then
    self:add_nil_literal()
  else --luacov:disable
    errorer.errorf('not implemented: `CEmitter:add_literal` for valtype `%s`', valtype)
  end --luacov:enable
end

return CEmitter
