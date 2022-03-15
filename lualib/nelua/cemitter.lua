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
    if val.is_Nil or val.is_Nilptr or val.is_Id then
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
  local s
  if type.is_float128 and not self.context.pragmas.nocfloatsuffix then
    s = '0.0q'
  elseif type.is_clongdouble and not self.context.pragmas.nocfloatsuffix then
    s = '0.0l'
  elseif type.is_cfloat and not self.context.pragmas.nocfloatsuffix then
    s = '0.0f'
  elseif type.is_float then
    s = '0.0'
  elseif type.is_unsigned then
    s = '0U'
  elseif type.is_scalar then
    s = '0'
  elseif type.is_niltype or type.is_comptime then
    s = self.context:ensure_builtin('NELUA_NIL')
  elseif type.is_pointer or type.is_procedure then
    s = self.context:ensure_builtin('NULL')
  elseif type.is_boolean then
    s = self.context:ensure_builtin('false')
  else
    if typed then
      self:add('(', type, ')')
    end
    s = '{0}' -- should initialize almost anything in C
    if typedefs.emptysize == 0 then
      if type.is_empty then -- empty record/array
        s = '{}'
      elseif type.is_record and type.fields[1].type.is_empty then -- first field is an empty record
        s = '{{}}'
      end
    end
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
      self:add('(',val,', ',status,')')
    else
      self:add_value(status)
    end
  end
end

--[[
Adds a value of type `string` converted to a `cstring`.
The conversion may be check.
]]
function CEmitter:add_string2cstring(val)
  local check = not self.context.pragmas.nochecks and
                not (traits.is_astnode(val) and val.attr.comptime)
  self:add_builtin('nelua_string2cstring_', check) self:add('(', val, ')')
end

-- Adds a value of type `cstring` converted to a `string`.
function CEmitter:add_cstring2string(val, valtype)
  valtype = valtype or val.attr.type
  self:add_builtin('nelua_cstring2string')
  if valtype.is_cstring then
    self:add_text('(')
  else
    self:add_text('((char*)')
  end
  self:add(val, ')')
end

--[[
Adds dereference of `val` of type `valtype` (which must be a pointer type).
If `valtype` is unset then the type automatically detected from `val`.
The dereference may be check.
]]
function CEmitter:add_deref(val, valtype)
  valtype = valtype or val.attr.type
  assert(valtype.is_pointer)
  self:add_text('(*')
  if not self.context.pragmas.nochecks or valtype.is_unbounded_pointer then
    self:add('(', valtype.subtype, '*)')
  end
  if not self.context.pragmas.nochecks then -- check
    self:add_builtin('nelua_assert_deref')
    self:add('(', val, ')')
  else
    self:add_value(val)
  end
  self:add_text(')')
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
In case `force` is true, then checks for underflow/overflow is skipped.
If `untypedinit` is true, then type casting prefix is omitted if possible.
]]
function CEmitter:add_converted_val(type, val, valtype, force, untypedinit)
  if type.is_comptime then
    self:add_nil_literal()
    return
  end
  if val then
    local valattr = traits.is_astnode(val) and val.attr or {}
    valtype = valtype or valattr.type
    assert(valtype)
    if type == valtype then -- no conversion needed
      self:add_value(val, untypedinit)
    elseif type.is_boolean then -- ? -> boolean
      self:add_val2boolean(val, valtype)
    elseif type.is_pointer and valtype.is_string and
          (type.is_byte_pointer or type.is_bytearray_pointer) then -- cstring -> string
      if not type.is_cstring then
        self:add('(', type, ')')
      end
      self:add_string2cstring(val)
    elseif type.is_string and
          (valtype.is_byte_pointer or valtype.is_bytearray_pointer) then -- string -> cstring
      self:add_cstring2string(val, valtype)
    elseif valattr.comptime and type.is_scalar and valtype.is_scalar and
           (type.is_float or valtype.is_integral) then -- comptime scalar -> scalar
      self:add_scalar_literal(valattr.value, type, valattr.base, true)
    elseif type.is_pointer and valtype.is_aggregate then -- auto ref
      -- TODO: the following would maybe take address of rvalues properly in C++ backend?
      -- (without -fpermissive)
      --[[
      if valattr.promotelvalue then
        self:add_ln('({')
        self:inc_indent()
        self:add_indent_ln(valtype, ' _expr = ', val, ';')
        if valtype == type.subtype then
          self:add_indent_ln('&_expr;')
        else
          self:add_indent_ln('(', type, ')(&_expr);')
        end
        self:dec_indent()
        self:add_indent('})')
      else
      ]]
        if valtype == type.subtype then
          self:add('(&', val, ')')
        else
          self:add('((', type, ')(&', val, '))')
        end
      -- end
    elseif type.is_aggregate and valtype.is_pointer and valtype.subtype == type then -- auto deref
      self:add_deref(val, valtype)
    elseif valtype.is_void and type.is_niltype then
      self:add('(',val,',')
      self:add_nil_literal()
      self:add(')')
    else -- cast
      local checked = not (force or untypedinit)
      self:add_typed_val(type, val, valtype, checked)
    end
  else
    local typed = force and not untypedinit
    self:add_zeroed_type_literal(type, typed)
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
  self:add_builtin('NELUA_NIL')
