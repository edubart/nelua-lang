local cdefs = require 'nelua.cdefs'
local CEmitter = require 'nelua.cemitter'

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
  define_builtin(context, 'nelua_noinline', "#define nelua_noinline __attribute__((noinline))\n")
end

function builtins.nelua_noreturn(context)
  define_builtin(context, 'nelua_noreturn', "#define nelua_noreturn __attribute__((noreturn))\n")
end

-- string
function builtins.nelua_string(context)
  define_builtin(context, 'nelua_string',
    [[typedef struct nelua_string_object {
  intptr_t len;
  char data[];
} nelua_string_object;
typedef nelua_string_object* nelua_string;
]])
end

-- nil
function builtins.nelua_nilable(context)
  define_builtin(context, 'nelua_nilable', "typedef void* nelua_nilable;\n")
end

function builtins.nelua_unusedvar(context)
  define_builtin(context, 'nelua_unusedvar', "typedef void* nelua_unusedvar;\n")
end

-- panic
function builtins.nelua_panic_cstring(context)
  context:add_include('<stdlib.h>')
  context:ensure_runtime_builtin('nelua_noreturn')
  context:ensure_runtime_builtin('nelua_stderr_write_cstring')
  define_builtin(context, 'nelua_panic_cstring',
    'static nelua_noreturn void nelua_panic_cstring(const char* s);\n',
    [[inline nelua_noreturn void nelua_panic_cstring(const char *s) {
  nelua_stderr_write_cstring(s);
  exit(-1);
}
]])
end

