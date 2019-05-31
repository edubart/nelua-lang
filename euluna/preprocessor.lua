local traits = require 'euluna.utils.traits'
local tabler = require 'euluna.utils.tabler'
local iters = require 'euluna.utils.iterators'
local class = require 'euluna.utils.class'
local except = require 'euluna.utils.except'
local bn = require 'euluna.utils.bn'
local compat = require 'pl.compat'
local typedefs = require 'euluna.typedefs'
local Context = require 'euluna.context'
local Emitter = require 'euluna.emitter'

local function default_visitor(self, node, emitter, ...)
  local nargs = traits.is_astnode(node) and node.nargs or #node
  for i,arg in iters.inpairs(node, nargs) do
    if traits.is_astnode(arg) then
      self:traverse(arg, emitter, node, i, ...)
    elseif traits.is_table(arg) then
      default_visitor(self, arg, emitter, ...)
    end
  end
end

local PPContext = class(Context)

function PPContext:_init(context, visitors)
  Context._init(self, visitors, default_visitor)
  self.context = context
  self.aster = context.astbuilder.aster
  self.registry = {}
end

function PPContext.toname(_, val, orignode)
  orignode:assertraisef(traits.is_string(val),
    'unable to convert preprocess value of type "%s" to a compile time name', type(val))
  return val
end

function PPContext:tovalue(val, orignode)
  local node
  if traits.is_astnode(val) then
    node = val
  elseif traits.is_type(val) then
    node = self.aster.Type{'void'}
    -- inject persistent parsed type
    node.pattr = {
      type = typedefs.primtypes.type,
      holdedtype = val,
      const = true
    }
    tabler.update(node.attr, node.pattr)
  elseif traits.is_string(val) then
    node = self.aster.String{val}
  elseif traits.is_number(val) or traits.is_bignumber(val) then
    local num = bn.new(val)
    if num:isintegral() then
      node = self.aster.Number{'dec', num:todec()}
    else
      local int, frac = num:todec():match('^(-?%d+).(%d+)$')
      node = self.aster.Number{'dec', int, frac}
    end
  elseif traits.is_boolean(val) then
    node = self.aster.Boolean{val}
  --TODO: table, nil
  else
    orignode:raisef('unable to convert preprocess value of type "%s" to a const value', type(val))
  end
  node.srcname = orignode.srcname
  node.modname = orignode.modname
  node.src = orignode.src
  node.pos = orignode.pos
  return node
end

function PPContext:getregistryindex(what)
  local registry = self.registry
  local regindex = registry[what]
  if not regindex then
    table.insert(registry, what)
    regindex = #registry
    registry[what] = regindex
  end
  return regindex
end

local visitors = {}

function visitors.PreprocessName(ppcontext, node, emitter, parent, parentindex)
  local luacode = node[1]
  local parentregindex = ppcontext:getregistryindex(parent)
  local selfregindex = ppcontext:getregistryindex(node)
  emitter:add_ln(
    'ppregistry[', parentregindex, '][', parentindex, ']',
    ' = ppcontext:toname(', luacode, ', ppregistry[', selfregindex, '])')
end

function visitors.PreprocessExpr(ppcontext, node, emitter, parent, parentindex)
  local luacode = node[1]
  local parentregindex = ppcontext:getregistryindex(parent)
  local selfregindex = ppcontext:getregistryindex(node)
  emitter:add_ln(
    'ppregistry[', parentregindex, '][', parentindex, ']',
    ' = ppcontext:tovalue(', luacode, ', ppregistry[', selfregindex, '])')
end

function visitors.Preprocess(_, node, emitter)
  local luacode = node[1]
  emitter:add_ln(luacode)
end

function visitors.ForNum(ppcontext, node, emitter)
  local itvarnode, begvalnode, compop, endvalnode, stepvalnode, blocknode = node:args()
  ppcontext:traverse(begvalnode, emitter, node, 2)
  ppcontext:traverse(endvalnode, emitter, node, 4)
  if stepvalnode then
    ppcontext:traverse(stepvalnode, emitter, node, 5)
  end
  emitter:add_ln([[
local ppitvarnode, ppbegvalnode, _, ppendvalnode, ppstepvalnode, ppblocknode = ppstatnode:args()
context:traverse(ppbegvalnode)
context:traverse(ppendvalnode)
if ppstepvalnode then
context:traverse(ppstepvalnode)
end
context:push_scope("loop")]])
  ppcontext:traverse(itvarnode, emitter, node, 1)
  emitter:add_ln([[context:traverse(ppitvarnode)]])
  ppcontext:traverse(blocknode, emitter, node, 6)
  emitter:add_ln([[context:traverse(ppblocknode)
context:pop_scope()]])
end