end

--[[
Adds a `string` literal, or a `cstring` literal if `ascstring` is true.
Intended for short strings, because it uses just one line.
]]
function CEmitter:add_short_string_literal(val, ascstring, untypedinit)
  local context = self.context
  local quotedliterals = context.quotedliterals
  local quoted_value = quotedliterals[val]
  if not quoted_value then
    quoted_value = pegger.double_quote_c_string(val)
    quotedliterals[val] = quoted_value
  end
  if ascstring then
    self:add('(char*)',quoted_value)
  else
    if not untypedinit then
      self:add_text('(')
      self:add('(', primtypes.string, ')')
    end
    self.context:ensure_type(primtypes.uint8)
    self:add('{(uint8_t*)', quoted_value, ', ', #val, '}')
    if not untypedinit then
      self:add_text(')')
    end
  end
end

--[[
Adds a `string` literal, or a `cstring` literal if `ascstring` is true.
Intended for long strings, because it may use multiple lines.
]]
function CEmitter:add_long_string_literal(val, ascstring, untypedinit)
  local context = self.context
  local stringliterals = context.stringliterals
  local varname = stringliterals[val]
  local size = #val
  if varname then
    if ascstring then
      self:add_text(varname)
    else
      if not untypedinit then
        self:add('((', primtypes.string, ')')
      end
      self.context:ensure_type(primtypes.uint8)
      self:add('{(uint8_t*)', varname, ', ', size, '}')
      if not untypedinit then
        self:add_text(')')
      end
    end
    return
  end
  varname = context.rootscope:generate_name('nelua_strlit')
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
    if not untypedinit then
      self:add_text('(')
      self:add('(', primtypes.string, ')')
    end
    self.context:ensure_type(primtypes.uint8)
    self:add('{(uint8_t*)', varname, ', ', size, '}')
    if not untypedinit then
      self:add_text(')')
    end
  end
end

-- Adds a `string` literal, or a `cstring` literal if `ascstring` is true.
function CEmitter:add_string_literal(val, ascstring, untypedinit)
  if #val < 80 then
    return self:add_short_string_literal(val, ascstring, untypedinit)
  end
  return self:add_long_string_literal(val, ascstring, untypedinit)
end

-- Adds a scalar literal `num`, with appropriate suffix for type `numtype`.
function CEmitter:add_scalar_literal(num, numtype, base)
  -- wrap values out of range
  if numtype.is_integral and ((numtype.is_unsigned and bn.isneg(num)) or
                              not numtype:is_inrange(num)) then
    num = numtype:wrap_value(num)
  end
  local minusone = false
  -- add number literal
  if numtype.is_float then -- float
    if bn.isnan(num) then -- not a number
      self:add_builtin('NELUA_NAN_', numtype)
      return
    elseif bn.isinfinite(num) then -- infinite
      if num < 0 then
        self:add_text('-')
      end
      self:add_builtin('NELUA_INF_', numtype)
      return
    else -- a number
      self:add_text(bn.todecsci(num, numtype.decimaldigits, true))
    end
  else -- integral
    if numtype.is_integral and numtype.is_signed and num == numtype.min then
      -- workaround C warning `integer constant is so large that it is unsigned`
      minusone = true
      num = num + 1
      self:add_text('(')
    end
    if (not base and num ~= numtype.min and num ~= numtype.max) or
        base == 10 or num:isneg() then -- use decimal base
      self:add_text(bn.todecint(num))
    else -- use hexadecimal base
      self:add('0x', bn.tohexint(num))
    end
  end
  -- add suffixes
  if numtype.is_float128 and not self.context.pragmas.nocfloatsuffix then
    self:add_text('q')
  elseif numtype.is_clongdouble and not self.context.pragmas.nocfloatsuffix then
    self:add_text('l')
  elseif numtype.is_cfloat and not self.context.pragmas.nocfloatsuffix then
    self:add_text('f')
  elseif numtype.is_unsigned then
    self:add_text('U')
  end
  if numtype.is_integral and (not primtypes.cint:is_inrange(num) or num == primtypes.cint.min) then
    if numtype.is_clong or numtype.is_culong then
      self:add_text('L')
    elseif numtype.is_clonglong or numtype.is_culonglong or
          (numtype.is_signed and primtypes.clonglong:is_inrange(num)) or
          (numtype.is_unsigned and primtypes.culonglong:is_inrange(num)) then
      self:add_text('LL')
    end
  end
  if minusone then
    self:add_text('-1)')
  end
end

-- Adds a pointer literal.
function CEmitter:add_pointer_literal(value, type)
  type = type or primtypes.pointer
  self:add('((', type , ')0x', bn.tohexint(value), ')')
end

-- Adds a array literal from list of attrs `valattrs`.
function CEmitter:add_array_literal(valattrs, arrtype, untypedinit)
  if untypedinit then
    self:add('{')
  else
    self:add('(', arrtype, '){{')
  end
  local subtype = arrtype.subtype
  for i=1,#valattrs do
    if i > 1 then self:add_text(', ') end
    self:add_literal(valattrs[i], subtype, true)
  end
  if untypedinit then
    self:add('}')
  else
    self:add('}}')
  end
end


-- Adds a literal from attr `valattr`.
function CEmitter:add_literal(valattr, untypedinit)
  local valtype = valattr.type
  assert(valattr.comptime or valtype.is_comptime)
  local value = valattr.value
  if valtype.is_boolean then
    self:add_boolean(value)
  elseif valtype.is_scalar then
    self:add_scalar_literal(value, valtype, valattr.base)
  elseif valtype.is_string then
    self:add_string_literal(value, false, untypedinit)
  elseif valtype.is_cstring then
    self:add_string_literal(value, true, untypedinit)
  elseif valtype.is_pointer then
    self:add_pointer_literal(value, valtype)
  elseif valtype.is_procedure then
    self:add_text(self.context:declname(value))
  elseif valtype.is_niltype then
    self:add_nil_literal()
  elseif valtype.is_array then
    self:add_array_literal(value, valtype, untypedinit)
  else --luacov:disable
    errorer.errorf('`CEmitter:add_literal` for valtype `%s` is not implemented', valtype)
  end --luacov:enable
end

function CEmitter:add_type_qualifiers(type)
  if type.aligned then
    self:add(' ', self.context:ensure_builtin('NELUA_ALIGNED'), '(', type.aligned, ')')
  end
  if type.packed then
    self:add(' ', self.context:ensure_builtin('NELUA_PACKED'))
  end
end

function CEmitter:add_qualified_declaration(attr, type, name)
  local context = self.context
  local pragmas = context.pragmas
  if attr.cinclude then
    context:ensure_include(attr.cinclude)
  end
  -- storage specifiers
  if attr.aligned then
    self:add(context:ensure_builtin('NELUA_ALIGNAS'), '(', attr.aligned, ') ')
  end
  if attr.cimport and attr.codename ~= 'nelua_main' and
                      attr.codename ~= 'nelua_argc' and
                      attr.codename ~= 'nelua_argv' then
    self:add(context:ensure_builtin('NELUA_CIMPORT'), ' ')
  elseif attr.cexport then
    self:add(context:ensure_builtin('NELUA_CEXPORT'), ' ')
  elseif attr.static or
    (attr.staticstorage and not attr.entrypoint and not attr.nocstatic and not pragmas.nocstatic) then
    self:add('static ')
  elseif attr.register then
    self:add(context:ensure_builtin('NELUA_REGISTER'), ' ')
  end
  -- function specifiers
  if attr.inline and not pragmas.nocinlines then
    self:add(context:ensure_builtin('NELUA_INLINE'), ' ')
  elseif attr.noinline and not pragmas.nocinlines then
    self:add(context:ensure_builtin('NELUA_NOINLINE'), ' ')
  end
  if attr.noreturn then
    self:add(context:ensure_builtin('NELUA_NORETURN'), ' ')
  end
  if attr.threadlocal then
    self:add(context:ensure_builtin('NELUA_THREAD_LOCAL'), ' ')
  end
  -- type qualifiers
  if attr.const and not attr.ignoreconst then
    if traits.is_type(type) and (type.is_pointer or type.is_scalar or type.is_boolean) then
       -- only allow const on some basic types
      self:add('const ')
    end
  end
  if attr.volatile or pragmas.volatile then
    self:add('volatile ')
  end
  if attr.cqualifier then
    self:add(attr.cqualifier, ' ')
  end
  if attr.atomic then
    self:add(context:ensure_builtin('NELUA_ATOMIC'), '(', type, ') ')
  else
    self:add(type, ' ')
  end
  -- late type qualifiers
  if attr.restrict then
    self:add('__restrict ')
  end
  if attr.cattribute then
    self:add(string.format('__attribute__((%s)) ', attr.cattribute))
  end
  self:add(name)
end

return CEmitter
