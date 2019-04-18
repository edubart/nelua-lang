local cdefs = require 'euluna.cdefs'
local Emitter = require 'euluna.emitter'

local builtins = {}

function builtins.len(context, _, emitter, argnode)
  if argnode.type:is_arraytable() then
    emitter:add(context:get_ctype(argnode), '_length(&', argnode, ')')
  elseif argnode.type:is_array() then
    emitter:add(argnode.type.length)
  elseif argnode.type:is_record() then
    emitter:add('sizeof(',context:get_ctype(argnode),')')
  end
end

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

function builtins.assert(context, node)
  local args = node:args()
  if #args == 2 then
    context:add_runtime_builtin('assert_message')
    return 'euluna_assert_message'
  elseif #args == 1 then
    context:add_runtime_builtin('assert')
    return 'euluna_assert'
  else
    node:raisef('invalid assert call')
  end
end

function builtins.print(context, node)
  local args = node:args()
  local funcname = '__euluna_print_' .. node.pos

  context:add_runtime_builtin('stdout_write')

  --function declaration
  local decemitter = Emitter(context)
  decemitter:add_indent('static inline ')
  decemitter:add('void ', funcname, '(')
  for i,arg in ipairs(args) do
    if i>1 then decemitter:add(', ') end
    local ctype = context:get_ctype(arg)
    decemitter:add('const ', ctype, ' a', i)
  end
  decemitter:add_ln(');')
  context:add_declaration(decemitter:generate(), funcname)

  --function head
  local defemitter = Emitter(context)
  defemitter:add_indent('void ', funcname, '(')
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

  context:add_definition(defemitter:generate(), funcname)

  -- the call
  return funcname
end

return builtins
