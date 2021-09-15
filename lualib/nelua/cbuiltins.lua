--[[
C builtins.

This module defines implementations for many builtin C functions used by the C code generator.
]]

local pegger = require 'nelua.utils.pegger'
local cdefs = require 'nelua.cdefs'
local CEmitter = require 'nelua.cemitter'
local typedefs = require 'nelua.typedefs'
local primtypes = typedefs.primtypes

-- The cbuiltins table.
local cbuiltins = {}

do -- Define builtins from C headers.
  for name, header in pairs(cdefs.builtins_headers) do
    cbuiltins[name] = function(context)
      context:ensure_include(header)
    end
  end
end

-- Used by `likely` builtin.
function cbuiltins.NELUA_LIKELY(context)
  context:define_builtin_macro('NELUA_LIKELY', [[
/* Macro used for branch prediction. */
#if defined(__GNUC__) || defined(__clang__)
  #define NELUA_LIKELY(x) __builtin_expect(x, 1)
#else
  #define NELUA_LIKELY(x) (x)
#endif
]], 'directives')
end

-- Used by `unlikely` builtin.
function cbuiltins.NELUA_UNLIKELY(context)
  context:define_builtin_macro('NELUA_UNLIKELY', [[
/* Macro used for branch prediction. */
#if defined(__GNUC__) || defined(__clang__)
  #define NELUA_UNLIKELY(x) __builtin_expect(x, 0)
#else
  #define NELUA_UNLIKELY(x) (x)
#endif
]], 'directives')
end

-- Used by import and export builtins.
function cbuiltins.NELUA_EXTERN(context)
  context:define_builtin_macro('NELUA_EXTERN', [[
/* Macro used to import/export extern C functions. */
#ifdef __cplusplus
  #define NELUA_EXTERN extern "C"
#else
  #define NELUA_EXTERN extern
#endif
]], 'directives')
end

-- Used by `<cexport>`.
function cbuiltins.NELUA_CEXPORT(context)
  context:ensure_builtin('NELUA_EXTERN')
  context:define_builtin_macro('NELUA_CEXPORT', [[
/* Macro used to export C functions. */
#ifdef _WIN32
  #define NELUA_CEXPORT NELUA_EXTERN __declspec(dllexport)
#elif defined(__GNUC__)
  #define NELUA_CEXPORT NELUA_EXTERN __attribute__((visibility("default")))
#else
  #define NELUA_CEXPORT NELUA_EXTERN
#endif
]], 'directives')
end

-- Used by `<cimport>` without `<nodecl>`.
function cbuiltins.NELUA_CIMPORT(context)
  context:ensure_builtin('NELUA_EXTERN')
  context:define_builtin_macro('NELUA_CIMPORT', [[
/* Macro used to import C functions. */
#define NELUA_CIMPORT NELUA_EXTERN
]], 'directives')
end

-- Used by `<noinline>`.
function cbuiltins.NELUA_NOINLINE(context)
  context:define_builtin_macro('NELUA_NOINLINE', [[
/* Macro used to force not inlining a function. */
#ifdef __GNUC__
  #define NELUA_NOINLINE __attribute__((noinline))
#elif defined(_MSC_VER)
  #define NELUA_NOINLINE __declspec(noinline)
#else
  #define NELUA_NOINLINE
#endif
]], 'directives')
end

-- Used by `<inline>`.
function cbuiltins.NELUA_INLINE(context)
  context:define_builtin_macro('NELUA_INLINE', [[
/* Macro used to force inlining a function. */
#ifdef __GNUC__
  #define NELUA_INLINE __attribute__((always_inline)) inline
#elif defined(_MSC_VER)
  #define NELUA_INLINE __forceinline
#elif __STDC_VERSION__ >= 199901L
  #define NELUA_INLINE inline
#else
  #define NELUA_INLINE
#endif
]], 'directives')
end

-- Used by `<register>`.
function cbuiltins.NELUA_REGISTER(context)
  context:define_builtin_macro('NELUA_REGISTER', [[
/* Macro used to hint a variable to use a register. */
#ifdef __STDC_VERSION__
  #define NELUA_REGISTER register
#else
  #define NELUA_REGISTER
#endif
]], 'directives')
end

-- Used by `<noreturn>`.
function cbuiltins.NELUA_NORETURN(context)
  context:define_builtin_macro('NELUA_NORETURN', [[
/* Macro used to specify a function that never returns. */
#if __STDC_VERSION__ >= 201112L
  #define NELUA_NORETURN _Noreturn
#elif defined(__GNUC__)
  #define NELUA_NORETURN __attribute__((noreturn))
#elif defined(_MSC_VER)
  #define NELUA_NORETURN __declspec(noreturn)
#else
  #define NELUA_NORETURN
#endif
]], 'directives')
end

-- Used by `<atomic>`.
function cbuiltins.NELUA_ATOMIC(context)
  context:define_builtin_macro('NELUA_ATOMIC', [[
/* Macro used to declare atomic types. */
#if __STDC_VERSION__ >= 201112L && !defined(__STDC_NO_ATOMICS__)
  #define NELUA_ATOMIC _Atomic
#elif __cplusplus >= 202002L
  #include <stdatomic.h>
  #define NELUA_ATOMIC _Atomic
#else
  #define NELUA_ATOMIC(a) a
  #error "Atomic is unsupported."
#endif
]], 'directives')
end

-- Used by `<threadlocal>`.
function cbuiltins.NELUA_THREAD_LOCAL(context)
  context:define_builtin_macro('NELUA_THREAD_LOCAL', [[
/* Macro used to specify a alignment for structs. */
#if __STDC_VERSION__ >= 201112L && !defined(__STDC_NO_THREADS__)
  #define NELUA_THREAD_LOCAL _Thread_local
#elif __cplusplus >= 201103L
  #define NELUA_THREAD_LOCAL thread_local
#elif defined(__GNUC__)
  #define NELUA_THREAD_LOCAL __thread
#elif defined(_MSC_VER)
  #define NELUA_THREAD_LOCAL __declspec(thread)
#else
  #define NELUA_THREAD_LOCAL
  #error "Thread local is unsupported."
#endif
]], 'directives')
end

-- Used by `<packed>` on type declarations.
function cbuiltins.NELUA_PACKED(context)
  context:define_builtin_macro('NELUA_PACKED', [[
/* Macro used to specify a struct alignment. */
#if defined(__GNUC__) || defined(__clang__)
  #define NELUA_PACKED __attribute__((packed))
#else
  #define NELUA_PACKED
#endif
]], 'directives')
end

-- Used by `<aligned>` on type declarations.
function cbuiltins.NELUA_ALIGNED(context)
  context:define_builtin_macro('NELUA_ALIGNED', [[
/* Macro used to specify a alignment for structs. */
#if defined(__GNUC__)
  #define NELUA_ALIGNED(X) __attribute__((aligned(X)))
#elif defined(_MSC_VER)
  #define NELUA_ALIGNED(X) __declspec(align(X))
#else
  #define NELUA_ALIGNED(X)
#endif
]], 'directives')
end

