local class = require 'pl.class'
local Traverser = class()

function Traverser:_init()
  self.visitors = {}
end

function Traverser:register(name, func)
  self.visitors[name] = func
end

function Traverser:traverse(ast, context, scope)
  assert(scope, 'no scope in traversal')
  local visitor_func = assert(self.visitors[ast.tag], 'visitor does not exist')
  return visitor_func(ast, context, scope)
end

return Traverser