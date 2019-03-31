local iters = require 'euluna.utils.iterators'
local tabler = require 'euluna.utils.tabler'
local class = require 'euluna.utils.class'

local Symbol = class()

function Symbol:_init(ast)
  self.ast = ast
  self.ast_references = {}
  self.possible_types = {}
end

function Symbol:add_possible_type(type, required)
  if self.type then return end
  if not type and required then
    self.has_unknown_type = true
    return
  end
  if tabler.find(self.possible_types, type) then return end
  table.insert(self.possible_types, type)
end

function Symbol:add_ast_reference(ast)
  if tabler.find(self.ast_references, ast) then return end
  table.insert(self.ast_references, ast)
end

function Symbol:link_ast_type(ast)
  if self.type then
    ast.type = self.type
  else
    self:add_ast_reference(ast)
  end
end

function Symbol:update_ast_references()
  for ast in iters.values(self.ast_references) do
    ast.type = self.type
  end
end

function Symbol:set_type(type)
  self.type = type
  self:update_ast_references()
end

return Symbol