-- Used by `<aligned>` on variable declarations.
function cbuiltins.NELUA_ALIGNAS(context)
  context:define_builtin_macro('NELUA_ALIGNAS', [[
/* Macro used set alignment for a type. */
#if __STDC_VERSION__ >= 201112L
  #define NELUA_ALIGNAS(X) _Alignas(X)
#elif __cplusplus >= 201103L
  #define NELUA_ALIGNAS(X) alignas(X)
#elif defined(__GNUC__)
  #define NELUA_ALIGNAS(X) __attribute__((aligned(X)))
#elif defined(_MSC_VER)
  #define NELUA_ALIGNAS(X) __declspec(align(X))
#else
  #define NELUA_ALIGNAS(X)
#endif
]], 'directives')
end

-- Used to assure some C compiler requirements.
function cbuiltins.NELUA_STATIC_ASSERT(context)
  context:define_builtin_macro('NELUA_STATIC_ASSERT', [[
/* Macro used to perform compile-time checks. */
#if __STDC_VERSION__ >= 201112L
  #define NELUA_STATIC_ASSERT _Static_assert
#elif __cplusplus >= 201103L
  #define NELUA_STATIC_ASSERT static_assert
#else
  #define NELUA_STATIC_ASSERT(x, y)
#endif
]], 'directives')
end

-- Used to assure some C compiler requirements.
function cbuiltins.NELUA_ALIGNOF(context)
  context:define_builtin_macro('NELUA_ALIGNOF', [[
/* Macro used to get alignment of a type. */
#if __STDC_VERSION__ >= 201112L
  #define NELUA_ALIGNOF _Alignof
#elif __cplusplus >= 201103L
  #define NELUA_ALIGNOF alignof
#elif defined(__GNUC__)
  #define NELUA_ALIGNOF __alignof__
#elif defined(_MSC_VER)
  #define NELUA_ALIGNOF __alignof
#else
  #define NELUA_ALIGNOF(x)
#endif
]], 'directives')
end

-- Used to do type punning without issues on GCC when strict aliasing is enabled.
function cbuiltins.NELUA_MAYALIAS(context)
  context:define_builtin_macro('NELUA_MAYALIAS', [[
/* Macro used sign that a type punning cast may alias (related to strict aliasing). */
#ifdef __GNUC__
  #define NELUA_MAYALIAS __attribute__((may_alias))
#else
  #define NELUA_MAYALIAS
#endif
]], 'directives')
end

--[[
Called before aborting when sanitizing.
Its purpose is to generate traceback before aborting.
]]
function cbuiltins.NELUA_UBSAN_UNREACHABLE(context)
  context:ensure_builtin('NELUA_EXTERN')
  context:define_builtin_macro('NELUA_UBSAN_UNREACHABLE', [[
/* Macro used to generate traceback on aborts when sanitizing. */
#if defined(__clang__) && defined(__has_feature)
  #if __has_feature(undefined_behavior_sanitizer)
    #define NELUA_UBSAN_UNREACHABLE __builtin_unreachable
  #endif
#elif defined(__gnu_linux__) && defined(__GNUC__) && __GNUC__ >= 5
  NELUA_EXTERN void __ubsan_handle_builtin_unreachable(void*) __attribute__((weak));
  #define NELUA_UBSAN_UNREACHABLE() {if(&__ubsan_handle_builtin_unreachable) __builtin_unreachable();}
#endif
#ifndef NELUA_UBSAN_UNREACHABLE
  #define NELUA_UBSAN_UNREACHABLE()
#endif
]], 'directives')
end

-- Used by `nil` type at runtime.
function cbuiltins.nlniltype(context)
  context:define_builtin_decl('nlniltype',
    "typedef struct nlniltype {"..
    (typedefs.emptysize == 0 and '' or 'char x;')..
    "} nlniltype;")
end

-- Used by `nil` at runtime.
function cbuiltins.NELUA_NIL(context)
  context:ensure_builtin('nlniltype')
  context:define_builtin_macro('NELUA_NIL', "#define NELUA_NIL (nlniltype)"..
    (typedefs.emptysize == 0 and '{}' or '{.x=0}'))
end

-- Used by infinite float number literal.
function cbuiltins.NELUA_INF_(context, type)
  context:ensure_include('<math.h>')
  local S = ''
  if type.is_float128 then S = 'Q'
  elseif type.is_clongdouble then S = 'L'
  elseif type.is_cfloat then S = 'F' end
  local name = 'NELUA_INF'..S
  if context.usedbuiltins[name] then return name end
  if type.is_float128 then
    context:define_builtin_macro(name, [[
/* Infinite number constant. */
#define NELUA_INFQ (1.0q/0.0q)
]])
  else
    context:define_builtin_macro(name, pegger.substitute([[
/* Infinite number constant. */
#ifdef HUGE_VAL$(S)
  #define NELUA_INF$(S) HUGE_VAL$(S)
#else
  #define NELUA_INF$(S) (1.0$(s)/0.0$(s))
#endif
]], {s=S:lower(), S=S}))
  end
  return name
end

-- Used by NaN (not a number) float number literal.
function cbuiltins.NELUA_NAN_(context, type)
  context:ensure_include('<math.h>')
  local S = ''
  if type.is_float128 then S = 'Q'
  elseif type.is_clongdouble then S = 'L'
  elseif type.is_cfloat then S = 'F' end
  local name = 'NELUA_NAN'..S
  if context.usedbuiltins[name] then return name end
  context:define_builtin_macro(name, pegger.substitute([[
/* Not a number constant. */
#ifdef NAN
  #define NELUA_NAN$(S) (($(T))NAN)
#else
  #define NELUA_NAN$(S) (-(0.0$(s)/0.0$(s)))
#endif
]], {s=S:lower(), S=S, T=context:ensure_type(type)}))
  return name
end

-- Used to abort the application.
function cbuiltins.nelua_abort(context)
  local abortcall
  if context.pragmas.noabort then
    context:ensure_builtin('exit')
    abortcall = 'exit(-1)'
  else
    context:ensure_builtin('abort')
    abortcall = 'abort()'
  end
  context:ensure_builtins('fflush', 'stderr', 'NELUA_UBSAN_UNREACHABLE')
  context:define_function_builtin('nelua_abort',
    'NELUA_NORETURN', primtypes.void, {}, {[[{
  fflush(stderr);
  NELUA_UBSAN_UNREACHABLE();
  ]],abortcall,[[;
}]]})
end

