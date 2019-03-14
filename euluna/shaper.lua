local class = require 'pl.class'
local types = require 'tableshape'.types
local inspect = require 'inspect'
local unpack = table.unpack or unpack

local ASTNode = class()
ASTNode.tag = 'Node'
ASTNode.nargs = 0
ASTNode.is_astnode = true

function ASTNode:args()
  return unpack(self, 1, self.nargs)
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
    table_inserts(t, "AST('", node.tag, "'")
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

function ASTNode:__tostring()
  return stringfy_ast(self, 0, {})
end

local Shaper = class()

local function get_astnode_shapetype(self, name)
  local nodeklass = self.nodes[name]
  return types.custom(function(val)
    if type(val) == 'table' and val.is_a and val:is_a(nodeklass) then
      return true
    end
    return nil, string.format('expected type "ASTNode", got "%s"', type(val))
  end)
end

function Shaper:_init()
  self.nodes = {
    node = ASTNode
  }
  self.creates = {}
  self.types = {
    ASTNode = get_astnode_shapetype(self)
  }
  setmetatable(self.types, {
    __index = types
  })
end

function Shaper:register(name, shape)
  local klass = class(ASTNode)
  self.nodes[name] = klass
  klass.tag = name
  klass.nargs = #shape.shape
  klass.is_astnode = true
  local klass_mt = getmetatable(klass())
  local function node_create(...)
    local node = {...}
    setmetatable(node, klass_mt)
    local ok, err = shape(node)
    if not ok then
      error(string.format('invalid shape while creating AST node "%s": %s', name, err))
    end
    return node
  end
  klass.create = node_create
  self.creates[name] = node_create
  self.types['AST' .. name] = get_astnode_shapetype(self, name)
  return klass
end

function Shaper:create(tag, ...)
  local create = self.creates[tag]
  if not create then
    error(string.format("AST with name '%s' is not registered", tag))
  end
  return create(...)
end

return Shaper
