local tabler = require 'nelua.utils.tabler'
local class = require 'nelua.utils.class'
local sstream = require 'nelua.utils.sstream'
local Symbol = class()

function Symbol:_init(name, node, type)
  assert(name)
  local attr = node and node.attr or {}
  self.name = name
  self.node = node
  self.possibletypes = {}
  self.attr = attr
  attr.name = name
  attr.codename = name
  if type then
    attr.type = type
  end
end

function Symbol:add_possible_type(type, required)
  if self.attr.type then return end
  if not type then
    if required then
      self.requnknown = true
    else
      self.hasunknown = true
    end
    return
  end
  if tabler.ifind(self.possibletypes, type) then return end
  table.insert(self.possibletypes, type)
end

function Symbol:link_node(node)
  if node.attr == self.attr then
    return
  end
  if next(node.attr) == nil then
    node.attr = self.attr
  else
    -- merge attrs into others node and link
    local attr = self.attr
    for k,v in pairs(node.attr) do
      if attr[k] == nil then
        attr[k] = v
      else
        assert(attr[k] == v, 'cannot link to a node with different attributes')
      end
    end
    node.attr = attr
  end
end

function Symbol:__tostring()
  local ss = sstream('symbol<')
  ss:add(self.name)
  if self.attr.const or self.attr.compconst or self.attr.type then
    ss:add(': ')
  end
  if self.attr.const then
    ss:add('const ')
  end
  if self.attr.compconst then
    ss:add('compconst ')
  end
  if self.attr.type then
    ss:add(self.attr.type)
  end
  if self.attr.value then
    ss:add(' = ', self.attr.value)
  end
  ss:add('>')
  return ss:tostring()
end

return Symbol
