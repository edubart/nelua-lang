--[[
C builtins.

This module defines implementations for many builtin C functions used by the C code generator.
]]

local pegger = require 'nelua.utils.pegger'
local bn = require 'nelua.utils.bn'
local cdefs = require 'nelua.cdefs'
local CEmitter = require 'nelua.cemitter'
local primtypes = require 'nelua.typedefs'.primtypes

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
function cbuiltins.nelua_likely(context)
  context:define_builtin_macro('nelua_likely', [[
#ifdef __GNUC__
#define nelua_likely(x) __builtin_expect(x, 1)
#define nelua_unlikely(x) __builtin_expect(x, 0)
#else
#define nelua_likely(x) (x)
#define nelua_unlikely(x) (x)
#endif
]], 'directives')
end

-- Used by `unlikely` builtin.
function cbuiltins.nelua_unlikely(context)
  context:ensure_builtin('nelua_likely')
end

-- Used by `<cexport>`.
function cbuiltins.nelua_cexport(context)
  context:define_builtin_macro('nelua_cexport', [[
#ifdef _WIN32
#define nelua_cexport __declspec(dllexport) extern
#elif defined(__GNUC__)
#define nelua_cexport __attribute__((visibility ("default"))) extern
#else
#define nelua_cexport extern
#endif
]], 'directives')
end

-- Used by `<noinline>`.
function cbuiltins.nelua_noinline(context)
  context:define_builtin_macro('nelua_noinline', [[
#ifdef __GNUC__
#define nelua_noinline __attribute__((noinline))
#else
#define nelua_noinline
#endif
]], 'directives')
end

-- Used by `<inline>`.
function cbuiltins.nelua_inline(context)
  context:define_builtin_macro('nelua_inline', [[
#ifdef __GNUC__
#define nelua_inline __attribute__((always_inline)) inline
#elif __STDC_VERSION__ >= 199901L
#define nelua_inline inline
#else
#define nelua_inline
#endif
]], 'directives')
end

-- Used by `<noreturn>`.
function cbuiltins.nelua_noreturn(context)
  context:define_builtin_macro('nelua_noreturn', [[
#if __STDC_VERSION__ >= 201112L
#define nelua_noreturn _Noreturn
#elif defined(__GNUC__)
#define nelua_noreturn __attribute__((noreturn))
#else
#define nelua_noreturn
#endif
]], 'directives')
end

-- Used to assure some C compiler requirements.
function cbuiltins.nelua_static_assert(context)
  context:define_builtin_macro('nelua_static_assert', [[
#if __STDC_VERSION__ >= 201112L
#define nelua_static_assert _Static_assert
#elif defined(__cplusplus) && __cplusplus >= 201103L
#define nelua_static_assert static_assert
#else
#define nelua_static_assert(x, y)
#endif
]], 'directives')
end

-- Used to assure some C compiler requirements.
function cbuiltins.nelua_alignof(context)
  context:define_builtin_macro('nelua_alignof', [[
#if __STDC_VERSION__ >= 201112L
#define nelua_alignof _Alignof
#elif defined(__cplusplus) && __cplusplus >= 201103L
#define nelua_alignof alignof
#else
#define nelua_alignof(x)
#endif
]], 'directives')
end

-- Used by `nil` type at runtime.
function cbuiltins.nlniltype(context)
  context:define_builtin_decl('nlniltype', "typedef struct nlniltype {} nlniltype;")
end

-- Used by `nil` at runtime.
function cbuiltins.NLNIL(context)
  context:ensure_builtin('nlniltype')
  context:define_builtin_macro('NLNIL', "#define NLNIL (nlniltype){}")
end

-- Used by infinite float number literal.
function cbuiltins.NLINF_(context, type)
  local name = type.is_float32 and 'NLINFF' or 'NLINF'
  if context.usedbuiltins[name] then return name end
  if type.is_float32 then
    context:define_builtin_macro(name, "#define "..name.." (1.0f/0.0f)")
  else
    context:define_builtin_macro(name, "#define "..name.." (1.0/0.0)")
  end
  return name
end

