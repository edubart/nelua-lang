--[[
Analyzer context.

This is the context used while analyzing an AST.
It extends the visitor context and adds some methods to assist analyzing.
]]

local class = require 'nelua.utils.class'
local stringer = require 'nelua.utils.stringer'
local Scope = require 'nelua.scope'
local VisitorContext = require 'nelua.visitorcontext'

-- The analyzer context class.
local AnalyzerContext = class(VisitorContext)

function AnalyzerContext:_init(visitors, ast, generator)
  assert(visitors and ast and generator)
  local rootscope = Scope.create_root(self, ast)
  VisitorContext._init(self, visitors, rootscope)
  self.ast = ast
  self.scope = self.rootscope
  self.usedbuiltins = {}
  self.env = setmetatable({}, {__index = _G})
  self.requires = {}
  self.usedcodenames = {}
  self.afteranalyzes = {}
  self.afterinfers = {}
  self.unresolvedcount = 0
  self.generator = generator
end

function AnalyzerContext:push_forked_cleaned_scope(node)
  local scope = self:push_forked_scope(node)
  scope:clear_symbols()
  return scope
end

function AnalyzerContext:mark_funcscope_sideeffect()
  local funcscope = self.state.funcscope
  if funcscope then
    funcscope.sideeffect = true
  end
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
  local usedcodenames = self.usedcodenames
  local count = usedcodenames[name]
  if count then
    usedcodenames[name] = count + 1
    name = string.format('%s_%d', name, count)
  end
  usedcodenames[name] = 1
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

--[[
local nodetravs, numretravs, numtravs = {}, {}, {}
local function bench_traverse(self, node)
  if node._astnode then
    local tag = node.tag
    numtravs[tag] = (numtravs[tag] or 0) + 1
    if nodetravs[node] then
      numretravs[tag] = (numretravs[tag] or 0) + 1
    end
    nodetravs[node] = true
  end
  if #self.nodestack == 0 then
    print '============================report'
    for k,v in require'nelua.utils.iterators'.ospairs(numretravs) do
      print(v,k, string.format('%.2f', v*100/numtravs[k]))
    end
  end
end
]]

-- Like `VisitorContext:traverse_node`, but optimized for analyzer context.
function AnalyzerContext:traverse_node(node, ...)
  local done = node.done
  if done then
    return done ~= true and done or nil
  end
  -- bench_traverse(self, node)
  local nodestack = self.nodestack
  local index = #nodestack+1
  nodestack[index] = node -- push node
  local ret = self.visitors[node.tag](self, node, ...)
  nodestack[index] = nil -- pop node
  return ret
end

return AnalyzerContext
