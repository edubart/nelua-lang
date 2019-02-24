local class = require 'pl.class'
local Coder = require 'euluna.coder'
local Scope = require 'euluna.scope'
local Traverser = class()

function Traverser:_init(name)
  self.name = name
  self.visitors = {}
end

function Traverser:register(name, func)
  self.visitors[name] = func
end

function Traverser:traverse(ast, context, parent_scope)
  if not parent_scope then
    parent_scope = Scope()
  end
  local visitor_func = assert(self.visitors[ast.tag], 'visitor does not exist')
  return visitor_func(ast, context, parent_scope)
end

function Traverser:generate(ast)
  local coder = Coder()
  self:traverse(ast, coder)
  return coder:generate()
end

return Traverser