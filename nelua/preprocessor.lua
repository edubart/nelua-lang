--[[
Preprocessor module.

The preprocessor works the following way for each source file:

1. Traverse a source file generating preprocessing code for all nodes in the source file.
2. The generated preprocessed code is run, creating a 'preprocess' function for all nodes.
3. The first time a node is visited, its respective 'preprocess' function is called just once.
4. The preprocess function may inject new ast nodes and analyze it right away.

Note that the preprocessing is done gradually, that is,
preprocessing is done per node, at the first time a node is visited.
Thus the compiler will preprocess and then analyze nodes gradually.
]]

local PPContext = require 'nelua.ppcontext'
local Emitter = require 'nelua.emitter'
local except = require 'nelua.utils.except'
local console = require 'nelua.utils.console'
local nanotimer = require 'nelua.utils.nanotimer'
local config = require 'nelua.configer'.get()

-- List tags of nodes that will be preprocessed.
local preprocess_tags = {
  Preprocess = true,
  PreprocessName = true,
  PreprocessExpr = true
}

-- Default preprocessing node visitor.
local function default_visitor(self, node, emitter, ...)
  for i=1,#node do
    local arg = node[i]
    if type(arg) == 'table' then
      if arg._astnode then
        self:traverse_node(arg, emitter, node, i, ...)
      else
        default_visitor(self, arg, emitter, ...)
      end
    end
  end
end

-- Visitors table, invalid indexes will fall back to the default visitor.
local visitors = setmetatable({}, {__index = function(self, tag)
  self[tag] = default_visitor -- set the first time tag is visited (optimization)
  return default_visitor
end})

-- Visit a node that should be converted to a name (a string).
function visitors.PreprocessName(ppcontext, node, emitter, parent, parentindex)
  local luacode = node[1]
  local pregidx, nregidx = ppcontext:get_registry_index(parent), ppcontext:get_registry_index(node)
  emitter:add_indent_ln('ppcontext:inject_name(',luacode,
    ',ppregistry[',pregidx,'],',parentindex,',ppregistry[',nregidx,'])')
end

-- Visit a node that should be converted to another node.
function visitors.PreprocessExpr(ppcontext, node, emitter, parent, parentindex)
  local luacode = node[1]
  local pregidx, nregidx = ppcontext:get_registry_index(parent), ppcontext:get_registry_index(node)
  emitter:add_indent_ln('ppcontext:inject_value(',luacode,
    ',ppregistry[',pregidx,'],',parentindex,',ppregistry[',nregidx,'])')
end

-- Visit a node that should execute a code.
function visitors.Preprocess(_, node, emitter)
  local luacode = node[1]
  emitter:add_ln(luacode)
end

-- Visit a block node.
function visitors.Block(ppcontext, node, emitter)
  local statnodes = node
  if not node.needprocess then
    ppcontext:traverse_nodes(statnodes, emitter)
    return
  end
  node.needprocess = nil
  local blockregidx = ppcontext:get_registry_index(node)
  emitter:add_indent_ln('ppregistry[', blockregidx, '].preprocess=function(blocknode, ...)')
  emitter:inc_indent()
  emitter:add_indent_ln('ppcontext:push_statnodes(blocknode)')
  for i=1,#statnodes do
    local statnode = statnodes[i]
    local statregidx = ppcontext:get_registry_index(statnode)
    ppcontext:traverse_node(statnode, emitter)
    statnodes[i] = nil
    if statnode.tag ~= 'Preprocess' then
      emitter:add_indent_ln('ppcontext:inject_statement(ppregistry[', statregidx, '])')
    end
  end
  emitter:add_indent_ln('ppcontext:pop_statnodes()')
  emitter:dec_indent()
  emitter:add_indent_ln('end')
end

