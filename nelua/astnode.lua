local pegger = require 'nelua.utils.pegger'
local class = require 'nelua.utils.class'
local errorer = require 'nelua.utils.errorer'
local iters = require 'nelua.utils.iterators'
local traits = require 'nelua.utils.traits'
local except = require 'nelua.utils.except'
local sstream = require 'nelua.utils.sstream'
local stringer = require 'nelua.utils.stringer'
local console = require 'nelua.utils.console'
local config = require 'nelua.configer'.get()
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

ASTNode.genuid = genuid

function ASTNode:_init(...)
  for i=1,select('#', ...) do
    self[i] = select(i, ...)
  end
  self.attr = setmetatable({}, Attr)
  self.uid = genuid()
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

local clone_attr = Attr.clone
local clone_nodetable, clone_node

clone_nodetable = function(t)
  local n = t.n
  local ct = {
    n = n -- in case of packed tables
  }
  for i=1,n or #t do
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
  local cloned = {
    pos = node.pos,
    endpos = node.endpos,
    src = node.src,
    preprocess = node.preprocess,
    uid = genuid(),
    attr = setmetatable({}, Attr)
  }
  local pattr = node.pattr
  if pattr then
    cloned.attr = clone_attr(pattr)
    cloned.pattr = pattr
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
  return setmetatable(cloned, getmetatable(node))
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
