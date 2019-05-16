local traits = require 'euluna.utils.traits'
local iters = require 'euluna.utils.iterators'
local class = require 'euluna.utils.class'
local except = require 'euluna.utils.except'
local Context = require 'euluna.context'
local Emitter = require 'euluna.emitter'
local compat = require 'pl.compat'

--[=[
local function preprocess_traverse(context, node, statnodes)
  if not tabler.ifindif(statnodes, function(statnode) return statnode.tag == 'Preprocess' end) then
    -- no preprocess statement found
    context:traverse(statnodes)
    return statnodes
  end

  local ss = sstream()
  ss:addln('local __newstatnodes,__node = {}')
  local line2node = {}
  local linecounter = 1
  local lastppnode = nil
  for i,statnode in ipairs(statnodes) do
    local luacode, numlines
    if statnode.tag == 'Preprocess' then
      luacode = statnode[1]
      lastppnode = statnode
      numlines = stringer.count(luacode, '\n') + 1
    else
      luacode = string.format([[
local __node = __statnodes[%d]:clone()
table.insert(__newstatnodes, __node) context:traverse(__node)]], i)
numlines = 2
end
ss:addln(luacode)
for _=1,numlines do
  linecounter = linecounter + 1
  line2node[linecounter] = statnode
end
end
ss:addln('return __newstatnodes')
local ppcode = ss:tostring()
local env = setmetatable({
context = context,
scope = context.scope,
node = node,
__statnodes = statnodes
}, {__index = _G})
local newnodes, err = compat.load(ppcode, '@pp', "t", env)
local ok = not err
local newstatnodes
if newnodes then
ok, newstatnodes = pcall(newnodes)
if not ok then
  err = newstatnodes
end
end
if not ok then
local line, lineerr = err:match('pp:(%d+): (.*)')
assert(line and lineerr)
local linenode = line2node[line] or lastppnode
linenode:raisef('preprocessing error: %s', lineerr)
end
return newstatnodes

]=]

--[[
print #[a]


]]

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

function PPContext.toname(_, val)
  local vtype = type(val)
  assert(vtype == 'string')
  return val
end

function PPContext:tovalue(val, orignode)
  local vtype = type(val)
  local node
  if vtype == 'string' then
    node = self.aster.String{val}
  elseif vtype == 'number' then
    node = self.aster.Number{'dec', tostring(val)}
  else
    error 'not implemented'
  end
  node.srcname = orignode.srcname
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

function visitors.PreprocessName(ppcontext, node, emitter, parentnode, parentindex)
  local luacode = node[1]
  local parentregindex = ppcontext:getregistryindex(parentnode)
  local selfregindex = ppcontext:getregistryindex(node)
  emitter:add_ln(
    'ppregistry[', parentregindex, '][', parentindex, ']',
    ' = ppcontext:toname(', luacode, ', ppregistry[', selfregindex, '])')
end

function visitors.PreprocessExpr(ppcontext, node, emitter, parentnode, parentindex)
  local luacode = node[1]
  local parentregindex = ppcontext:getregistryindex(parentnode)
  local selfregindex = ppcontext:getregistryindex(node)
  emitter:add_ln(
    'ppregistry[', parentregindex, '][', parentindex, ']',
    ' = ppcontext:tovalue(', luacode, ', ppregistry[', selfregindex, '])')
end

function visitors.Preprocess(_, node, emitter)
  local luacode = node[1]
  emitter:add_ln(luacode)
end

function visitors.Block(ppcontext, node, emitter, parentnode)
  local statnodes = node.origstatnodes or node[1]

  node.processed = true
  --[[
  local preprocess_tags = {
    Preprocess = true,
    PreprocessExpr = true,
    PreprocessName = true
  }
  if node:find_child_if(function(childnode) return preprocess_tags[childnode.tag] end) then
    -- this block doesn't have any preprocess directive
    emitter:add_ln('do')
    emitter:add_ln('context:push_scope("block")')
    ppcontext:traverse(statnodes)
    emitter:add_ln('context:pop_scope()')
    emitter:add_ln('end')
    return
  end
  ]]

  if parentnode and not node.origstatnodes then
    node.origstatnodes = statnodes
  end

  emitter:add_ln('do')
  emitter:add_ln('local ppnewstatnodes, ppstatnode = {}')
  emitter:add_ln('ppregistry[', ppcontext:getregistryindex(node), '][1] = ppnewstatnodes')
  emitter:add_ln('context:push_scope("block")')
  for _,statnode in ipairs(statnodes) do
    ppcontext:traverse(statnode, emitter)
    if statnode.tag ~= 'Preprocess' then
      emitter:add_ln('ppstatnode = ppregistry[', ppcontext:getregistryindex(statnode), ']:clone()')
      emitter:add_ln('table.insert(ppnewstatnodes, ppstatnode) context:traverse(ppstatnode)')
    end
  end
  emitter:add_ln('context:pop_scope()')
  emitter:add_ln('end')
end

local preprocessor = {}
function preprocessor.preprocess(context, ast)
  local ppcontext = PPContext(context, visitors)

  local emitter = Emitter(ppcontext, 0)
  assert(ast.tag == 'Block')
  ppcontext:traverse(ast, emitter)

  local ppcode = emitter:generate()
  local env = setmetatable({
    context = context,
    ppcontext = ppcontext,
    ppregistry = ppcontext.registry
  }, { __index = _G })

  local ppfunc, err = compat.load(ppcode, '@pp', "t", env)
  local ok = not err
  if ppfunc then
    ok, err = pcall(ppfunc)
  end
  if except.is_exception(err) then
    except.reraise(err)
  else
    ast:assertraisef(ok, tostring(err))
  end
end

return preprocessor