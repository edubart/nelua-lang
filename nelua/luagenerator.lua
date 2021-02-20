local pegger = require 'nelua.utils.pegger'
local traits = require 'nelua.utils.traits'
local luadefs = require 'nelua.luadefs'
local luabuiltins = require 'nelua.luabuiltins'
local config = require 'nelua.configer'.get()
local Emitter = require 'nelua.emitter'
local bn = require 'nelua.utils.bn'

local visitors = {}

function visitors.Number(_, node, emitter)
  local base, int, frac, exp, literal = node:args()
  node:assertraisef(literal == nil, 'literals are not supported in lua')
  emitter:add_composed_number(base, int, frac, exp, bn.abs(node.attr.value))
end

function visitors.String(_, node, emitter)
  local value, literal = node:args()
  node:assertraisef(literal == nil, 'literals are not supported in lua')
  local quoted_value
  if value:find('"') and not value:find("'") then
    quoted_value = pegger.single_quote_lua_string(value)
  else
    quoted_value = pegger.double_quote_lua_string(value)
  end
  emitter:add(quoted_value)
end

function visitors.Boolean(_, node, emitter)
  local value = node:args()
  emitter:add(tostring(value))
end

function visitors.Nil(_, _, emitter)
  emitter:add('nil')
end

function visitors.Varargs(_, _, emitter)
  emitter:add('...')
end

function visitors.Table(_, node, emitter)
  local contents = node:args()
  emitter:add('{', contents, '}')
end

function visitors.Pair(_, node, emitter)
  local field, value = node:args()
  if type(field) == 'string' then
    emitter:add(field)
  else
    emitter:add('[', field, ']')
  end
  emitter:add(' = ', value)
end

-- TODO: Annotation

function visitors.Id(_, node, emitter)
  local name = node:args()
  emitter:add(name)
end
function visitors.Paren(_, node, emitter)
  local what = node:args()
  emitter:add('(', what, ')')
end
function visitors.Type() end
function visitors.FuncType() end
function visitors.ArrayType() end
function visitors.IdDecl(_, node, emitter)
  local name = node:args()
  emitter:add(name)
end

function visitors.DotIndex(_, node, emitter)
  local name, obj = node:args()
  emitter:add(obj, '.', name)
end

function visitors.ColonIndex(_, node, emitter)
  local name, obj = node:args()
  emitter:add(obj, ':', name)
end

function visitors.ArrayIndex(_, node, emitter)
  local index, obj = node:args()
  emitter:add(obj, '[', index, ']')
end

function visitors.Call(context, node, emitter)
  local args, callee = node:args()
  local isblockcall = context:get_parent_node().tag == 'Block'
  if isblockcall then emitter:add_indent() end
  emitter:add(callee, '(', args, ')')
  if isblockcall then emitter:add_ln() end
end

function visitors.CallMethod(context, node, emitter)
  local name, args, callee = node:args()
  local isblockcall = context:get_parent_node().tag == 'Block'
  if isblockcall then emitter:add_indent() end
  emitter:add(callee, ':', name, '(', args, ')')
  if isblockcall then emitter:add_ln() end
end

function visitors.Block(context, node, emitter)
  local stats = node:args()
  emitter:inc_indent()
  context:push_forked_scope(node)
  emitter:add_traversal_list(stats, '')
  context:pop_scope()
  emitter:dec_indent()
end

function visitors.Return(_, node, emitter)
  local rets = node:args()
  emitter:add_indent("return")
  if #rets > 0 then
    emitter:add(' ')
  end
  emitter:add_ln(rets)
end

function visitors.If(_, node, emitter)
  local ifparts, elseblock = node:args()
  for i,ifpart in ipairs(ifparts) do
    local cond, block = ifpart[1], ifpart[2]
    if i == 1 then
      emitter:add_indent("if ")
      emitter:add(cond)
      emitter:add_ln(" then")
    else
      emitter:add_indent("elseif ")
      emitter:add(cond)
      emitter:add_ln(" then")
    end
    emitter:add(block)
  end
  if elseblock then
    emitter:add_indent_ln("else")
    emitter:add(elseblock)
  end
  emitter:add_indent_ln("end")
end

