local cdefs = require 'nelua.cdefs'
local CEmitter = require 'nelua.cemitter'
local primtypes = require 'nelua.typedefs'.primtypes
local bn = require 'nelua.utils.bn'

local builtins, operators, inlines = {}, {}, {}
local cbuiltins = {
  operators = operators,
  builtins = builtins,
  inlines = inlines,
}

--------------------------------------------------------------------------------
-- Builtins

function builtins.nelua_likely(context)
  context:define_builtin('nelua_likely', [[
#ifdef __GNUC__
#define nelua_likely(x) __builtin_expect(x, 1)
#define nelua_unlikely(x) __builtin_expect(x, 0)
#else
#define nelua_likely(x) (x)
#define nelua_unlikely(x) (x)
#endif
]])
end

function builtins.nelua_cexport(context)
  context:define_builtin('nelua_cexport', [[
#ifdef _WIN32
#define nelua_cexport __declspec(dllexport) extern
#elif defined(__GNUC__)
#define nelua_cexport __attribute__((visibility ("default"))) extern
#else
#define nelua_cexport extern
#endif
]])
end

function builtins.nelua_unlikely(context)
  context:ensure_builtin('nelua_likely')
end

function builtins.nelua_noinline(context)
  context:define_builtin('nelua_noinline', [[
#if defined(__GNUC__)
#define nelua_noinline __attribute__((noinline))
#else
#define nelua_noinline
#endif
]])
end

function builtins.nelua_noreturn(context)
  context:define_builtin('nelua_noreturn', [[
#if __STDC_VERSION__ >= 201112L
#define nelua_noreturn _Noreturn
#elif defined(__GNUC__)
#define nelua_noreturn __attribute__((noreturn))
#else
#define nelua_noreturn
#endif
]])
end

function builtins.nlniltype(context)
  context:define_builtin('nlniltype', "typedef struct nlniltype {} nlniltype;")
end

function builtins.NLNIL(context)
  context:ensure_builtin('nlniltype')
  context:define_builtin('NLNIL', "#define NLNIL (nlniltype){}")
end

function builtins.NULL(context)
  context:ensure_include('<stddef.h>')
end

function builtins.nelua_abort(context)
  local abortcall
  if context.pragmas.noabort then
    abortcall = 'exit(-1)'
  else
    abortcall = 'abort()'
  end
  context:ensure_include('<stdlib.h>')
  context:ensure_include('<stdio.h>')
  context:ensure_builtins('nelua_noreturn')
  context:define_function_builtin('nelua_abort',
    'static nelua_noreturn', primtypes.void, {}, [[{
  fflush(stderr);
  ]]..abortcall..[[;
}]])
end

function builtins.nelua_panic_cstring(context)
  context:ensure_include('<stdio.h>')
  context:ensure_builtins('nelua_noreturn', 'nelua_abort')
  context:define_function_builtin('nelua_panic_cstring',
    'static nelua_noreturn', primtypes.void, {{primtypes.cstring, 's'}}, [[{
  fputs(s, stderr);
  fputc('\n', stderr);
  nelua_abort();
}]])
end

function builtins.nelua_panic_stringview(context)
  context:ensure_include('<stdio.h>')
  context:ensure_builtins('nelua_noreturn', 'nelua_abort')
  context:define_function_builtin('nelua_panic_stringview',
    'static nelua_noreturn', primtypes.void, {{primtypes.stringview, 's'}}, [[{
  if(s.data && s.size > 0) {
    fwrite(s.data, 1, s.size, stderr);
    fputc('\n', stderr);
  }
  nelua_abort();
}]])
end

function builtins.nelua_assert_bounds_(context, indextype)
  local name = 'nelua_assert_bounds_' .. indextype.codename
  if context.usedbuiltins[name] then return name end
  context:ensure_include('<stdint.h>')
  context:ensure_builtins('nelua_panic_cstring', 'nelua_unlikely')
  local cond = '(uintptr_t)index >= len'
  if not indextype.is_unsigned then
    cond = cond .. ' || index < 0'
  end
  context:define_function_builtin(name,
    'static inline', indextype, {{indextype, 'index'}, {primtypes.usize, 'len'}}, [[{
  if(nelua_unlikely(]]..cond..[[)) {
    nelua_panic_cstring("array index: position out of bounds");
  }
  return index;
}]])
  return name
end

