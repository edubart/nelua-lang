local cdefs = require 'nelua.cdefs'
local CEmitter = require 'nelua.cemitter'
local primtypes = require 'nelua.typedefs'.primtypes
local config = require 'nelua.configer'.get()
local bn = require 'nelua.utils.bn'

local cbuiltins = {}

local builtins = {}
cbuiltins.builtins = builtins

local function define_builtin(context, name, deccode, defcode)
  if deccode then
    context:add_declaration(deccode)
  end
  if defcode then
    context:add_definition(defcode)
  end
  context.usedbuiltins[name] = true
end

local function define_inline_builtin(context, name, ret, args, body)
  context:add_declaration('static ' .. ret .. ' ' .. name .. args .. ';\n')
  context:add_definition('inline ' .. ret .. ' ' .. name .. args .. ' ' .. body .. '\n')
  context.usedbuiltins[name] = true
end

-- macros
function builtins.nelua_likely(context)
  define_builtin(context, 'nelua_likely',
[[#ifdef __GNUC__
#define nelua_likely(x) __builtin_expect(x, 1)
#define nelua_unlikely(x) __builtin_expect(x, 0)
#else
#define nelua_likely(x) (x)
#define nelua_unlikely(x) (x)
#endif
]])
end

function builtins.nelua_unlikely(context)
  context:ensure_runtime_builtin('nelua_likely')
end

function builtins.nelua_noinline(context)
  define_builtin(context, 'nelua_noinline',
    "#define nelua_noinline __attribute__((noinline))\n")
end

function builtins.nelua_noreturn(context)
  define_builtin(context, 'nelua_noreturn',
    "#define nelua_noreturn __attribute__((noreturn))\n")
end

-- nil
function builtins.nlniltype(context)
  define_builtin(context, 'nlniltype', "typedef void* nlniltype;\n")
end

function builtins.nlunusedvar(context)
  define_builtin(context, 'nlunusedvar', "typedef void* nlunusedvar;\n")
end

-- panic
function builtins.nelua_panic_cstring(context)
  context:add_include('<stdlib.h>')
  context:add_include('<stdio.h>')
  context:ensure_runtime_builtin('nelua_noreturn')
  local abort = config.no_abort and 'exit(-1)' or 'abort()'
  define_builtin(context, 'nelua_panic_cstring',
    'static nelua_noreturn void nelua_panic_cstring(char* s);\n',
    [[void nelua_panic_cstring(char *s) {
  fprintf(stderr, "%s\n", s);
  ]]..abort..[[;
}
]])
end

function builtins.nelua_panic_stringview(context)
  context:add_include('<stdlib.h>')
  context:add_include('<stdio.h>')
  context:ensure_runtime_builtin('nelua_noreturn')
  context:ctype(primtypes.stringview)
  local abort = config.no_abort and 'exit(-1)' or 'abort()'
  define_builtin(context, 'nelua_panic_stringview',
    'static nelua_noreturn void nelua_panic_stringview(nlstringview s);\n',
    [[void nelua_panic_stringview(nlstringview s) {
  if(s.data && s.size > 0) {
    fprintf(stderr, "%s\n", (char*)s.data);
  }
  ]]..abort..[[;
}
]])
end

-- assert
function builtins.nelua_assert(context)
  context:ensure_runtime_builtin('nelua_panic_cstring')
  context:ensure_runtime_builtin('nelua_unlikely')
  define_builtin(context, 'nelua_assert',
    'static void nelua_assert(bool cond);\n',
    [[inline void nelua_assert(bool cond) {
  if(nelua_unlikely(!cond)) {
    nelua_panic_cstring("assertion failed!");
  }
}
]])
end

function builtins.nelua_assert_stringview(context)
  context:ensure_runtime_builtin('nelua_panic_stringview')
  context:ensure_runtime_builtin('nelua_unlikely')
  context:ctype(primtypes.stringview)
  define_builtin(context, 'nelua_assert_stringview',
    'static void nelua_assert_stringview(bool cond, nlstringview s);\n',
    [[inline void nelua_assert_stringview(bool cond, nlstringview s) {
  if(nelua_unlikely(!cond)) {
    nelua_panic_stringview(s);
  }
}
]])
end

