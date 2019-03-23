local Traverser = require 'euluna.traverser'
local class = require 'euluna.utils.class'
local assertf = require 'euluna.utils.errorer'.assertf
local cdefs = require 'euluna.generators.c.definitions'
local cbuiltins = require 'euluna.generators.c.builtins'

local CContext = class(Traverser.Context)

function CContext:_init(traverser)
  self:super(traverser)
  self.includes = {}
  self.builtins = {}
end

function CContext:add_include(name)
  local includes = self.includes
  if includes[name] then return end
  includes[name] = true
  self.includes_coder:add_ln(string.format('#include %s', name))
end

function CContext:add_builtin(name)
  local builtins = self.builtins
  if builtins[name] then return end
  builtins[name] = true
  local builtin = cbuiltins[name]
  assertf(builtin, 'builtin %s not found', name)
  builtin(self)
end

function CContext:get_ctype(ast)
  local tyname = ast:assertf(ast.type, 'unknown type for for AST node')
  local ttype = cdefs.PRIMIVE_TYPES[tyname]
  ast:assertf(ttype, 'type %s is not known', tyname)
  if ttype.include then
    self:add_include(ttype.include)
  end
  if ttype.builtin then
    self:add_builtin(ttype.builtin)
  end
  return ttype.ctype
end

return CContext