function builtins.nelua_assert_deref_(context, indextype)
  local name = 'nelua_assert_deref_' .. indextype.codename
  if context.usedbuiltins[name] then return name end
  context:ensure_builtins('nelua_panic_cstring', 'nelua_unlikely', 'NULL')
  context:define_function_builtin(name,
    'static inline', indextype,  {{indextype, 'p'}}, [[{
  if(nelua_unlikely(p == NULL)) {
    nelua_panic_cstring("attempt to dereference a null pointer");
  }
  return p;
}]])
  return name
end

function builtins.nelua_warn(context)
  context:ensure_include('<stdio.h>')
  context:define_function_builtin('nelua_warn',
    'static', primtypes.void, {{primtypes.stringview, 's'}}, [[{
  if(s.data && s.size > 0) {
    fputs("warning: ", stderr);
    fwrite(s.data, 1, s.size, stderr);
    fputc('\n', stderr);
    fflush(stderr);
  }
}]])
end

function builtins.nelua_stringview_eq(context)
  context:ensure_include('<string.h>')
  context:define_function_builtin('nelua_stringview_eq',
    'static inline', primtypes.boolean, {{primtypes.stringview, 'a'}, {primtypes.stringview, 'b'}}, [[{
  return a.size == b.size && (a.data == b.data || a.size == 0 || memcmp(a.data, b.data, a.size) == 0);
}]])
end

function builtins.nelua_stringview_ne(context)
  context:ensure_builtin('nelua_stringview_eq')
  context:define_function_builtin('nelua_stringview_ne',
    'static inline', primtypes.boolean, {{primtypes.stringview, 'a'}, {primtypes.stringview, 'b'}}, [[{
  return !nelua_stringview_eq(a, b);
}]])
end

function builtins.nelua_cstring2stringview(context)
  context:ensure_include('<string.h>', '<stdint.h>')
  context:ensure_builtin('NULL')
  context:define_function_builtin('nelua_cstring2stringview',
    'static', primtypes.stringview, {{primtypes.cstring, 's'}}, [[{
  if(s == NULL) return (nlstringview){0};
  uintptr_t size = strlen(s);
  if(size == 0) return (nlstringview){0};
  return (nlstringview){(uint8_t*)s, size};
}]])
end

function builtins.nlruntype(context)
  context:ensure_type(primtypes.stringview)
  context:define_builtin('nlruntype', [[
typedef struct nlruntype {
  nlstringview name;
} nlruntype;
]])
end

