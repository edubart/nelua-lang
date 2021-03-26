local traits = require 'nelua.utils.traits'
local tabler = require 'nelua.utils.tabler'
local types = require 'nelua.types'
local typedefs = require 'nelua.typedefs'
local VisitorContext = require 'nelua.visitorcontext'
local PPContext = require 'nelua.ppcontext'
local Emitter = require 'nelua.emitter'
local except = require 'nelua.utils.except'
local errorer = require 'nelua.utils.errorer'
local config = require 'nelua.configer'.get()
local stringer = require 'nelua.utils.stringer'
local memoize = require 'nelua.utils.memoize'
local bn = require 'nelua.utils.bn'
local ccompiler = require 'nelua.ccompiler'
local console = require 'nelua.utils.console'
local nanotimer = require 'nelua.utils.nanotimer'

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
  emitter:add_indent_ln('ppcontext:inject_value(',luacode,
    ',ppregistry[', nindex, '],ppregistry[', pindex,'],', parentindex,')')
end

local function make_expr_node_preprocess(ppcontext, node, emitter)
  local luacode = node[1]
  local nindex = ppcontext:getregistryindex(node)
  emitter:add_indent_ln('ppregistry[', nindex, '].preprocess=function(parent, pindex)')
  emitter:inc_indent()
  emitter:add_indent_ln('ppcontext:inject_value(', luacode, ', ppregistry[', nindex, '], parent, pindex)')
  emitter:dec_indent()
  emitter:add_indent_ln('end')
end

function visitors.FuncDef(ppcontext, node, emitter)
  local namenode, argnodes, retnodes, annotnodes, blocknode = node[2], node[3], node[4], node[5], node[6]
  ppcontext:traverse_node(namenode, emitter, node, 2)
  ppcontext:traverse_nodes(argnodes, emitter, node, 3)
  for i=1,#retnodes do
    local retnode = retnodes[i]
    if retnode.tag == 'PreprocessExpr' then
      make_expr_node_preprocess(ppcontext, retnode, emitter)
    else
      ppcontext:traverse_node(retnode, emitter, retnodes, i)
    end
  end
  if annotnodes then
    ppcontext:traverse_nodes(annotnodes, emitter, node, 5)
  end
  ppcontext:traverse_node(blocknode, emitter, node, 6)
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
      emitter:add_indent_ln('ppcontext:add_statnode(ppregistry[', statsregidx, '][', i, '])')
    end
  end
  emitter:add_indent_ln('ppcontext:pop_statnodes()')
  emitter:dec_indent()
  emitter:add_indent_ln('end')
end

local preprocessor = {working_time = 0}

local function mark_preprocessing_nodes(ast)
  local needprocess
  local preprocess_tags = {
    Preprocess = true,
    PreprocessName = true,
    PreprocessExpr = true
  }
  for _, parents in ast:walk_trace_nodes(preprocess_tags) do
    needprocess = true
    -- mark nearest parent block above
    for i=#parents-1,1,-1 do
      local pnode = parents[i]
      if pnode.tag == 'Block' then
        pnode.needprocess = true
        break
      end
    end
  end
  return needprocess
end

