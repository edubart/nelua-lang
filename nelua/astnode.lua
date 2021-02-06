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

local ASTNode = class()
ASTNode.tag = 'Node'
ASTNode.nargs = 0
ASTNode._astnode = true

local uid = 0

function ASTNode._create(klass, ...)
  local nuid = uid + 1
  uid = nuid
  return setmetatable({
    attr = setmetatable({}, Attr),
    uid = nuid,
    ...
  }, klass)
end
getmetatable(ASTNode).__call = ASTNode._create

function ASTNode.make_toastnode(parser, astnodes)
  local function to_astnode(pos, tag, ...)
    local nuid = uid + 1
    uid = nuid
    local n = select('#', ...)
    local endpos = select(n, ...)
    local src = parser.src
    local attr = setmetatable({}, Attr)
    local node = setmetatable({
        attr = attr,
        src = src,
        endpos = endpos,
        pos = pos,
        uid = nuid,
        ...
      }, astnodes[tag])
    node[n] = nil -- remove endpos
    return node
  end
  return to_astnode
end

function ASTNode:args()
  return table.unpack(self, 1, self.nargs)
end

function ASTNode:transform(node)
  local nargs = self.nargs
  setmetatable(self, getmetatable(node))
  nargs = math.max(nargs, self.nargs)
  for i=1,nargs do
    self[i] = node[i]
  end
  self.attr = node.attr
  self.pattr = node.pattr
end

local clone_nodetable, clone_node
local tabler_update = tabler.update

clone_nodetable = function(t)
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

clone_node = function(node)
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
  for i=1,node.nargs do
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

ASTNode.clone = clone_node

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
    ss:add(node.tag, ' ')
  end
  ss:add('{\n')
  for k,v in iters.ospairs(node) do
    if not ignored_stringfy_keys[k] then
      if isnode and k == 'attr' and traits.is_table(v) then
        if next(v) then
          ss:add(indent, '  attr = ')
          stringfy_astnode(v, depth+1, ss, true)
          ss:add(',\n')
        end
      else
        ss:add(indent, '  ', k, ' = ', stringfy_val2str(v), ',\n')
      end
    end
  end
  local nargs = isnode and node.nargs or #node
  if nargs > 0 then
    for i=1,nargs do
      local v = node[i]
      if type(v) == 'table' then
        stringfy_astnode(v, depth+1, ss)
      else
        ss:add(indent, '  ', stringfy_val2str(v))
      end
      ss:add(i == nargs and '\n' or ',\n')
    end
  end
  ss:add(indent, '}')
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
  for i=1,node.nargs or #node do
    local v = node[i]
    if type(v) == 'table' then
      walk_symbols(v)
    end
  end
end

function ASTNode:walk_symbols()
  return coroutine_wrap(walk_symbols), self
end

local function walk_nodes(node)
  if node._astnode then
    coroutine_yield(node)
  end
  for i=1,node.nargs or #node do
    local v = node[i]
    if type(v) == 'table' then
      walk_nodes(v)
    end
  end
end

function ASTNode:walk_nodes()
  return coroutine_wrap(walk_nodes), self
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
