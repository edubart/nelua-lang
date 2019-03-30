local TraverseContext = require 'euluna.traversecontext'
local class = require 'euluna.utils.class'
local cdefs = require 'euluna.generators.c.definitions'

local CContext = class(TraverseContext)

function CContext:_init(visitors)
  TraverseContext._init(self, visitors)
  self.includes = {}
end

function CContext:add_include(name)
  local includes = self.includes
  if includes[name] then return end
  includes[name] = true
  self.includes_coder:add_ln(string.format('#include %s', name))
end

function CContext.get_ctype(_, ast)
  local type
  if ast.tag == 'Type' then
    type = ast.holding_type
  else
    type = ast.type
  end
  ast:assertraisef(type, 'unknown type for AST node while trying to get the C type')
  local ctype = cdefs.primitive_ctypes[type]
  ast:assertraisef(ctype, 'ctype for "%s" is unknown', tostring(type))
  return ctype.name
end

return CContext