-- Used with check functions.
function cbuiltins.nelua_panic_cstring(context)
  context:ensure_builtins('fputs', 'fputc', 'nelua_abort')
  context:define_function_builtin('nelua_panic_cstring',
    'NELUA_NORETURN', primtypes.void, {{'const char*', 's'}}, [[{
  fputs(s, stderr);
  fputc('\n', stderr);
  nelua_abort();
}]])
end

-- Used by `panic` builtin.
function cbuiltins.nelua_panic_string(context)
  context:ensure_builtins('fwrite', 'fputc', 'nelua_abort')
  context:define_function_builtin('nelua_panic_string',
    'NELUA_NORETURN', primtypes.void, {{primtypes.string, 's'}}, [[{
  if(s.size > 0) {
    fwrite(s.data, 1, s.size, stderr);
    fputc('\n', stderr);
  }
  nelua_abort();
}]])
end

-- Used by `warn` builtin.
function cbuiltins.nelua_warn(context)
  context:ensure_builtins('fputs', 'fwrite', 'fputc', 'fflush')
  context:define_function_builtin('nelua_warn',
    '', primtypes.void, {{primtypes.string, 's'}}, [[{
  if(s.size > 0) {
    fputs("warning: ", stderr);
    fwrite(s.data, 1, s.size, stderr);
    fputc('\n', stderr);
    fflush(stderr);
  }
}]])
end

--[[
Used to check conversion of a scalar to a narrow scalar.
On underflow/overflow the application will panic.
]]
function cbuiltins.nelua_assert_narrow_(context, dtype, stype)
  local name = 'nelua_assert_narrow_'..stype.codename..'_'..dtype.codename
  if context.usedbuiltins[name] then return name end
  assert(dtype.is_integral and stype.is_scalar)
  context:ensure_builtins('NELUA_UNLIKELY', 'nelua_panic_cstring')
  local emitter = CEmitter(context)
  emitter:add_ln('{') emitter:inc_indent()
  emitter:add_indent('if(NELUA_UNLIKELY(')
  if stype.is_float then -- float -> integral
    emitter:add('(',dtype,')(x) != x')
  elseif stype.is_signed and dtype.is_unsigned then -- signed -> unsigned
    emitter:add('x < 0')
    if stype.max > dtype.max then
      emitter:add(' || x > ')
      emitter:add_scalar_literal(dtype.max, stype, 16)
    end
  elseif stype.is_unsigned and dtype.is_signed then -- unsigned -> signed
    assert(stype.max > dtype.max)
    emitter:add('x > ')
    emitter:add_scalar_literal(dtype.max, stype, 16)
  else -- signed -> signed / unsigned -> unsigned
    emitter:add('x > ')
    emitter:add_scalar_literal(dtype.max, dtype, 16)
    if stype.is_signed then -- signed -> signed
      emitter:add(' || x < ')
      emitter:add_scalar_literal(dtype.min, dtype, 16)
    end
  end
  emitter:add_ln(')) {') emitter:inc_indent()
  emitter:add_indent_ln('nelua_panic_cstring("narrow casting from ',
      tostring(stype),' to ',tostring(dtype),' failed");')
  emitter:dec_indent() emitter:add_indent_ln('}')
  emitter:add_indent('return ')
  emitter:add_converted_val(dtype, 'x', stype, true)
  emitter:add_ln(';')
  emitter:dec_indent() emitter:add('}')
  context:define_function_builtin(name, 'NELUA_INLINE', dtype, {{stype, 'x'}}, emitter:generate())
  return name
end