function builtins.nlruntype_(context, typename)
  local name = 'nlruntype_' .. typename
  if context.usedbuiltins[name] then return name end
  context:ensure_builtin('nlruntype')
  context:ensure_include('<stdint.h>')
  local code = string.format('static nlruntype %s = {{(uint8_t*)"%s", %d}};', name, typename, #typename)
  context:define_builtin(name, code)
  return name
end

function builtins.nelua_narrow_cast_(context, dtype, stype)
  local name = 'nelua_narrow_cast_'..stype.codename..'_'..dtype.codename
  if context.usedbuiltins[name] then return name end
  assert(dtype.is_integral and stype.is_arithmetic)
  local cond
  if stype.is_float then -- float -> integral
    cond = '(('..context:ctype(dtype)..')(x)) != x'
  elseif stype.is_signed and dtype.is_unsigned then -- signed -> unsigned
    cond = 'x < 0'
    if stype.max > dtype.max then
      cond = cond .. ' || x > 0x' .. bn.tohex(dtype.max)
    end
  elseif stype.is_unsigned and dtype.is_signed then -- unsigned -> signed
    cond = 'x > 0x' .. bn.tohex(dtype.max) .. 'U'
  else -- signed -> signed / unsigned -> unsigned
    cond = 'x > 0x' .. bn.tohex(dtype.max) .. (stype.is_unsigned and 'U' or '')
    if stype.is_signed then -- signed -> signed
      cond = cond .. ' || x < ' .. bn.todec(dtype.min)
    end
  end
  context:ensure_builtins('nelua_unlikely', 'nelua_panic_cstring')
  context:define_function_builtin(name, 'static inline', dtype, {{stype, 'x'}}, [[{
  if(nelua_unlikely(]]..cond..[[)) {
    nelua_panic_cstring("narrow casting from ]]..tostring(stype)..[[ to ]]..tostring(dtype)..[[ failed");
  }
  return x;
}]])
  return name
end

function builtins.nelua_lt_(context, ltype, rtype)
  local name = 'nelua_lt_'..ltype.codename..'_'..rtype.codename
  if context.usedbuiltins[name] then return name end
  local code
  if ltype.is_signed and rtype.is_unsigned then
    code = context:emitter_join([[{
  return a < 0 || (]],ltype:unsigned_type(),[[)a < b;
}]])
  else
    assert(ltype.is_unsigned and rtype.is_signed)
    code = context:emitter_join([[{
  return b > 0 && a < (]],rtype:unsigned_type(),[[)b;
}]])
  end
  context:define_function_builtin(name, 'static inline', primtypes.boolean, {{ltype, 'a'}, {rtype, 'b'}}, code)
  return name
end

function builtins.nelua_eq_(context, ltype, rtype)
  if not rtype then
    local type = ltype
    local name = 'nelua_eq_'..type.codename
    if context.usedbuiltins[name] then return name end
    assert(type.is_composite)
    local defemitter = CEmitter(context)
    defemitter:add_ln('{')
    defemitter:inc_indent()
    defemitter:add_indent('return ')
    if type.is_union then
      context:ensure_include('<string.h>')
      defemitter:add('memcmp(&a, &b, sizeof(', type, ')) == 0')
    elseif #type.fields > 0 then
      for i,field in ipairs(type.fields) do
        if i > 1 then
          defemitter:add(' && ')
        end
        if field.type.is_composite then
          local op = context:ensure_builtin('nelua_eq_', field.type)
          defemitter:add(op, '(a.', field.name, ', b.', field.name, ')')
        elseif field.type.is_array then
          context:ensure_include('<string.h>')
          defemitter:add('memcmp(a.', field.name, ', ', 'b.', field.name, ', sizeof(', type, ')) == 0')
        else
          defemitter:add('a.', field.name, ' == ', 'b.', field.name)
        end
      end
    else
      defemitter:add(true)
    end
    defemitter:add_ln(';')
    defemitter:dec_indent()
    defemitter:add_ln('}')
    context:define_function_builtin(name,
      'static inline', primtypes.boolean, {{type, 'a'}, {type, 'b'}},
      defemitter:generate())
    return name
  else
    local name = 'nelua_eq_'..ltype.codename..'_'..rtype.codename
    if context.usedbuiltins[name] then return name end
    assert(ltype.is_integral and ltype.is_signed and rtype.is_unsigned)
    local mtype = primtypes['uint'..math.max(ltype.bitsize, rtype.bitsize)]
    context:define_function_builtin(name,
      'static inline', primtypes.boolean, {{ltype, 'a'}, {rtype, 'b'}}, context:emitter_join([[{
  return (]],mtype,[[)a == (]],mtype,[[)b && a >= 0;
}]]))
    return name
  end
end

function builtins.nelua_idiv_(context, type)
  local name = 'nelua_idiv_'..type.codename
  if context.usedbuiltins[name] then return name end
  assert(type.is_signed)
  local stype, utype = type:signed_type(), type:unsigned_type()
  context:ensure_builtins('nelua_unlikely', 'nelua_panic_cstring')
  context:define_function_builtin(name,
    'static inline', type, {{type, 'a'}, {type, 'b'}}, context:emitter_join([[{
  if(nelua_unlikely(b == -1)) return 0U - (]],utype,[[)a;
  if(nelua_unlikely(b == 0)) nelua_panic_cstring("division by zero");
  ]],stype,[[ q = a / b;
  return q * b == a ? q : q - ((a < 0) ^ (b < 0));
}]]))
  return name
end

function builtins.nelua_imod_(context, type)
  local name = 'nelua_imod_'..type.codename
  if context.usedbuiltins[name] then return name end
  assert(type.is_signed)
  context:ensure_builtins('nelua_unlikely', 'nelua_panic_cstring')
  context:define_function_builtin(name,
    'static inline', type, {{type, 'a'}, {type, 'b'}}, context:emitter_join([[{
  if(nelua_unlikely(b == -1)) return 0;
  if(nelua_unlikely(b == 0)) nelua_panic_cstring("division by zero");
  ]],type,[[ r = a % b;
  return (r != 0 && (a ^ b) < 0) ? r + b : r;
}]]))
  return name
end

function builtins.nelua_shl_(context, type)
  local name = 'nelua_shl_'..type.codename
  if context.usedbuiltins[name] then return name end
  local bitsize, stype, utype = type.bitsize, type:signed_type(), type:unsigned_type()
  context:ensure_builtin('nelua_unlikely')
  context:define_function_builtin(name,
    'static inline', type, {{type, 'a'}, {stype, 'b'}},
    context:emitter_join([[{
  if(nelua_likely(b >= 0 && b < ]],bitsize,[[)) return (]],utype,[[)a << b;
  else if(nelua_unlikely(b < 0 && b > -]],bitsize,[[)) return (]],utype,[[)a >> -b;
  else return 0;
}]]))
  return name
end

function builtins.nelua_shr_(context, type)
  local name = 'nelua_shr_'..type.codename
  if context.usedbuiltins[name] then return name end
  local bitsize, stype, utype = type.bitsize, type:signed_type(), type:unsigned_type()
  context:ensure_builtin('nelua_unlikely')
  context:define_function_builtin(name,
    'static inline', type, {{type, 'a'}, {stype, 'b'}},
    context:emitter_join([[{
  if(nelua_likely(b >= 0 && b < ]],bitsize,[[)) return (]],utype,[[)a >> b;
  else if(nelua_unlikely(b < 0 && b > -]],bitsize,[[)) return (]],utype,[[)a << -b;
  else return 0;
}]]))
  return name
end

function builtins.nelua_asr_(context, type)
  local name = 'nelua_asr_'..type.codename
  if context.usedbuiltins[name] then return name end
  local bitsize = type.bitsize
  context:define_function_builtin(name,
    'static inline', type, {{type, 'a'}, {type:signed_type(), 'b'}},
    context:emitter_join([[{
  if(nelua_likely(b >= 0 && b < ]],bitsize,[[)) return a >> b;
  else if(nelua_unlikely(b >= ]],bitsize,[[)) return a < 0 ? -1 : 0;
  else if(nelua_unlikely(b < 0 && b > -]],bitsize,[[)) return a << -b;
  else return 0;
}]]))
  return name
end

function builtins.nelua_fmod_(context, type)
  local cfmod = type.is_float32 and 'fmodf' or 'fmod'
  local name = 'nelua_'..cfmod
  if context.usedbuiltins[name] then return name end
  context:ensure_include('<math.h>')
  context:ensure_builtin('nelua_unlikely')
  context:define_function_builtin(name,
    'static inline', type, {{type, 'a'}, {type, 'b'}}, context:emitter_join([[{
  ]],type,[[ r = ]],cfmod,[[(a, b);
  if(nelua_unlikely((r > 0 && b < 0) || (r < 0 && b > 0)))
    r += b;
  return r;
}]]))
  return name
end

--------------------------------------------------------------------------------
-- Binary operator builtins

operators["or"] = function(_, emitter, lnode, rnode, lname, rname)
  emitter:add_val2boolean(lname, lnode.attr.type)
  emitter:add_one(' || ')
  emitter:add_val2boolean(rname, rnode.attr.type)
end

operators["and"] = function(_, emitter, lnode, rnode, lname, rname)
  emitter:add_val2boolean(lname, lnode.attr.type)
  emitter:add_one(' && ')
  emitter:add_val2boolean(rname, rnode.attr.type)
end

local function operator_binary_op(op, node, emitter, lnode, rnode, lname, rname)
  local lattr, rattr = lnode.attr, rnode.attr
  local ltype, rtype = lattr.type, rattr.type
  if ltype.is_integral and rtype.is_integral and
     ltype.is_unsigned ~= rtype.is_unsigned and
     not lattr.comptime and not rattr.comptime then
    emitter:add('(',node.attr.type,')(', lname, ' ', op, ' ', rname, ')')
  else
    assert(ltype.is_arithmetic and rtype.is_arithmetic)
    emitter:add(lname, ' ', op, ' ', rname)
  end
end

function operators.bor(...)
  operator_binary_op('|', ...)
end

function operators.bxor(...)
  operator_binary_op('^', ...)
end

function operators.band(...)
  operator_binary_op('&', ...)
end

function operators.add(...)
  operator_binary_op('+', ...)
end

function operators.sub(...)
  operator_binary_op('-', ...)
end

function operators.mul(...)
  operator_binary_op('*', ...)
end

function operators.div(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if not rtype.is_float and not ltype.is_float then
    assert(type.is_float)
    emitter:add(lname, ' / (', type, ')', rname)
  else
    operator_binary_op('/', node, emitter, lnode, rnode, lname, rname)
  end
end

function operators.idiv(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if ltype.is_float or rtype.is_float then
    local floorname = type.is_float32 and 'floorf' or 'floor'
    emitter.context:ensure_include('<math.h>')
    emitter:add(floorname, '(', lname, ' / ', rname, ')')
  elseif type.is_integral and (lnode.attr:is_maybe_negative() or rnode.attr:is_maybe_negative()) then
    local op = emitter.context:ensure_builtin('nelua_idiv_', type)
    emitter:add(op, '(', lname, ', ', rname, ')')
  else
    operator_binary_op('/', node, emitter, lnode, rnode, lname, rname)
  end
end

function operators.tdiv(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if ltype.is_float or rtype.is_float then
    local truncname = type.is_float32 and 'truncf' or 'trunc'
    emitter.context:ensure_include('<math.h>')
    emitter:add(truncname, '(', lname, ' / ', rname, ')')
  else
    operator_binary_op('/', node, emitter, lnode, rnode, lname, rname)
  end
end

function operators.mod(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if ltype.is_float or rtype.is_float then
    local op = emitter.context:ensure_builtin('nelua_fmod_', type)
    emitter:add(op, '(', lname, ', ', rname, ')')
  elseif type.is_integral and (lnode.attr:is_maybe_negative() or rnode.attr:is_maybe_negative()) then
    local op = emitter.context:ensure_builtin('nelua_imod_', type)
    emitter:add(op, '(', lname, ', ', rname, ')')
  else
    operator_binary_op('%', node, emitter, lnode, rnode, lname, rname)
  end
end

function operators.tmod(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if ltype.is_float or rtype.is_float then
    emitter.context:ensure_include('<math.h>')
    local fmodname = type.is_float32 and 'fmodf' or 'fmod'
    emitter:add(fmodname, '(', lname, ', ', rname, ')')
  else
    operator_binary_op('%', node, emitter, lnode, rnode, lname, rname)
  end
end

function operators.shl(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  assert(ltype.is_integral and rtype.is_integral)
  if rnode.attr.comptime and rnode.attr.value >= 0 and rnode.attr.value < ltype.bitsize then
    -- no overflow possible, can use plain C shift
    emitter:add(lname, ' << ', rname)
  else
    local op = emitter.context:ensure_builtin('nelua_shl_', type)
    emitter:add(op, '(', lname, ', ', rname, ')')
  end
end

function operators.shr(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  assert(ltype.is_integral and rtype.is_integral)
  if ltype.is_unsigned and rnode.attr.comptime and rnode.attr.value >= 0 and rnode.attr.value < ltype.bitsize then
    -- no overflow possible, can use plain C shift
    emitter:add(lname, ' >> ', rname)
  else
    local op = emitter.context:ensure_builtin('nelua_shr_', type)
    emitter:add(op, '(', lname, ', ', rname, ')')
  end
end

function operators.asr(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  assert(ltype.is_integral and rtype.is_integral)
  if rnode.attr.comptime and rnode.attr.value >= 0 and rnode.attr.value < ltype.bitsize then
    -- no overflow possible, can use plain C shift
    emitter:add(lname, ' >> ', rname)
  else
    local op = emitter.context:ensure_builtin('nelua_asr_', type)
    emitter:add(op, '(', lname, ', ', rname, ')')
  end
end

function operators.pow(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  local powname = type.is_float32 and 'powf' or 'pow'
  emitter.context:ensure_include('<math.h>')
  emitter:add(powname, '(', lname, ', ', rname, ')')
end

local function needs_signed_unsigned_comparision(lnode, rnode)
  local lattr, rattr = lnode.attr, rnode.attr
  local ltype, rtype = lattr.type, rattr.type
  if not ltype.is_integral or not rtype.is_integral or
     ltype.is_unsigned == rtype.is_unsigned or
     lattr.comptime or rattr.comptime then
    return false
  end
  return true
end

function operators.lt(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if needs_signed_unsigned_comparision(lnode, rnode) then
    local op = emitter.context:ensure_builtin('nelua_lt_', ltype, rtype)
    emitter:add(op, '(', lname, ', ', rname, ')')
  else
    emitter:add(lname, ' < ', rname)
  end
end

function operators.gt(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if needs_signed_unsigned_comparision(lnode, rnode) then
    local op = emitter.context:ensure_builtin('nelua_lt_', rtype, ltype)
    emitter:add(op, '(', rname, ', ', lname, ')')
  else
    emitter:add(lname, ' > ', rname)
  end
end

function operators.le(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if needs_signed_unsigned_comparision(lnode, rnode) then
    local op = emitter.context:ensure_builtin('nelua_lt_', rtype, ltype)
    emitter:add('!', op, '(', rname, ', ', lname, ')')
  else
    emitter:add(lname, ' <= ', rname)
  end
end

function operators.ge(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if needs_signed_unsigned_comparision(lnode, rnode) then
    local op = emitter.context:ensure_builtin('nelua_lt_', ltype, rtype)
    emitter:add('!', op, '(', lname, ', ', rname, ')')
  else
    emitter:add(lname, ' >= ', rname)
  end
end

function operators.eq(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  if (ltype.is_stringview and (rtype.is_stringview or rtype.is_cstring)) or
     (ltype.is_cstring and rtype.is_stringview) then
    emitter:add_builtin('nelua_stringview_eq')
    emitter:add('(')
    emitter:add_val2type(primtypes.stringview, lname, ltype)
    emitter:add(', ')
    emitter:add_val2type(primtypes.stringview, rname, rtype)
    emitter:add(')')
  elseif ltype.is_composite or rtype.is_composite then
    if ltype == rtype then
      local op = emitter.context:ensure_builtin('nelua_eq_', ltype)
      emitter:add(op, '(', lname, ', ', rname, ')')
    else
      emitter:add(false)
    end
  elseif ltype.is_array then
    assert(ltype == rtype)
    emitter.context:ensure_include('<string.h>')
    emitter:add('memcmp(&', lname, ', &', rname, ', sizeof(', ltype, ')) == 0')
  elseif needs_signed_unsigned_comparision(lnode, rnode) then
    if not ltype.is_unsigned then
      local op = emitter.context:ensure_builtin('nelua_eq_', ltype, rtype)
      emitter:add(op, '(', lname, ', ', rname, ')')
    else
      local op = emitter.context:ensure_builtin('nelua_eq_', rtype, ltype)
      emitter:add(op, '(', rname, ', ', lname, ')')
    end
  elseif ltype.is_niltype or rtype.is_niltype then
    emitter:add('({(void)', lname, '; (void)', rname, '; ', ltype == rtype, ';})')
  else
    emitter:add(lname, ' == ')
    if ltype ~= rtype then
      emitter:add_val2type(ltype, rname, rtype)
    else
      emitter:add(rname)
    end
  end
end

function operators.ne(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  if (ltype.is_stringview and (rtype.is_stringview or rtype.is_cstring)) or
     (ltype.is_cstring and rtype.is_stringview) then
    emitter:add_builtin('nelua_stringview_ne')
    emitter:add('(')
    emitter:add_val2type(primtypes.stringview, lname, ltype)
    emitter:add(', ')
    emitter:add_val2type(primtypes.stringview, rname, rtype)
    emitter:add(')')
  elseif ltype.is_composite then
    if ltype == rtype then
      local op = emitter.context:ensure_builtin('nelua_eq_', ltype)
      emitter:add('!', op, '(', lname, ', ', rname, ')')
    else
      emitter:add(true)
    end
  elseif ltype.is_array then
    assert(ltype == rtype)
    emitter.context:ensure_include('<string.h>')
    emitter:add('memcmp(&', lname, ', &', rname, ', sizeof(', ltype, ')) != 0')
  elseif needs_signed_unsigned_comparision(lnode, rnode) then
    if not ltype.is_unsigned then
      local op = emitter.context:ensure_builtin('nelua_eq_', ltype, rtype)
      emitter:add('!', op, '(', lname, ', ', rname, ')')
    else
      local op = emitter.context:ensure_builtin('nelua_eq_', rtype, ltype)
      emitter:add('!', op, '(', rname, ', ', lname, ')')
    end
  elseif ltype.is_niltype or rtype.is_niltype then
    emitter:add('({(void)', lname, '; (void)', rname, '; ', ltype ~= rtype, ';})')
  else
    emitter:add(lname, ' != ')
    if ltype ~= rtype then
      emitter:add_val2type(ltype, rname, rtype)
    else
      emitter:add(rname)
    end
  end
end

--------------------------------------------------------------------------------
-- Unary operator builtins

operators["not"] = function(_, emitter, argnode)
  emitter:add('!')
  emitter:add_val2boolean(argnode)
end

function operators.unm(_, emitter, argnode)
  assert(argnode.attr.type.is_arithmetic)
  emitter:add('-', argnode)
end

function operators.bnot(_, emitter, argnode)
  assert(argnode.attr.type.is_integral)
  emitter:add('~', argnode)
end

function operators.ref(_, emitter, argnode)
  assert(argnode.attr.lvalue)
  emitter:add('&', argnode)
end

function operators.deref(_, emitter, argnode)
  assert(argnode.attr.type.is_pointer)
  emitter:add('*')
  local indextype = argnode.attr.type
  if indextype.subtype.is_array and indextype.subtype.length == 0 then
    -- use pointer to the actual subtype structure, because its type may have been simplified
    emitter:add('(',indextype.subtype,'*)')
  end
  if argnode.checkderef then
    local op = emitter.context:ensure_builtin('nelua_assert_deref_', argnode.attr.type)
    emitter:add(op, '(', argnode, ')')
  else
    emitter:add(argnode)
  end
end

function operators.len(_, emitter, argnode)
  local argattr = argnode.attr
  local type = argattr.type
  if type.is_stringview then
    emitter:add('((',primtypes.isize,')(', argnode, ').size)')
  elseif type.is_cstring then
    emitter.context:ensure_includes('<string.h>')
    emitter:add('((',primtypes.isize,')strlen(', argnode, '))')
  elseif type.is_type then
    emitter:add('sizeof(', argattr.value, ')')
  else --luacov:disable
    argnode:errorf('not implemented')
  end --luacov:enable
end

--------------------------------------------------------------------------------
-- Inline builtins

function inlines.assert(context, node)
  local builtintype = node.attr.builtintype
  local argattrs = builtintype.argattrs
  local funcname = context:genuniquename('nelua_assert_line')
  local emitter = CEmitter(context)
  context:ensure_includes('<stdio.h>')
  context:ensure_builtins('nelua_unlikely', 'nelua_abort')
  local nargs = #argattrs
  local qualifier = 'static inline'
  local assertmsg = 'assertion failed!'
  local condtype = nargs > 0 and argattrs[1].type or primtypes.void
  local rettype = builtintype.rettypes[1] or primtypes.void
  local wherenode = nargs > 0 and node[1][1] or node
  local where = wherenode:format_message('runtime error', assertmsg)
  emitter:add_ln('{')
  if nargs == 2 then
    local pos = where:find(assertmsg)
    local msg1, msg1len = emitter:cstring_literal(where:sub(1, pos-1))
    local msg2, msg2len = emitter:cstring_literal(where:sub(pos + #assertmsg))
    emitter:add([[
  if(nelua_unlikely(!]]) emitter:add_val2boolean('cond', condtype) emitter:add([[)) {
    fwrite(]],msg1,[[, 1, ]],msg1len,[[, stderr);
    fwrite(msg.data, msg.size, 1, stderr);
    fwrite(]],msg2,[[, 1, ]],msg2len,[[, stderr);
    nelua_abort();
  }
]])
  elseif nargs == 1 then
    local msg, msglen = emitter:cstring_literal(where)
    emitter:add([[
  if(nelua_unlikely(!]]) emitter:add_val2boolean('cond', condtype) emitter:add([[)) {
    fwrite(]],msg,[[, 1, ]],msglen,[[, stderr);
    nelua_abort();
  }
]])
  else -- nargs == 0
    local msg, msglen = emitter:cstring_literal(where)
    context:ensure_builtin('nelua_noreturn')
    qualifier = 'static inline nelua_noreturn'
    emitter:add([[
  fwrite(]],msg,[[, 1, ]],msglen,[[, stderr);
  nelua_abort();
]])
  end
  if rettype ~= primtypes.void then
    emitter:add_ln('  return cond;')
  end
  emitter:add('}')
  context:define_function_builtin(funcname, qualifier, rettype, argattrs, emitter:generate())
  return funcname
end

function inlines.check(context, node)
  return inlines.assert(context, node)
end

function inlines.print(context, node)
  context:ensure_include('<stdio.h>')
  local argtypes = node.attr.builtintype.argtypes

  -- compute args hash
  local printhash = {}
  for i,argtype in ipairs(argtypes) do
    printhash[i] = argtype.codename
  end
  printhash = table.concat(printhash,' ')

  local funcname = context.printcache[printhash]
  if funcname then
    return funcname
  end

  funcname = context:genuniquename('nelua_print')

  -- function declaration
  local decemitter = CEmitter(context)
  decemitter:add('void ', funcname, '(')
  for i,argtype in ipairs(argtypes) do
    if i>1 then decemitter:add(', ') end
    decemitter:add(argtype, ' a', i)
  end
  decemitter:add(')')
  local heading = decemitter:generate()
  context:add_declaration('static '..heading..';\n', funcname)

  -- function body
  local defemitter = CEmitter(context)
  defemitter:add(heading)
  defemitter:add_ln(' {')
  defemitter:inc_indent()
  for i,argtype in ipairs(argtypes) do
    defemitter:add_indent()
    if i > 1 then
      defemitter:add_ln("fputc('\\t', stdout);")
      defemitter:add_indent()
    end
    if argtype.is_stringview or argtype.is_string then
      defemitter:add_ln('if(a',i,'.size > 0) {')
      defemitter:inc_indent()
      defemitter:add_indent_ln('fwrite(a',i,'.data, 1, a',i,'.size, stdout);')
      defemitter:dec_indent()
      defemitter:add_indent_ln('}')
    elseif argtype.is_cstring then
      defemitter:add_ln('fputs(a',i,', stdout);')
    elseif argtype.is_niltype then
      defemitter:add_ln('fputs("nil", stdout);')
    elseif argtype.is_boolean then
      defemitter:add_ln('fputs(a',i,' ? "true" : "false", stdout);')
    elseif argtype.is_nilptr then
      defemitter:add_ln('fputs("(null)", stdout);')
    elseif argtype.is_pointer then
      context:ensure_include('<stdint.h>')
      context:ensure_include('<inttypes.h>')
      context:ensure_builtin('NULL')
      defemitter:add_ln('if(a',i,' != NULL) {')
        defemitter:inc_indent()
        defemitter:add_indent_ln('fprintf(stdout, "0x%" PRIxPTR, (intptr_t)a',i,');')
        defemitter:dec_indent()
      defemitter:add_indent_ln('} else {')
        defemitter:inc_indent()
        defemitter:add_indent_ln('fputs("(null)", stdout);')
        defemitter:dec_indent()
      defemitter:add_indent_ln('}')
    elseif argtype.is_arithmetic then
      context:ensure_include('<inttypes.h>')
      local ty = node:assertraisef(argtype, 'type is not defined in AST node')
      if ty.is_enum then
        ty = ty.subtype
      end
      local tyformat = cdefs.types_printf_format[ty.codename]
      node:assertraisef(tyformat, 'invalid type "%s" for printf format', ty)
      defemitter:add_ln('fprintf(stdout, ', tyformat,', a',i,');')
    else --luacov:disable
      node:raisef('cannot handle type "%s" in print', argtype)
    end --luacov:enable
  end
  defemitter:add_indent_ln([[fputc('\n', stdout);]])
  defemitter:add_indent_ln('fflush(stdout);')
  defemitter:add_ln('}')
  context:add_definition(defemitter:generate(), funcname)
  context.printcache[printhash] = funcname
  return funcname
end

function inlines.type(context, node, emitter)
  local argnode = node[1][1]
  local type = argnode.attr.type
  local typename
  if type.is_arithmetic then
    typename = 'number'
  elseif type.is_nilptr then
    typename = 'pointer'
  elseif type.is_stringy then
    typename = 'string'
  elseif type.is_any then --luacov:disable
    node:raisef('type() for any values not implemented yet')
  else --luacov:enable
    typename = type.name
  end
  context:ensure_builtin('nlruntype_', typename)
  emitter:add('nlruntype_',typename,'.name')
end

function inlines.likely(context)
  return context:ensure_builtin('nelua_likely')
end

function inlines.unlikely(context)
  return context:ensure_builtin('nelua_unlikely')
end

function inlines.error(context)
  return context:ensure_builtin('nelua_panic_stringview')
end

function inlines.warn(context)
  return context:ensure_builtin('nelua_warn')
end

function inlines.panic(context)
  return context:ensure_builtin('nelua_panic_stringview')
end

function inlines.require(context, node, emitter)
  local attr = node.attr
  if attr.alreadyrequired then
    return
  end
  local ast = attr.loadedast
  assert(not attr.runtime_require and ast)
  local bracepos = emitter:get_pos()
  emitter:add_indent_ln("{ /* require '", attr.requirename, "' */")
  local lastpos = emitter:get_pos()
  context:push_scope(context.rootscope)
  emitter:add(ast)
  context:pop_scope()
  if emitter:get_pos() == lastpos then
    emitter:remove_until_pos(bracepos)
  else
    emitter:add_indent_ln('}')
  end
end

return cbuiltins
