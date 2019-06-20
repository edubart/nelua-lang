local cdefs = require 'euluna.cdefs'
local CEmitter = require 'euluna.cemitter'

local builtins = {}

local operators = {}
builtins.operators = operators

function operators.len(_, emitter, argnode)
  local type = argnode.attr.type
  if type:is_arraytable() then
    emitter:add(type, '_length(&', argnode, ')')
  elseif type:is_array() then
    emitter:add(type.length)
  elseif type:is_record() then
    emitter:add('sizeof(', type, ')')
  end
end

function operators.div(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  if ltype:is_numeric() and rtype:is_numeric() then
    if not rtype:is_float() and not ltype:is_float() then
      assert(type:is_float())
      emitter:add(lname, ' / (', type, ')', rname)
    else
      emitter:add(lname, ' / ', rname)
    end
  else --luacov:disable
    error('not implemented')
  end --luacov:enable
end

function operators.idiv(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  if ltype:is_numeric() and rtype:is_numeric() then
    if ltype:is_float() or rtype:is_float() then
      local floorname = type:is_float32() and 'floorf' or 'floor'
      emitter:add(floorname, '(', lname, ' / ', rname, ')')
      emitter.context.has_math = true
    else
      emitter:add(lname, ' / ', rname)
    end
  else --luacov:disable
    error('not implemented')
  end --luacov:enable
end

function operators.mod(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  if ltype:is_numeric() and rtype:is_numeric() then
    if ltype:is_float() or rtype:is_float() then
      local modfuncname = type:is_float32() and 'fmodf' or 'fmod'
      emitter:add(modfuncname, '(', lname, ', ', rname, ')')
      emitter.context.has_math = true
    else
      emitter:add(lname, ' % ', rname)
    end
  else --luacov:disable
    error('not implemented')
  end --luacov:enable
end

function operators.pow(node, emitter, lnode, rnode, lname, rname)
  local type, ltype, rtype = node.attr.type, lnode.attr.type, rnode.attr.type
  if ltype:is_numeric() and rtype:is_numeric() then
    local powname = type:is_float32() and 'powf' or 'pow'
    emitter:add(powname, '(', lname, ', ', rname, ')')
    emitter.context.has_math = true
  else --luacov:disable
    error('not implemented')
  end --luacov:enable
end

local functions = {}
builtins.functions = functions

function functions.assert(context, node)
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

function functions.print(context, node)
  local argnodes = node:args()
  local funcname = context:genuniquename('euluna_print')

  context:add_runtime_builtin('stdout_write')

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
    if i > 1 then
      defemitter:add_indent_ln('euluna_stdout_write("\\t");')
    end
    if argtype:is_any() then
      defemitter:add_indent_ln('euluna_stdout_write_any(a',i,');')
    elseif argtype:is_string() then
      defemitter:add_indent_ln('euluna_stdout_write_string(a',i,');')
    elseif argtype:is_cstring() then
      defemitter:add_indent_ln('euluna_stdout_write(a',i,');')
    elseif argtype:is_boolean() then
      defemitter:add_indent_ln('euluna_stdout_write_boolean(a',i,');')
    elseif argtype:is_numeric() then
      local tyname = node:assertraisef(argtype, 'type is not defined in AST node')
      local tyformat = cdefs.types_printf_format[tyname]
      node:assertraisef(tyformat, 'invalid type "%s" for printf format', tyname)
      defemitter:add_indent_ln('euluna_stdout_write_format("',tyformat,'", a',i,');')
    else --luacov:disable
      node:raisef('cannot handle type "%s" in print', argtype)
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
