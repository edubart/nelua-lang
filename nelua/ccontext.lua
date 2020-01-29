local Context = require 'nelua.analyzercontext'
local class = require 'nelua.utils.class'
local cdefs = require 'nelua.cdefs'
local traits = require 'nelua.utils.traits'
local pegger = require 'nelua.utils.pegger'
local fs = require 'nelua.utils.fs'
local cbuiltins = require 'nelua.cbuiltins'

local CContext = class(Context)

function CContext:init(visitors, typevisitors)
  self:set_visitors(visitors)
  self.typevisitors = typevisitors
  self.declarations = {}
  self.definitions = {}
  self.compileopts = {
    cflags = {},
    ldflags = {},
    linklibs = {}
  }
  self.uniquecounters = {}
  self.builtins = cbuiltins.builtins
end

function CContext.promote_context(self, visitors, typevisitors)
  setmetatable(self, CContext)
  self:init(visitors, typevisitors)
  return self
end

function CContext:declname(node)
  local attr = node.attr
  if node._symbol then
    attr = node
  end
  if attr.declname then
    return attr.declname
  end
  local declname = attr.codename
  if not attr.nodecl then
    if not attr.cimport and not attr.metavar then
      if attr.staticstorage then
        local modname = attr.modname or node.modname
        if modname then
          declname = string.format('%s_%s', modname, declname)
        end
      end
      declname = cdefs.quotename(declname)
    end
    if attr.shadows or
      (attr.type:is_function() and not attr.staticstorage) then
      declname = self:genuniquename(declname, '%s__%d')
    end
  end
  attr.declname = declname
  return declname
end

function CContext:genuniquename(kind, fmt)
  local count = self.uniquecounters[kind]
  if not count then
    count = 0
  end
  count = count + 1
  self.uniquecounters[kind] = count
  if not fmt then
    fmt = '__%s%d'
  end
  return string.format(fmt, kind, count)
end

function CContext:typename(type)
  assert(traits.is_type(type))
  local visitor

  -- search visitor for any inherited type class
  local mt = getmetatable(type)
  repeat
    local mtindex = rawget(mt, '__index')
    if not mtindex then break end
    visitor = self.typevisitors[mtindex]
    mt = getmetatable(mtindex)
    if not mt then break end
  until visitor

  if visitor then
    visitor(self, type)
  end
  return type.codename
end

function CContext:ctype(type)
  local codename = self:typename(type)
  local ctype = cdefs.primitive_ctypes[type.codename]
  if ctype then
    return ctype
  end
  return codename
end

function CContext:runctype(type)
  local typename = self:typename(type)
  self:ensure_runtime_builtin('nelua_runtype_', typename)
  return 'nelua_runtype_' .. typename
end

function CContext:funcretctype(functype)
  if functype:has_enclosed_return() then
    return functype.codename .. '_ret'
  else
    return self:ctype(functype:get_return_type(1))
  end
end

function CContext:use_gc()
  self:ensure_runtime('nelua_gc')
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

function CContext:is_declared(name)
  return self.declarations[name] == true
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
