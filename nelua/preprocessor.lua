local traits = require 'nelua.utils.traits'
local tabler = require 'nelua.utils.tabler'
local compat = require 'pl.compat'
local typedefs = require 'nelua.typedefs'
local Context = require 'nelua.context'
local PPContext = require 'nelua.ppcontext'
local Emitter = require 'nelua.emitter'
local except = require 'nelua.utils.except'
local errorer = require 'nelua.utils.errorer'
local config = require 'nelua.configer'.get()
local stringer = require 'nelua.utils.stringer'

local function pp_default_visitor(self, node, emitter, ...)
  for i=1,node.nargs or #node do
    local arg = node[i]
    if traits.is_astnode(arg) then
      self:traverse(arg, emitter, node, i, ...)
    elseif traits.is_table(arg) then
      pp_default_visitor(self, arg, emitter, ...)
    end
  end
end

local visitors = { default_visitor = pp_default_visitor }

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
  emitter:add_indent_ln('local ppstatnodes = ppcontext:push_statnodes()')
  emitter:add_indent_ln('local injectnode = function(node) table.insert(ppstatnodes, node) context:traverse(node) end')
  emitter:add_indent_ln('blocknode[1] = ppstatnodes')
  emitter:add_indent_ln('context:push_scope("block")')
  emitter:inc_indent()
  for _,statnode in ipairs(statnodes) do
    local statregidx = ppcontext:getregistryindex(statnode)
    ppcontext:traverse(statnode, emitter)
    if statnode.tag ~= 'Preprocess' then
      emitter:add_indent_ln('injectnode(ppregistry[', statregidx, ']:clone())')
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
  PreprocessExpr = mark_process_visitor
}

function marker_visitors.Block(markercontext, node)
  local statnodes = node[1]
  markercontext:traverse(statnodes)
end

local preprocessor = {}

function preprocessor.preprocess(context, ast)
  assert(ast.tag == 'Block')

  local markercontext = Context(marker_visitors)

  -- first pass, mark blocks that needs preprocess
  markercontext:traverse(ast)

  if not markercontext.needprocess then
    -- no preprocess directive found for this block, finished
    return
  end

  -- second pass, emit the preprocess lua code
  local ppcontext = PPContext(visitors, context)
  local aster = context.astbuilder.aster
  local emitter = Emitter(ppcontext, 0)
  emitter:add_ln("local context = context")
  emitter:add_ln("local ppcontext = ppcontext")
  emitter:add_ln("local ppregistry = ppcontext.registry")
  emitter:add_ln("local context = ppcontext.context")
  ppcontext:traverse(ast, emitter)

  -- generate the preprocess function`
  local ppcode = emitter:generate()

  local function raise_preprocess_error(msg, ...)
    msg = stringer.pformat(msg, ...)
    local lineno = debug.getinfo(3).currentline
    msg = errorer.get_pretty_source_line_errmsg(ppcode, 'preprocessor', lineno, msg)
    except.raise(msg, 2)
  end


  local env
  env = setmetatable({
    context = context,
    ppcontext = ppcontext,
    ast = ast,
    aster = aster,
    config = config,
    primtypes = require 'nelua.typedefs'.primtypes,
    staticassert = function(status, msg, ...)
      if not status then
        if not msg then
          msg = 'static assertion failed!'
        else
          msg = 'static assertion failed: ' .. msg
        end
        raise_preprocess_error(msg, ...)
      end
      return status
    end,
  }, { __index = function(_, key)
    local v = rawget(context.env, key)
    if v ~= nil then
      return v
    end
    local symbol = context.scope.symbols[key]
    if symbol then
      return symbol
    elseif typedefs.field_pragmas[key] then
      return context[key]
    elseif typedefs.call_pragmas[key] then
      return function(...)
        local args = tabler.pack(...)
        local ok, err = typedefs.call_pragmas[key](args)
        if not ok then
          raise_preprocess_error("invalid arguments for preprocess function '%s': %s", key, err)
        end
        ppcontext:add_statnode(aster.PragmaCall{key, tabler.pack(...)})
      end
    else
      return _G[key]
    end
  end, __newindex = function(_, key, value)
    if typedefs.field_pragmas[key] then
      local ok, err = typedefs.field_pragmas[key](value)
      if not ok then
        raise_preprocess_error("invalid type for preprocess variable '%s': %s", key, err)
      end
      context[key] = value
    else
      rawset(context.env, key, value)
    end
  end})

  -- try to run the preprocess otherwise capture and show the error
  local ppfunc, err = compat.load(ppcode, '@preprocessor', "t", env)
  local ok = not err
  if ppfunc then
    ok, err = except.trycall(ppfunc)
  end
  if not ok then
    ast:raisef('error while preprocessing: %s', err)
  end
end

return preprocessor
