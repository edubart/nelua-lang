local TraverseContext = require 'euluna.traversecontext'
local class = require 'euluna.utils.class'
local errorer = require 'euluna.utils.errorer'
local cdefs = require 'euluna.generators.c.definitions'
local cbuiltins = require 'euluna.generators.c.builtins'

local CContext = class(TraverseContext)

function CContext:_init(visitors)
  TraverseContext._init(self, visitors)
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
  errorer.assertf(builtin, 'builtin %s not found', name)
  builtin(self)
end

function CContext:get_ctype(ast)
  local type
  if ast.tag == 'Type' then
    type = ast.holding_type
  else
    type = ast.type
  end
  ast:assertraisef(type, 'unknown type for AST node while trying to get the C type')
  local ctype = cdefs.primitive_ctypes[type]
  ast:assertraisef(ctype, 'ctype for "%s" is unknown', tostring(type))
  if ctype.builtin then
    self:add_builtin(ctype.builtin)
  end
  return ctype.name
end

return CContext