--[[
Visit function definition node.
This is a special case because preprocessing of returns is delayed after arguments are traversed.
]]
function visitors.FuncDef(ppcontext, node, emitter)
  local namenode, argnodes, retnodes, annotnodes, blocknode = node[2], node[3], node[4], node[5], node[6]
  ppcontext:traverse_node(namenode, emitter, node, 2)
  ppcontext:traverse_nodes(argnodes, emitter, node, 3)
  if retnodes then
    for i=1,#retnodes do
      local retnode = retnodes[i]
      local needpreprocess
      for subnode in retnode:walk_nodes() do
        if preprocess_tags[subnode.tag] then
          needpreprocess = true
          break
        end
      end
      if not needpreprocess then
        ppcontext:traverse_node(retnode, emitter, retnodes, i)
      else -- preprocess later to have arguments visible in the preprocess context
        local retindex = ppcontext:get_registry_index(retnode)
        emitter:add_indent_ln('ppregistry[',retindex,'].preprocess=function(parent,pregidx)')
        emitter:inc_indent()
        ppcontext:traverse_node(retnode, emitter, retnodes, i)
        local retsindex = ppcontext:get_registry_index(retnodes)
        emitter:add_indent_ln("parent[pregidx]=ppregistry[",retsindex,"][",i,"]:clone()")
        emitter:add_indent_ln("ppregistry[",retsindex,"][",i,"]=ppregistry[",retindex,"]")
        emitter:dec_indent()
        emitter:add_indent_ln('end')
      end
    end
  end
  if annotnodes then
    ppcontext:traverse_nodes(annotnodes, emitter, node, 5)
  end
  ppcontext:traverse_node(blocknode, emitter, node, 6)
end

-- The preprocessor module.
local preprocessor = {working_time = 0}

local function mark_preprocessing_nodes(ast)
  local needprocess
  for _, parents in ast:walk_trace_nodes(preprocess_tags) do
    needprocess = true
    -- mark nearest parent block above
    for i=#parents,1,-1 do
      local pnode = parents[i]
      if pnode.tag == 'Block' then
        pnode.needprocess = true
        break
      end
    end
  end
  return needprocess
end

-- Preprocess AST `ast` using analyzer context `context`.
function preprocessor.preprocess(context, ast)
  assert(ast.tag == 'Block')
  -- begin tracking time
  local timer
  if config.more_timing or config.timing then
    timer = nanotimer()
  end
  -- creates ppcontext if the node doesn't have one yet
  local ppcontext = context.ppcontext
  if not ppcontext then
    ppcontext = PPContext(visitors, context)
    context.ppcontext = ppcontext
  end
  -- generate preprocess code only when a preprocessing directive is found
  local preprocessed = false
  if mark_preprocessing_nodes(ast) then -- we really need to preprocess the ast
    -- second pass, emit the preprocess lua code
    local emitter = Emitter(ppcontext, 0)
    if config.define and not ppcontext.defined then -- TODO: move code
      for _,define in ipairs(config.define) do
        emitter:add_ln(define)
      end
      ppcontext.defined = true
    end
    ppcontext:traverse_node(ast, emitter)
    -- generate the preprocess function`
    local ppcode = emitter:generate()
    local chukname = '@ppcode'
    if ast.attr.filename then
      chukname = '@'..ast.attr.filename..':'..chukname
    end
    ppcontext:register_code(chukname, ppcode)
    -- try to run the preprocess otherwise capture and show the error
    local ppfunc, err = load(ppcode, chukname, "t", ppcontext.env)
    local ok = not err
    if ppfunc then
      ok, err = except.trycall(ppfunc)
    end
    if not ok then
      ast:raisef('error while preprocessing: %s', err)
    end
    preprocessed = true
  end
  -- finish time tracking
  if timer then
    local elapsed = timer:elapsed()
    preprocessor.working_time = preprocessor.working_time + elapsed
    if config.more_timing then
      console.debugf('preprocessed %s (%.1f ms)', ast.src.name, timer:elapsed())
    end
  end
  return preprocessed
end

return preprocessor
