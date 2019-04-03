local TraverseContext = require 'euluna.traversecontext'
local class = require 'euluna.utils.class'
local cdefs = require 'euluna.generators.c.definitions'
local traits = require 'euluna.utils.traits'
local tabler = require 'euluna.utils.tabler'
local errorer = require 'euluna.utils.errorer'

local CContext = class(TraverseContext)

function CContext:_init(visitors)
  TraverseContext._init(self, visitors)
  self.builtin_types = {}
  self.builtins = {}
end

function CContext:add_runtime_builtin(name)
  self.builtins[name] = true
end

function CContext:get_ctype(ast_or_type)
  local type = ast_or_type
  if traits.is_astnode(ast_or_type) then
    type = ast_or_type.type
    ast_or_type:assertraisef(type, 'unknown type for AST node while trying to get the C type')
  end
  local ctype = cdefs.primitive_ctypes[type]
  errorer.assertf(ctype, 'ctype for "%s" is unknown', tostring(type))
  tabler.insertonce(self.builtin_types, type)
  return ctype.name
end

return CContext