-- Used to check array bounds when indexing.
function cbuiltins.nelua_assert_bounds_(context, indextype)
  local name = 'nelua_assert_bounds_'..indextype.codename
  if context.usedbuiltins[name] then return name end
  context:ensure_builtins('nelua_panic_cstring', 'NELUA_UNLIKELY')
  context:define_function_builtin(name,
    'NELUA_INLINE', indextype, {{indextype, 'index'}, {primtypes.usize, 'len'}}, {[[{
  if(NELUA_UNLIKELY((]],primtypes.usize,')index >= len',indextype.is_signed and ' || index < 0' or '',[[)) {
    nelua_panic_cstring("array index: position out of bounds");
  }
  return index;
}]]})
  return name
end

-- Used to check dereference of pointers.
function cbuiltins.nelua_assert_deref(context)
  context:ensure_builtins('nelua_panic_cstring', 'NELUA_UNLIKELY', 'NULL')
  context:define_function_builtin('nelua_assert_deref',
    'NELUA_INLINE', primtypes.pointer,  {{primtypes.pointer, 'p'}}, [[{
  if(NELUA_UNLIKELY(p == NULL)) {
    nelua_panic_cstring("attempt to dereference a null pointer");
  }
  return p;
}]])
end

-- Used to convert a string to a C string.
function cbuiltins.nelua_string2cstring_(context, checked)
  local name = checked and 'nelua_assert_string2cstring' or 'nelua_string2cstring'
  if context.usedbuiltins[name] then return name end
  local code
  if checked then
    context:ensure_builtins('nelua_panic_cstring', 'NELUA_UNLIKELY')
    code = [[{
  if(s.size == 0) {
    return (char*)"";
  }
  if(NELUA_UNLIKELY(s.data[s.size]) != 0) {
    nelua_panic_cstring("attempt to convert a non null terminated string to cstring");
  }
  return (char*)s.data;
}]]
  else
    code = [[{
  return (s.size == 0) ? (char*)"" : (char*)s.data;
}]]
  end
  context:define_function_builtin(name,
    'NELUA_INLINE', primtypes.cstring, {{primtypes.string, 's'}}, code)
  return name
end

-- Used to convert a C string to a string.
function cbuiltins.nelua_cstring2string(context)
  context:ensure_builtins('strlen', 'NULL')
  context:define_function_builtin('nelua_cstring2string',
    'NELUA_INLINE', primtypes.string, {{'const char*', 's'}}, {[[{
  if(s == NULL) {
    return (]],primtypes.string,[[){0};
  }
  ]], primtypes.usize, [[ size = strlen(s);
  if(size == 0) {
    return (]],primtypes.string,[[){0};
  }
  return (]],primtypes.string,[[){(]],primtypes.byte,[[*)s, size};
}]]})
end

-- Used by integer less than operator (`<`).
function cbuiltins.nelua_lt_(context, ltype, rtype)
  local name = 'nelua_lt_'..ltype.codename..'_'..rtype.codename
  if context.usedbuiltins[name] then return name end
  local emitter = CEmitter(context)
  if ltype.is_signed and rtype.is_unsigned then
    emitter:add([[{
  return a < 0 || (]],ltype:unsigned_type(),[[)a < b;
}]])
  else
    assert(ltype.is_unsigned and rtype.is_signed)
    emitter:add([[{
  return b > 0 && a < (]],rtype:unsigned_type(),[[)b;
}]])
  end
  context:define_function_builtin(name,
    'NELUA_INLINE', primtypes.boolean, {{ltype, 'a'}, {rtype, 'b'}}, emitter:generate())
  return name
end

-- Used by equality operator (`==`).
function cbuiltins.nelua_eq_(context, ltype, rtype)
  if not rtype then -- comparing same type
    local type = ltype
    local name = 'nelua_eq_'..type.codename
    if context.usedbuiltins[name] then return name end
    assert(type.is_composite)
    local defemitter = CEmitter(context)
    defemitter:add_ln('{') defemitter:inc_indent()
    defemitter:add_indent('return ')
    if type.is_union then
      defemitter:add_builtin('memcmp')
      defemitter:add('(&a, &b, sizeof(', type, ')) == 0')
    elseif #type.fields > 0 then
      for i,field in ipairs(type.fields) do
        if i > 1 then
          defemitter:add(' && ')
        end
        local fieldname, fieldtype = field.name, field.type
        if fieldtype.is_composite then
          defemitter:add_builtin('nelua_eq_', fieldtype)
          defemitter:add('(a.', fieldname, ', b.', fieldname, ')')
        elseif fieldtype.is_array then
          defemitter:add_builtin('memcmp')
          defemitter:add('(a.', fieldname, ', ', 'b.', fieldname, ', sizeof(', type, ')) == 0')
        else
          defemitter:add('a.', fieldname, ' == ', 'b.', fieldname)
        end
      end
    else
      defemitter:add(true)
    end
    defemitter:add_ln(';')
    defemitter:dec_indent() defemitter:add_ln('}')
    context:define_function_builtin(name,
      'NELUA_INLINE', primtypes.boolean, {{type, 'a'}, {type, 'b'}},
      defemitter:generate())
    return name
  else -- comparing different types
    local name = 'nelua_eq_'..ltype.codename..'_'..rtype.codename
    if context.usedbuiltins[name] then return name end
    assert(ltype.is_integral and ltype.is_signed and rtype.is_unsigned)
    local mtype = primtypes['uint'..math.max(ltype.bitsize, rtype.bitsize)]
    context:define_function_builtin(name,
      'NELUA_INLINE', primtypes.boolean, {{ltype, 'a'}, {rtype, 'b'}}, {[[{
  return (]],mtype,[[)a == (]],mtype,[[)b && a >= 0;
}]]})
    return name
  end
end

-- Used by string equality operator (`==`).
function cbuiltins.nelua_eq_string(context)
  context:ensure_builtins('memcmp')
  context:define_function_builtin('nelua_eq_string',
    'NELUA_INLINE', primtypes.boolean, {{primtypes.string, 'a'}, {primtypes.string, 'b'}}, [[{
  return a.size == b.size && (a.data == b.data || a.size == 0 || memcmp(a.data, b.data, a.size) == 0);
}]])
end

-- Used by integer division operator (`//`).
function cbuiltins.nelua_idiv_(context, type, checked)
  local name = (checked and 'nelua_assert_idiv_' or 'nelua_idiv_')..type.codename
  if context.usedbuiltins[name] then return name end
  assert(type.is_signed)
  local stype, utype = type:signed_type(), type:unsigned_type()
  context:ensure_builtins('NELUA_UNLIKELY', 'nelua_panic_cstring')
  local emitter = CEmitter(context)
  emitter:add_ln('{') emitter:inc_indent()
  emitter:add_indent_ln('if(NELUA_UNLIKELY(b == -1)) return 0U - (', utype ,')a;')
  if not checked then
    emitter:add_indent_ln('if(NELUA_UNLIKELY(b == 0)) nelua_panic_cstring("division by zero");')
  end
  emitter:add_indent_ln(stype,' q = a / b;')
  emitter:add_indent_ln('return q * b == a ? q : q - ((a < 0) ^ (b < 0));')
  emitter:dec_indent() emitter:add('}')
  context:define_function_builtin(name,
    'NELUA_INLINE', type, {{type, 'a'}, {type, 'b'}}, emitter:generate())
  return name
end

-- Used by integer modulo operator (`%`).
function cbuiltins.nelua_imod_(context, type, checked)
  local name = (checked and  'nelua_assert_imod_' or 'nelua_imod_')..type.codename
  if context.usedbuiltins[name] then return name end
  assert(type.is_signed)
  context:ensure_builtins('NELUA_UNLIKELY', 'nelua_panic_cstring')
  local emitter = CEmitter(context)
  emitter:add_ln('{') emitter:inc_indent()
  emitter:add_indent_ln('if(NELUA_UNLIKELY(b == -1)) return 0;')
  if checked then
    emitter:add_indent_ln('if(NELUA_UNLIKELY(b == 0)) nelua_panic_cstring("division by zero");')
  end
  emitter:add_indent_ln(type,' r = a % b;')
  emitter:add_indent_ln('return (r != 0 && (a ^ b) < 0) ? r + b : r;')
  emitter:dec_indent() emitter:add('}')
  context:define_function_builtin(name,
    'NELUA_INLINE', type, {{type, 'a'}, {type, 'b'}}, emitter:generate())
  return name
end

-- Used by float modulo operator (`%`).
function cbuiltins.nelua_fmod_(context, type)
  local cfmod = context:ensure_cmath_func('fmod', type)
  local name = 'nelua_'..cfmod
  if context.usedbuiltins[name] then return name end
  context:ensure_builtins('NELUA_UNLIKELY')
  context:define_function_builtin(name,
    'NELUA_INLINE', type, {{type, 'a'}, {type, 'b'}}, {[[{
  ]],type,[[ r = ]],cfmod,[[(a, b);
  if(NELUA_UNLIKELY((r > 0 && b < 0) || (r < 0 && b > 0))) {
    r += b;
  }
  return r;
}]]})
  return name
end

-- Used by integer logical shift left operator (`<<`).
function cbuiltins.nelua_shl_(context, type)
  local name = 'nelua_shl_'..type.codename
  if context.usedbuiltins[name] then return name end
  local bitsize, stype, utype = type.bitsize, type:signed_type(), type:unsigned_type()
  context:ensure_builtins('NELUA_LIKELY', 'NELUA_UNLIKELY')
  context:define_function_builtin(name,
    'NELUA_INLINE', type, {{type, 'a'}, {stype, 'b'}},
    {[[{
  if(NELUA_LIKELY(b >= 0 && b < ]],bitsize,[[)) {
    return ((]],utype,[[)a) << b;
  } else if(NELUA_UNLIKELY(b < 0 && b > -]],bitsize,[[)) {
    return (]],utype,[[)a >> -b;
  } else {
    return 0;
  }
}]]})
  return name
end

-- Used by integer logical shift right operator (`>>`).
function cbuiltins.nelua_shr_(context, type)
  local name = 'nelua_shr_'..type.codename
  if context.usedbuiltins[name] then return name end
  local bitsize, stype, utype = type.bitsize, type:signed_type(), type:unsigned_type()
  context:ensure_builtins('NELUA_LIKELY', 'NELUA_UNLIKELY')
  context:define_function_builtin(name,
    'NELUA_INLINE', type, {{type, 'a'}, {stype, 'b'}},
    {[[{
  if(NELUA_LIKELY(b >= 0 && b < ]],bitsize,[[)) {
    return (]],utype,[[)a >> b;
  } else if(NELUA_UNLIKELY(b < 0 && b > -]],bitsize,[[)) {
    return (]],utype,[[)a << -b;
  } else {
    return 0;
  }
}]]})
  return name
end

-- Used by integer arithmetic shift right operator (`>>>`).
function cbuiltins.nelua_asr_(context, type)
  local name = 'nelua_asr_'..type.codename
  if context.usedbuiltins[name] then return name end
  local bitsize = type.bitsize
  context:ensure_builtins('NELUA_LIKELY', 'NELUA_UNLIKELY')
  context:define_function_builtin(name,
    'NELUA_INLINE', type, {{type, 'a'}, {type:signed_type(), 'b'}},
    {[[{
  if(NELUA_LIKELY(b >= 0 && b < ]],bitsize,[[)) {
    return a >> b;
  } else if(NELUA_UNLIKELY(b >= ]],bitsize,[[)) {
    return a < 0 ? -1 : 0;
  } else if(NELUA_UNLIKELY(b < 0 && b > -]],bitsize,[[)) {
    return a << -b;
  } else {
    return 0;
  }
}]]})
  return name
end

--------------------------------------------------------------------------------
--[[
Call builtins.
These builtins may overrides the callee when not returning a name.
]]
cbuiltins.calls = {}

-- Implementation of `likely` builtin.
function cbuiltins.calls.likely(context)
  return context:ensure_builtin('NELUA_LIKELY')
end

-- Implementation of `unlikely` builtin.
function cbuiltins.calls.unlikely(context)
  return context:ensure_builtin('NELUA_UNLIKELY')
end

-- Implementation of `panic` builtin.
function cbuiltins.calls.panic(context)
  return context:ensure_builtin('nelua_panic_string')
end

-- Implementation of `error` builtin.
function cbuiltins.calls.error(context)
  return context:ensure_builtin('nelua_panic_string')
end

-- Implementation of `warn` builtin.
function cbuiltins.calls.warn(context)
  return context:ensure_builtin('nelua_warn')
end

-- Implementation of `assert` builtin.
function cbuiltins.calls.assert(context, node)
  local builtintype = node.attr.builtintype
  local argattrs = builtintype.argattrs
  local funcname = context.rootscope:generate_name('nelua_assert_line')
  local emitter = CEmitter(context)
  context:ensure_builtins('fwrite', 'stderr', 'NELUA_UNLIKELY', 'nelua_abort')
  local nargs = #argattrs
  local qualifier = ''
  local assertmsg = 'assertion failed!'
  local condtype = nargs > 0 and argattrs[1].type or primtypes.void
  local rettype = builtintype.rettypes[1] or primtypes.void
  local wherenode = nargs > 0 and node[1][1] or node
  local where = wherenode:format_message('runtime error', assertmsg)
  emitter:add_ln('{')
  if nargs == 2 then
    local pos = where:find(assertmsg)
    local msg1, msg2 = where:sub(1, pos-1), where:sub(pos + #assertmsg)
    local emsg1, emsg2 = pegger.double_quote_c_string(msg1), pegger.double_quote_c_string(msg2)
    emitter:add([[
  if(NELUA_UNLIKELY(!]]) emitter:add_val2boolean('cond', condtype) emitter:add([[)) {
    fwrite(]],emsg1,[[, 1, ]],#msg1,[[, stderr);
    fwrite(msg.data, msg.size, 1, stderr);
    fwrite(]],emsg2,[[, 1, ]],#msg2,[[, stderr);
    nelua_abort();
  }
]])
  elseif nargs == 1 then
    local msg = pegger.double_quote_c_string(where)
    emitter:add([[
  if(NELUA_UNLIKELY(!]]) emitter:add_val2boolean('cond', condtype) emitter:add([[)) {
    fwrite(]],msg,[[, 1, ]],#where,[[, stderr);
    nelua_abort();
  }
]])
  else -- nargs == 0
    local msg = pegger.double_quote_c_string(where)
    qualifier = 'NELUA_NORETURN'
    emitter:add([[
  fwrite(]],msg,[[, 1, ]],#where,[[, stderr);
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

-- Implementation of `check` builtin.
function cbuiltins.calls.check(context, node)
  if context.pragmas.nochecks then return end -- omit call
  return cbuiltins.calls.assert(context, node)
end

-- Implementation of `require` builtin.
function cbuiltins.calls.require(context, node, emitter)
  local attr = node.attr
  if attr.alreadyrequired then
    return
  end
  local ast = attr.loadedast
  assert(not attr.runtime_require and ast)
  local bracepos = emitter:get_pos()
  emitter:add_indent_ln("{ /* require '", attr.requirename, "' */")
  local lastpos = emitter:get_pos()
  context:push_forked_state{inrequire = true}
  context:push_scope(context.rootscope)
  context:push_forked_pragmas(attr.pragmas)
  emitter:add(ast)
  context:pop_pragmas()
  context:pop_scope()
  context:pop_state()
  if emitter:get_pos() == lastpos then
    emitter:rollback(bracepos)
  else
    emitter:add_indent_ln('}')
  end
end

-- Implementation of `print` builtin.
function cbuiltins.calls.print(context, node)
  local argtypes = node.attr.builtintype.argtypes
  -- compute args hash
  local printhash = {}
  for i,argtype in ipairs(argtypes) do
    printhash[i] = argtype.codename
  end
  printhash = table.concat(printhash,' ')
  -- generate function name
  local funcname = context.printcache[printhash]
  if funcname then
    return funcname
  end
  funcname = context.rootscope:generate_name('nelua_print')
  -- function declaration
  local decemitter = CEmitter(context)
  decemitter:add('void ', funcname, '(')
  local hasfloat
  if #argtypes > 0 then
    for i,argtype in ipairs(argtypes) do
      if i>1 then decemitter:add(', ') end
      decemitter:add(argtype, ' a', i)
      if argtype.is_float then
        hasfloat = true
      end
    end
  else
    decemitter:add_text('void')
  end
  decemitter:add(')')
  local heading = decemitter:generate()
  context:add_declaration('static '..heading..';\n', funcname)
  -- function body
  local defemitter = CEmitter(context)
  defemitter:add(heading)
  defemitter:add_ln(' {')
  defemitter:inc_indent()
  if hasfloat then
    defemitter:add_indent_ln("int len;")
    defemitter:add_indent_ln("bool fractnum;")
    defemitter:add_indent_ln("char buff[48];")
    defemitter:add_indent_ln("buff[sizeof(buff)-1] = 0;")
  end
  for i,argtype in ipairs(argtypes) do
    defemitter:add_indent()
    if i > 1 then
      context:ensure_builtins('fwrite', 'stdout')
      defemitter:add_ln("fputc('\\t', stdout);")
      defemitter:add_indent()
    end
    if argtype.is_string then
      context:ensure_builtins('fwrite', 'stdout')
      defemitter:add_ln('if(a',i,'.size > 0) {')
      defemitter:inc_indent()
      defemitter:add_indent_ln('fwrite(a',i,'.data, 1, a',i,'.size, stdout);')
      defemitter:dec_indent()
      defemitter:add_indent_ln('}')
    elseif argtype.is_cstring then
      context:ensure_builtins('fputs', 'stdout', 'NULL')
      defemitter:add_ln('fputs(a',i,' != NULL ? a',i,' : "(null cstring)", stdout);')
    elseif argtype.is_acstring then
      context:ensure_builtins('fputs', 'stdout')
      defemitter:add_ln('fputs(a',i,' != NULL ? (char*)a',i,' : "(null cstring)", stdout);')
    elseif argtype.is_niltype then
      context:ensure_builtins('fputs', 'stdout')
      defemitter:add_ln('fputs("nil", stdout);')
    elseif argtype.is_boolean then
      context:ensure_builtins('fputs', 'stdout')
      defemitter:add_ln('fputs(a',i,' ? "true" : "false", stdout);')
    elseif argtype.is_nilptr then
      context:ensure_builtins('fputs', 'stdout')
      defemitter:add_ln('fputs("(null)", stdout);')
    elseif argtype.is_pointer or argtype.is_function then
      context:ensure_builtins('fputs', 'fprintf', 'stdout', 'NULL')
      if argtype.is_function then
        defemitter:add_ln('fputs("function: ", stdout);')
      end
      defemitter:add_ln('if(a',i,' != NULL) {')
        defemitter:inc_indent()
        defemitter:add_indent_ln('fprintf(stdout, "0x%llx", (unsigned long long)(',primtypes.usize,')a',i,');')
        defemitter:dec_indent()
      defemitter:add_indent_ln('} else {')
        defemitter:inc_indent()
        defemitter:add_indent_ln('fputs("(null)", stdout);')
        defemitter:dec_indent()
      defemitter:add_indent_ln('}')
    elseif argtype.is_float then
      local fname = 'snprintf'
      local tyformat
      if argtype.is_cfloat then tyformat = '%.7g'
      elseif argtype.is_cdouble then tyformat = '%.14g'
      elseif argtype.is_clongdouble then tyformat = '%.19Lg'
      elseif argtype.is_float128 then
        fname = 'quadmath_snprintf'
        tyformat = '%.32Qg'
        context:ensure_linklib('quadmath')
      end
      if not tyformat then
        node:raisef('in print: cannot handle type "%s"', argtype)
      end
      context:ensure_builtins(fname, 'fwrite', 'stdout', 'false', 'true')
      defemitter:add_ln('len = ',fname,'(buff, sizeof(buff)-1, "',tyformat,'", a',i,');')
      defemitter:add([[
  fractnum = false;
  for(int i=0;i<len && buff[i] != 0;++i) {
    if(!((buff[i] >= '0' && buff[i] <= '9') || buff[i] == '-')) {
      fractnum = true;
      break;
    }
  }
  if(!fractnum && len > 0 && len + 2 < (int)sizeof(buff)) {
    buff[len] = '.';
    buff[len+1] = '0';
    len = len + 2;
  }
  fwrite(buff, 1, len, stdout);
]])
    elseif argtype.is_integral then
      context:ensure_builtins('fprintf', 'stdout')
      if argtype.is_enum then
        argtype = argtype.subtype
      end
      local tyformat, castname
      if argtype.is_unsigned then
        tyformat = '%llu'
        castname = 'unsigned long long'
      else
        tyformat = '%lli'
        castname = 'long long'
      end
      defemitter:add_ln('fprintf(stdout, "', tyformat,'", (',castname,')a',i,');')
    elseif argtype.is_record then
      node:raisef('in print: cannot handle type "%s", you could implement `__tostring` metamethod for it', argtype)
    else --luacov:disable
      node:raisef('in print: cannot handle type "%s"', argtype)
    end --luacov:enable
  end
  context:ensure_builtins('fputc', 'fflush', 'stdout')
  defemitter:add_indent_ln([[fputc('\n', stdout);]])
  defemitter:add_indent_ln('fflush(stdout);')
  defemitter:add_ln('}')
  context:add_definition(defemitter:generate(), funcname)
  context.printcache[printhash] = funcname
  return funcname
end

--------------------------------------------------------------------------------
--[[
Binary operators.
These builtins overrides binary operations.
]]
cbuiltins.operators = {}

-- Helper to check if two nodes are comparing a signed integral with an unsigned integral.
local function needs_signed_unsigned_comparision(lattr, rattr)
  local ltype, rtype = lattr.type, rattr.type
  if not ltype.is_integral or not rtype.is_integral or
     ltype.is_unsigned == rtype.is_unsigned or
     (lattr.comptime and not ltype.is_unsigned and lattr.value >= 0) or
     (rattr.comptime and not rtype.is_unsigned and rattr.value >= 0) then
    return false
  end
  return true
end

-- Helper to implement some binary operators.
local function operator_binary_op(op, _, node, emitter, lattr, rattr, lname, rname)
  local ltype, rtype = lattr.type, rattr.type
  if ltype.is_integral and rtype.is_integral and
     ltype.is_unsigned ~= rtype.is_unsigned and
     not lattr.comptime and not rattr.comptime then
    emitter:add('(',node.attr.type,')(', lname, ' ', op, ' ', rname, ')')
  else
    assert(ltype.is_arithmetic and rtype.is_arithmetic)
    emitter:add('(', lname, ' ', op, ' ', rname, ')')
  end
end

-- Implementation of bitwise OR operator (`|`).
function cbuiltins.operators.bor(...)
  operator_binary_op('|', ...)
end

-- Implementation of bitwise XOR operator (`~`).
function cbuiltins.operators.bxor(...)
  operator_binary_op('^', ...)
end

-- Implementation of bitwise AND operator (`&`).
function cbuiltins.operators.band(...)
  operator_binary_op('&', ...)
end

-- Implementation of add operator (`*`).
function cbuiltins.operators.add(...)
  operator_binary_op('+', ...)
end

-- Implementation of subtract operator (`*`).
function cbuiltins.operators.sub(...)
  operator_binary_op('-', ...)
end

-- Implementation of multiply operator (`*`).
function cbuiltins.operators.mul(...)
  operator_binary_op('*', ...)
end

-- Implementation of division operator (`/`).
function cbuiltins.operators.div(context, node, emitter, lattr, rattr, lname, rname)
  local type, ltype, rtype = node.attr.type, lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if not rtype.is_float and not ltype.is_float and type.is_float then
    emitter:add('(', lname, ' / (', type, ')', rname, ')')
  else
    operator_binary_op('/', context, node, emitter, lattr, rattr, lname, rname)
  end
end

-- Implementation of floor division operator (`//`).
function cbuiltins.operators.idiv(context, node, emitter, lattr, rattr, lname, rname)
  local type, ltype, rtype = node.attr.type, lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if ltype.is_float or rtype.is_float then
    emitter:add(context:ensure_cmath_func('floor', type), '(', lname, ' / ', rname, ')')
  elseif type.is_integral and (lattr:is_maybe_negative() or rattr:is_maybe_negative()) then
    emitter:add_builtin('nelua_idiv_', type, not context.pragmas.nochecks)
    emitter:add('(', lname, ', ', rname, ')')
  else
    operator_binary_op('/', context, node, emitter, lattr, rattr, lname, rname)
  end
end

-- Implementation of truncate division operator (`///`).
function cbuiltins.operators.tdiv(context, node, emitter, lattr, rattr, lname, rname)
  local type, ltype, rtype = node.attr.type, lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if ltype.is_float or rtype.is_float then
    emitter:add(context:ensure_cmath_func('trunc', type), '(', lname, ' / ', rname, ')')
  else
    operator_binary_op('/', context, node, emitter, lattr, rattr, lname, rname)
  end
end

-- Implementation of floor division remainder operator (`%`).
function cbuiltins.operators.mod(context, node, emitter, lattr, rattr, lname, rname)
  local type, ltype, rtype = node.attr.type, lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if ltype.is_float or rtype.is_float then
    emitter:add_builtin('nelua_fmod_', type)
    emitter:add('(', lname, ', ', rname, ')')
  elseif type.is_integral and (lattr:is_maybe_negative() or rattr:is_maybe_negative()) then
    emitter:add_builtin('nelua_imod_', type, not context.pragmas.nochecks)
    emitter:add('(', lname, ', ', rname, ')')
  else
    operator_binary_op('%', context, node, emitter, lattr, rattr, lname, rname)
  end
end

-- Implementation of truncate division remainder operator (`%%%`).
function cbuiltins.operators.tmod(context, node, emitter, lattr, rattr, lname, rname)
  local type, ltype, rtype = node.attr.type, lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if ltype.is_float or rtype.is_float then
    emitter:add(context:ensure_cmath_func('fmod', type), '(', lname, ', ', rname, ')')
  else
    operator_binary_op('%', context, node, emitter, lattr, rattr, lname, rname)
  end
end

-- Implementation of logical shift left operator (`<<`).
function cbuiltins.operators.shl(_, node, emitter, lattr, rattr, lname, rname)
  local type, ltype, rtype = node.attr.type, lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  assert(ltype.is_integral and rtype.is_integral)
  if rattr.comptime and rattr.value >= 0 and rattr.value < ltype.bitsize then
    -- no overflow possible, can use plain C shift
    if ltype.is_unsigned then
      emitter:add('(', lname, ' << ', rname, ')')
    else
      emitter:add('((',ltype,')((',ltype:unsigned_type(),')', lname, ' << ', rname, '))')
    end
  else
    emitter:add_builtin('nelua_shl_', type)
    emitter:add('(', lname, ', ', rname, ')')
  end
end

-- Implementation of logical shift right operator (`>>`).
function cbuiltins.operators.shr(_, node, emitter, lattr, rattr, lname, rname)
  local type, ltype, rtype = node.attr.type, lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  assert(ltype.is_integral and rtype.is_integral)
  if ltype.is_unsigned and rattr.comptime and rattr.value >= 0 and rattr.value < ltype.bitsize then
    -- no overflow possible, can use plain C shift
    emitter:add('(', lname, ' >> ', rname, ')')
  else
    emitter:add_builtin('nelua_shr_', type)
    emitter:add('(', lname, ', ', rname, ')')
  end
end

-- Implementation of arithmetic shift right operator (`>>>`).
function cbuiltins.operators.asr(_, node, emitter, lattr, rattr, lname, rname)
  local type, ltype, rtype = node.attr.type, lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  assert(ltype.is_integral and rtype.is_integral)
  if rattr.comptime and rattr.value >= 0 and rattr.value < ltype.bitsize then
    -- no overflow possible, can use plain C shift
    emitter:add('(', lname, ' >> ', rname, ')')
  else
    emitter:add_builtin('nelua_asr_', type)
    emitter:add('(', lname, ', ', rname, ')')
  end
end

-- Implementation of pow operator (`^`).
function cbuiltins.operators.pow(context, node, emitter, lattr, rattr, lname, rname)
  local type, ltype, rtype = node.attr.type, lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  emitter:add(context:ensure_cmath_func('pow', type), '(', lname, ', ', rname, ')')
end

-- Implementation of less than operator (`<`).
function cbuiltins.operators.lt(_, _, emitter, lattr, rattr, lname, rname)
  local ltype, rtype = lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if needs_signed_unsigned_comparision(lattr, rattr) then
    emitter:add_builtin('nelua_lt_', ltype, rtype)
    emitter:add('(', lname, ', ', rname, ')')
  else
    emitter:add('(', lname, ' < ', rname, ')')
  end
end

-- Implementation of greater than operator (`>`).
function cbuiltins.operators.gt(_, _, emitter, lattr, rattr, lname, rname)
  local ltype, rtype = lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if needs_signed_unsigned_comparision(lattr, rattr) then
    emitter:add_builtin('nelua_lt_', rtype, ltype)
    emitter:add('(', rname, ', ', lname, ')')
  else
    emitter:add('(', lname, ' > ', rname, ')')
  end
end

-- Implementation of less or equal than operator (`<=`).
function cbuiltins.operators.le(_, _, emitter, lattr, rattr, lname, rname)
  local ltype, rtype = lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if needs_signed_unsigned_comparision(lattr, rattr) then
    emitter:add('!')
    emitter:add_builtin('nelua_lt_', rtype, ltype)
    emitter:add('(', rname, ', ', lname, ')')
  else
    emitter:add('(', lname, ' <= ', rname, ')')
  end
end

-- Implementation of greater or equal than operator (`>=`).
function cbuiltins.operators.ge(_, _, emitter, lattr, rattr, lname, rname)
  local ltype, rtype = lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if needs_signed_unsigned_comparision(lattr, rattr) then
    emitter:add('!')
    emitter:add_builtin('nelua_lt_', ltype, rtype)
    emitter:add('(', lname, ', ', rname, ')')
  else
    emitter:add('(', lname, ' >= ', rname, ')')
  end
end

-- Implementation of equal operator (`==`).
function cbuiltins.operators.eq(_, _, emitter, lattr, rattr, lname, rname)
  local ltype, rtype = lattr.type, rattr.type
  if ltype.is_stringy and rtype.is_stringy then
    emitter:add_builtin('nelua_eq_string')
    emitter:add('(')
    emitter:add_converted_val(primtypes.string, lname, ltype)
    emitter:add(', ')
    emitter:add_converted_val(primtypes.string, rname, rtype)
    emitter:add(')')
  elseif ltype.is_composite or rtype.is_composite then
    if ltype == rtype then
      emitter:add_builtin('nelua_eq_', ltype)
      emitter:add('(', lname, ', ', rname, ')')
    else
      emitter:add('(', lname, ', ', rname, ', ', false, ')')
    end
  elseif ltype.is_array then
    assert(ltype == rtype)
    if lattr.lvalue and rattr.lvalue and not lattr.comptime and not rattr.comptime then
      emitter:add('(')
      emitter:add_builtin('memcmp')
      emitter:add('(&', lname, ', &', rname, ', sizeof(', ltype, ')) == 0)')
    else
      emitter:add('({', ltype, ' a = ', lname, '; ',
                        rtype, ' b = ', rname, '; ')
      emitter:add_builtin('memcmp')
      emitter:add('(&a, &b, sizeof(', ltype, ')) == 0; })')
    end
  elseif needs_signed_unsigned_comparision(lattr, rattr) then
    if ltype.is_unsigned then
      ltype, rtype, lname, rname = rtype, ltype, rname, lname -- swap
    end
    emitter:add_builtin('nelua_eq_', ltype, rtype)
    emitter:add('(', lname, ', ', rname, ')')
  elseif ltype.is_scalar and rtype.is_scalar then
    emitter:add('(', lname, ' == ', rname, ')')
  elseif ltype.is_niltype or rtype.is_niltype or
         ((ltype.is_boolean or rtype.is_boolean) and ltype ~= rtype) then
    emitter:add('(', lname, ', ', rname, ', ', ltype == rtype, ')')
  else
    emitter:add('(', lname, ' == ')
    if ltype ~= rtype then
      emitter:add_converted_val(ltype, rname, rtype)
    else
      emitter:add(rname)
    end
    emitter:add(')')
  end
end

-- Implementation of not equal operator (`~=`).
function cbuiltins.operators.ne(_, _, emitter, lattr, rattr, lname, rname)
  local ltype, rtype = lattr.type, rattr.type
  if ltype.is_stringy and rtype.is_string then
    emitter:add('(!')
    emitter:add_builtin('nelua_eq_string')
    emitter:add('(')
    emitter:add_converted_val(primtypes.string, lname, ltype)
    emitter:add(', ')
    emitter:add_converted_val(primtypes.string, rname, rtype)
    emitter:add('))')
  elseif ltype.is_composite or rtype.is_composite then
    if ltype == rtype then
      emitter:add('(!')
      emitter:add_builtin('nelua_eq_', ltype)
      emitter:add('(', lname, ', ', rname, '))')
    else
      emitter:add('(', lname, ', ', rname, ', ', true, ')')
    end
  elseif ltype.is_array then
    assert(ltype == rtype)
    if lattr.lvalue and rattr.lvalue and not lattr.comptime and not rattr.comptime then
      emitter:add('(')
      emitter:add_builtin('memcmp')
      emitter:add('(&', lname, ', &', rname, ', sizeof(', ltype, ')) != 0)')
    else
      emitter:add('({', ltype, ' a = ', lname, '; ',
                        rtype, ' b = ', rname, '; ')
      emitter:add_builtin('memcmp')
      emitter:add('(&a, &b, sizeof(', ltype, ')) != 0; })')
    end
  elseif needs_signed_unsigned_comparision(lattr, rattr) then
    if ltype.is_unsigned then
      ltype, rtype, lname, rname = rtype, ltype, rname, lname -- swap
    end
    emitter:add('(!')
    emitter:add_builtin('nelua_eq_', ltype, rtype)
    emitter:add('(', lname, ', ', rname, '))')
  elseif ltype.is_scalar and rtype.is_scalar then
    emitter:add('(', lname, ' != ', rname, ')')
  elseif ltype.is_niltype or rtype.is_niltype or
         ((ltype.is_boolean or rtype.is_boolean) and ltype ~= rtype) then
    emitter:add('(', lname, ', ', rname, ', ', ltype ~= rtype, ')')
  else
    emitter:add('(', lname, ' != ')
    if ltype ~= rtype then
      emitter:add_converted_val(ltype, rname, rtype)
    else
      emitter:add(rname)
    end
    emitter:add(')')
  end
end

-- Implementation of conditional OR operator (`or`).
cbuiltins.operators["or"] = function(_, _, emitter, lattr, rattr, lname, rname)
  emitter:add_text('(')
  emitter:add_val2boolean(lname, lattr.type)
  emitter:add_text(' || ')
  emitter:add_val2boolean(rname, rattr.type)
  emitter:add_text(')')
end

-- Implementation of conditional AND operator (`and`).
cbuiltins.operators["and"] = function(_, _, emitter, lattr, rattr, lname, rname)
  emitter:add_text('(')
  emitter:add_val2boolean(lname, lattr.type)
  emitter:add_text(' && ')
  emitter:add_val2boolean(rname, rattr.type)
  emitter:add_text(')')
end

-- Implementation of not operator (`not`).
cbuiltins.operators["not"] = function(_, _, emitter, argattr, argname)
  emitter:add_text('(!')
  emitter:add_val2boolean(argname, argattr.type)
  emitter:add_text(')')
end

-- Implementation of unary minus operator (`-`).
function cbuiltins.operators.unm(_, _, emitter, argattr, argname)
  assert(argattr.type.is_arithmetic)
  emitter:add('(-', argname, ')')
end

-- Implementation of bitwise not operator (`~`).
function cbuiltins.operators.bnot(_, _, emitter, argattr, argname)
  assert(argattr.type.is_integral)
  emitter:add('(~', argname, ')')
end

-- Implementation of reference operator (`&`).
function cbuiltins.operators.ref(_, _, emitter, argattr, argname)
  assert(argattr.lvalue)
  emitter:add('(&', argname, ')')
end

-- Implementation of dereference operator (`$`).
function cbuiltins.operators.deref(_, _, emitter, argattr, argname)
  local type = argattr.type
  assert(type.is_pointer)
  emitter:add_deref(argname, type)
end

-- Implementation of length operator (`#`).
function cbuiltins.operators.len(_, node, emitter, argattr, argname)
  local type = argattr.type
  if type.is_string then
    emitter:add('((',primtypes.isize,')(', argname, ').size)')
  elseif type.is_cstring then
    emitter:add('((',primtypes.isize,')')
    emitter:add_builtin('strlen')
    emitter:add('(', argname, '))')
  elseif type.is_type then
    emitter:add('sizeof(', argattr.value, ')')
  else --luacov:disable
    node:raisef('not implemented')
  end --luacov:enable
end

return cbuiltins
