local traits = require 'nelua.utils.traits'
local tabler = require 'nelua.utils.tabler'
local types = require 'nelua.types'
local typedefs = require 'nelua.typedefs'
local VisitorContext = require 'nelua.analyzercontext'
local PPContext = require 'nelua.ppcontext'
local Emitter = require 'nelua.emitter'
local except = require 'nelua.utils.except'
local errorer = require 'nelua.utils.errorer'
local config = require 'nelua.configer'.get()
local stringer = require 'nelua.utils.stringer'
local memoize = require 'nelua.utils.memoize'
local sstream = require 'nelua.utils.sstream'

local traverse_node = VisitorContext.traverse_node
local function pp_default_visitor(self, node, emitter, ...)
  for i=1,node.nargs or #node do
    local arg = node[i]
    if arg and type(arg) == 'table' then
      if arg._astnode then
        traverse_node(self, arg, emitter, node, i, ...)
      else
        pp_default_visitor(self, arg, emitter, ...)
      end
    end
  end
end

local visitors = { default_visitor = pp_default_visitor }

function visitors.PreprocessName(ppcontext, node, emitter, parent, parentindex)
  local luacode = node[1]
  local pindex, nindex = ppcontext:getregistryindex(parent), ppcontext:getregistryindex(node)
  emitter:add_indent_ln('ppregistry[', pindex, '][', parentindex, ']',
                        '=ppcontext:toname(', luacode, ',ppregistry[', nindex, '])')
end

function visitors.PreprocessExpr(ppcontext, node, emitter, parent, parentindex)
  local luacode = node[1]
  local pindex, nindex = ppcontext:getregistryindex(parent), ppcontext:getregistryindex(node)
  emitter:add_indent_ln('ppregistry[', pindex, '][', parentindex, ']',
                        '=ppcontext:tovalue(', luacode, ',ppregistry[', nindex, '])')
end

function visitors.Preprocess(_, node, emitter)
  local luacode = node[1]
  emitter:add_ln(luacode)
end

function visitors.Block(ppcontext, node, emitter)
  local statnodes = node[1]
  if not node.needprocess then
    ppcontext:traverse_nodes(statnodes, emitter)
    return
  end
  node.needprocess = nil

  local blockregidx = ppcontext:getregistryindex(node)
  emitter:add_indent_ln('ppregistry[', blockregidx, '].preprocess=function(blocknode)')
  emitter:inc_indent()
  emitter:add_indent_ln('blocknode[1]=ppcontext:push_statnodes()')
  local statsregidx = ppcontext:getregistryindex(statnodes)
  for i=1,#statnodes do
    local statnode = statnodes[i]
    ppcontext:traverse_node(statnode, emitter)
    if statnode.tag ~= 'Preprocess' then
      emitter:add_indent_ln('ppcontext:add_statnode(ppregistry[', statsregidx, '][', i, '],true)')
    end
  end
  emitter:add_indent_ln('ppcontext:pop_statnodes()')
  emitter:dec_indent()
  emitter:add_indent_ln('end')
end

local function mark_process_visitor(markercontext)
  local nodes = markercontext.visiting_nodes
  -- mark nearest parent block above
  for i=#nodes-1,1,-1 do
    local pnode = nodes[i]
    if pnode.tag == 'Block' then
      pnode.needprocess = true
      break
    end
  end
  markercontext.needprocess = true
end

local marker_visitors = {
  Preprocess = mark_process_visitor,
  PreprocessName = mark_process_visitor,
  PreprocessExpr = mark_process_visitor
}

function marker_visitors.Block(markercontext, node)
  markercontext:traverse_nodes(node[1])
end

local preprocessor = {}

local function table2key(t)
  for k,v in pairs(_G) do
    if v == t then
      return k
    end
  end
end

