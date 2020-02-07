local pegger = require 'nelua.utils.pegger'
local class = require 'nelua.utils.class'
local errorer = require 'nelua.utils.errorer'
local tabler = require 'nelua.utils.tabler'
local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local except = require 'nelua.utils.except'
local sstream = require 'nelua.utils.sstream'
local stringer = require 'nelua.utils.stringer'
local Attr = require 'nelua.attr'

local ASTNode = class()
ASTNode.tag = 'Node'
ASTNode.nargs = 0
ASTNode._astnode = true

local uid = 0
local function genuid()
  uid = uid + 1
  return uid
end

function ASTNode:_init(...)
  for i=1,select('#', ...) do
    self[i] = select(i, ...)
  end
  self.attr = setmetatable({}, Attr)
  self.uid = genuid()
end

function ASTNode:args()
  return tabler.unpack(self, 1, self.nargs)
end

local clone_attr = Attr.clone
local clone_nodetable, clone_node

clone_nodetable = function(t)
  local ct = {}
  for i=1,t.n or #t do
    local v = t[i]
    local tv = type(v)
    if tv == 'table' then
      if v._astnode then
        ct[i] = clone_node(v)
      elseif getmetatable(v) == nil then
        ct[i] = clone_nodetable(v)
      else --luacov:disable
        errorer.errorf("invalid table metatable in node clone")
      end --luacov:enable
    else --luacov:disable
      if tv == 'number' or tv == 'userdata' or tv == 'string' or
         tv == 'boolean' or tv == 'function' then
        ct[i] = v
      else
        errorer.errorf("invalid value type '%s' in node clone", tv)
      end
    end --luacov:enable
  end
  -- in case of packed tables
  ct.n = t.n
  return ct
end

clone_node = function(node)
  local cloned = setmetatable({}, getmetatable(node))
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
  if not node.pattr then
    cloned.attr = setmetatable({}, Attr)
  else
    -- copy persistent attributes
    cloned.attr = clone_attr(node.pattr)
    cloned.pattr = node.pattr
  end
  cloned.pos = node.pos
  cloned.src = node.src
  cloned.srcname = node.srcname
  cloned.preprocess = node.preprocess
  cloned.uid = genuid()
  return cloned
end

ASTNode.clone = clone_node

--[[
local function iterate_children_visitor(node, depth)
  local nargs = traits.is_astnode(node) and node.nargs or #node
  for _,arg in iters.inpairs(node, nargs) do
    if traits.is_astnode(arg) then
      coroutine.yield(arg, depth)
      iterate_children_visitor(arg, depth+1)
    elseif traits.is_table(arg) then
      iterate_children_visitor(arg, depth+1)
    end
  end
end

function ASTNode:iterate_children()
  return coroutine.wrap(function()
    coroutine.yield(self, 0)
    iterate_children_visitor(self, 1)
  end)
end
]]

-------------------
-- error handling
-------------------
function ASTNode:format_errmsg(message, ...)
  message = stringer.pformat(message, ...)
  if self.src and self.pos then
    message = errorer.get_pretty_source_pos_errmsg(self.src, self.srcname, self.pos, message)
  end
  return message
end

--luacov:disable
function ASTNode:errorf(message, ...)
  error(self:format_errmsg(message, ...), 2)
end

function ASTNode:assertf(cond, message, ...)
  if not cond then
    error(self:format_errmsg(message, ...), 2)
  end
  return cond
end

function ASTNode:assertraisef(cond, message, ...)
  if not cond then
    except.raise(self:format_errmsg(message, ...), 2)
  end
  return cond
end
--luacov:enable

function ASTNode:raisef(message, ...)
  except.raise(self:format_errmsg(message, ...), 2)
end

-------------------
-- pretty print ast
-------------------
local ignored_stringfy_keys = {
  pos = true, src = true, srcname=true,
  uid = true,
  desiredtype = true,
  preprocess = true,
  loadedast = true,
  node = true,
  scope = true,
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

return ASTNode
