local iters = require 'euluna.utils.iterators'
local cdefs = require 'euluna.generators.c.definitions'

local builtins = {}

function builtins.euluna_string_t(context)
  context:add_include("<stdint.h>")
  context.builtins_declarations_coder:add(
[[typedef struct euluna_string_t {
    uintptr_t len;
    uintptr_t res;
    char data[];
} euluna_string_t;
]])
end

local functions = {}
builtins.functions = functions

function functions.print(context, ast, coder)
  local argtypes, args = ast:args()
  local funcname = '__euluna_print_' .. ast.pos
  context:add_include("<stdio.h>")

  -- needed bultins
  for arg in iters.ivalues(args) do
    if arg.tag == 'String' then
      context:add_builtin('euluna_string_t')
      break
    end
  end

  --function head
  local defcoder = context.definitions_coder
  defcoder:add_indent('static inline ')
  defcoder:add('void ', funcname, '(')
  for i,arg in ipairs(args) do
    if i>1 then defcoder:add(', ') end
    if arg.tag == 'String' then
      defcoder:add('const euluna_string_t* a', i)
    elseif arg.tag == 'Number' or arg.tag == 'Id' then
      local ctype = context:get_ctype(arg)
      defcoder:add('const ', ctype, ' a', i)
    end
  end
  defcoder:add(')')

  -- function body
  defcoder:add_ln(' {')
  defcoder:inc_indent()
  for i,arg in ipairs(args) do
    if i > 1 then
      defcoder:add_indent_ln('fwrite("\\t", 1, 1, stdout);')
    end
    if arg.tag == 'String' then
      defcoder:add_indent_ln('fwrite(a',i,'->data, a',i,'->len, 1, stdout);')
    elseif arg.tag == 'Number' or arg.tag == 'Id' then
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
    if arg.tag == 'String' then
      coder:add('(euluna_string_t*) &', arg)
    elseif arg.tag == 'Number' or arg.tag == 'Id' then
      coder:add(arg)
    end
  end
  coder:add(')')
end

return builtins
