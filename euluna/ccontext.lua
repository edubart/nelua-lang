local Context = require 'euluna.context'
local class = require 'euluna.utils.class'
local cdefs = require 'euluna.cdefs'
local traits = require 'euluna.utils.traits'
local errorer = require 'euluna.utils.errorer'

local CContext = class(Context)

function CContext:_init(visitors)
  Context._init(self, visitors)
  self.arrtabtypes = {}
  self.recordtypes = {}
  self.primtypes = {}
end

function CContext:get_ctype(nodeortype)
  local type = nodeortype
  if traits.is_astnode(nodeortype) then
    type = nodeortype.type
    nodeortype:assertraisef(type, 'unknown type for AST node while trying to get the C type')
  end
  assert(type, 'impossible')
  if type:is_arraytable() then
    self.arrtabtypes[type.codename] = type.subtypes[1].codename
    self.has_gc = true
    self.has_arrtab = true
  --elseif type:is_record() then
    --self.recordtypes[type.codename] = type
  elseif type:is_string() then
    self.has_string = true
  elseif type:is_any() then
    self.has_any = true
    self.has_type = true
  elseif type:is_nil() then
    self.has_nil = true
  else
    local ctype = cdefs.primitive_ctypes[type]
    self.primtypes[type.codename] = ctype
    errorer.assertf(ctype, 'ctype for "%s" is unknown', tostring(type))
  end
  return type.codename
end

function CContext:get_typectype(nodeortype)
  local ctype = self:get_ctype(nodeortype)
  self.has_type = true
  return ctype .. '_type'
end

return CContext
