local pegger = require 'nelua.utils.pegger'
local traits = require 'nelua.utils.traits'
local luadefs = require 'nelua.luadefs'
local luabuiltins = require 'nelua.luabuiltins'
local config = require 'nelua.configer'.get()
local Emitter = require 'nelua.emitter'
local bn = require 'nelua.utils.bn'

local visitors = {}

function visitors.Number(_, node, emitter)
  local numstr, literal = node[1], node[2]
  node:assertraisef(literal == nil, 'literals are not supported in lua')
  local attr = node.attr
  local value, base = attr.value, attr.base
  if base == 2 then
    if bn.isintegral(value) and not bn.isneg(value) then
      emitter:add('0x'..bn.tohexint(value))
    else
      emitter:add(bn.todecsci(value))
    end
  elseif base == 16 and not bn.isintegral(value) then
    emitter:add(bn.todecsci(value))
  else
    emitter:add(numstr)
  end
end

function visitors.String(_, node, emitter)
  local value, literal = node[1], node[2]
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
  local value = node[1]
  emitter:add(tostring(value))
end

function visitors.Nil(_, _, emitter)
  emitter:add('nil')
end

function visitors.Varargs(_, _, emitter)
  emitter:add('...')
end

function visitors.InitList(_, node, emitter)
  local childnodes = node
  emitter:add('{')
  emitter:add_traversal_list(childnodes, ', ')
  emitter:add('}')
end

function visitors.Pair(_, node, emitter)
  local field, value = node[1], node[2]
  if type(field) == 'string' then
    emitter:add(field)
  else
    emitter:add('[', field, ']')
  end
  emitter:add(' = ', value)
end

-- TODO: Annotation

function visitors.Id(_, node, emitter)
  local name = node[1]
  emitter:add(name)
end
function visitors.Paren(_, node, emitter)
  local what = node[1]
  emitter:add('(', what, ')')
end
function visitors.Type() end
function visitors.FuncType() end
function visitors.ArrayType() end
function visitors.VarargsType(_, _, emitter)
  emitter:add('...')
end
function visitors.IdDecl(_, node, emitter)
  local name = node[1]
  emitter:add(name)
end

function visitors.DotIndex(_, node, emitter)
  local name, obj = node[1], node[2]
  emitter:add(obj, '.', name)
end

function visitors.ColonIndex(_, node, emitter)
  local name, obj = node[1], node[2]
  emitter:add(obj, ':', name)
end

function visitors.KeyIndex(_, node, emitter)
  local index, obj = node[1], node[2]
  emitter:add(obj, '[', index, ']')
end

function visitors.Call(context, node, emitter)
  local args, callee = node[1], node[2]
  local isblockcall = context:get_parent_node().tag == 'Block'
  if isblockcall then emitter:add_indent() end
  emitter:add(callee, '(', args, ')')
  if isblockcall then emitter:add_ln() end
end

function visitors.CallMethod(context, node, emitter)
  local name, args, callee = node[1], node[2], node[3]
  local isblockcall = context:get_parent_node().tag == 'Block'
  if isblockcall then emitter:add_indent() end
  emitter:add(callee, ':', name, '(', args, ')')
  if isblockcall then emitter:add_ln() end
end

function visitors.Block(context, node, emitter)
  local stats = node
  emitter:inc_indent()
  context:push_forked_scope(node)
  emitter:add_traversal_list(stats, '')
  context:pop_scope()
  emitter:dec_indent()
end

function visitors.Return(_, node, emitter)
  local retnodes = node
  emitter:add_indent("return")
  if #retnodes > 0 then
    emitter:add(' ')
    emitter:add_traversal_list(retnodes, ', ')
  end
  emitter:add_ln()
end

function visitors.If(_, node, emitter)
  local ifpairs, elsenode = node[1], node[2]
  for i=1,#ifpairs,2 do
    local condnode, blocknode = ifpairs[i], ifpairs[i+1]
    if i == 1 then
      emitter:add_indent("if ")
      emitter:add(condnode)
      emitter:add_ln(" then")
    else
      emitter:add_indent("elseif ")
      emitter:add(condnode)
      emitter:add_ln(" then")
    end
    emitter:add(blocknode)
  end
  if elsenode then
    emitter:add_indent_ln("else")
    emitter:add(elsenode)
  end
  emitter:add_indent_ln("end")
end

function visitors.Switch(context, node, emitter)
  local val, casepairs, elsenode = node[1], node[2], node[3]
  local varname = '__switchval' .. node.pos
  emitter:add_indent_ln("local ", varname, " = ", val)
  node:assertraisef(#casepairs > 0, "switch must have case parts")
  context:push_forked_scope(node)
  for i=1,#casepairs,2 do
    local caseexprs, caseblock = casepairs[i], casepairs[i+1]
    if i == 1 then
      emitter:add_indent('if ')
    else
      emitter:add_indent('elseif ')
    end
    emitter:add_ln(varname, ' == ', caseexprs, ' then')
    emitter:add(caseblock)
  end
  if elsenode then
    emitter:add_indent_ln('else')
    emitter:add(elsenode)
  end
  context:pop_scope(node)
  emitter:add_indent_ln("end")
end

function visitors.Do(_, node, emitter)
  local block = node[1]
  emitter:add_indent_ln("do")
  emitter:add(block)
  emitter:add_indent_ln("end")
end

function visitors.While(context, node, emitter)
  local cond, block = node[1], node[2]
  emitter:add_indent_ln("while ", cond, ' do')
  context:push_forked_scope(node)
  emitter:add(block)
  context:pop_scope()
  emitter:add_indent_ln("end")
end

function visitors.Repeat(context, node, emitter)
  local block, cond = node[1], node[2]
  emitter:add_indent_ln("repeat")
  context:push_forked_cleaned_scope(node)
  emitter:add(block)
  emitter:add_indent_ln('until ', cond)
  context:pop_scope()
end

function visitors.ForNum(context, node, emitter)
  local itvar, begval, comp, endval, incrval, block =
        node[1], node[2], node[3], node[4], node[5], node[6]
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
  local itvars, iterator, block = node[1], node[2], node[3]
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
  local name = node[1]
  emitter:add_indent_ln('::', name, '::')
end

function visitors.Goto(_, node, emitter)
  local labelname = node[1]
  emitter:add_indent_ln('goto ', labelname)
end

function visitors.VarDecl(context, node, emitter)
  local varscope, varnodes, valnodes = node[1], node[2], node[3]
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
      elseif varnode.attr.type.is_scalar then
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
  local varnodes, valnodes = node[1], node[2]
  emitter:add_indent_ln(varnodes, ' = ', valnodes)
end

function visitors.FuncDef(context, node, emitter)
  local varscope, name, args, block = node[1], node[2], node[3], node[6]
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
  local args, block = node[1], node[4]
  if #block == 0 then
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
  local opname, argnode = node[1], node[2]
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
  local lnode, opname, rnode = node[1], node[2], node[3]
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