function builtins.nelua_assert_bounds_(context, indextype)
  local name = 'nelua_assert_bounds_' .. indextype.name
  if context.usedbuiltins[name] then return name end
  local indexctype = context:ctype(indextype)
  context:ensure_runtime_builtin('nelua_panic_cstring')
  context:ensure_runtime_builtin('nelua_unlikely')
  local cond = '(uintptr_t)index >= len'
  if not indextype.is_unsigned then
    cond = cond .. ' || index < 0'
  end
  define_inline_builtin(context, name,
    indexctype,
    string.format('(%s index, uintptr_t len)', indexctype),
    [[{
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
  local indexctype = context:ctype(indextype)
  context:ensure_runtime_builtin('nelua_panic_cstring')
  context:ensure_runtime_builtin('nelua_unlikely')
  define_inline_builtin(context, name,
    indexctype,
    string.format('(%s p)', indexctype), [[{
  if(nelua_unlikely(p == NULL)) {
    nelua_panic_cstring("attempt to dereference a null pointer");
  }
  return p;
}]])
  return name
end

function builtins.nelua_warn(context)
  context:add_include('<stdio.h>')
  context:ctype(primtypes.stringview)
  define_inline_builtin(context, 'nelua_warn',
    'void', '(nlstringview s)', [[{
  if(s.data && s.size > 0) {
    fprintf(stderr, "%s\n", (char*)s.data);
  }
}]])
end

-- string
function builtins.nelua_stringview_eq(context)
  context:add_include('<string.h>')
  context:ctype(primtypes.stringview)
  define_inline_builtin(context,'nelua_stringview_eq',
    'bool', '(nlstringview a, nlstringview b)', [[{
  return a.size == b.size && (a.data == b.data || a.size == 0 || memcmp(a.data, b.data, a.size) == 0);
}]])
end

function builtins.nelua_stringview_ne(context)
  context:ensure_runtime_builtin('nelua_stringview_eq')
  define_inline_builtin(context, 'nelua_stringview_ne',
    'bool', '(nlstringview a, nlstringview b)', [[{
  return !nelua_stringview_eq(a, b);
}]])
end

function builtins.nelua_cstring2stringview(context)
  context:add_include('<string.h>')
  context:ctype(primtypes.stringview)
  define_inline_builtin(context, 'nelua_cstring2stringview',
    'nlstringview', '(char *s)', [[{
  if(s == NULL) return (nlstringview){0};
  uintptr_t size = strlen(s);
  if(size == 0) return (nlstringview){0};
  return (nlstringview){s, size};
}]])
end

-- runtime type
function builtins.nlruntype(context)
  context:ctype(primtypes.stringview)
  define_builtin(context, 'nlruntype', [[typedef struct nlruntype {
  nlstringview name;
} nlruntype;
]])
end

function builtins.nlruntype_(context, typename)
  local name = 'nlruntype_' .. typename
  if context.usedbuiltins[name] then return name end
  context:ctype(primtypes.stringview)
  context:ensure_runtime_builtin('nlruntype')
  local code = string.format('static nlruntype %s ='..
    '{ {"%s", %d} };\n',
    name, typename, #typename)
  define_builtin(context, name, code)
  return name
end

-- any
function builtins.nlany(context)
  context:ensure_runtime_builtin('nlniltype')
  context:ensure_runtime_builtin('nlruntype')
  define_builtin(context, 'nlany', [[typedef struct nlany {
  nlruntype *type;
  union {
    intptr_t _nlisize;
    int8_t _nlint8;
    int16_t _nlint16;
    int32_t _nlint32;
    int64_t _nlint64;
    uintptr_t _nlusize;
    uint8_t _nluint8;
    uint16_t _nluint16;
    uint32_t _nluint32;
    uint64_t _nluint64;
    float _nlfloat32;
    double _nlfloat64;
    bool _nlboolean;
    nlstringview _nlstringview;
    char* _nlcstring;
    void* _nlpointer;
    char _nlcchar;
    signed char _nlcschar;
    short _nlcshort;
    int _nlcint;
    long _nlclong;
    long long _nlclonglong;
    ptrdiff_t _nlcptrdiff;
    unsigned char _nlcuchar;
    unsigned short _nlcushort;
    unsigned int _nlcuint;
    unsigned long _nlculong;
    unsigned long long _nlculonglong;
    size_t _nlcsize;
    nlniltype _nlniltype;
  } value;
} nlany;
]])
end

function builtins.nlany_to_(context, type)
  local typename = context:typename(type)
  local name = 'nlany_to_' .. typename
  if context.usedbuiltins[name] then return name end
  local ctype = context:ctype(type)
  context:ensure_runtime_builtin('nlany')
  context:ensure_runtime_builtin('nlruntype_', typename)
  if type.is_boolean then
    context:ensure_runtime_builtin('nlruntype_', 'nlpointer')
    define_inline_builtin(context, name, ctype, '(nlany a)',
      string.format([[{
  if(a.type == &nlruntype_nlboolean) {
    return a.value._nlboolean;
  } else if(a.type == &nlruntype_nlpointer) {
    return a.value._nlpointer != NULL;
  } else {
    return a.type != NULL;
  }
}]], typename, typename))
  else
    context:ensure_runtime_builtin('nelua_unlikely')
    context:ensure_runtime_builtin('nelua_panic_cstring')
    define_inline_builtin(context, name, ctype, '(nlany a)',
      string.format([[{
  if(nelua_unlikely(a.type != &nlruntype_%s)) {
    nelua_panic_cstring("type check fail");
  }
  return a.value._%s;
}]], typename, typename))
  end
  return name
end

-- writing
function builtins.nelua_stdout_write_stringview(context)
  context:add_include('<stdio.h>')
  define_inline_builtin(context, 'nelua_stdout_write_stringview',
    'void', '(nlstringview s)', [[{
  if(s.data && s.size > 0) {
    fwrite((char*)s.data, s.size, 1, stdout);
  }
}]])
end

function builtins.nelua_stdout_write_any(context)
  context:add_include('<stdio.h>')
  context:add_include('<inttypes.h>')
  context:ensure_runtime_builtin('nlruntype_', 'nlboolean')
  context:ensure_runtime_builtin('nlruntype_', 'nlisize')
  context:ensure_runtime_builtin('nlruntype_', 'nlusize')
  context:ensure_runtime_builtin('nlruntype_', 'nlint8')
  context:ensure_runtime_builtin('nlruntype_', 'nlint16')
  context:ensure_runtime_builtin('nlruntype_', 'nlint32')
  context:ensure_runtime_builtin('nlruntype_', 'nlint64')
  context:ensure_runtime_builtin('nlruntype_', 'nluint8')
  context:ensure_runtime_builtin('nlruntype_', 'nluint16')
  context:ensure_runtime_builtin('nlruntype_', 'nluint32')
  context:ensure_runtime_builtin('nlruntype_', 'nluint64')
  context:ensure_runtime_builtin('nlruntype_', 'nlfloat32')
  context:ensure_runtime_builtin('nlruntype_', 'nlfloat64')
  context:ensure_runtime_builtin('nlruntype_', 'nlpointer')
  context:ensure_runtime_builtin('nelua_panic_cstring')
  define_inline_builtin(context, 'nelua_stdout_write_any',
    'void', '(nlany a)', [[{
  if(a.type == &nlruntype_nlboolean) {
    printf(a.value._nlboolean ? "true" : "false");
  } else if(a.type == &nlruntype_nlisize) {
    printf("%" PRIiPTR, a.value._nlisize);
  } else if(a.type == &nlruntype_nlusize) {
    printf("%" PRIuPTR, a.value._nlusize);
  } else if(a.type == &nlruntype_nlint8) {
    printf("%" PRIi8, a.value._nlint8);
  } else if(a.type == &nlruntype_nlint16) {
    printf("%" PRIi16, a.value._nlint16);
  } else if(a.type == &nlruntype_nlint32) {
    printf("%" PRIi32, a.value._nlint32);
  } else if(a.type == &nlruntype_nlint64) {
    printf("%" PRIi64, a.value._nlint64);
  } else if(a.type == &nlruntype_nluint8) {
    printf("%" PRIu8, a.value._nluint8);
  } else if(a.type == &nlruntype_nluint16) {
    printf("%" PRIu16, a.value._nluint16);
  } else if(a.type == &nlruntype_nluint32) {
    printf("%" PRIu32, a.value._nluint32);
  } else if(a.type == &nlruntype_nluint64) {
    printf("%" PRIu64, a.value._nluint64);
  } else if(a.type == &nlruntype_nlfloat32) {
    printf("%f", a.value._nlfloat32);
  } else if(a.type == &nlruntype_nlfloat64) {
    printf("%lf", a.value._nlfloat64);
  } else if(a.type == &nlruntype_nlpointer) {
    printf("%p", a.value._nlpointer);
  } else if(a.type == NULL) {
    printf("nil");
  } else {
    nelua_panic_cstring("invalid type for nelua_fwrite_any");
  }
}]])
end

function builtins.nelua_narrow_cast_(context, dtype, stype)
  assert(dtype.is_integral and stype.is_arithmetic)
  local dctype = context:ctype(dtype)
  local sctype = context:ctype(stype)
  local name = string.format('nelua_narrow_cast_%s%s', stype.name, dtype.name)
  if context.usedbuiltins[name] then return name end
  context:ensure_runtime_builtin('nelua_unlikely')
  context:ensure_runtime_builtin('nelua_panic_cstring')
  local cond
  assert(dtype.is_integral)
  if stype.is_float then -- float -> integral
    cond = string.format('((%s)(x)) != x', dctype)
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

  local body = string.format([[{
  if(nelua_unlikely(%s)) {
    nelua_panic_cstring("narrow casting from %s to %s failed");
  }
  return x;
}]], cond, stype.name, dtype.name)

  define_inline_builtin(context, name,
    dctype,
    string.format('(%s x)', sctype),
    body)
  return name
end

function builtins.nelua_lt_(context, ltype, rtype)
  if ltype.is_signed and rtype.is_unsigned then
    local name = string.format('nelua_lt_i%du%d', ltype.bitsize, rtype.bitsize)
    if context.usedbuiltins[name] then return name end
    define_inline_builtin(context, name,
      'bool',
      string.format('(int%d_t a, uint%d_t b)', ltype.bitsize, rtype.bitsize),
      string.format("{ return a < 0 || (uint%d_t)a < b; }", ltype.bitsize))
    return name
  else
    assert(ltype.is_unsigned and rtype.is_signed)
    local name = string.format('nelua_lt_u%di%d', ltype.bitsize, rtype.bitsize)
    if context.usedbuiltins[name] then return name end
    define_inline_builtin(context, name,
      'bool',
      string.format('(uint%d_t a, int%d_t b)', ltype.bitsize, rtype.bitsize),
      string.format("{ return b > 0 && a < (uint%d_t)b; }", rtype.bitsize))
    return name
  end
end

function builtins.nelua_eq_(context, ltype, rtype)
  if not rtype then
    local type = ltype
    assert(type.is_record)
    local name = string.format('nelua_eq_%s', type.codename)
    if context.usedbuiltins[name] then return name end
    local ctype = context:ctype(type)
    local defemitter = CEmitter(context)
    defemitter:add_ln('{')
    defemitter:inc_indent()
    defemitter:add_indent('return ')
    if #type.fields > 0 then
      for i,field in ipairs(type.fields) do
        if i > 1 then
          defemitter:add(' && ')
        end
        if field.type.is_record then
          local op = context:ensure_runtime_builtin('nelua_eq_', field.type)
          defemitter:add(op, '(a.', field.name, ', b.', field.name, ')')
        elseif field.type.is_array then
          context:add_include('<string.h>')
          defemitter:add('memcmp(a.', field.name, ', ', 'b.', field.name, ', sizeof(', type, ')) == 0')
        else
          defemitter:add('a.', field.name, ' == ', 'b.', field.name)
        end
      end
    else
      defemitter:add('true')
    end
    defemitter:add_ln(';')
    defemitter:dec_indent()
    defemitter:add_ln('}')
    define_inline_builtin(context, name,
      'bool',
      string.format('(%s a, %s b)', ctype, ctype),
      defemitter:generate())
    return name
  else
    assert(ltype.is_integral and ltype.is_signed and rtype.is_unsigned)
    local name = string.format('nelua_eq_i%du%d', ltype.bitsize, rtype.bitsize)
    local maxbitsize = math.max(ltype.bitsize, rtype.bitsize)
    if context.usedbuiltins[name] then return name end
    define_inline_builtin(context, name,
      'bool',
      string.format('(int%d_t a, uint%d_t b)', ltype.bitsize, rtype.bitsize),
      string.format("{ return (uint%d_t)a == (uint%d_t)b && a >= 0; }",
        maxbitsize, maxbitsize, ltype.bitsize))
    return name
  end
end


function builtins.nelua_idiv_(context, type)
  local name = string.format('nelua_idiv_i%d', type.bitsize)
  if context.usedbuiltins[name] then return name end
  local ictype = string.format('int%d_t', type.bitsize)
  local uctype = string.format('uint%d_t', type.bitsize)
  context:ensure_runtime_builtin('nelua_unlikely')
  define_inline_builtin(context, name,
    ictype,
    string.format('(%s a, %s b)', ictype, ictype),
    string.format([[{
  if(nelua_unlikely(b == -1)) return 0U - (%s)a;
  %s d = a / b;
  return d * b == a ? d : d - ((a < 0) ^ (b < 0));
}]], uctype, ictype))
  return name
end

function builtins.nelua_imod_(context, type)
  local name = string.format('nelua_imod_i%d', type.bitsize)
  if context.usedbuiltins[name] then return name end
  local ictype = string.format('int%d_t', type.bitsize)
  context:ensure_runtime_builtin('nelua_unlikely')
  define_inline_builtin(context, name,
    ictype,
    string.format('(%s a, %s b)', ictype, ictype),
    string.format([[{
  if(nelua_unlikely(b == -1)) return 0;
  %s r = a %% b;
  return (r != 0 && (a ^ b) < 0) ? r + b : r;
}]], ictype))
  return name
end

function builtins.nelua_shl_(context, type)
  local ctype = context:ctype(type)
  local uctype = context:ctype(primtypes['uint'..type.bitsize])
  local intctype = context:ctype(primtypes.integer)
  local shlname = string.format('nelua_shl_%s', tostring(type))
  if context.usedbuiltins[shlname] then return shlname end
  context:ensure_runtime_builtin('nelua_unlikely')
  define_inline_builtin(context, shlname,
    ctype,
    string.format('(%s a, %s b)', ctype, intctype),
    string.format([[{
  if(nelua_unlikely(b >= %d)) return 0;
  else if(nelua_unlikely(b < 0)) return nelua_shr_%s(a, -b);
  else return (%s)a << b;
}]], type.bitsize, tostring(type), uctype))
  local shrname = string.format('nelua_shr_%s', tostring(type))
  define_inline_builtin(context, shrname,
    ctype,
    string.format('(%s a, %s b)', ctype, intctype),
    string.format([[{
  if(nelua_unlikely(b >= %d)) return 0;
  else if(nelua_unlikely(b < 0)) return nelua_shl_%s(a, -b);
  else return (%s)a >> b;
}]], type.bitsize, tostring(type), uctype))
  return shlname
end

function builtins.nelua_shr_(context, type)
  context:ensure_runtime_builtin('nelua_shl_', type)
  return string.format('nelua_shr_%s', tostring(type))
end

function builtins.nelua_fmod_(context, type)
  local ctype = context:ctype(type)
  local cfmod = type.is_float32 and 'fmodf' or 'fmod'
  local name = 'nelua_' .. cfmod
  if context.usedbuiltins[name] then return name end
  context:ensure_runtime_builtin('nelua_unlikely')
  context:add_include('<math.h>')
  define_inline_builtin(context, name,
    ctype,
    string.format('(%s a, %s b)', ctype, ctype),
    string.format([[{
  %s r = %s(a, b);
  if(nelua_unlikely((r > 0 && b < 0) || (r < 0 && b > 0)))
    r += b;
  return r;
}]], ctype, cfmod))
  return name
end

local operators = {}
cbuiltins.operators = operators

function operators.div(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  if ltype.is_arithmetic and rtype.is_arithmetic then
    if not rtype.is_float and not ltype.is_float then
      assert(type.is_float)
      emitter:add(lname, ' / (', type, ')', rname)
    else
      emitter:add(lname, ' / ', rname)
    end
  else --luacov:disable
    node:errorf('not implemented')
  end --luacov:enable
end

function operators.idiv(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  if ltype.is_arithmetic and rtype.is_arithmetic then
    if ltype.is_float or rtype.is_float then
      local floorname = type.is_float32 and 'floorf' or 'floor'
      emitter.context:add_include('<math.h>')
      emitter:add(floorname, '(', lname, ' / ', rname, ')')
    elseif type.is_integral and (lnode.attr:is_maybe_negative() or rnode.attr:is_maybe_negative()) then
      local op = emitter.context:ensure_runtime_builtin('nelua_idiv_', type)
      emitter:add(op, '(', lname, ', ', rname, ')')
    else
      emitter:add(lname, ' / ', rname)
    end
  else --luacov:disable
    node:errorf('not implemented')
  end --luacov:enable
end

function operators.mod(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  if ltype.is_arithmetic and rtype.is_arithmetic then
    if ltype.is_float or rtype.is_float then
      local op = emitter.context:ensure_runtime_builtin('nelua_fmod_', type)
      emitter:add(op, '(', lname, ', ', rname, ')')
    elseif type.is_integral and (ltype.is_signed or rtype.is_signed) then
      local op = emitter.context:ensure_runtime_builtin('nelua_imod_', type)
      emitter:add(op, '(', lname, ', ', rname, ')')
    else
      emitter:add(lname, ' % ', rname)
    end
  else --luacov:disable
    node:errorf('not implemented')
  end --luacov:enable
end

function operators.shl(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  if ltype.is_arithmetic and rtype.is_arithmetic then
    assert(ltype.is_integral and rtype.is_integral)
    local op = emitter.context:ensure_runtime_builtin('nelua_shl_', type)
    emitter:add(op, '(', lname, ', ', rname, ')')
  else --luacov:disable
    node:errorf('not implemented')
  end --luacov:enable
end

function operators.shr(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  if ltype.is_arithmetic and rtype.is_arithmetic then
    assert(ltype.is_integral and rtype.is_integral)
    local op = emitter.context:ensure_runtime_builtin('nelua_shr_', type)
    emitter:add(op, '(', lname, ', ', rname, ')')
  else --luacov:disable
    node:errorf('not implemented')
  end --luacov:enable
end

function operators.pow(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  if ltype.is_arithmetic and rtype.is_arithmetic then
    local powname = type.is_float32 and 'powf' or 'pow'
    emitter.context:add_include('<math.h>')
    emitter:add(powname, '(', lname, ', ', rname, ')')
  else --luacov:disable
    node:errorf('not implemented')
  end --luacov:enable
end

local function needs_signed_unsigned_comparision(lnode, rnode)
  local lattr, rattr = lnode.attr, rnode.attr
  local ltype, rtype = lattr.type, rattr.type
  if not ltype.is_integral or not rtype.is_integral then
    return false
  end
  if ltype.is_unsigned == rtype.is_unsigned then
    return false
  end
  if lattr.comptime or rattr.comptime then
    return false
  end
  return true
end

function operators.lt(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  if needs_signed_unsigned_comparision(lnode, rnode) then
    local op = emitter.context:ensure_runtime_builtin('nelua_lt_', ltype, rtype)
    emitter:add(op, '(', lname, ', ', rname, ')')
  else
    emitter:add(lname, ' < ', rname)
  end
end

function operators.gt(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  if needs_signed_unsigned_comparision(lnode, rnode) then
    local op = emitter.context:ensure_runtime_builtin('nelua_lt_', rtype, ltype)
    emitter:add(op, '(', rname, ', ', lname, ')')
  else
    emitter:add(lname, ' > ', rname)
  end
end

function operators.le(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  if needs_signed_unsigned_comparision(lnode, rnode) then
    local op = emitter.context:ensure_runtime_builtin('nelua_lt_', rtype, ltype)
    emitter:add('!', op, '(', rname, ', ', lname, ')')
  else
    emitter:add(lname, ' <= ', rname)
  end
end

function operators.ge(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  if needs_signed_unsigned_comparision(lnode, rnode) then
    local op = emitter.context:ensure_runtime_builtin('nelua_lt_', ltype, rtype)
    emitter:add('!', op, '(', lname, ', ', rname, ')')
  else
    emitter:add(lname, ' >= ', rname)
  end
end

function operators.eq(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  if ltype.is_stringview then
    assert(rtype.is_stringview)
    emitter:add_builtin('nelua_stringview_eq')
    emitter:add('(', lname, ', ', rname, ')')
  elseif ltype.is_record then
    assert(ltype == rtype)
    local op = emitter.context:ensure_runtime_builtin('nelua_eq_', ltype)
    emitter:add(op, '(', lname, ', ', rname, ')')
  elseif ltype.is_array then
    assert(ltype == rtype)
    emitter.context:add_include('<string.h>')
    emitter:add('memcmp(&', lname, ', &', rname, ', sizeof(', ltype, ')) == 0')
  elseif needs_signed_unsigned_comparision(lnode, rnode) then
    if not ltype.is_unsigned then
      local op = emitter.context:ensure_runtime_builtin('nelua_eq_', ltype, rtype)
      emitter:add(op, '(', lname, ', ', rname, ')')
    else
      local op = emitter.context:ensure_runtime_builtin('nelua_eq_', rtype, ltype)
      emitter:add(op, '(', rname, ', ', lname, ')')
    end
  else
    emitter:add(lname, ' == ')
    if ltype ~= rtype then
      emitter:add_val2type(ltype, rnode, rtype)
    else
      emitter:add(rname)
    end
  end
end

function operators.ne(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  if ltype.is_stringview and rtype.is_stringview then
    emitter:add_builtin('nelua_stringview_ne')
    emitter:add('(', lname, ', ', rname, ')')
  elseif ltype.is_record then
    assert(ltype == rtype)
    local op = emitter.context:ensure_runtime_builtin('nelua_eq_', ltype)
    emitter:add('!', op, '(', lname, ', ', rname, ')')
  elseif ltype.is_array then
    assert(ltype == rtype)
    emitter.context:add_include('<string.h>')
    emitter:add('memcmp(&', lname, ', &', rname, ', sizeof(', ltype, ')) != 0')
  elseif needs_signed_unsigned_comparision(lnode, rnode) then
    if not ltype.is_unsigned then
      local op = emitter.context:ensure_runtime_builtin('nelua_eq_', ltype, rtype)
      emitter:add('!', op, '(', lname, ', ', rname, ')')
    else
      local op = emitter.context:ensure_runtime_builtin('nelua_eq_', rtype, ltype)
      emitter:add('!', op, '(', rname, ', ', lname, ')')
    end
  else
    emitter:add(lname, ' != ')
    if ltype ~= rtype then
      emitter:add_val2type(ltype, rnode, rtype)
    else
      emitter:add(rname)
    end
  end
end

function operators.deref(_, emitter, argnode)
  if argnode.checkderef then
    local op = emitter.context:ensure_runtime_builtin('nelua_assert_deref_', argnode.attr.type)
    emitter:add('*', op, '(', argnode, ')')
  else
    emitter:add('*', argnode)
  end
end

function operators.len(_, emitter, argnode)
  local type = argnode.attr.type
  if type.is_stringview then
    emitter:add('((intptr_t)(', argnode, ').size)')
  elseif type.is_cstring then
    emitter.context:add_include('<string.h>')
    emitter:add('((intptr_t)strlen(', argnode, '))')
  else --luacov:disable
    argnode:errorf('not implemented')
  end --luacov:enable
end

local inlines = {}
cbuiltins.inlines = inlines

function inlines.assert(context, node)
  local args = node:args()
  if #args == 2 then
    return context:ensure_runtime_builtin('nelua_assert_stringview')
  elseif #args == 1 then
    return context:ensure_runtime_builtin('nelua_assert')
  else
    node:raisef('invalid assert call')
  end
end

function inlines.check(context, node)
  local args = node:args()
  assert(#args == 2)
  return context:ensure_runtime_builtin('nelua_assert_stringview')
end

function inlines.print(context, node)
  context:add_include('<stdio.h>')
  context:add_include('<inttypes.h>')
  local argnodes = node:args()
  local funcname = context:genuniquename('nelua_print')

  --function declaration
  local decemitter = CEmitter(context)
  decemitter:add_indent('static ')
  decemitter:add('void ', funcname, '(')
  for i,argnode in ipairs(argnodes) do
    if i>1 then decemitter:add(', ') end
    decemitter:add(argnode.attr.type, ' a', i)
  end
  decemitter:add_ln(');')
  context:add_declaration(decemitter:generate(), funcname)

  --function head
  local defemitter = CEmitter(context)
  defemitter:add_indent('inline void ', funcname, '(')
  for i,argnode in ipairs(argnodes) do
    if i>1 then defemitter:add(', ') end
    defemitter:add(argnode.attr.type, ' a', i)
  end
  defemitter:add(')')

  -- function body
  defemitter:add_ln(' {')
  defemitter:inc_indent()
  for i,argnode in ipairs(argnodes) do
    local argtype = argnode.attr.type
    defemitter:add_indent()
    if i > 1 then
      defemitter:add_ln("putchar('\\t');")
      defemitter:add_indent()
    end
    if argtype.is_any then
      defemitter:add_builtin('nelua_stdout_write_any')
      defemitter:add_ln('(a',i,');')
    elseif argtype.is_stringview then
      defemitter:add_builtin('nelua_stdout_write_stringview')
      defemitter:add_ln('(a',i,');')
    elseif argtype.is_cstring then
      defemitter:add_ln('printf("%s", a',i,');')
    elseif argtype.is_string then
      defemitter:add_builtin('nelua_stdout_write_stringview')
      defemitter:add_ln('((nlstringview){(char*)a',i,'.data, a',i,'.size});')
    elseif argtype.is_niltype then
      defemitter:add_ln('printf("nil");')
    elseif argtype.is_boolean then
      defemitter:add_ln('printf(a',i,' ? "true" : "false");')
    elseif argtype.is_arithmetic then
      local ty = node:assertraisef(argtype, 'type is not defined in AST node')
      if ty.is_enum then
        ty = ty.subtype
      end
      local tyformat = cdefs.types_printf_format[ty.codename]
      node:assertraisef(tyformat, 'invalid type "%s" for printf format', ty)
      defemitter:add_ln('printf(', tyformat,', a',i,');')
    else --luacov:disable
      node:raisef('cannot handle type "%s" in print', argtype)
    end --luacov:enable
  end
  defemitter:add_indent_ln('printf("\\n");')
  defemitter:add_ln('}')

  context:add_definition(defemitter:generate(), funcname)

  -- the call
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
  context:ensure_runtime_builtin('nlruntype_', typename)
  emitter:add('nlruntype_',typename,'.name')
end

function inlines.likely(context)
  return context:ensure_runtime_builtin('nelua_likely')
end

function inlines.unlikely(context)
  return context:ensure_runtime_builtin('nelua_unlikely')
end

function inlines.error(context)
  return context:ensure_runtime_builtin('nelua_panic_stringview')
end

function inlines.warn(context)
  return context:ensure_runtime_builtin('nelua_warn')
end

function inlines.panic(context)
  return context:ensure_runtime_builtin('nelua_panic_stringview')
end

function inlines.require(context, node, emitter)
  if node.attr.alreadyrequired then
    return
  end
  local ast = node.attr.loadedast
  assert(not node.attr.runtime_require and ast)
  local bracepos = emitter:get_pos()
  emitter:add_indent_ln('{')
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