function builtins.nelua_panic_string(context)
  context:ensure_runtime_builtin('nelua_string')
  context:ensure_runtime_builtin('nelua_panic_cstring')
  context:ensure_runtime_builtin('nelua_noreturn')
  define_builtin(context, 'nelua_panic_string',
    'static nelua_noreturn void nelua_panic_string(const nelua_string s);\n',
    [[inline nelua_noreturn void nelua_panic_string(const nelua_string s) {
  nelua_panic_cstring(s->data);
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

function builtins.nelua_assert_cstring(context)
  context:ensure_runtime_builtin('nelua_panic_cstring')
  context:ensure_runtime_builtin('nelua_unlikely')
  define_builtin(context, 'nelua_assert_cstring',
    'static void nelua_assert_cstring(bool cond, const char* s);\n',
    [[inline void nelua_assert_cstring(bool cond, const char* s) {
  if(nelua_unlikely(!cond)) {
    nelua_panic_cstring(s);
  }
}
]])
end

function builtins.nelua_assert_string(context)
  context:ensure_runtime_builtin('nelua_panic_string')
  context:ensure_runtime_builtin('nelua_unlikely')
  define_builtin(context, 'nelua_assert_string',
    'static void nelua_assert_string(bool cond, const nelua_string s);\n',
    [[inline void nelua_assert_string(bool cond, const nelua_string s) {
  if(nelua_unlikely(!cond)) {
    nelua_panic_string(s);
  }
}
]])
end

-- stderr write
function builtins.nelua_stderr_write_cstring(context)
  context:add_include('<stdio.h>')
  define_builtin(context, 'nelua_stderr_write_cstring',
    'static void nelua_stderr_write_cstring(const char* s);\n',
    [[void nelua_stderr_write_cstring(const char *s) {
  fputs(s, stderr);
  fputs("\n", stderr);
  fflush(stderr);
}
]])
end

function builtins.nelua_stderr_write_string(context)
  context:ensure_runtime_builtin('nelua_string')
  context:ensure_runtime_builtin('nelua_stderr_write_cstring')
  define_inline_builtin(context, 'nelua_stderr_write_string',
    'void', '(const nelua_string s)', [[{
  nelua_stderr_write_cstring(s->data);
}]])
end

-- string
function builtins.nelua_string_eq(context)
  context:ensure_runtime_builtin('nelua_string')
  context:add_include('<string.h>')
  define_inline_builtin(context,'nelua_string_eq',
    'bool', '(const nelua_string a, const nelua_string b)', [[{
  return a->len == b->len && memcmp(a->data, b->data, a->len) == 0;
}]])
end

function builtins.nelua_string_ne(context)
  context:ensure_runtime_builtin('nelua_string')
  context:ensure_runtime_builtin('nelua_string_eq')
  define_inline_builtin(context, 'nelua_string_ne',
    'bool', '(const nelua_string a, const nelua_string b)', [[{
  return !nelua_string_eq(a, b);
}]])
end

function builtins.nelua_cstring2string(context)
  context:add_include('<stdlib.h>')
  context:add_include('<string.h>')
  context:ensure_runtime_builtin('nelua_string')
  context:ensure_runtime_builtin('nelua_assert_cstring')
  --TODO: free allocated strings
  define_inline_builtin(context, 'nelua_cstring2string',
    'nelua_string', '(const char *s)', [[{
  nelua_assert_cstring(s != NULL, "NULL cstring while converting to string");
  size_t slen = strlen(s);
  nelua_string str = (nelua_string)malloc(sizeof(nelua_string_object) + slen+1);
  str->len = slen;
  memcpy(str->data, s, slen);
  str->data[slen] = 0;
  return str;
}]])
end

-- runtime type
function builtins.nelua_runtype(context)
  context:ensure_runtime_builtin('nelua_string')
  define_builtin(context, 'nelua_runtype', [[typedef struct nelua_runtype {
  nelua_string name;
} nelua_runtype;
]])
end

function builtins.nelua_runtype_(context, typename)
  local name = 'nelua_runtype_' .. typename
  if context.usedbuiltins[name] then return name end
  context:ensure_runtime_builtin('nelua_runtype')
  context:ensure_runtime_builtin('nelua_static_string_', typename)
  local code = string.format('static nelua_runtype %s = { (nelua_string)&nelua_static_string_%s };\n',
    name,
    typename)
  define_builtin(context, name, code)
  return name
end

-- static string
function builtins.nelua_static_string_(context, s)
  local name = 'nelua_static_string_' .. s
  if context.usedbuiltins[name] then return name end
  local len = #s
  local code = string.format(
    'static const struct { uintptr_t len; char data[%d]; } %s = {%d,"%s"};\n',
    len+1, name, len, s)
  define_builtin(context, name, code)
  return name
end

-- any
function builtins.nelua_any(context)
  context:ensure_runtime_builtin('nelua_nilable')
  context:ensure_runtime_builtin('nelua_runtype')
  define_builtin(context, 'nelua_any', [[typedef struct nelua_any {
  nelua_runtype *type;
  union {
    intptr_t _nelua_isize;
    int8_t _nelua_int8;
    int16_t _nelua_int16;
    int32_t _nelua_int32;
    int64_t _nelua_int64;
    uintptr_t _nelua_usize;
    uint8_t _nelua_uint8;
    uint16_t _nelua_uint16;
    uint32_t _nelua_uint32;
    uint64_t _nelua_uint64;
    float _nelua_float32;
    double _nelua_float64;
    bool _nelua_boolean;
    nelua_string _nelua_string;
    char* _nelua_cstring;
    void* _nelua_pointer;
    char _nelua_cchar;
    signed char _nelua_cschar;
    short _nelua_cshort;
    int _nelua_cint;
    long _nelua_clong;
    long long _nelua_clonglong;
    ptrdiff_t _nelua_cptrdiff;
    unsigned char _nelua_cuchar;
    unsigned short _nelua_cushort;
    unsigned int _nelua_cuint;
    unsigned long _nelua_culong;
    unsigned long long _nelua_culonglong;
    size_t _nelua_csize;
    nelua_nilable _nelua_nilable;
  } value;
} nelua_any;
]])
end

function builtins.nelua_any_to_(context, type)
  local typename = context:typename(type)
  local name = 'nelua_any_to_' .. typename
  if context.usedbuiltins[name] then return name end
  local ctype = context:ctype(type)
  context:ensure_runtime_builtin('nelua_any')
  context:ensure_runtime_builtin('nelua_runtype_', typename)
  if type:is_boolean() then
    context:ensure_runtime_builtin('nelua_runtype_', 'nelua_pointer')
    define_inline_builtin(context, name, ctype, '(const nelua_any a)',
      string.format([[{
  if(a.type == &nelua_runtype_nelua_boolean) {
    return a.value._nelua_boolean;
  } else if(a.type == &nelua_runtype_nelua_pointer) {
    return a.value._nelua_pointer != NULL;
  } else {
    return a.type != NULL;
  }
}]], typename, typename))
  else
    context:ensure_runtime_builtin('nelua_unlikely')
    context:ensure_runtime_builtin('nelua_panic_cstring')
    define_inline_builtin(context, name, ctype, '(const nelua_any a)',
      string.format([[{
  if(nelua_unlikely(a.type != &nelua_runtype_%s)) {
    nelua_panic_cstring("type check fail");
  }
  return a.value._%s;
}]], typename, typename))
  end
  return name
end

-- writing
function builtins.nelua_stdout_write_cstring(context)
  context:add_include('<stdio.h>')
  define_inline_builtin(context, 'nelua_stdout_write_cstring',
    'void', '(const char *s)', [[{
  fputs(s, stdout);
}]])
end

function builtins.nelua_stdout_write_string(context)
  context:ensure_runtime_builtin('nelua_string')
  context:add_include('<stdio.h>')
  define_inline_builtin(context, 'nelua_stdout_write_string',
    'void', '(const nelua_string s)', [[{
  if(s && s->len > 0)
    fwrite(s->data, s->len, 1, stdout);
}]])
end

function builtins.nelua_stdout_write_boolean(context)
  context:add_include('<stdio.h>')
  define_inline_builtin(context, 'nelua_stdout_write_boolean',
    'void', '(const bool b)', [[{
  if(b) {
    fwrite("true", 4, 1, stdout);
  } else {
    fwrite("false", 5, 1, stdout);
  }
}]])
end

function builtins.nelua_stdout_write_nil(context)
  context:add_include('<stdio.h>')
  define_inline_builtin(context, 'nelua_stdout_write_nil',
    'void', '()', [[{
  fwrite("nil", 3, 1, stdout);
}]])
end

function builtins.nelua_stdout_write_newline(context)
  context:add_include('<stdio.h>')
  define_inline_builtin(context, 'nelua_stdout_write_newline',
    'void', '()', [[{
  fwrite("\n", 1, 1, stdout);
  fflush(stdout);
}]])
end

function builtins.nelua_stdout_write_format(context)
  context:add_include('<stdio.h>')
  context:add_include('<stdarg.h>')
  define_inline_builtin(context, 'nelua_stdout_write_format',
    'void', '(char *format, ...)', [[{
  va_list args;
  va_start(args, format);
  vfprintf(stdout, format, args);
  va_end(args);
}]])
end

function builtins.nelua_stdout_write_any(context)
  context:add_include('<stdio.h>')
  context:ensure_runtime_builtin('nelua_runtype_', 'nelua_boolean')
  context:ensure_runtime_builtin('nelua_runtype_', 'nelua_isize')
  context:ensure_runtime_builtin('nelua_runtype_', 'nelua_usize')
  context:ensure_runtime_builtin('nelua_runtype_', 'nelua_int8')
  context:ensure_runtime_builtin('nelua_runtype_', 'nelua_int16')
  context:ensure_runtime_builtin('nelua_runtype_', 'nelua_int32')
  context:ensure_runtime_builtin('nelua_runtype_', 'nelua_int64')
  context:ensure_runtime_builtin('nelua_runtype_', 'nelua_uint8')
  context:ensure_runtime_builtin('nelua_runtype_', 'nelua_uint16')
  context:ensure_runtime_builtin('nelua_runtype_', 'nelua_uint32')
  context:ensure_runtime_builtin('nelua_runtype_', 'nelua_uint64')
  context:ensure_runtime_builtin('nelua_runtype_', 'nelua_float32')
  context:ensure_runtime_builtin('nelua_runtype_', 'nelua_float64')
  context:ensure_runtime_builtin('nelua_runtype_', 'nelua_pointer')
  context:ensure_runtime_builtin('nelua_stdout_write_boolean')
  context:ensure_runtime_builtin('nelua_panic_cstring')
  define_inline_builtin(context, 'nelua_stdout_write_any',
    'void', '(const nelua_any a)', [[{
  if(a.type == &nelua_runtype_nelua_boolean) {
    nelua_stdout_write_boolean(a.value._nelua_boolean);
  } else if(a.type == &nelua_runtype_nelua_isize) {
    fprintf(stdout, "%ti", a.value._nelua_isize);
  } else if(a.type == &nelua_runtype_nelua_usize) {
    fprintf(stdout, "%tu", a.value._nelua_usize);
  } else if(a.type == &nelua_runtype_nelua_int8) {
    fprintf(stdout, "%hhi", a.value._nelua_int8);
  } else if(a.type == &nelua_runtype_nelua_int16) {
    fprintf(stdout, "%hi", a.value._nelua_int16);
  } else if(a.type == &nelua_runtype_nelua_int32) {
    fprintf(stdout, "%i", a.value._nelua_int32);
  } else if(a.type == &nelua_runtype_nelua_int64) {
    fprintf(stdout, "%li", a.value._nelua_int64);
  } else if(a.type == &nelua_runtype_nelua_uint8) {
    fprintf(stdout, "%hhu", a.value._nelua_uint8);
  } else if(a.type == &nelua_runtype_nelua_uint16) {
    fprintf(stdout, "%hu", a.value._nelua_uint16);
  } else if(a.type == &nelua_runtype_nelua_uint32) {
    fprintf(stdout, "%u", a.value._nelua_uint32);
  } else if(a.type == &nelua_runtype_nelua_uint64) {
    fprintf(stdout, "%lu", a.value._nelua_uint64);
  } else if(a.type == &nelua_runtype_nelua_float32) {
    fprintf(stdout, "%f", a.value._nelua_float32);
  } else if(a.type == &nelua_runtype_nelua_float64) {
    fprintf(stdout, "%lf", a.value._nelua_float64);
  } else if(a.type == &nelua_runtype_nelua_pointer) {
    fprintf(stdout, "%p", a.value._nelua_pointer);
  } else if(a.type == NULL) {
    fprintf(stdout, "nil");
  } else {
    nelua_panic_cstring("invalid type for nelua_fwrite_any");
  }
}]])
end

function builtins.nelua_lt_(context, ltype, rtype)
  if ltype:is_signed() and rtype:is_unsigned() then
    local name = string.format('nelua_lt_i%du%d', ltype.bitsize, rtype.bitsize)
    if context.usedbuiltins[name] then return name end
    define_inline_builtin(context, name,
      'bool',
      string.format('(int%d_t a, uint%d_t b)', ltype.bitsize, rtype.bitsize),
      string.format("{ return a < 0 || (uint%d_t)a < b; }", ltype.bitsize))
    return name
  else
    assert(ltype:is_unsigned() and rtype:is_signed())
    local name = string.format('nelua_lt_u%di%d', ltype.bitsize, rtype.bitsize)
    if context.usedbuiltins[name] then return name end
    define_inline_builtin(context, name,
      'bool',
      string.format('(uint%d_t a, int%d_t b)', ltype.bitsize, rtype.bitsize),
      string.format("{ return b > 0 && a < (uint%d_t)b; }", rtype.bitsize))
    return name
  end
end

function builtins.nelua_idiv_(context, type)
  local name = string.format('nelua_idiv_i%d', type.bitsize)
  if context.usedbuiltins[name] then return name end
  local ictype = string.format('int%d_t', type.bitsize)
  define_inline_builtin(context, name,
    ictype,
    string.format('(%s a, %s b)', ictype, ictype),
    string.format([[{
  %s d = a / b;
  return d * b == a ? d : d - ((a < 0) ^ (b < 0));
}]], ictype))
  return name
end

function builtins.nelua_imod_(context, type)
  local name = string.format('nelua_imod_i%d', type.bitsize)
  if context.usedbuiltins[name] then return name end
  local ictype = string.format('int%d_t', type.bitsize)
  define_inline_builtin(context, name,
    ictype,
    string.format('(%s a, %s b)', ictype, ictype),
    string.format([[{
  %s r = a %% b;
  return (r != 0 && (a ^ b) < 0) ? r + b : r;
}]], ictype))
  return name
end

function builtins.nelua_fmod_(context, type)
  local ctype = context:ctype(type)
  local cfmod = type:is_float32() and 'fmodf' or 'fmod'
  local name = 'nelua_' .. cfmod
  if context.usedbuiltins[name] then return name end
  context:add_include('<math.h>')
  define_inline_builtin(context, name,
    ctype,
    string.format('(%s a, %s b)', ctype, ctype),
    string.format([[{
  %s r = %s(a, b);
  return r * b >= 0 ? r : r +b;
}]], ctype, cfmod))
  return name
end

local operators = {}
cbuiltins.operators = operators

function operators.len(node, emitter, argnode)
  local type = argnode.attr.type
  if type:is_arraytable() then
    emitter:add(type, '_length(&', argnode, ')')
  else --luacov:disable
    node:errorf('not implemented')
  end --luacov:enable
end

function operators.div(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  if ltype:is_arithmetic() and rtype:is_arithmetic() then
    if not rtype:is_float() and not ltype:is_float() then
      assert(type:is_float())
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
  if ltype:is_arithmetic() and rtype:is_arithmetic() then
    if ltype:is_float() or rtype:is_float() then
      local floorname = type:is_float32() and 'floorf' or 'floor'
      emitter.context:add_include('<math.h>')
      emitter:add(floorname, '(', lname, ' / ', rname, ')')
    elseif type:is_integral() and (ltype:is_signed() or rtype:is_signed()) then
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
  if ltype:is_arithmetic() and rtype:is_arithmetic() then
    if ltype:is_float() or rtype:is_float() then
      local op = emitter.context:ensure_runtime_builtin('nelua_fmod_', type)
      emitter:add(op, '(', lname, ', ', rname, ')')
    elseif type:is_integral() and (ltype:is_signed() or rtype:is_signed()) then
      local op = emitter.context:ensure_runtime_builtin('nelua_imod_', type)
      emitter:add(op, '(', lname, ', ', rname, ')')
    else
      emitter:add(lname, ' % ', rname)
    end
  else --luacov:disable
    node:errorf('not implemented')
  end --luacov:enable
end

function operators.pow(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  if ltype:is_arithmetic() and rtype:is_arithmetic() then
    local powname = type:is_float32() and 'powf' or 'pow'
    emitter.context:add_include('<math.h>')
    emitter:add(powname, '(', lname, ', ', rname, ')')
  else --luacov:disable
    node:errorf('not implemented')
  end --luacov:enable
end

function operators.lt(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  if ltype:is_integral() and rtype:is_integral() and ltype:is_unsigned() ~= rtype:is_unsigned() then
    local op = emitter.context:ensure_runtime_builtin('nelua_lt_', ltype, rtype)
    emitter:add(op, '(', lname, ', ', rname, ')')
  else
    emitter:add(lname, ' < ', rname)
  end
end

function operators.gt(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  if ltype:is_integral() and rtype:is_integral() and ltype:is_unsigned() ~= rtype:is_unsigned() then
    local op = emitter.context:ensure_runtime_builtin('nelua_lt_', rtype, ltype)
    emitter:add(op, '(', rname, ', ', lname, ')')
  else
    emitter:add(lname, ' > ', rname)
  end
end

function operators.le(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  if ltype:is_integral() and rtype:is_integral() and ltype:is_unsigned() ~= rtype:is_unsigned() then
    local op = emitter.context:ensure_runtime_builtin('nelua_lt_', rtype, ltype)
    emitter:add('!', op, '(', rname, ', ', lname, ')')
  else
    emitter:add(lname, ' <= ', rname)
  end
end

function operators.ge(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  if ltype:is_integral() and rtype:is_integral() and ltype:is_unsigned() ~= rtype:is_unsigned() then
    local op = emitter.context:ensure_runtime_builtin('nelua_lt_', ltype, rtype)
    emitter:add('!', op, '(', lname, ', ', rname, ')')
  else
    emitter:add(lname, ' >= ', rname)
  end
end

function operators.eq(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  if ltype:is_string() and rtype:is_string() then
    emitter:add_builtin('nelua_string_eq')
    emitter:add('(', lname, ', ', rname, ')')
  else
    emitter:add(lname, ' == ', rname)
  end
end

function operators.ne(_, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  if ltype:is_string() and rtype:is_string() then
    emitter:add_builtin('nelua_string_ne')
    emitter:add('(', lname, ', ', rname, ')')
  else
    emitter:add(lname, ' != ', rname)
  end
end

function operators.range(node, emitter, lnode, rnode)
  local subtype = node.attr.type.subtype
  emitter:add_ctypecast(node.attr.type)
  emitter:add('{')
  emitter:add_val2type(subtype, lnode)
  emitter:add(',')
  emitter:add_val2type(subtype, rnode)
  emitter:add('}')
end

local inlines = {}
cbuiltins.inlines = inlines

function inlines.assert(context, node)
  local args = node:args()
  if #args == 2 then
    return context:ensure_runtime_builtin('nelua_assert_string')
  elseif #args == 1 then
    return context:ensure_runtime_builtin('nelua_assert')
  else
    node:raisef('invalid assert call')
  end
end

function inlines.print(context, node)
  local argnodes = node:args()
  local funcname = context:genuniquename('nelua_print')

  --function declaration
  local decemitter = CEmitter(context)
  decemitter:add_indent('static inline ')
  decemitter:add('void ', funcname, '(')
  for i,argnode in ipairs(argnodes) do
    if i>1 then decemitter:add(', ') end
    decemitter:add('const ', argnode.attr.type, ' a', i)
  end
  decemitter:add_ln(');')
  context:add_declaration(decemitter:generate(), funcname)

  --function head
  local defemitter = CEmitter(context)
  defemitter:add_indent('void ', funcname, '(')
  for i,argnode in ipairs(argnodes) do
    if i>1 then defemitter:add(', ') end
    defemitter:add('const ', argnode.attr.type, ' a', i)
  end
  defemitter:add(')')

  -- function body
  defemitter:add_ln(' {')
  defemitter:inc_indent()
  for i,argnode in ipairs(argnodes) do
    local argtype = argnode.attr.type
    defemitter:add_indent()
    if i > 1 then
      defemitter:add_builtin('nelua_stdout_write_cstring')
      defemitter:add_ln('("\\t");')
      defemitter:add_indent()
    end
    if argtype:is_any() then
      defemitter:add_builtin('nelua_stdout_write_any')
      defemitter:add_ln('(a',i,');')
    elseif argtype:is_string() then
      defemitter:add_builtin('nelua_stdout_write_string')
      defemitter:add_ln('(a',i,');')
    elseif argtype:is_cstring() then
      defemitter:add_builtin('nelua_stdout_write_cstring')
      defemitter:add_ln('(a',i,');')
    elseif argtype:is_nil() then
      defemitter:add_builtin('nelua_stdout_write_nil')
      defemitter:add_ln('();')
    elseif argtype:is_boolean() then
      defemitter:add_builtin('nelua_stdout_write_boolean')
      defemitter:add_ln('(a',i,');')
    elseif argtype:is_arithmetic() then
      local ty = node:assertraisef(argtype, 'type is not defined in AST node')
      if ty:is_enum() then
        ty = ty.subtype
      end
      local tyformat = cdefs.types_printf_format[ty.codename]
      node:assertraisef(tyformat, 'invalid type "%s" for printf format', ty)
      defemitter:add_builtin('nelua_stdout_write_format')
      defemitter:add_ln('("',tyformat,'", a',i,');')
    else --luacov:disable
      node:raisef('cannot handle type "%s" in print', argtype)
    end --luacov:enable
  end
  defemitter:add_indent()
  defemitter:add_builtin('nelua_stdout_write_newline')
  defemitter:add_ln('();')
  defemitter:dec_indent()
  defemitter:add_ln('}')

  context:add_definition(defemitter:generate(), funcname)

  -- the call
  return funcname
end

function inlines.type(_, node, emitter)
  local argnode = node[1][1]
  local type = argnode.attr.type
  local typename
  if type:is_arithmetic() then
    typename = 'number'
  elseif type:is_nilptr() then
    typename = 'pointer'
  elseif type:is_any() then --luacov:disable
    node:raisef('type() for any values not implemented yet')
  else --luacov:enable
    typename = type.name
  end
  emitter:add('(nelua_string)&')
  emitter:add_builtin('nelua_static_string_', typename)
  return nil
end

function inlines.likely(context)
  return context:ensure_runtime_builtin('nelua_likely')
end

function inlines.unlikely(context)
  return context:ensure_runtime_builtin('nelua_unlikely')
end

function inlines.error(context)
  return context:ensure_runtime_builtin('nelua_panic_string')
end

function inlines.warn(context)
  return context:ensure_runtime_builtin('nelua_stderr_write_string')
end

function inlines.panic(context)
  return context:ensure_runtime_builtin('nelua_panic_string')
end

function inlines.require(context, node, emitter)
  if node.attr.alreadyrequired then
    return
  end
  local ast = node.attr.loadedast
  if node.attr.runtime_require then
    if node.attr.unitname then
      node:raisef("compile time module '%s' not found", node.attr.unitname)
    else
      node:raisef('runtime require is not supported in C backend yet')
    end
  end
  assert(ast)
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
