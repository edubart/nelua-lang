local class = require 'pl.class'
local Scope = require 'euluna.scope'

local TraverserContext = class()

function TraverserContext:_init(traverser)
  self.scope = Scope()
  self.visitors = traverser.visitors
  self.default_visitor = traverser.default_visitor
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
  local visitor_func = self.visitors[ast.tag] or self.default_visitor
  ast:assertf(visitor_func, "visitor for AST node '%s' does not exist", ast.tag)
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

local function default_visitor(self, ast, ...)
  local nargs = ast.is_astnode and ast.nargs or #ast
  for i=1,nargs do
    local arg = ast[i]
    if type(arg) == 'table' then
      if arg.is_astnode then
        self:traverse(arg, ...)
      else
        default_visitor(self, arg, ...)
      end
    end
  end
end

function Traverser:enable_default_visitor(visitor)
  self.default_visitor = visitor or default_visitor
end

function Traverser:newContext(...)
  return self.Context(self, ...)
end

return Traverser
