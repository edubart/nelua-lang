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

local function clone_nodetable(t)
  local ct = {}
  for i,v in ipairs(t) do
    if traits.is_astnode(v) then
      ct[i] = v:clone()
    elseif traits.is_table(v) then
      ct[i] = clone_nodetable(v)
    elseif traits.is_astprimitive(v) then
      ct[i] = v
    else --luacov:disable
      error('invalid value type in node clone')
    end --luacov:enable
  end
  if t.n then
    -- in case of packed tables
    ct.n = t.n
  end
  return ct
end

function ASTNode:clone()
  local node = setmetatable({}, getmetatable(self))
  for i=1,self.nargs do
    local arg = self[i]
    if traits.is_astnode(arg) then
      arg = arg:clone()
    elseif traits.is_table(arg) then
      arg = clone_nodetable(arg)
    end
    node[i] = arg
  end
  if self.pattr then
    -- copy persistent attributes
    node.attr = self.pattr:clone()
    node.pattr = self.pattr
  else
    node.attr = setmetatable({}, Attr)
  end
  node.pos = self.pos
  node.src = self.src
  node.srcname = self.srcname
  node.modname = self.modname
  node.cloned = true
  node.uid = genuid()
  return node
end

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
local function format_node_errmsg(node, message, ...)
  message = stringer.pformat(message, ...)
  if node.src and node.pos then
    message = errorer.get_pretty_source_errmsg(node.src, node.srcname, node.pos, message)
  end
  return message
end

--luacov:disable
function ASTNode:errorf(message, ...)
  error(format_node_errmsg(self, message, ...), 2)
end

function ASTNode:assertf(cond, message, ...)
  if not cond then
    error(format_node_errmsg(self, message, ...), 2)
  end
  return cond
end
--luacov:enable

function ASTNode:raisef(message, ...)
  except.raise(format_node_errmsg(self, message, ...), 2)
end

function ASTNode:assertraisef(cond, message, ...)
  if not cond then
    except.raise(format_node_errmsg(self, message, ...), 2)
  end
  return cond
end

-------------------
-- pretty print ast
-------------------
local ignored_stringfy_keys = {
  pos = true, src = true, srcname=true, modname=true,
  uid = true,
  processed = true,
  desiredtype = true,
  cloned = true,
  needprocess = true,
  possibletypes = true,
  node = true,
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
