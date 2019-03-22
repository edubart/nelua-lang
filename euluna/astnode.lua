local class = require 'euluna.utils.class'
local inspect = require 'inspect'
local utils = require 'euluna.utils.errorer'
local tabler = require 'euluna.utils.tabler'

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

function ASTNode:args()
  return tabler.unpack(self, 1, self.nargs)
end

function ASTNode:assertf(cond, format, ...)
  if not cond then
    local msg = string.format(format, ...)
    if self.src and self.pos then
      msg = utils.get_pretty_source_errmsg(self.src, self.srcname, self.pos, msg)
    end
    error(msg)
  end
  return cond
end

-- pretty print ast
local function stringfy_ast(node, depth, t, skipindent)
  local indent = string.rep('  ', depth)
  local isast = node._astnode
  if not skipindent then
    table.insert(t, indent)
  end
  if isast then
    if node.type then
      tabler.insert_many(t, "TAST('", node.type, "', '", node.tag, "'")
    else
      tabler.insert_many(t, "AST('", node.tag, "'")
    end
  end
  local nargs = isast and node.nargs or #node
  if nargs > 0 then
    table.insert(t, isast and ',\n' or '{ ')
    for i=1,nargs do
      local v = node[i]
      if type(v) == 'table' then
        stringfy_ast(v, depth+1, t, i == 1 and not isast)
      else
        tabler.insert_many(t, indent, '  ', inspect(v))
      end
      table.insert(t, (i == nargs and '\n' or ',\n'))
    end
    tabler.insert_many(t, indent, isast and ')' or '}')
  else
    table.insert(t,  (isast and ')' or '{}'))
  end
  if depth == 0 then
    return table.concat(t)
  end
end

function ASTNode:__tostring()
  return stringfy_ast(self, 0, {})
end

return ASTNode