function visitors.Switch(context, node, emitter)
  local val, caseparts, switchelseblock = node:args()
  local varname = '__switchval' .. node.pos
  emitter:add_indent_ln("local ", varname, " = ", val)
  node:assertraisef(#caseparts > 0, "switch must have case parts")
  context:push_forked_scope(node)
  for i,casepart in ipairs(caseparts) do
    local caseval, caseblock = casepart[1], casepart[2]
    if i == 1 then
      emitter:add_indent('if ')
    else
      emitter:add_indent('elseif ')
    end
    emitter:add_ln(varname, ' == ', caseval, ' then')
    emitter:add(caseblock)
  end
  if switchelseblock then
    emitter:add_indent_ln('else')
    emitter:add(switchelseblock)
  end
  context:pop_scope(node)
  emitter:add_indent_ln("end")
end

function visitors.Do(_, node, emitter)
  local block = node:args()
  emitter:add_indent_ln("do")
  emitter:add(block)
  emitter:add_indent_ln("end")
end

function visitors.While(context, node, emitter)
  local cond, block = node:args()
  emitter:add_indent_ln("while ", cond, ' do')
  context:push_forked_scope(node)
  emitter:add(block)
  context:pop_scope()
  emitter:add_indent_ln("end")
end

function visitors.Repeat(context, node, emitter)
  local block, cond = node:args()
  emitter:add_indent_ln("repeat")
  context:push_forked_cleaned_scope(node)
  emitter:add(block)
  emitter:add_indent_ln('until ', cond)
  context:pop_scope()
end

function visitors.ForNum(context, node, emitter)
  local itvar, begval, comp, endval, incrval, block  = node:args()
  if not comp then
    comp = 'le'
  end
  node:assertraisef(comp == 'le', 'for comparator not supported yet')
  context:push_forked_scope(node)
  emitter:add_indent("for ", itvar, '=', begval, ',', endval)
  if incrval then
    emitter:add(',', incrval)
  end
  emitter:add_ln(' do')
  emitter:add(block)
  emitter:add_indent_ln("end")
  context:pop_scope()
end

function visitors.ForIn(context, node, emitter)
  local itvars, iterator, block = node:args()
  context:push_forked_scope(node)
  emitter:add_indent("for ", itvars)
  emitter:add_ln(' in ', iterator, ' do')
  emitter:add(block)
  emitter:add_indent_ln("end")
  context:pop_scope()
end

function visitors.Break(_, _, emitter)
  emitter:add_indent_ln('break')
end

-- TODO: Continue

function visitors.Label(_, node, emitter)
  local name = node:args()
  emitter:add_indent_ln('::', name, '::')
end

function visitors.Goto(_, node, emitter)
  local labelname = node:args()
  emitter:add_indent_ln('goto ', labelname)
end

function visitors.VarDecl(context, node, emitter)
  local varscope, varnodes, valnodes = node:args()
  local is_local = (varscope == 'local') or not context.scope.is_topscope
  emitter:add_indent()
  if is_local then
    emitter:add('local ')
  end
  emitter:add(varnodes)
  local doassigns = valnodes or not is_local
  for _,varnode in ipairs(varnodes) do
    if not varnode.attr.type.is_any then
      doassigns = true
      break
    end
  end
  if doassigns then
    emitter:add(' = ')
    local istart = 1
    if valnodes then
      emitter:add(valnodes)
      istart = #valnodes+1
    end
    for i=istart,#varnodes do
      if i > 1 then emitter:add(', ') end
      local varnode = varnodes[i]
      if varnode.attr.type.is_table then
        emitter:add('{}')
      elseif varnode.attr.type.is_arithmetic then
        emitter:add('0')
      elseif varnode.attr.type.is_boolean then
        emitter:add('false')
      else
        emitter:add('nil')
      end
    end
  end
  emitter:add_ln()
end

function visitors.Assign(_, node, emitter)
  local varnodes, valnodes = node:args()
  emitter:add_indent_ln(varnodes, ' = ', valnodes)
end

function visitors.FuncDef(context, node, emitter)
  local varscope, name, args, _, _, block = node:args()
  emitter:add_indent()
  if varscope == 'local' then
    emitter:add('local ')
  end
  emitter:add('function ', name)
  context:push_forked_scope(node)
  emitter:add_ln('(', args, ')')
  emitter:add(block)
  context:pop_scope()
  emitter:add_indent_ln('end')
end

function visitors.Function(context, node, emitter)
  local args, _, _, block = node:args()
  if #block[1] == 0 then
    emitter:add('function(', args, ') end')
  else
    emitter:add_ln('function(', args, ')')
    context:push_forked_scope(node)
    emitter:add(block)
    context:pop_scope()
    emitter:add_indent('end')
  end
end

-- operators
function visitors.UnaryOp(context, node, emitter)
  local opname, argnode = node:args()
  local op = node:assertraisef(luadefs.unary_ops[opname], 'unary operator "%s" not found', opname)
  if config.lua_version ~= '5.3' then
    local fallop = luadefs.lua51_unary_ops[opname]
    if fallop then
      context:ensure_builtin(fallop.builtin)
      emitter:add(fallop.func, '(', argnode, ')')
      return
    end
  end
  local surround = node.attr.inoperator
  if surround then emitter:add('(') end
  emitter:add(op, argnode)
  if surround then emitter:add(')') end
end

function visitors.BinaryOp(context, node, emitter)
  local opname, lnode, rnode = node:args()
  local op = node:assertraisef(luadefs.binary_ops[opname], 'binary operator "%s" not found', opname)
  if config.lua_version ~= '5.3' then
    local fallop = luadefs.lua51_binary_ops[opname]
    if fallop then
      if fallop.builtin then
        context:ensure_builtin(fallop.builtin)
      end
      if traits.is_function(fallop.func) then
        fallop.func(context, node, emitter, lnode, rnode)
      else
        emitter:add(fallop.func, '(', lnode, ', ', rnode, ')')
      end
      return
    end
  end
  local surround = node.attr.inoperator
  if surround then emitter:add('(') end
  emitter:add(lnode, ' ', op, ' ', rnode)
  if surround then emitter:add(')') end
end

local generator = {}

function generator.generate(ast, context)
  context:set_visitors(visitors)
  context.builtins = luabuiltins.builtins
  local emitter = Emitter(context, -1)
  context.emitter = emitter
  emitter:add_traversal(ast)
  return emitter:generate()
end

generator.compiler = require('nelua.luacompiler')

return generator
