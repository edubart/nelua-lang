local class = require 'nelua.utils.class'
local tabler = require 'nelua.utils.tabler'
local Scope = require 'nelua.scope'
local errorer = require 'nelua.utils.errorer'
local VisitorContext = require 'nelua.visitorcontext'

local AnalyzerContext = class(VisitorContext)

function AnalyzerContext:_init(visitors, parser)
  VisitorContext._init(self, visitors)
  self.parser = parser
  self.rootscope = Scope(self, 'root')
  self.usedbuiltins = {}
  self.env = {}
  self.requires = {}
  self.scope = self.rootscope
  self.scopestack = {}
  self.state = {}
  self.statestack = {}
  self.pragmas = {}
  self.pragmastack = {}
end

function AnalyzerContext:reset_pragmas()
  tabler.clear(self.pragmas)
end

function AnalyzerContext:push_pragmas()
  table.insert(self.pragmastack, self.pragmas)
  local newpragmas = tabler.copy(self.pragmas)
  self.pragmas = newpragmas
  return newpragmas
end

function AnalyzerContext:pop_pragmas()
  self.pragmas = table.remove(self.pragmastack)
  assert(self.pragmas)
end

function AnalyzerContext:push_state()
  table.insert(self.statestack, self.state)
  local newstate = tabler.copy(self.state)
  self.state = newstate
  return newstate
end

function AnalyzerContext:pop_state()
  self.state = table.remove(self.statestack)
  assert(self.state)
end

function AnalyzerContext:push_scope(scope)
  table.insert(self.scopestack, self.scope)
  self.scope = scope
end

function AnalyzerContext:push_forked_scope(kind, node)
  local scope
  if node.scope then
    scope = node.scope
    assert(scope.kind == kind)
    assert(scope.parent == self.scope)

    -- symbols will be repopulated again
    scope:clear_symbols()
  else
    scope = self.scope:fork(kind)
    node.scope = scope
  end
  self:push_scope(scope)
  return scope
end

function AnalyzerContext:pop_scope()
  self.scope = table.remove(self.scopestack)
end

function AnalyzerContext:repeat_scope_until_resolution(scope_kind, node, after_push)
  local scope
  repeat
    scope = self:push_forked_scope(scope_kind, node)
    after_push(scope)
    local resolutions_count = scope:resolve()
    self:pop_scope()
  until resolutions_count == 0
  return scope
end

function AnalyzerContext:ensure_runtime_builtin(name, p1, p2)
  if not (p1 or p2) and self.usedbuiltins[name] then
    return name
  end
  errorer.assertf(self.builtins[name], 'builtin "%s" not defined', name)
  local func = self.builtins[name]
  if func then
    local newname = func(self, p1, p2)
    if newname then
      name = newname
    end
  end
  self.usedbuiltins[name] = true
  return name
end

function AnalyzerContext:choose_codename(name)
  local modname = self.pragmas.modname or self.state.modname
  if modname then
    return modname .. '_' .. name
  end
  return name
end

return AnalyzerContext
