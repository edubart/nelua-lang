local traits = require 'nelua.utils.traits'
local tabler = require 'nelua.utils.tabler'
local class = require 'nelua.utils.class'
local bn = require 'nelua.utils.bn'
local compat = require 'pl.compat'
local typedefs = require 'nelua.typedefs'
local Context = require 'nelua.context'
local Emitter = require 'nelua.emitter'
local Attr = require 'nelua.attr'
local config = require 'nelua.configer'.get()

local function default_visitor(self, node, emitter, ...)
  for i=1,node.nargs or #node do
    local arg = node[i]
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

function PPContext:get_registry(index)
  local node = self.registry[index]
  self.lastregnode = node
  return node
end

function PPContext:push_statnodes()
  local statnodes = {oldstatnodes = self.statnodes}
  self.statnodes = statnodes
  return statnodes
end

function PPContext:pop_statnodes()
  local curstatnodes = self.statnodes
  self.statnodes = curstatnodes.oldstatnodes
  curstatnodes.oldstatnodes = nil
end

function PPContext:add_statnode(node)
  table.insert(self.statnodes, node)
  self.context:traverse(node)
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
    node = self.aster.Type{'auto'}
    -- inject persistent parsed type
    local pattr = Attr({
      type = typedefs.primtypes.type,
      value = val,
      comptime = true
    })
    node.attr:merge(pattr)
    node.pattr = pattr
  elseif traits.is_string(val) then
    node = self.aster.String{val}
  elseif traits.is_number(val) or traits.is_bignumber(val) then
    local num = bn.new(val)
    local neg = false
    if num:isneg() then
      num = num:abs()
      neg = true
    end
    if num:isintegral() then
      node = self.aster.Number{'dec', num:todec()}
    else
      local int, frac = num:todec():match('^(-?%d+).(%d+)$')
      node = self.aster.Number{'dec', int, frac}
    end
    if neg then
      node = self.aster.UnaryOp{'unm', node}
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
  emitter:add_indent_ln(
    'ppregistry[', parentregindex, '][', parentindex, ']',
    ' = ppcontext:toname(', luacode, ', ppregistry[', selfregindex, '])')
end

function visitors.PreprocessExpr(ppcontext, node, emitter, parent, parentindex)
  local luacode = node[1]
  local parentregindex = ppcontext:getregistryindex(parent)
  local selfregindex = ppcontext:getregistryindex(node)
  emitter:add_indent_ln(
    'ppregistry[', parentregindex, '][', parentindex, ']',
    ' = ppcontext:tovalue(', luacode, ', ppregistry[', selfregindex, '])')
end

function visitors.Preprocess(_, node, emitter)
  local luacode = node[1]
  emitter:add_ln(luacode)
end

function visitors.Block(ppcontext, node, emitter)
  local statnodes = node[1]

  if not node.needprocess then
    ppcontext:traverse(statnodes, emitter)
    return
  end

  node.needprocess = nil

  local blockregidx = ppcontext:getregistryindex(node)
  emitter:add_indent_ln('ppregistry[', blockregidx, '].preprocess = function(blocknode)')
  emitter:inc_indent()
  emitter:add_indent_ln('local ppstatnode')
  emitter:add_indent_ln('blocknode[1] = ppcontext:push_statnodes()')
  emitter:add_indent_ln('context:push_scope("block")')
  emitter:inc_indent()
  for _,statnode in ipairs(statnodes) do
    local statregidx = ppcontext:getregistryindex(statnode)
    emitter:add_indent_ln('ppstatnode = ppcontext:get_registry(', statregidx, ')')
    ppcontext:traverse(statnode, emitter)
    if statnode.tag ~= 'Preprocess' then
      emitter:add_indent_ln('ppcontext:add_statnode(ppstatnode:clone())')
    end
  end
  emitter:dec_indent()
  emitter:add_indent_ln('ppcontext:pop_statnodes()')
  emitter:add_indent_ln('context:pop_scope()')
  emitter:dec_indent()
  emitter:add_indent_ln('end')
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
end

local ppenvgetfields = {}
function ppenvgetfields:scope()
  return self.context.scope
end
function ppenvgetfields:symbols()
  return self.context.scope.symbols
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
  local aster = context.astbuilder.aster
  local emitter = Emitter(ppcontext, 0)
  emitter:add_ln("local ppcontext = ppcontext")
  emitter:add_ln("local ppregistry = ppcontext.registry")
  emitter:add_ln("local context = ppcontext.context")
  ppcontext:traverse(ast, emitter)

  -- generate the preprocess function
  local ppcode = emitter:generate()
  local env
  env = setmetatable({
    context = context,
    ppcontext = ppcontext,
    ast = ast,
    aster = aster,
    primtypes = require 'nelua.typedefs'.primtypes,
    addnode = function(node) ppcontext:add_statnode(node) end,
    staticassert = function(status, msg, ...)
      if not status then
        if not msg then
          msg = 'static assertion failed!'
        else
          msg = 'static assertion failed: ' .. msg
        end
        ppcontext.lastregnode:raisef(msg, ...)
      end
      return status
    end,
    config = config
  }, { __index = function(_, key)
    local ppenvfield = ppenvgetfields[key]
    if ppenvfield then
      return ppenvfield(env)
    elseif typedefs.field_pragmas[key] then
      return context[key]
    elseif typedefs.call_pragmas[key] then
      return function(...)
        local args = tabler.pack(...)
        local ok, err = typedefs.call_pragmas[key](args)
        if not ok then
          ppcontext.lastregnode:raisef("invalid arguments for preprocess function '%s': %s", key, err)
        end
        ppcontext:add_statnode(aster.PragmaCall{key, tabler.pack(...)})
      end
    else
      local v = rawget(context.env, key)
      if v ~= nil then
        return v
      else
        return _G[key]
      end
    end
  end, __newindex = function(_, key, value)
    if typedefs.field_pragmas[key] then
      local ok, err = typedefs.field_pragmas[key](value)
      if not ok then
        ppcontext.lastregnode:raisef("invalid type for preprocess variable '%s': %s", key, err)
      end
      ppcontext:add_statnode(aster.PragmaSet{key, value})
    else
      rawset(context.env, key, value)
    end
  end})

  -- try to run the preprocess otherwise capture and show the error
  local ppfunc, err = compat.load(ppcode, '@pp', "t", env)
  local ok = not err
  if ppfunc then
    ok, err = pcall(ppfunc)
  end
  if not ok then
    ast:raisef('error while preprocessing file: %s', err)
  end

  context.preprocessing = false
end

return preprocessor
