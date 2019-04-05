local pegger = require 'euluna.utils.pegger'
local class = require 'euluna.utils.class'
local errorer = require 'euluna.utils.errorer'
local tabler = require 'euluna.utils.tabler'
local iters = require 'euluna.utils.iterators'
local traits = require 'euluna.utils.traits'
local except = require 'euluna.utils.except'

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

local function stringfy_astnode(node, depth, t, skipindent)
  local indent = string.rep('  ', depth)
  local isnode = node._astnode
  if not skipindent then
    table.insert(t, indent)
  end
  local empty = true
  for k,_ in pairs(node) do
    if not isnode or not ignored_stringfy_keys[k] then
      empty = false
    end
  end
  if isnode then
    tabler.insertmany(t, node.tag, ' ')
  end
  table.insert(t, '{')
  if isnode and not empty then
    table.insert(t, '\n')
  else
    table.insert(t, ' ')
  end
  for k,v in iters.ospairs(node) do
    if not isnode or not ignored_stringfy_keys[k] then
      tabler.insertmany(t, indent, '  ', k, ' = ', stringfy_val2str(v), ',\n')
    end
  end
  local nargs = isnode and node.nargs or #node
  if nargs > 0 then
    for i,v in iters.inpairs(node, nargs) do
      if type(v) == 'table' then
        stringfy_astnode(v, depth+1, t, i == 1 and not isnode)
      else
        tabler.insertmany(t, indent, '  ', stringfy_val2str(v))
      end
      table.insert(t, (i == nargs and '\n' or ',\n'))
    end
    tabler.insertmany(t, indent, '}')
  else
    table.insert(t, (isnode and '}' or '{}'))
  end
  if depth == 0 then
    return table.concat(t)
  end
end

function ASTNode:__tostring()
  return stringfy_astnode(self, 0, {})
end

return ASTNode
