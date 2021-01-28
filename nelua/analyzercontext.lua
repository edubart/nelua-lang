local class = require 'nelua.utils.class'
local tabler = require 'nelua.utils.tabler'
local Scope = require 'nelua.scope'
local errorer = require 'nelua.utils.errorer'
local stringer = require 'nelua.utils.stringer'
local sstream = require 'nelua.utils.sstream'
local VisitorContext = require 'nelua.visitorcontext'

local AnalyzerContext = class(VisitorContext)

function AnalyzerContext:_init(visitors, parser, ast, generator)
  VisitorContext._init(self, visitors)
  self.parser = parser
  self.rootscope = Scope(self, ast)
  self.ast = ast
  self.scope = self.rootscope
  self.usedbuiltins = {}
  self.env = {}
  self.requires = {}
  self.scopestack = {}
  self.globalpragmas = {}
  self.pragmas = setmetatable({}, {__index = self.globalpragmas})
  self.pragmastack = {}
  self.usedcodenames = {}
  self.after_analyze = {}
  self.after_inferences = {}
  self.unresolvedcount = 0
  assert(generator)
  self.generator = generator
end

function AnalyzerContext:push_pragmas()
  table.insert(self.pragmastack, self.pragmas)
  local newpragmas = setmetatable(tabler.copy(self.pragmas), getmetatable(self.pragmas))
  self.pragmas = newpragmas
  return newpragmas
end

function AnalyzerContext:pop_pragmas()
  self.pragmas = table.remove(self.pragmastack)
  assert(self.pragmas)
end

function AnalyzerContext:push_scope(scope)
  local scopestack = self.scopestack
  scopestack[#scopestack+1] = self.scope
  self.scope = scope
end

function AnalyzerContext:push_forked_scope(node)
  local scope
  if node.scope then
    scope = node.scope
    assert(scope.parent == self.scope and scope.node == node)
  else
    scope = self.scope:fork(node)
    node.scope = scope
  end
  self:push_scope(scope)
  return scope
end

function AnalyzerContext:push_forked_cleaned_scope(node)
  local scope = self:push_forked_scope(node)
  scope:clear_symbols()
  return scope
end

function AnalyzerContext:pop_scope()
  local scopestack = self.scopestack
  local index = #scopestack
  self.scope = scopestack[index]
  scopestack[index] = nil
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
  local unitname = self.pragmas.unitname or self.state.unitname
  name = name:gsub('%(','_'):gsub('[^%w_]','')
  if unitname and unitname ~= '' then
    unitname = unitname .. '_'
    if not stringer.startswith(name, unitname) then
      name = unitname .. name
    end
  end
  local count = self.usedcodenames[name]
  if count then
    self.usedcodenames[name] = count + 1
    name = string.format('%s__%d', name, count)
  end
  self.usedcodenames[name] = 1
  return name
end

function AnalyzerContext:choose_type_symbol_names(symbol)
  local type = symbol.value
  if type:suggest_nickname(symbol.name) then
    if symbol.staticstorage and symbol.codename then
      type:set_codename(symbol.codename)
    else
      local codename = self:choose_codename(symbol.name)
      type:set_codename(codename)
    end
    type.symbol = symbol
  end
end

function AnalyzerContext:traceback()
  local nodes = self.nodes
  local ss = sstream()
  local polysrcnode = self.state.inpolyeval and self.state.inpolyeval.srcnode
  if polysrcnode then
    ss:add(polysrcnode:format_message('from', 'polymorphic function instantiation'))
  end
  for i=1,#nodes-1 do
    local node = nodes[i]
    if node._astnode and node.tag ~= 'Block' then
      ss:add(node:format_message('from', 'AST node %s', node.tag))
    end
  end
  return ss:tostring()
end

return AnalyzerContext
