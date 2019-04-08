local pegger = require 'euluna.utils.pegger'
local class = require 'euluna.utils.class'
local errorer = require 'euluna.utils.errorer'
local tabler = require 'euluna.utils.tabler'
local iters = require 'euluna.utils.iterators'
local traits = require 'euluna.utils.traits'
local except = require 'euluna.utils.except'
local sstream = require 'euluna.utils.sstream'

local ASTNode = class()
ASTNode.tag = 'Node'
ASTNode.nargs = 0
ASTNode._astnode = true

function ASTNode:_init(...)
  local nargs = select('#', ...)
  for i=1,nargs do
    self[i] = select(i, ...)
  end
end

function ASTNode:arg(index)
  assert(index >= 1 and index <= self.nargs)
  return self[index]
end

function ASTNode:args()
  return tabler.unpack(self, 1, self.nargs)
end

-------------------
-- error handling
-------------------
local function format_node_errmsg(node, message, ...)
  message = string.format(message, ...)
  if node.src and node.pos then
    message = errorer.get_pretty_source_errmsg(node.src, node.srcname, node.pos, message)
  end
  return message
end

--luacov:disable
function ASTNode:errorf(message, ...)
  error(format_node_errmsg(self, message, ...))
end

function ASTNode:assertf(cond, message, ...)
  if not cond then
    error(format_node_errmsg(self, message, ...))
  end
  return cond
end

function ASTNode:raisef(message, ...)
  except.raise(format_node_errmsg(self, message, ...))
end

function ASTNode:assertraisef(cond, message, ...)
  if not cond then
    except.raise(format_node_errmsg(self, message, ...))
  end
  return cond
end
--luacov:enable

-------------------
-- pretty print ast
-------------------
local ignored_stringfy_keys = { pos = true, src = true, srcname=true }
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
  local empty = true
  for k,_ in pairs(node) do
    if not isnode or not ignored_stringfy_keys[k] then
      empty = false
    end
  end
  if isnode then
    ss:add(node.tag, ' ')
  end
  ss:add('{')
  if isnode and not empty then
    ss:add('\n')
  else
    ss:add(' ')
  end
  for k,v in iters.ospairs(node) do
    if not isnode or not ignored_stringfy_keys[k] then
      ss:add(indent, '  ', k, ' = ', stringfy_val2str(v), ',\n')
    end
  end
  local nargs = isnode and node.nargs or #node
  if nargs > 0 then
    for i,v in iters.inpairs(node, nargs) do
      if type(v) == 'table' then
        stringfy_astnode(v, depth+1, ss, i == 1 and not isnode)
      else
        ss:add(indent, '  ', stringfy_val2str(v))
      end
      ss:add(i == nargs and '\n' or ',\n')
    end
    ss:add(indent, '}')
  else
    ss:add(isnode and '}' or '{}')
  end
end

function ASTNode:__tostring()
  local ss = sstream()
  stringfy_astnode(self, 0, ss)
  return ss:tostring()
end

return ASTNode