function preprocessor.preprocess(context, ast)
  assert(ast.tag == 'Block')

  local timer
  if config.more_timing or config.timing then
    timer = nanotimer()
  end

  local ppcontext = context.ppcontext
  if not ppcontext then
    ppcontext = PPContext(visitors, context)
    context.ppcontext = ppcontext
  end

  if not mark_preprocessing_nodes(ast) then
    -- no preprocess directive found for this block, finished
    if timer then --luacov:disable
      local elapsed = timer:elapsed()
      preprocessor.working_time = preprocessor.working_time + elapsed
      if config.more_timing then
        console.debugf('skip preprocess %s (%.1f ms)', ast.src.name, elapsed)
      end
    end --luacov:enable
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
    ppcontext = ppcontext,
    ppregistry = ppcontext.registry,
    ast = ast,
    bn = bn,
    aster = aster,
    config = config,
    types = types,
    traits = traits,
    primtypes = primtypes
  }
  if context.generator == 'c' then
    ppenv.ccinfo = ccompiler.get_cc_info()
  end
  local function concept(f)
    local type = types.ConceptType(f)
    type.node = context:get_current_node()
    return type
  end
  local function overload_concept(syms, ...)
    return types.make_overload_concept(context, syms, ...)
  end
  local function facultative_concept(sym, noconvert)
    return overload_concept({sym, primtypes.niltype, noconvert=noconvert})
  end
  local function generic(f)
    local type = types.GenericType(f)
    type.node = context:get_current_node()
    return type
  end
  local function hygienize(f)
    local scope = context.scope
    local checkpoint = scope:make_checkpoint()
    local statnodes = ppcontext.statnodes
    local addindex = #statnodes+1
    return function(...)
      statnodes.addindex = addindex
      ppcontext:push_statnodes(statnodes)
      scope:push_checkpoint(checkpoint)
      context:push_scope(scope)
      local rets = table.pack(f(...))
      ppcontext:pop_statnodes()
      context:pop_scope()
      scope:pop_checkpoint()
      if addindex ~= statnodes.addindex then -- new statement nodes were added
        -- must delay resolution to fully parse the new added nodes later
        context.rootscope:delay_resolution()
        addindex = statnodes.addindex
      end
      statnodes.addindex = nil
      return table.unpack(rets)
    end
  end
  local function exprmacro(f)
    return function(...)
      local curnode = context:get_current_node()
      local args = {...}
      return aster.DoExpr{aster.Block{{},
        preprocess = function(blocknode)
          blocknode[1] = ppcontext:push_statnodes()
          f(table.unpack(args))
          ppcontext:pop_statnodes()
        end,
        pos = curnode.pos, src = curnode.src
      }, pos = curnode.pos, src = curnode.src}
    end
  end
  local function generalize(f)
    return generic(memoize(hygienize(f)))
  end
  local function after_analyze(f)
    if not traits.is_function(f) then
      raise_preprocess_error("invalid arguments for preprocess function")
    end
    table.insert(context.after_analyze, { f=f, node = context:get_current_node() })
  end
  local function after_inference(f)
    if not traits.is_function(f) then
      raise_preprocess_error("invalid arguments for preprocess function")
    end
    local oldscope = context.scope
    local function fproxy()
      context:push_scope(oldscope)
      f()
      context:pop_scope()
    end
    table.insert(context.after_inferences, fproxy)
  end
  local function static_error(msg, ...)
    if not msg then
      msg = 'static error!'
    end
    raise_preprocess_error(msg, ...)
  end
  local function static_assert(status, msg, ...)
    if not status then
      if not msg then
        msg = 'static assertion failed!'
      end
      raise_preprocess_error(msg, ...)
    end
    return status
  end
  local function select_varargs(index, endindex)
    local polyeval = context.state.inpolyeval
    static_assert(polyeval, 'cannot used select_varargs outside a polymorphic function')
    local varargsnodes = polyeval.varargsnodes
    local nvarargs = #varargsnodes
    if index == '#' then
      return nvarargs
    else
      if index < 0 then index = nvarargs + index + 1 end
      static_assert(index >= 1 and index <= nvarargs, 'select index out of range')
      if endindex then
        if endindex < 0 then endindex = nvarargs + endindex + 1 end
        static_assert(endindex >= 1 and endindex <= nvarargs, 'select end index out of range')
        local selectnodes = {_varargs=true}
        for i=index,endindex,(endindex >= index) and 1 or -1 do
          selectnodes[#selectnodes+1] = varargsnodes[i]
        end
        return selectnodes
      else
        return varargsnodes[index]
      end
    end
  end
  local function inject_astnode(node, clone)
    return ppcontext:add_statnode(node, not clone)
  end
  tabler.update(ppenv, {
    after_analyze = after_analyze,
    after_inference = after_inference,
    static_error = static_error,
    static_assert = static_assert,
    inject_astnode = inject_astnode,
    concept = concept,
    overload_concept = overload_concept,
    facultative_concept = facultative_concept,
    select_varargs = select_varargs,
    generic = generic,
    hygienize = hygienize,
    generalize = generalize,
    memoize = memoize,
    exprmacro = exprmacro,
    -- deprecated aliases
    optional_concept = facultative_concept,
    staticerror = static_error,
    staticassert = static_assert,
  })
  local contextenv = context.env
  setmetatable(ppenv, { __index = function(_, key)
    local v = contextenv[key]
    if v ~= nil then
      return v
    end
    if key == 'symbols' then
      return context.scope.symbols
    end
    if key == 'pragmas' then
      return context.pragmas
    end
    local symbol = context.scope.symbols[key]
    if symbol then
      return symbol
    elseif typedefs.call_pragmas[key] then
      return function(...)
        local args = table.pack(...)
        local ok, err = typedefs.call_pragmas[key](args)
        if not ok then
          raise_preprocess_error("invalid arguments for preprocess function '%s': %s", key, err)
        end
        ppcontext:add_statnode(aster.PragmaCall{key, table.pack(...)}, true)
      end
    end
  end, __newindex = function(_, key, value)
    contextenv[key] = value
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

  if timer then
    local elapsed = timer:elapsed()
    preprocessor.working_time = preprocessor.working_time + elapsed
    if config.more_timing then
      console.debugf('preprocessed %s (%.1f ms)', ast.src.name, timer:elapsed())
    end
  end

  return true
end

return preprocessor
