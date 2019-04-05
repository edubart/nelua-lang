local Context = require 'euluna.context'
local class = require 'euluna.utils.class'
local cdefs = require 'euluna.cdefs'
local traits = require 'euluna.utils.traits'
local errorer = require 'euluna.utils.errorer'

local CContext = class(Context)

function CContext:_init(visitors)
  Context._init(self, visitors)
  self.builtintypes = {}
  self.builtins = {}
  self.arraytypes = {}
end

function CContext:add_runtime_builtin(name)
  self.builtins[name] = true
end

function CContext:get_ctype(nodeortype)
  local type = nodeortype
  if traits.is_astnode(nodeortype) then
    type = nodeortype.type
    nodeortype:assertraisef(type, 'unknown type for AST node while trying to get the C type')
  end
  assert(type, 'impossible')
  if type:is_arraytable() then
    local subtype = type.subtypes[1]
    local csubtype = self:get_ctype(subtype)
    self.arraytypes[subtype.name] = csubtype
    self.has_gc = true
    self.has_arrtab = true
    return string.format('euluna_arrtab_%s_t', subtype.name)
  end
  local ctype = cdefs.primitive_ctypes[type]
  errorer.assertf(ctype, 'ctype for "%s" is unknown', tostring(type))
  self.builtintypes[type] = true
  return ctype.name
end

return CContext
