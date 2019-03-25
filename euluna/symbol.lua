local iters = require 'euluna.utils.iterators'
local class = require 'euluna.utils.class'

local Symbol = class()

function Symbol:_init(ast)
  self.ast = ast
  self.ast_references = {}
  self.possible_types = {}
end

function Symbol:add_possible_type(type)
  table.insert(self.possible_types, type)
end

function Symbol:add_ast_reference(ast)
  table.insert(self.ast_references, ast)
end

local function update_ast_references(self)
  for ast in iters.values(self.ast_references) do
    ast.type = self.type
  end
end

local function find_common_type(types)
  local len = #types
  if len == 0 then return nil end
  if len == 1 then return types[1] end
  --TODO: find best type
end

function Symbol:resolve_type()
  if self.type then
    return self.type
  end
  self.type = find_common_type(self.possible_types)
  update_ast_references(self)
  return self.type
end

return Symbol
