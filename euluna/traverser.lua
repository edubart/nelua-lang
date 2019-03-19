local class = require 'pl.class'
local Scope = require 'euluna.scope'
local assertf = require 'euluna.utils'.assertf

local TraverserContext = class()

function TraverserContext:_init(traverser)
  self.scope = Scope()
  self.visitors = traverser.visitors
  self.asts = {}
  self.coders = {}
end

function TraverserContext:push_scope()
  local scope = self.scope:fork()
  self.scope = scope
  return scope
end

function TraverserContext:pop_scope()
  self.scope = self.scope.parent
end

function TraverserContext:push_ast(ast)
  table.insert(self.asts, ast)
end

function TraverserContext:pop_ast()
  table.remove(self.asts)
end

function TraverserContext:get_parent_ast()
  return self.asts[#self.asts - 1]
end

function TraverserContext:traverse(ast, ...)
  assert(ast.is_astnode, "trying to traverse a non ast value")
  local visitor_func = self.visitors[ast.tag]
  assertf(visitor_func, "visitor '%s' does not exist", ast.tag)
  self:push_ast(ast)
  visitor_func(self, ast, ...)
  self:pop_ast()
end

local Traverser = class()
Traverser.Context = TraverserContext

function Traverser:_init()
  self.visitors = {}
end

function Traverser:register(name, func)
  self.visitors[name] = func
end

function Traverser:newContext(...)
  return self.Context(self, ...)
end

return Traverser