-- Used by NaN (not a number) float number literal.
function cbuiltins.NLNAN_(context, type)
  local name = type.is_float32 and 'NLNANF' or 'NLNAN'
  if context.usedbuiltins[name] then return name end
  if type.is_float32 then
    context:define_builtin_macro(name, "#define "..name.." (0.0f/0.0f)")
  else
    context:define_builtin_macro(name, "#define "..name.." (0.0/0.0)")
  end
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
  context:ensure_builtins('fflush', 'stderr')
  context:define_function_builtin('nelua_abort',
    'nelua_noreturn', primtypes.void, {}, {[[{
  fflush(stderr);
  ]],abortcall,[[;
}]]})
end

-- Used with check functions.
function cbuiltins.nelua_panic_cstring(context)
  context:ensure_builtins('fputs', 'fputc', 'nelua_abort')
  context:define_function_builtin('nelua_panic_cstring',
    'nelua_noreturn', primtypes.void, {{'const char*', 's'}}, [[{
  fputs(s, stderr);
  fputc('\n', stderr);
  nelua_abort();
}]])
end

-- Used by `panic` builtin.
function cbuiltins.nelua_panic_string(context)
  context:ensure_builtins('fwrite', 'fputc', 'nelua_abort')
  context:define_function_builtin('nelua_panic_string',
    'nelua_noreturn', primtypes.void, {{primtypes.string, 's'}}, [[{
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
  context:ensure_builtins('nelua_unlikely', 'nelua_panic_cstring')
  local emitter = CEmitter(context)
  emitter:add_ln('{') emitter:inc_indent()
  emitter:add_indent('if(nelua_unlikely(')
  if stype.is_float then -- float -> integral
    emitter:add('(',dtype,')(x) != x')
  elseif stype.is_signed and dtype.is_unsigned then -- signed -> unsigned
    emitter:add('x < 0')
    if stype.max > dtype.max then
      emitter:add(' || x > 0x', bn.tohexint(dtype.max))
    end
  elseif stype.is_unsigned and dtype.is_signed then -- unsigned -> signed
    emitter:add('x > 0x', bn.tohexint(dtype.max), 'U')
  else -- signed -> signed / unsigned -> unsigned
    emitter:add('x > 0x', bn.tohexint(dtype.max), (stype.is_unsigned and 'U' or ''))
    if stype.is_signed then -- signed -> signed
      emitter:add(' || x < ', bn.todecint(dtype.min))
    end
  end
  emitter:add_ln(')) {') emitter:inc_indent()
  emitter:add_indent_ln('nelua_panic_cstring("narrow casting from ',
      tostring(stype),' to ',tostring(dtype),' failed");')
  emitter:dec_indent() emitter:add_indent_ln('}')
  emitter:add_indent_ln('return x;')
  emitter:dec_indent() emitter:add('}')
  context:define_function_builtin(name, 'nelua_inline', dtype, {{stype, 'x'}}, emitter:generate())
  return name
end

-- Used to check array bounds when indexing.
function cbuiltins.nelua_assert_bounds_(context, indextype)
  local name = 'nelua_assert_bounds_'..indextype.codename
  if context.usedbuiltins[name] then return name end
  context:ensure_builtins('nelua_panic_cstring', 'nelua_unlikely')
  context:define_function_builtin(name,
    'nelua_inline', indextype, {{indextype, 'index'}, {primtypes.usize, 'len'}}, {[[{
  if(nelua_unlikely((]],primtypes.usize,')index >= len',indextype.is_signed and ' || index < 0' or '',[[)) {
    nelua_panic_cstring("array index: position out of bounds");
  }
  return index;
}]]})
  return name
end

-- Used to check dereference of pointers.
function cbuiltins.nelua_assert_deref_(context, pointertype)
  local name = 'nelua_assert_deref_'..pointertype.codename
  if context.usedbuiltins[name] then return name end
  context:ensure_builtins('nelua_panic_cstring', 'nelua_unlikely', 'NULL')
  context:define_function_builtin(name,
    'nelua_inline', pointertype,  {{pointertype, 'p'}}, [[{
  if(nelua_unlikely(p == NULL)) {
    nelua_panic_cstring("attempt to dereference a null pointer");
  }
  return p;
}]])
  return name
end

-- Used to convert a string to a C string.
function cbuiltins.nelua_string2cstring_(context, checked)
  local name = checked and 'nelua_assert_string2cstring' or 'nelua_string2cstring'
  if context.usedbuiltins[name] then return name end
  local code
  if checked then
    context:ensure_builtins('nelua_panic_cstring', 'nelua_unlikely')
    code = [[{
    if(s.size == 0) {
      return (char*)"";
    }
    if(nelua_unlikely(s.data[s.size]) != 0) {
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
    'nelua_inline', primtypes.cstring, {{primtypes.string, 's'}}, code)
  return name
end

-- Used to convert a C string to a string.
function cbuiltins.nelua_cstring2string(context)
  context:ensure_builtins('strlen', 'NULL')
  context:define_function_builtin('nelua_cstring2string',
    'nelua_inline', primtypes.string, {{'const char*', 's'}}, {[[{
  if(s == NULL) return (]],primtypes.string,[[){0};
  ]], primtypes.usize, [[ size = strlen(s);
  if(size == 0) return (]],primtypes.string,[[){0};
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
    'nelua_inline', primtypes.boolean, {{ltype, 'a'}, {rtype, 'b'}}, emitter:generate())
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
      'nelua_inline', primtypes.boolean, {{type, 'a'}, {type, 'b'}},
      defemitter:generate())
    return name
  else -- comparing different types
    local name = 'nelua_eq_'..ltype.codename..'_'..rtype.codename
    if context.usedbuiltins[name] then return name end
    assert(ltype.is_integral and ltype.is_signed and rtype.is_unsigned)
    local mtype = primtypes['uint'..math.max(ltype.bitsize, rtype.bitsize)]
    context:define_function_builtin(name,
      'nelua_inline', primtypes.boolean, {{ltype, 'a'}, {rtype, 'b'}}, {[[{
  return (]],mtype,[[)a == (]],mtype,[[)b && a >= 0;
}]]})
    return name
  end
end

-- Used by string equality operator (`==`).
function cbuiltins.nelua_eq_string(context)
  context:ensure_builtins('memcmp')
  context:define_function_builtin('nelua_eq_string',
    'nelua_inline', primtypes.boolean, {{primtypes.string, 'a'}, {primtypes.string, 'b'}}, [[{
  return a.size == b.size && (a.data == b.data || a.size == 0 || memcmp(a.data, b.data, a.size) == 0);
}]])
end

-- Used by integer division operator (`//`).
function cbuiltins.nelua_idiv_(context, type, checked)
  local name = (checked and 'nelua_assert_idiv_' or 'nelua_idiv_')..type.codename
  if context.usedbuiltins[name] then return name end
  assert(type.is_signed)
  local stype, utype = type:signed_type(), type:unsigned_type()
  context:ensure_builtins('nelua_unlikely', 'nelua_panic_cstring')
  local emitter = CEmitter(context)
  emitter:add_ln('{') emitter:inc_indent()
  emitter:add_indent_ln('if(nelua_unlikely(b == -1)) return 0U - (', utype ,')a;')
  if not checked then
    emitter:add_indent_ln('if(nelua_unlikely(b == 0)) nelua_panic_cstring("division by zero");')
  end
  emitter:add_indent_ln(stype,' q = a / b;')
  emitter:add_indent_ln('return q * b == a ? q : q - ((a < 0) ^ (b < 0));')
  emitter:dec_indent() emitter:add_ln('}')
  context:define_function_builtin(name,
    'nelua_inline', type, {{type, 'a'}, {type, 'b'}}, emitter:generate())
  return name
end

-- Used by integer modulo operator (`%`).
function cbuiltins.nelua_imod_(context, type, checked)
  local name = (checked and  'nelua_assert_imod_' or 'nelua_imod_')..type.codename
  if context.usedbuiltins[name] then return name end
  assert(type.is_signed)
  context:ensure_builtins('nelua_unlikely', 'nelua_panic_cstring')
  local emitter = CEmitter(context)
  emitter:add_ln('{') emitter:inc_indent()
  emitter:add_indent_ln('if(nelua_unlikely(b == -1)) return 0;')
  if checked then
    emitter:add_indent_ln('if(nelua_unlikely(b == 0)) nelua_panic_cstring("division by zero");')
  end
  emitter:add_indent_ln(type,' r = a % b;')
  emitter:add_indent_ln('return (r != 0 && (a ^ b) < 0) ? r + b : r;')
  emitter:dec_indent() emitter:add_ln('}')
  context:define_function_builtin(name,
    'nelua_inline', type, {{type, 'a'}, {type, 'b'}}, emitter:generate())
  return name
end

-- Used by float modulo operator (`%`).
function cbuiltins.nelua_fmod_(context, type)
  local cfmod = type.is_float32 and 'fmodf' or 'fmod'
  local name = 'nelua_'..cfmod
  if context.usedbuiltins[name] then return name end
  context:ensure_builtins(cfmod, 'nelua_unlikely')
  context:define_function_builtin(name,
    'nelua_inline', type, {{type, 'a'}, {type, 'b'}}, {[[{
  ]],type,[[ r = ]],cfmod,[[(a, b);
  if(nelua_unlikely((r > 0 && b < 0) || (r < 0 && b > 0)))
    r += b;
  return r;
}]]})
  return name
end

-- Used by integer logical shift left operator (`<<`).
function cbuiltins.nelua_shl_(context, type)
  local name = 'nelua_shl_'..type.codename
  if context.usedbuiltins[name] then return name end
  local bitsize, stype, utype = type.bitsize, type:signed_type(), type:unsigned_type()
  context:ensure_builtins('nelua_unlikely')
  context:define_function_builtin(name,
    'nelua_inline', type, {{type, 'a'}, {stype, 'b'}},
    {[[{
  if(nelua_likely(b >= 0 && b < ]],bitsize,[[)) return (]],utype,[[)a << b;
  else if(nelua_unlikely(b < 0 && b > -]],bitsize,[[)) return (]],utype,[[)a >> -b;
  else return 0;
}]]})
  return name
end

-- Used by integer logical shift right operator (`>>`).
function cbuiltins.nelua_shr_(context, type)
  local name = 'nelua_shr_'..type.codename
  if context.usedbuiltins[name] then return name end
  local bitsize, stype, utype = type.bitsize, type:signed_type(), type:unsigned_type()
  context:ensure_builtins('nelua_unlikely')
  context:define_function_builtin(name,
    'nelua_inline', type, {{type, 'a'}, {stype, 'b'}},
    {[[{
  if(nelua_likely(b >= 0 && b < ]],bitsize,[[)) return (]],utype,[[)a >> b;
  else if(nelua_unlikely(b < 0 && b > -]],bitsize,[[)) return (]],utype,[[)a << -b;
  else return 0;
}]]})
  return name
end

-- Used by integer arithmetic shift right operator (`>>>`).
function cbuiltins.nelua_asr_(context, type)
  local name = 'nelua_asr_'..type.codename
  if context.usedbuiltins[name] then return name end
  local bitsize = type.bitsize
  context:ensure_builtins('nelua_unlikely')
  context:define_function_builtin(name,
    'nelua_inline', type, {{type, 'a'}, {type:signed_type(), 'b'}},
    {[[{
  if(nelua_likely(b >= 0 && b < ]],bitsize,[[)) return a >> b;
  else if(nelua_unlikely(b >= ]],bitsize,[[)) return a < 0 ? -1 : 0;
  else if(nelua_unlikely(b < 0 && b > -]],bitsize,[[)) return a << -b;
  else return 0;
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
  return context:ensure_builtin('nelua_likely')
end

-- Implementation of `unlikely` builtin.
function cbuiltins.calls.unlikely(context)
  return context:ensure_builtin('nelua_unlikely')
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
  local funcname = context:genuniquename('nelua_assert_line')
  local emitter = CEmitter(context)
  context:ensure_builtins('fwrite', 'stderr', 'nelua_unlikely', 'nelua_abort')
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
  if(nelua_unlikely(!]]) emitter:add_val2boolean('cond', condtype) emitter:add([[)) {
    fwrite(]],emsg1,[[, 1, ]],#msg1,[[, stderr);
    fwrite(msg.data, msg.size, 1, stderr);
    fwrite(]],emsg2,[[, 1, ]],#msg2,[[, stderr);
    nelua_abort();
  }
]])
  elseif nargs == 1 then
    local msg = pegger.double_quote_c_string(where)
    emitter:add([[
  if(nelua_unlikely(!]]) emitter:add_val2boolean('cond', condtype) emitter:add([[)) {
    fwrite(]],msg,[[, 1, ]],#where,[[, stderr);
    nelua_abort();
  }
]])
  else -- nargs == 0
    local msg = pegger.double_quote_c_string(where)
    qualifier = 'nelua_noreturn'
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
    emitter:trim(bracepos)
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
  funcname = context:genuniquename('nelua_print')
  -- function declaration
  local decemitter = CEmitter(context)
  decemitter:add('void ', funcname, '(')
  local hasfloat
  for i,argtype in ipairs(argtypes) do
    if i>1 then decemitter:add(', ') end
    decemitter:add(argtype, ' a', i)
    if argtype.is_float then
      hasfloat = true
    end
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
    defemitter:add_indent_ln("char buff[48];")
    defemitter:add_indent_ln("buff[sizeof(buff)-1] = 0;")
    defemitter:add_indent_ln("int len;")
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
      context:ensure_builtins('fputs', 'stdout')
      defemitter:add_ln('fputs(a',i,', stdout);')
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
      context:ensure_builtins('fputs', 'fprintf', 'stdout', 'PRIxPTR', 'NULL')
      if argtype.is_function then
        defemitter:add_ln('fputs("function: ", stdout);')
      end
      defemitter:add_ln('if(a',i,' != NULL) {')
        defemitter:inc_indent()
        defemitter:add_indent_ln('fprintf(stdout, "0x%" PRIxPTR, (',primtypes.isize,')a',i,');')
        defemitter:dec_indent()
      defemitter:add_indent_ln('} else {')
        defemitter:inc_indent()
        defemitter:add_indent_ln('fputs("(null)", stdout);')
        defemitter:dec_indent()
      defemitter:add_indent_ln('}')
    elseif argtype.is_float then
      context:ensure_builtins('snprintf', 'strspn', 'fwrite', 'stdout')
      local tyformat = cdefs.types_printf_format[argtype.codename]
      assert(tyformat, 'invalid type for printf format')
      defemitter:add_ln('len = snprintf(buff, sizeof(buff)-1, ',tyformat,', a',i,');')
      defemitter:add_indent_ln('if(buff[strspn(buff, "-0123456789")] == 0) {')
        defemitter:inc_indent()
        defemitter:add_indent_ln('len = snprintf(buff, sizeof(buff)-1, "%.1f", a',i,');')
        defemitter:dec_indent()
      defemitter:add_indent_ln('}')
      defemitter:add_indent_ln('fwrite(buff, 1, len, stdout);')
    elseif argtype.is_scalar then
      context:ensure_builtins('fprintf', 'stdout')
      if argtype.is_enum then
        argtype = argtype.subtype
      end
      local tyformat = cdefs.types_printf_format[argtype.codename]
      local priformat = tyformat:match('PRI[%w]+')
      if priformat then
        context:ensure_builtin(priformat)
      end
      assert(tyformat, 'invalid type for printf format')
      defemitter:add_ln('fprintf(stdout, ', tyformat,', a',i,');')
    elseif argtype.is_record then
      node:raisef('cannot handle type "%s" in print, you could implement `__tostring` metamethod for it', argtype)
    else --luacov:disable
      node:raisef('cannot handle type "%s" in print', argtype)
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
local function needs_signed_unsigned_comparision(lnode, rnode)
  local lattr, rattr = lnode.attr, rnode.attr
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
local function operator_binary_op(op, _, node, emitter, lnode, rnode, lname, rname)
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
function cbuiltins.operators.div(context, node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if not rtype.is_float and not ltype.is_float and type.is_float then
    emitter:add(lname, ' / (', type, ')', rname)
  else
    operator_binary_op('/', context, node, emitter, lnode, rnode, lname, rname)
  end
end

-- Implementation of floor division operator (`//`).
function cbuiltins.operators.idiv(context, node, emitter, lnode, rnode, lname, rname)
  local lattr, rattr = lnode.attr, rnode.attr
  local type, ltype, rtype = node.attr.type, lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if ltype.is_float or rtype.is_float then
    emitter:add_builtin(type.is_float32 and 'floorf' or 'floor')
    emitter:add('(', lname, ' / ', rname, ')')
  elseif type.is_integral and (lattr:is_maybe_negative() or rattr:is_maybe_negative()) then
    emitter:add_builtin('nelua_idiv_', type, not context.pragmas.nochecks)
    emitter:add('(', lname, ', ', rname, ')')
  else
    operator_binary_op('/', context, node, emitter, lnode, rnode, lname, rname)
  end
end

-- Implementation of truncate division operator (`///`).
function cbuiltins.operators.tdiv(context, node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if ltype.is_float or rtype.is_float then
    emitter:add_builtin(type.is_float32 and 'truncf' or 'trunc')
    emitter:add('(', lname, ' / ', rname, ')')
  else
    operator_binary_op('/', context, node, emitter, lnode, rnode, lname, rname)
  end
end

-- Implementation of floor division remainder operator (`%`).
function cbuiltins.operators.mod(context, node, emitter, lnode, rnode, lname, rname)
  local lattr, rattr = lnode.attr, rnode.attr
  local type, ltype, rtype = node.attr.type, lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if ltype.is_float or rtype.is_float then
    emitter:add_builtin('nelua_fmod_', type)
    emitter:add('(', lname, ', ', rname, ')')
  elseif type.is_integral and (lattr:is_maybe_negative() or rattr:is_maybe_negative()) then
    emitter:add_builtin('nelua_imod_', type, not context.pragmas.nochecks)
    emitter:add('(', lname, ', ', rname, ')')
  else
    operator_binary_op('%', context, node, emitter, lnode, rnode, lname, rname)
  end
end

-- Implementation of truncate division remainder operator (`%%%`).
function cbuiltins.operators.tmod(context, node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if ltype.is_float or rtype.is_float then
    emitter:add_builtin(type.is_float32 and 'fmodf' or 'fmod')
    emitter:add('(', lname, ', ', rname, ')')
  else
    operator_binary_op('%', context, node, emitter, lnode, rnode, lname, rname)
  end
end

-- Implementation of logical shift left operator (`<<`).
function cbuiltins.operators.shl(_, node, emitter, lnode, rnode, lname, rname)
  local lattr, rattr = lnode.attr, rnode.attr
  local type, ltype, rtype = node.attr.type, lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  assert(ltype.is_integral and rtype.is_integral)
  if rattr.comptime and rattr.value >= 0 and rattr.value < ltype.bitsize then
    -- no overflow possible, can use plain C shift
    emitter:add(lname, ' << ', rname)
  else
    emitter:add_builtin('nelua_shl_', type)
    emitter:add('(', lname, ', ', rname, ')')
  end
end

-- Implementation of logical shift right operator (`>>`).
function cbuiltins.operators.shr(_, node, emitter, lnode, rnode, lname, rname)
  local lattr, rattr = lnode.attr, rnode.attr
  local type, ltype, rtype = node.attr.type, lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  assert(ltype.is_integral and rtype.is_integral)
  if ltype.is_unsigned and rattr.comptime and rattr.value >= 0 and rattr.value < ltype.bitsize then
    -- no overflow possible, can use plain C shift
    emitter:add(lname, ' >> ', rname)
  else
    emitter:add_builtin('nelua_shr_', type)
    emitter:add('(', lname, ', ', rname, ')')
  end
end

-- Implementation of arithmetic shift right operator (`>>>`).
function cbuiltins.operators.asr(_, node, emitter, lnode, rnode, lname, rname)
  local lattr, rattr = lnode.attr, rnode.attr
  local type, ltype, rtype = node.attr.type, lattr.type, rattr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  assert(ltype.is_integral and rtype.is_integral)
  if rattr.comptime and rattr.value >= 0 and rattr.value < ltype.bitsize then
    -- no overflow possible, can use plain C shift
    emitter:add(lname, ' >> ', rname)
  else
    emitter:add_builtin('nelua_asr_', type)
    emitter:add('(', lname, ', ', rname, ')')
  end
end

-- Implementation of pow operator (`^`).
function cbuiltins.operators.pow(_, node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  emitter:add_builtin(type.is_float32 and 'powf' or 'pow')
  emitter:add('(', lname, ', ', rname, ')')
end

-- Implementation of less than operator (`<`).
function cbuiltins.operators.lt(_, _, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if needs_signed_unsigned_comparision(lnode, rnode) then
    emitter:add_builtin('nelua_lt_', ltype, rtype)
    emitter:add('(', lname, ', ', rname, ')')
  else
    emitter:add(lname, ' < ', rname)
  end
end

-- Implementation of greater than operator (`>`).
function cbuiltins.operators.gt(_, _, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if needs_signed_unsigned_comparision(lnode, rnode) then
    emitter:add_builtin('nelua_lt_', rtype, ltype)
    emitter:add('(', rname, ', ', lname, ')')
  else
    emitter:add(lname, ' > ', rname)
  end
end

-- Implementation of less or equal than operator (`<=`).
function cbuiltins.operators.le(_, _, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if needs_signed_unsigned_comparision(lnode, rnode) then
    emitter:add('!')
    emitter:add_builtin('nelua_lt_', rtype, ltype)
    emitter:add('(', rname, ', ', lname, ')')
  else
    emitter:add(lname, ' <= ', rname)
  end
end

-- Implementation of greater or equal than operator (`>=`).
function cbuiltins.operators.ge(_, _, emitter, lnode, rnode, lname, rname)
  local ltype, rtype = lnode.attr.type, rnode.attr.type
  assert(ltype.is_arithmetic and rtype.is_arithmetic)
  if needs_signed_unsigned_comparision(lnode, rnode) then
    emitter:add('!')
    emitter:add_builtin('nelua_lt_', ltype, rtype)
    emitter:add('(', lname, ', ', rname, ')')
  else
    emitter:add(lname, ' >= ', rname)
  end
end

-- Implementation of equal operator (`==`).
function cbuiltins.operators.eq(_, _, emitter, lnode, rnode, lname, rname)
  local lattr, rattr = lnode.attr, rnode.attr
  local ltype, rtype = lattr.type, rattr.type
  if (ltype.is_string and (rtype.is_string or rtype.is_cstring)) or
     (ltype.is_cstring and rtype.is_string) then
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
      emitter:add('((void)', lname, ', (void)', rname, ', ', false, ')')
    end
  elseif ltype.is_array then
    assert(ltype == rtype)
    if lattr.lvalue and rattr.lvalue then
      emitter:add_builtin('memcmp')
      emitter:add('(&', lname, ', &', rname, ', sizeof(', ltype, ')) == 0')
    else
      emitter:add('({', ltype, ' a = ', lname, '; ',
                        rtype, ' b = ', rname, '; ')
      emitter:add_builtin('memcmp')
      emitter:add('(&a, &b, sizeof(', ltype, ')) == 0; })')
    end
  elseif needs_signed_unsigned_comparision(lnode, rnode) then
    if ltype.is_unsigned then
      ltype, rtype, lname, rname = rtype, ltype, rname, lname -- swap
    end
    emitter:add_builtin('nelua_eq_', ltype, rtype)
    emitter:add('(', lname, ', ', rname, ')')
  elseif ltype.is_scalar and rtype.is_scalar then
    emitter:add(lname, ' == ', rname)
  elseif ltype.is_niltype or rtype.is_niltype or
         ((ltype.is_boolean or rtype.is_boolean) and ltype ~= rtype) then
    emitter:add('((void)', lname, ', (void)', rname, ', ', ltype == rtype, ')')
  else
    emitter:add(lname, ' == ')
    if ltype ~= rtype then
      emitter:add_converted_val(ltype, rname, rtype)
    else
      emitter:add(rname)
    end
  end
end

-- Implementation of not equal operator (`~=`).
function cbuiltins.operators.ne(_, _, emitter, lnode, rnode, lname, rname)
  local lattr, rattr = lnode.attr, rnode.attr
  local ltype, rtype = lattr.type, rattr.type
  if (ltype.is_string and (rtype.is_string or rtype.is_cstring)) or
     (ltype.is_cstring and rtype.is_string) then
    emitter:add('!')
    emitter:add_builtin('nelua_eq_string')
    emitter:add('(')
    emitter:add_converted_val(primtypes.string, lname, ltype)
    emitter:add(', ')
    emitter:add_converted_val(primtypes.string, rname, rtype)
    emitter:add(')')
  elseif ltype.is_composite or rtype.is_composite then
    if ltype == rtype then
      emitter:add('!')
      emitter:add_builtin('nelua_eq_', ltype)
      emitter:add('(', lname, ', ', rname, ')')
    else
      emitter:add('((void)', lname, ', (void)', rname, ', ', true, ')')
    end
  elseif ltype.is_array then
    assert(ltype == rtype)
    if lattr.lvalue and rattr.lvalue then
      emitter:add_builtin('memcmp')
      emitter:add('(&', lname, ', &', rname, ', sizeof(', ltype, ')) != 0')
    else
      emitter:add('({', ltype, ' a = ', lname, '; ',
                        rtype, ' b = ', rname, '; ')
      emitter:add_builtin('memcmp')
      emitter:add('(&a, &b, sizeof(', ltype, ')) != 0; })')
    end
  elseif needs_signed_unsigned_comparision(lnode, rnode) then
    if ltype.is_unsigned then
      ltype, rtype, lname, rname = rtype, ltype, rname, lname -- swap
    end
    emitter:add('!')
    emitter:add_builtin('nelua_eq_', ltype, rtype)
    emitter:add('(', lname, ', ', rname, ')')
  elseif ltype.is_scalar and rtype.is_scalar then
    emitter:add(lname, ' != ', rname)
  elseif ltype.is_niltype or rtype.is_niltype or
         ((ltype.is_boolean or rtype.is_boolean) and ltype ~= rtype) then
    emitter:add('((void)', lname, ', (void)', rname, ', ', ltype ~= rtype, ')')
  else
    emitter:add(lname, ' != ')
    if ltype ~= rtype then
      emitter:add_converted_val(ltype, rname, rtype)
    else
      emitter:add(rname)
    end
  end
end

-- Implementation of conditional OR operator (`or`).
cbuiltins.operators["or"] = function(_, _, emitter, lnode, rnode, lname, rname)
  emitter:add_val2boolean(lname, lnode.attr.type)
  emitter:add(' || ')
  emitter:add_val2boolean(rname, rnode.attr.type)
end

-- Implementation of conditional AND operator (`and`).
cbuiltins.operators["and"] = function(_, _, emitter, lnode, rnode, lname, rname)
  emitter:add_val2boolean(lname, lnode.attr.type)
  emitter:add(' && ')
  emitter:add_val2boolean(rname, rnode.attr.type)
end

-- Implementation of not operator (`not`).
cbuiltins.operators["not"] = function(_, _, emitter, argnode)
  emitter:add('!')
  emitter:add_val2boolean(argnode)
end

-- Implementation of unary minus operator (`-`).
function cbuiltins.operators.unm(_, _, emitter, argnode)
  assert(argnode.attr.type.is_arithmetic)
  emitter:add('-', argnode)
end

-- Implementation of bitwise not operator (`~`).
function cbuiltins.operators.bnot(_, _, emitter, argnode)
  assert(argnode.attr.type.is_integral)
  emitter:add('~', argnode)
end

-- Implementation of reference operator (`&`).
function cbuiltins.operators.ref(_, _, emitter, argnode)
  assert(argnode.attr.lvalue)
  emitter:add('&', argnode)
end

-- Implementation of dereference operator (`$`).
function cbuiltins.operators.deref(_, _, emitter, argnode)
  assert(argnode.attr.type.is_pointer)
  emitter:add_deref(argnode)
end

-- Implementation of length operator (`#`).
function cbuiltins.operators.len(_, _, emitter, argnode)
  local argattr = argnode.attr
  local type = argattr.type
  if type.is_string then
    emitter:add('((',primtypes.isize,')(', argnode, ').size)')
  elseif type.is_cstring then
    emitter:add('((',primtypes.isize,')')
    emitter:add_builtin('strlen')
    emitter:add('(', argnode, '))')
  elseif type.is_type then
    emitter:add('sizeof(', argattr.value, ')')
  else --luacov:disable
    argnode:raisef('not implemented')
  end --luacov:enable
end

return cbuiltins
