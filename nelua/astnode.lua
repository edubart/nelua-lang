local pegger = require 'nelua.utils.pegger'
local class = require 'nelua.utils.class'
local errorer = require 'nelua.utils.errorer'
local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local except = require 'nelua.utils.except'
local sstream = require 'nelua.utils.sstream'
local stringer = require 'nelua.utils.stringer'
local console = require 'nelua.utils.console'
local tabler = require'nelua.utils.tabler'
local config = require 'nelua.configer'.get()
local Attr = require 'nelua.attr'

local tabler_update = tabler.update
local clone_node

-- Unique id counter for ASTNode.
local uid = 0

-- AST node class.
local ASTNode = class()

ASTNode.tag = 'Node' -- tag for a generic ASTNode
ASTNode._astnode = true -- used to quickly check weather a table is an ASTNode

-- Create an AST node with metatable `mt` filled with values `...`.
-- Called when manually creating or generating AST nodes.
function ASTNode._create(mt, ...)
  local nuid = uid + 1
  uid = nuid
  return setmetatable({
    attr = setmetatable({}, Attr),
    uid = nuid,
    ...
  }, mt)
end
getmetatable(ASTNode).__call = ASTNode._create

-- Create an AST node with metatable `mt` from table `node`.
-- Called for every AST node initialization while parsing.
function ASTNode.create_from(mt, node)
  local nuid = uid + 1
  uid = nuid
  node.uid = nuid
  node.attr = setmetatable({}, Attr)
  return setmetatable(node, mt)
end

-- Clone a node table.
local function clone_nodetable(t)
  local ct = {}
  for i=1,#t do
    local v = t[i]
    if v._astnode then
      ct[i] = clone_node(v)
    else
      ct[i] = clone_nodetable(v)
    end
  end
  return ct
end

-- Clone a node, copying only necessary values.
function ASTNode.clone(node)
  local nuid = uid + 1
  uid = nuid
  local pattr = node.pattr
  local attr = setmetatable({}, Attr)
  local cloned = setmetatable({
    attr = attr,
    pos = node.pos,
    endpos = node.endpos,
    src = node.src,
    preprocess = node.preprocess,
    pattr = pattr,
    uid = nuid,
    nil,nil,nil,nil,nil,nil -- preallocate array part
  }, getmetatable(node))
  if pattr then
    tabler_update(attr, pattr)
  end
  for i=1,#node do
    local arg = node[i]
    if type(arg) == 'table' then
      if arg._astnode then
        arg = clone_node(arg)
      else
        arg = clone_nodetable(arg)
      end
    end
    cloned[i] = arg
  end
  return cloned
end

clone_node = ASTNode.clone

