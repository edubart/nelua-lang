local cdefs = require 'euluna.generators.c.definitions'

local builtins = {}

function builtins.print(context, ast, coder)
  local argtypes, args = ast:args()
  local funcname = '__euluna_print_' .. ast.pos

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
      defcoder:add_indent_ln('euluna_stdout_write("\\t");')
    end
    if not arg.type or arg.type:is_any() then
      defcoder:add_indent_ln('euluna_stdout_write_any(a',i,');')
    elseif arg.type:is_string() then
      defcoder:add_indent_ln('euluna_stdout_write_string(a',i,');')
    elseif arg.type:is_boolean() then
      defcoder:add_indent_ln('euluna_stdout_write_boolean(a',i,');')
    elseif arg.type:is_number() then
      local tyname = ast:assertraisef(arg.type, 'type is not defined in AST node')
      local tyformat = cdefs.types_printf_format[tyname]
      ast:assertraisef(tyformat, 'invalid type "%s" for printf format', tyname)
      defcoder:add_indent_ln('euluna_stdout_write_format("',tyformat,'", a',i,');')
    else --luacov:disable
      ast:errorf('cannot handle AST node "%s" in print', arg.tag)
    end --luacov:enable
  end
  defcoder:add_indent_ln('euluna_stdout_write_newline();')
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
