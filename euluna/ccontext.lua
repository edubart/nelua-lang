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
  self.uniquecounters = {}
end

function CContext:declname(node)
  local attr = node.attr
  if attr.declname then
    return attr.declname
  end
  local declname = attr.codename
  if not attr.nodecl and not attr.cimport then
    if self.scope:is_main() and traits.is_astnode(node) then
      local modname = self.attr.modname or node.modname
      if modname ~= '' then
        declname = modname .. '_' .. declname
      end
    end
    declname = cdefs.quotename(declname)
  end
  if attr.shadowcount then
    declname = declname .. attr.shadowcount
  end
  attr.declname = declname
  return declname
end

function CContext:genuniquename(kind)
  local count = self.uniquecounters[kind]
  if not count then
    count = 0
  end
  count = count + 1
  self.uniquecounters[kind] = count
  return string.format('__%s%d', kind, count)
end

function CContext:typename(type)
  assert(traits.is_type(type))
  local codename = type.codename
  if type:is_arraytable() then
    local subctype = self:ctype(type.subtype)
    self:ensure_runtime(codename, 'euluna_arrtab', {
      tyname = codename,
      ctype = subctype,
      type = type
    })
    self:use_gc()
  elseif type:is_array() then
    local subctype = self:ctype(type.subtype)
    if not type.nodecl then
      self:ensure_runtime(codename, 'euluna_array', {
        tyname = codename,
        length = type.length,
        subctype = subctype,
        type = type
      })
    end
  elseif type:is_record() then
    local fields = tabler.imap(type.fields, function(f)
      return {name = f.name, ctype = self:ctype(f.type)}
    end)
    if not type.nodecl then
      self:ensure_runtime(codename, 'euluna_record', {
        tyname = codename,
        fields = fields,
        type = type
      })
    end
  elseif type:is_enum() then
    local subctype = self:ctype(type.subtype)
    if not type.nodecl then
      self:ensure_runtime(codename, 'euluna_enum', {
        tyname = codename,
        subctype = subctype,
        fields = type.fields,
        type = type
      })
    end
  elseif type:is_pointer() then
    local subctype = self:ctype(type.subtype)
    if not type.nodecl then
      self:ensure_runtime(codename, 'euluna_pointer', {
        tyname = codename,
        subctype = subctype,
        type = type
      })
    end
  elseif type:is_string() then
    self.has_string = true
  elseif type:is_function() then
    assert(false, 'ctype for functions not implemented yet')
  elseif type:is_any() then
    self.has_any = true
    self.has_string = true
    self.has_type = true
  else
    errorer.assertf(cdefs.primitive_ctypes[type], 'ctype for "%s" is unknown', tostring(type))
  end
  return codename
end

function CContext:ctype(type)
  local codename = self:typename(type)
  local ctype = cdefs.primitive_ctypes[type]
  if ctype then
    return ctype
  end
  return codename
end

function CContext:runctype(type)
  local typename = self:typename(type)
  self.has_type = true
  return typename .. '_type'
end

function CContext:funcretctype(functype)
  if functype:has_multiple_returns() then
    return functype.codename .. '_ret'
  else
    return self:ctype(functype:get_return_type(1))
  end
end

function CContext:use_gc()
  self:ensure_runtime('euluna_gc')
  self.has_gc = true
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
