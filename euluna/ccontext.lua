local Context = require 'euluna.context'
local class = require 'euluna.utils.class'
local cdefs = require 'euluna.cdefs'
local traits = require 'euluna.utils.traits'
local tabler = require 'euluna.utils.tabler'
local errorer = require 'euluna.utils.errorer'
local pegger = require 'euluna.utils.pegger'
local fs = require 'euluna.utils.fs'

local CContext = class(Context)

function CContext:_init(visitors)
  Context._init(self, visitors)
  self.declarations = {}
  self.definitions = {}
  self.compileopts = {
    cflags = {},
    ldflags = {},
    linklibs = {}
  }
end

function CContext:ensure_type(nodeortype)
  local type = nodeortype
  if traits.is_astnode(nodeortype) then
    type = nodeortype.attr.type
    nodeortype:assertraisef(type, 'unknown type for AST node while trying to get the C type')
  end
  if type:is_type() then
    type = nodeortype.attr.holdedtype
  end
  assert(type)
  local codename = type.codename
  if type:is_arraytable() then
    local subctype = self:get_ctype(type.subtype)
    self:ensure_runtime(codename, 'euluna_arrtab', {
      tyname = codename,
      ctype = subctype
    })
    self:use_gc()
  elseif type:is_array() then
    local subctype = self:get_ctype(type.subtype)
    self:ensure_runtime(codename, 'euluna_array', {
      tyname = codename,
      length = type.length,
      subctype = subctype
    })
  elseif type:is_record() then
    local fields = tabler.imap(type.fields, function(f)
      return {name = f.name, ctype = self:get_ctype(f.type)}
    end)
    self:ensure_runtime(codename, 'euluna_record', {
      tyname = codename,
      fields = fields
    })
  elseif type:is_enum() then
    local subctype = self:get_ctype(type.subtype)
    self:ensure_runtime(codename, 'euluna_enum', {
      tyname = codename,
      subctype = subctype,
      fields = type.fields
    })
  elseif type:is_pointer() then
    if not type:is_generic_pointer() then
      local subctype = self:get_ctype(type.subtype)
      self:ensure_runtime(codename, 'euluna_pointer', {
        tyname = codename,
        subctype = subctype
      })
    end
  elseif type:is_string() then
    self.has_string = true
  elseif type:is_any() then
    self.has_any = true
    self.has_type = true
  elseif type:is_nil() then
    self.has_nil = true
  else
    errorer.assertf(cdefs.primitive_ctypes[type], 'ctype for "%s" is unknown', tostring(type))
  end
  return codename, type
end

function CContext:get_typename(nodeortype)
  local codename = self:ensure_type(nodeortype)
  return codename
end

function CContext:get_ctype(nodeortype)
  local codename, type = self:ensure_type(nodeortype)
  local ctype = cdefs.primitive_ctypes[type]
  if ctype then
    return ctype
  end
  return codename
end

function CContext:get_declname(node)
  if node.attr.declname then
    return node.attr.declname
  end
  local declname = node.attr.codename
  if not node.attr.nodecl and not node.attr.cimport then
    if self.scope:is_main() then
      declname = node.modname .. '_' .. declname
    end
    declname = cdefs.quotename(declname)
  end
  node.attr.declname = declname
  return declname
end

function CContext:use_gc()
  self:ensure_runtime('euluna_gc')
  self.has_gc = true
end

function CContext:get_typectype(nodeortype)
  local typename = self:get_typename(nodeortype)
  self.has_type = true
  return typename .. '_type'
end

local function late_template_render(context, filename, params)
  params = params or {}
  params.context = context
  local file = fs.join(context.runtime_path, filename)
  return function()
    local content = fs.tryreadfile(file)
    return pegger.render_template(content, params)
  end
end

function CContext:ensure_runtime(name, template, params)
  if self.definitions[name] then return end
  if not template then
    template = name
  end
  local deccode = late_template_render(self, template .. '.h', params)
  local defcode = late_template_render(self, template .. '.c', params)
  self:add_declaration(deccode, name)
  self:add_definition(defcode, name)
end

function CContext:add_declaration(code, name)
  if name then
    assert(not self.declarations[name])
    self.declarations[name] = true
  end
  table.insert(self.declarations, code)
end

function CContext:add_definition(code, name)
  if name then
    assert(not self.definitions[name])
    self.definitions[name] = true
  end
  table.insert(self.definitions, code)
end

function CContext:add_include(name)
  if self.declarations[name] then return end
  self:add_declaration(string.format('#include %s\n', name), name)
end

local function eval_late_templates(templates)
  for i,v in ipairs(templates) do
    if type(v) == 'function' then
      templates[i] = v()
    end
  end
end

function CContext:evaluate_templates()
  eval_late_templates(self.declarations)
  eval_late_templates(self.definitions)
end

return CContext