function visitors.Block(ppcontext, node, emitter, parent)
  if not node.needprocess then
    -- this block doesn't have any preprocess directive, skip it
    return
  end

  -- always use original statement nodes for inner preprocessor blocks
  local statnodes = node.origstatnodes or node[1]
  if parent and not node.origstatnodes then
    -- clone because we may change origina ref
    node.origstatnodes = node:clone()[1]
  end

  node.processed = true
  node.needprocess = false

  emitter:add_ln('do')
  emitter:add_ln('local ppnewstatnodes = {}')
  emitter:add_ln('ppregistry[', ppcontext:getregistryindex(node), '][1] = ppnewstatnodes')
  emitter:add_ln('context:push_scope("block")')
  for _,statnode in ipairs(statnodes) do
    if statnode.tag == 'Preprocess' then
      ppcontext:traverse(statnode, emitter)
    else
      emitter:add_ln('do')
      emitter:add_ln('local ppstatnode = ppregistry[', ppcontext:getregistryindex(statnode), ']')
      ppcontext:traverse(statnode, emitter)
      emitter:add_ln('local ppnewstatnode =  ppstatnode:clone()')
      emitter:add_ln('table.insert(ppnewstatnodes, ppnewstatnode)')
      emitter:add_ln('context:traverse(ppnewstatnode)')
      emitter:add_ln('end')
    end
  end
  emitter:add_ln('context:pop_scope()')
  emitter:add_ln('end')
end

local function mark_process_visitor(markercontext)
  local topppblocknode = markercontext:get_parent_node_if(function(pnode)
    return pnode.needprocess
  end)
  if topppblocknode then
    -- mark all blocks between top pp block and this block
    for pnode in markercontext:iterate_parent_nodes() do
      if pnode.tag == 'Block' then
        if pnode == topppblocknode then
          break
        end
        pnode.needprocess = true
      end
    end
  else
    -- mark parent block
    local parentblocknode = markercontext:get_parent_node_if(function(pnode)
      return pnode.tag == 'Block'
    end)
    parentblocknode.needprocess = true
  end
  markercontext.needprocess = true
end

local marker_visitors = {
  Preprocess = mark_process_visitor,
  PreprocessName = mark_process_visitor,
  PreprocessExpr = mark_process_visitor,
}

function marker_visitors.Block(markercontext, node)
  local statnodes = node[1]
  markercontext:traverse(statnodes)
  if not node.needprocess then
    node.processed = true
  end
end

local preprocessor = {}
function preprocessor.preprocess(context, ast)
  assert(ast.tag == 'Block')

  local markercontext = Context(marker_visitors, true)

  -- first pass, mark blocks that needs preprocess
  markercontext:traverse(ast)

  if not markercontext.needprocess then
    -- none preprocess directive found for this block, finished
    return
  end

  context.preprocessing = true

  -- second pass, emit the preprocess lua code
  local ppcontext = PPContext(context, visitors)
  local emitter = Emitter(ppcontext, 0)
  ppcontext:traverse(ast, emitter)

  -- generate the preprocess function
  local ppcode = emitter:generate()
  local env = setmetatable({
    context = context,
    aster = context.astbuilder.aster,
    ppcontext = ppcontext,
    ppregistry = ppcontext.registry
  }, { __index = function(_, key)
    if key == 'scope' then
      return context.scope
    elseif key == 'ast' then
      return context:get_top_node()
    elseif key == 'symbols' then
      return context.scope.symbols
    else
      return _G[key]
    end
  end})

  -- try to run the preprocess otherwise capture and show the error
  local ppfunc, err = compat.load(ppcode, '@pp', "t", env)
  local ok = not err
  if ppfunc then
    ok, err = pcall(ppfunc)
  end
  if except.is_exception(err) then
    except.reraise(err)
  else
    --TODO: better error messages
    ast:assertraisef(ok, tostring(err))
  end

  context.preprocessing = false
end

return preprocessor
