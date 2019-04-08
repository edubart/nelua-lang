local cdefs = require 'euluna.cdefs'

local builtins = {}

function builtins.idiv(context, node, emitter, lnode, rnode)
  if lnode.type:is_number() and rnode.type:is_number() then
    if lnode.type:is_real() or rnode.type:is_real() then
      emitter:add('((', context:get_ctype(node), ')(', lnode, ' / ', rnode, '))')
    else
      emitter:add(lnode, ' / ', rnode)
    end
  else --luacov:disable
    error('not implemented')
  end --luacov:enable
end

function builtins.pow(context, node, emitter, lnode, rnode)
  if lnode.type:is_number() and rnode.type:is_number() then
    local powname = node.type:is_float32() and 'powf' or 'pow'
    emitter:add(powname, '(', lnode, ', ', rnode, ')')
    context.has_math = true
  else --luacov:disable
    error('not implemented')
  end --luacov:enable
end

function builtins.print(context, node)
  local argtypes, args = node:args()
  local funcname = '__euluna_print_' .. node.pos

  context:add_runtime_builtin('stdout_write')

  --function head
  local defemitter = context.definitions_emitter
  defemitter:add_indent('static inline ')
  defemitter:add('void ', funcname, '(')
  for i,arg in ipairs(args) do
    if i>1 then defemitter:add(', ') end
    local ctype = context:get_ctype(arg)
    defemitter:add('const ', ctype, ' a', i)
  end
  defemitter:add(')')

  -- function body
  defemitter:add_ln(' {')
  defemitter:inc_indent()
  for i,arg in ipairs(args) do
    if i > 1 then
      defemitter:add_indent_ln('euluna_stdout_write("\\t");')
    end
    if arg.type:is_any() then
      defemitter:add_indent_ln('euluna_stdout_write_any(a',i,');')
    elseif arg.type:is_string() then
      defemitter:add_indent_ln('euluna_stdout_write_string(a',i,');')
    elseif arg.type:is_boolean() then
      defemitter:add_indent_ln('euluna_stdout_write_boolean(a',i,');')
    elseif arg.type:is_number() then
      local tyname = node:assertraisef(arg.type, 'type is not defined in AST node')
      local tyformat = cdefs.types_printf_format[tyname]
      node:assertraisef(tyformat, 'invalid type "%s" for printf format', tyname)
      defemitter:add_indent_ln('euluna_stdout_write_format("',tyformat,'", a',i,');')
    else --luacov:disable
      node:raisef('cannot handle type "%s" in print', tostring(arg.type))
    end --luacov:enable
  end
  defemitter:add_indent_ln('euluna_stdout_write_newline();')
  defemitter:dec_indent()
  defemitter:add_ln('}')

  -- the call
  return funcname
end

return builtins
