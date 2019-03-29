local cdefs = require 'euluna.generators.c.definitions'
local typedefs = require 'euluna.analyzers.types.definitions'
local types = typedefs.primitive_types

local builtins = {}

function builtins.euluna_type_t(context)
  context.builtins_declarations_coder:add(
[[typedef struct euluna_type_t {
  char *name;
} euluna_type_t;
]])
  local added = {}
  for _,type in pairs(types) do
    if not type:is_any() and not added[type] then
      context.builtins_declarations_coder:add(string.format(
        'euluna_type_t euluna_type_%s = {"%s"};\n',
        type:codegen_name(), type.name
      ))
      added[type] = true
    end
  end
end

function builtins.euluna_string_t(context)
  context:add_builtin('euluna_type_t')
  context.builtins_declarations_coder:add(
[[typedef struct euluna_string_t {
    uintptr_t len;
    uintptr_t res;
    char data[];
} euluna_string_t;
]])
end

function builtins.euluna_any_t(context)
  context:add_builtin('euluna_type_t')
  context.builtins_declarations_coder:add(
[[typedef struct euluna_any_t {
    euluna_type_t *type;
    uint64_t value;
} euluna_any_t;
]])
end

function builtins.euluna_cast_any(context)
  context:add_include("<assert.h>")
  context:add_builtin('euluna_any_t')
  context:add_builtin('euluna_string_t')
  for type,conf in pairs(cdefs.primitive_ctypes) do
    if not type:is_any() then
      local ctype = conf.name
      context.builtins_declarations_coder:add(string.format(
[[static inline %s euluna_cast_any_%s(const euluna_any_t a);
]], ctype, type.name, ctype))
      context.builtins_definitions_coder:add(string.format(
[[static inline %s euluna_cast_any_%s(const euluna_any_t a) {
  assert(a.type == &euluna_type_%s);
  return (%s)a.value;
}
]], ctype, type.name, type.name, ctype))
    end
  end
end

function builtins.__euluna_fwrite_any(context)
  context:add_include("<stdio.h>")
  context:add_include("<assert.h>")
  context:add_builtin('euluna_any_t')
  context:add_builtin('euluna_string_t')
  context.builtins_declarations_coder:add(
[[void __euluna_fwrite_any(const euluna_any_t any, FILE* out);
]])
  context.builtins_definitions_coder:add(
[[void __euluna_fwrite_any(const euluna_any_t any, FILE* out) {
  if(any.type == &euluna_type_boolean) {
    if(any.value == 0)
      fwrite("false", 5, 1, out);
    else
      fwrite("true", 4, 1, out);
]])
  for type,format in pairs(cdefs.types_printf_format) do
    local ctype = cdefs.primitive_ctypes[type].name
    context.builtins_definitions_coder:add(string.format(
[[  } else if(any.type == &euluna_type_%s) {
    fprintf(out, "%s", (%s)any.value);
]], type.name, format, ctype))
  end
  context.builtins_definitions_coder:add(
[[  } else {
    assert(false);
  }
}
]])
end

local functions = {}
builtins.functions = functions

function functions.print(context, ast, coder)
  local argtypes, args = ast:args()
  local funcname = '__euluna_print_' .. ast.pos
  context:add_include("<stdio.h>")

  context:add_builtin('__euluna_fwrite_any')

  --function head
  local defcoder = context.definitions_coder
  defcoder:add_indent('static inline ')
  defcoder:add('void ', funcname, '(')
  for i,arg in ipairs(args) do
    if i>1 then defcoder:add(', ') end
    local ctype = context:get_ctype(arg)
    defcoder:add('const ', ctype, ' a', i)
  end
  defcoder:add(')')

  -- function body
  defcoder:add_ln(' {')
  defcoder:inc_indent()
  for i,arg in ipairs(args) do
    if i > 1 then
      defcoder:add_indent_ln('fwrite("\\t", 1, 1, stdout);')
    end
    if not arg.type or arg.type:is_any() then
      defcoder:add_indent_ln('__euluna_fwrite_any(a',i,', stdout);')
    elseif arg.type:is_string() then
      defcoder:add_indent_ln('fwrite(a',i,'->data, a',i,'->len, 1, stdout);')
    elseif arg.type:is_number() then
      local tyname = ast:assertraisef(arg.type, 'type is not defined in AST node')
      local tyformat = cdefs.types_printf_format[tyname]
      ast:assertraisef(tyformat, 'invalid type "%s" for printf format', tyname)
      defcoder:add_indent_ln('fprintf(stdout, "',tyformat,'", a',i,');')
    else --luacov:disable
      ast:errorf('cannot handle AST node "%s" in print', arg.tag)
    end --luacov:enable
  end
  defcoder:add_indent_ln('fwrite("\\n", 1, 1, stdout);')
  defcoder:add_indent_ln('fflush(stdout);')
  defcoder:dec_indent()
  defcoder:add_ln('}')

  -- the call
  coder:add(funcname, '(')
  for i,arg in ipairs(args) do
    if i>1 then coder:add(', ') end
    if arg.type then
      if arg.tag == 'String' then
        coder:add('(euluna_string_t*) &', arg)
      elseif arg.tag == 'Number' or arg.tag == 'Id' then
        coder:add(arg)
      end
    end
  end
  coder:add(')')
end

return builtins