function preprocessor.preprocess(context, ast)
  assert(ast.tag == 'Block')

  local ppcontext = context.ppcontext
  if not ppcontext then
    ppcontext = PPContext(visitors, context)
    context.ppcontext = ppcontext
  end

  local markercontext = VisitorContext(marker_visitors)

  -- first pass, mark blocks that needs preprocess
  markercontext:traverse_node(ast)

  if not markercontext.needprocess then
    -- no preprocess directive found for this block, finished
    return false
  end

  -- second pass, emit the preprocess lua code
  local aster = context.parser.astbuilder.aster
  local emitter = Emitter(ppcontext, 0)
  if config.define then
    for _,define in ipairs(config.define) do
      emitter:add_ln(define)
    end
  end
  ppcontext:traverse_node(ast, emitter)

  -- generate the preprocess function`
  local ppcode = emitter:generate()

  local function raise_preprocess_error(msg, ...)
    msg = stringer.pformat(msg, ...)
    local lineno = debug.getinfo(3).currentline
    msg = errorer.get_pretty_source_line_errmsg({content=ppcode, name='preprocessor'}, lineno, msg, 'error')
    except.raise(msg, 2)
  end

  local primtypes = typedefs.primtypes
  local ppenv = {
    context = context,
    pragmas = context.pragmas,
    ppcontext = ppcontext,
    ppregistry = ppcontext.registry,
    ast = ast,
    aster = aster,
    config = config,
    types = types,
    traits = traits,
    primtypes = primtypes
  }
  local function concept(f)
    local type = types.ConceptType(f)
    type.node = context:get_current_node()
    return type
  end
  local function overload_concept(syms, noconvert)
    return concept(function(x)
      if getmetatable(syms) ~= nil then
        context:get_current_node():raisef("in overload concept definition: use a raw tables for listing types")
      end
      local accepttypes = {}
      for i,sym in ipairs(syms) do
        local type
        if traits.is_type(sym) then
          type = sym
        elseif traits.is_symbol(sym) then
          assert(sym.type == primtypes.type)
          type = sym.value
        elseif traits.is_table(sym) then
          local symname = table2key(sym)
          if symname then
            sym = ppcontext.context.scope.symbols[symname]
            assert(sym.type == primtypes.type)
            type = sym.value
          end
        end
        if not type then
          context:get_current_node():raisef("in overload concept definition argument #%d: invalid type", i)
        end
        accepttypes[i] = type
      end

      -- try to match exact type first
      for i=1,#accepttypes do
        local type = accepttypes[i]
        if type == x.type then
          return type
        end
      end

      -- else try to convert one
      local errs = {}
      if not noconvert then
        for i=1,#accepttypes do
          local type = accepttypes[i]
          local ok, err = type:is_convertible_from(x.type)
          if ok then
            return type
          else
            table.insert(errs, err)
          end
        end
      end

      local ss = sstream()
      ss:add('cannot match overload concept:\n    ')
      ss:addlist(errs, '\n    ')
      return nil, ss:tostring()
    end)
  end
  local function optional_concept(sym, noconvert)
    return overload_concept({sym, primtypes.niltype}, noconvert)
  end
  local function generic(f)
    local type = types.GenericType(f)
    type.node = context:get_current_node()
    return type
  end
  local function hygienize(f)
    local scope = ppcontext.context.scope
    local checkpoint = scope:make_checkpoint()
    local statnodes = ppcontext.statnodes
    local addindex = #statnodes+1
    return function(...)
      statnodes.addindex = addindex
      ppcontext:push_statnodes(statnodes)
      scope:push_checkpoint(checkpoint)
      ppcontext.context:push_scope(scope)
      local rets = table.pack(f(...))
      ppcontext:pop_statnodes()
      ppcontext.context:pop_scope()
      -- must delay resolution to fully parse the new added nodes later
      ppcontext.context.rootscope:delay_resolution()
      scope:pop_checkpoint()
      addindex = statnodes.addindex
      statnodes.addindex = nil
      return table.unpack(rets)
    end
  end
  local function generalize(f)
    return generic(memoize(hygienize(f)))
  end
  tabler.update(ppenv, {
    afteranalyze = function(f)
      if not traits.is_function(f) then
        raise_preprocess_error("invalid arguments for preprocess function")
      end
      table.insert(context.afteranalyze, { f=f, node = context:get_current_node() })
    end,
    afterinfer = function(f)
      if not traits.is_function(f) then
        raise_preprocess_error("invalid arguments for preprocess function")
      end
      local oldscope = ppcontext.context.scope
      local function fproxy()
        context:push_scope(oldscope)
        f()
        context:pop_scope()
      end
      table.insert(context.afterinfers, fproxy)
    end,
    staticerror = function(msg, ...)
      if not msg then
        msg = 'static error!'
      end
      raise_preprocess_error(msg, ...)
    end,
    staticassert = function(status, msg, ...)
      if not status then
        if not msg then
          msg = 'static assertion failed!'
        end
        raise_preprocess_error(msg, ...)
      end
      return status
    end,
    concept = concept,
    overload_concept = overload_concept,
    optional_concept = optional_concept,
    generic = generic,
    hygienize = hygienize,
    generalize = generalize,
    memoize = memoize,
  })
  setmetatable(ppenv, { __index = function(_, key)
    local v = rawget(ppcontext.context.env, key)
    if v ~= nil then
      return v
    end
    if _G[key] ~= nil then
      return _G[key]
    end
    if key == 'symbols' then
      return ppcontext.context.scope.symbols
    end
    local symbol = ppcontext.context.scope.symbols[key]
    if symbol then
      return symbol
    elseif typedefs.call_pragmas[key] then
      return function(...)
        local args = table.pack(...)
        local ok, err = typedefs.call_pragmas[key](args)
        if not ok then
          raise_preprocess_error("invalid arguments for preprocess function '%s': %s", key, err)
        end
        ppcontext:add_statnode(aster.PragmaCall{key, table.pack(...)})
      end
    else
      return nil
    end
  end, __newindex = function(_, key, value)
    rawset(ppcontext.context.env, key, value)
  end})

  -- try to run the preprocess otherwise capture and show the error
  local ppfunc, err = load(ppcode, '@preprocessor', "t", ppenv)
  local ok = not err
  if ppfunc then
    ok, err = except.trycall(ppfunc)
  end
  if not ok then
    ast:raisef('error while preprocessing: %s', err)
  end

  return true
end

return preprocessor
