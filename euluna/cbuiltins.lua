local cdefs = require 'euluna.cdefs'
local Emitter = require 'euluna.emitter'

local builtins = {}

function builtins.len(context, _, emitter, argnode)
  if argnode.attr.type:is_arraytable() then
    emitter:add(context:get_ctype(argnode), '_length(&', argnode, ')')
  elseif argnode.attr.type:is_array() then
    emitter:add(argnode.attr.type.length)
  elseif argnode.attr.type:is_record() then
    emitter:add('sizeof(',context:get_ctype(argnode),')')
  end
end

function builtins.div(context, node, emitter, lnode, rnode, lname, rname)
  if lnode.attr.type:is_numeric() and rnode.attr.type:is_numeric() then
    if not rnode.attr.type:is_float() and not lnode.attr.type:is_float() then
      assert(node.attr.type:is_float())
      emitter:add(lname, ' / (', context:get_ctype(node.attr.type), ')', rname)
    else
      emitter:add(lname, ' / ', rname)
    end
  else --luacov:disable
    error('not implemented')
  end --luacov:enable
end

function builtins.idiv(context, node, emitter, lnode, rnode, lname, rname)
  if lnode.attr.type:is_numeric() and rnode.attr.type:is_numeric() then
    if lnode.attr.type:is_float() or rnode.attr.type:is_float() then
      local floorname = node.attr.type:is_float32() and 'floorf' or 'floor'
      emitter:add(floorname, '(', lname, ' / ', rname, ')')
      context.has_math = true
    else
      emitter:add(lname, ' / ', rname)
    end
  else --luacov:disable
    error('not implemented')
  end --luacov:enable
end

function builtins.mod(context, node, emitter, lnode, rnode, lname, rname)
  if lnode.attr.type:is_numeric() and rnode.attr.type:is_numeric() then
    if lnode.attr.type:is_float() or rnode.attr.type:is_float() then
      local modname = node.attr.type:is_float32() and 'fmodf' or 'fmod'
      emitter:add(modname, '(', lname, ', ', rname, ')')
      context.has_math = true
    else
      emitter:add(lname, ' % ', rname)
    end
  else --luacov:disable
    error('not implemented')
  end --luacov:enable
end

function builtins.pow(context, node, emitter, lnode, rnode, lname, rname)
  if lnode.attr.type:is_numeric() and rnode.attr.type:is_numeric() then
    local powname = node.attr.type:is_float32() and 'powf' or 'pow'
    emitter:add(powname, '(', lname, ', ', rname, ')')
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
  local argnodes = node:args()
  local funcname = '__euluna_print_' .. node.pos

  context:add_runtime_builtin('stdout_write')

  --function declaration
  local decemitter = Emitter(context)
  decemitter:add_indent('static inline ')
  decemitter:add('void ', funcname, '(')
  for i,argnode in ipairs(argnodes) do
    if i>1 then decemitter:add(', ') end
    local ctype = context:get_ctype(argnode)
    decemitter:add('const ', ctype, ' a', i)
  end
  decemitter:add_ln(');')
  context:add_declaration(decemitter:generate(), funcname)

  --function head
  local defemitter = Emitter(context)
  defemitter:add_indent('void ', funcname, '(')
  for i,arg in ipairs(argnodes) do
    if i>1 then defemitter:add(', ') end
    local ctype = context:get_ctype(arg)
    defemitter:add('const ', ctype, ' a', i)
  end
  defemitter:add(')')

  -- function body
  defemitter:add_ln(' {')
  defemitter:inc_indent()
  for i,argnode in ipairs(argnodes) do
    if i > 1 then
      defemitter:add_indent_ln('euluna_stdout_write("\\t");')
    end
    if argnode.attr.type:is_any() then
      defemitter:add_indent_ln('euluna_stdout_write_any(a',i,');')
    elseif argnode.attr.type:is_string() then
      defemitter:add_indent_ln('euluna_stdout_write_string(a',i,');')
    elseif argnode.attr.type:is_boolean() then
      defemitter:add_indent_ln('euluna_stdout_write_boolean(a',i,');')
    elseif argnode.attr.type:is_numeric() then
      local tyname = node:assertraisef(argnode.attr.type, 'type is not defined in AST node')
      local tyformat = cdefs.types_printf_format[tyname]
      node:assertraisef(tyformat, 'invalid type "%s" for printf format', tyname)
      defemitter:add_indent_ln('euluna_stdout_write_format("',tyformat,'", a',i,');')
    else --luacov:disable
      node:raisef('cannot handle type "%s" in print', tostring(argnode.attr.type))
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