--[[
Replace current AST node values and metatable with node `node`.
Used internally to transform a node to another node.
]]
function ASTNode:transform(node)
  setmetatable(self, getmetatable(node))
  for i=1,math.max(#self, #node) do
    self[i] = node[i]
  end
  self.attr = node.attr
  self.pattr = node.pattr
end


-------------------
-- error handling
-------------------
function ASTNode.format_message(self, category, message, ...)
  message = stringer.pformat(message, ...)
  if self and self.src and self.pos then
    message = errorer.get_pretty_source_pos_errmsg(self.src, self.pos, self.endpos, message, category)
  else --luacov:disable
    message = category .. ': ' .. message .. '\n'
  end --luacov:enable
  return message
end

--luacov:disable
function ASTNode.errorf(self, message, ...)
  error(ASTNode.format_message(self, 'error', message, ...), 2)
end

function ASTNode.assertf(self, cond, message, ...)
  if not cond then
    error(ASTNode.format_message(self, 'error', message, ...), 2)
  end
  return cond
end

function ASTNode.assertraisef(self, cond, message, ...)
  if not cond then
    except.raise(ASTNode.format_message(self, 'error', message, ...), 2)
  end
  return cond
end
--luacov:enable

function ASTNode.raisef(self, message, ...)
  except.raise(ASTNode.format_message(self, 'error', message, ...), 2)
end

function ASTNode.warnf(self, message, ...)
  if not config.no_warning then
    console.logerr(ASTNode.format_message(self, 'warning', message, ...))
  end
end

-------------------
-- pretty print ast
-------------------
local ignored_stringfy_keys = {
  src = true,
  pos = true, endpos = true,
  uid = true,
  desiredtype = true,
  preprocess = true,
  preprocessed = true,
  loadedast = true,
  node = true,
  scope = true,
  done = true,
  untyped = true,
  checked = true,
  usedby = true,
  argattrs = true,
}
local function stringfy_val2str(val)
  local vstr = tostring(val)
  if traits.is_number(val) or traits.is_boolean(val) or val == nil then
    return vstr
  else
    return pegger.double_quote_lua_string(vstr)
  end
end

local function stringfy_astnode(node, depth, ss, skipindent)
  local indent = string.rep('  ', depth)
  local isnode = node._astnode
  if not skipindent then
    ss:add(indent)
  end
  if isnode then
    ss:addmany(node.tag, ' ')
  end
  ss:add('{\n')
  for k,v in iters.ospairs(node) do
    if not ignored_stringfy_keys[k] then
      if isnode and k == 'attr' and traits.is_table(v) then
        if next(v) then
          ss:addmany(indent, '  attr = ')
          stringfy_astnode(v, depth+1, ss, true)
          ss:add(',\n')
        end
      else
        ss:addmany(indent, '  ', k, ' = ', stringfy_val2str(v), ',\n')
      end
    end
  end
  local nargs = #node
  if nargs > 0 then
    for i=1,nargs do
      local v = node[i]
      if type(v) == 'table' then
        stringfy_astnode(v, depth+1, ss)
      else
        ss:addmany(indent, '  ', stringfy_val2str(v))
      end
      ss:add(i == nargs and '\n' or ',\n')
    end
  end
  ss:addmany(indent, '}')
end

function ASTNode:__tostring()
  local ss = sstream()
  stringfy_astnode(self, 0, ss)
  return ss:tostring()
end

local coroutine_yield = coroutine.yield
local coroutine_wrap = coroutine.wrap

local function walk_symbols(node)
  if node._astnode then
    local attr = node.attr
    if attr and attr._symbol then
      coroutine_yield(attr)
    end
  end
  for i=1,#node do
    local v = node[i]
    if type(v) == 'table' then
      walk_symbols(v)
    end
  end
end

function ASTNode:walk_symbols()
  return coroutine_wrap(walk_symbols), self
end

local function walk_nodes(node, parent, parentindex)
  if node._astnode then
    coroutine_yield(node, parent, parentindex)
  end
  local n = #node
  for i=1,n do
    local v = node[i]
    if type(v) == 'table' then
      walk_nodes(v, node, i)
    end
  end
end

function ASTNode:walk_nodes()
  return coroutine_wrap(walk_nodes), self
end

function ASTNode:walk_trace_nodes(tagfilter)
  local trace = {}
  local function walk_trace_nodes(node, n)
    local parentpos = #trace+1
    trace[parentpos] = node
    for i=1,n do
      local subnode = node[i]
      if type(subnode) == 'table' then
        if subnode._astnode then
          if tagfilter[subnode.tag] then -- is an accepted astnode
            coroutine_yield(subnode, trace)
          end
        end
        local subn = #subnode
        if subn > 0 then
          walk_trace_nodes(subnode, subn)
        end
      end
    end
    trace[parentpos] = nil
  end
  return coroutine_wrap(walk_trace_nodes), self, #self
end

function ASTNode:has_sideeffect()
  for node in self:walk_nodes() do
    if node.attr.sideeffect then
      return true
    end
  end
  return false
end

return ASTNode
