local iters = require 'euluna.utils.iterators'
local tabler = require 'euluna.utils.tabler'
local class = require 'euluna.utils.class'
local typer = require 'euluna.typer'

local Symbol = class()

function Symbol:_init(ast)
  self.ast = ast
  self.ast_references = {}
  self.possible_types = {}
end

function Symbol:add_possible_type(type)
  if self.type or not type then return end
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

local function update_ast_references(self)
  for ast in iters.values(self.ast_references) do
    ast.type = self.type
  end
end

function Symbol:resolve_type()
  if self.type then
    return false
  end
  self.type = typer.find_common_type(self.possible_types)
  update_ast_references(self)
  return true
end

return Symbol
