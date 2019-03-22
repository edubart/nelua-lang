local class = require 'euluna.utils.class'
local types = require 'tableshape'.types
local inspect = require 'inspect'
local utils = require 'euluna.utils.errorer'
local tabler = require 'euluna.utils.tabler'
local assertf = utils.assertf

local ASTNode = class()
ASTNode.tag = 'Node'
ASTNode.nargs = 0
ASTNode.is_astnode = true

function ASTNode:args()
  return tabler.unpack(self, 1, self.nargs)
end

local table_insert = table.insert
local function table_inserts(t, v, ...)
  if v == nil then return end
  table_insert(t, v)
  table_inserts(t, ...)
end

local function stringfy_ast(node, depth, t, skipindent)
  local indent = string.rep('  ', depth)
  local isast = node.is_astnode
  if not skipindent then
    table_insert(t, indent)
  end
  if isast then
    if node.type then
      table_inserts(t, "TAST('", node.type, "', '", node.tag, "'")
    else
      table_inserts(t, "AST('", node.tag, "'")
    end
  end
  local nargs = isast and node.nargs or #node
  if nargs > 0 then
    table_insert(t, isast and ',\n' or '{ ')
    for i=1,nargs do
      local v = node[i]
      if type(v) == 'table' then
        stringfy_ast(v, depth+1, t, i == 1 and not isast)
      else
        table_inserts(t, indent, '  ', inspect(v))
      end
      table_insert(t, (i == nargs and '\n' or ',\n'))
    end
    table_inserts(t, indent, isast and ')' or '}')
  else
    table_insert(t,  (isast and ')' or '{}'))
  end
  if depth == 0 then
    return table.concat(t)
  end
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

function ASTNode:__tostring()
  return stringfy_ast(self, 0, {})
end

local Shaper = class()

local function get_astnode_shapetype(self, name)
  local nodeklass = self.nodes[name]
  return types.custom(function(val)
    if type(val) == 'table' and class.is_a(val, nodeklass) then
      return true
    end
    return nil, string.format('expected type "ASTNode", got "%s"', type(val))
  end)
end

function Shaper:_init()
  self.nodes = {
    Node = ASTNode
  }
  self.creates = {}
  self.types = {
    ASTNode = get_astnode_shapetype(self, 'Node')
  }
  tabler.setmetaindex(self.types, types)
end

function Shaper:register(name, shape)
  local klass = class(ASTNode)
  self.nodes[name] = klass
  klass.tag = name
  klass.nargs = #shape.shape
  local klass_mt = getmetatable(klass())
  local function node_create(node)
    setmetatable(node, klass_mt)
    local ok, err = shape(node)
    assertf(ok, 'invalid shape while creating AST node "%s": %s', name, err)
    return node
  end
  klass.create = node_create
  self.creates[name] = node_create
  self.types['AST' .. name] = get_astnode_shapetype(self, name)
  return klass
end

function Shaper:create(tag, node)
  local create = self.creates[tag]
  assertf(create, "AST with name '%s' is not registered", tag)
  return create(node)
end

function Shaper:clone()
  local clone = Shaper()
  tabler.update(clone.nodes, self.nodes)
  tabler.update(clone.creates, self.creates)
  tabler.update(clone.types, self.types)
  return clone
end

function Shaper:AST(tag, ...)
  return self:create(tag, {...})
end

function Shaper:TAST(type, tag, ...)
  local node = {...}
  self:create(tag, node)
  node.type = type
  return node
end

return Shaper
