local AnalyzerContext = require 'nelua.analyzercontext'
local class = require 'nelua.utils.class'
local cdefs = require 'nelua.cdefs'
local cbuiltins = require 'nelua.cbuiltins'
local traits = require 'nelua.utils.traits'
local CEmitter = require 'nelua.cemitter'
local config = require 'nelua.configer'.get()
local luatype = type

local CContext = class(AnalyzerContext)

function CContext:init(visitors, typevisitors)
  self:set_visitors(visitors)
  self.typevisitors = typevisitors
  self.declarations = {}
  self.definitions = {}
  self.directives = {}
  self.compileopts = {
    cflags = {},
    ldflags = {},
    linklibs = {}
  }
  self.stringliterals = {}
  self.uniquecounters = {}
  self.ctypes = {}
  self.builtins = cbuiltins.builtins
end

function CContext.promote_context(self, visitors, typevisitors)
  setmetatable(self, CContext)
  self:init(visitors, typevisitors)
  return self
end

function CContext:declname(attr)
  assert(attr._attr)
  if attr.declname then
    return attr.declname
  end
  local declname = attr.codename
  assert(attr.codename)
  if not attr.nodecl then
    if not attr.cimport then
      declname = cdefs.quotename(declname)
      if attr.shadows and not attr.staticstorage then
        declname = self:genuniquename(declname, '%s__%d')
      end
    end
  end
  attr.declname = declname
  return declname
end

function CContext:genuniquename(kind, fmt)
  local count = self.uniquecounters[kind] or 0
  count = count + 1
  self.uniquecounters[kind] = count
  if not fmt then
    fmt = '__%s%d'
  end
  return string.format(fmt, kind, count)
end

function CContext:typename(type)
  assert(type._type)
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
    if not self:is_declared(type.codename) then
      self.declarations[type.codename] = true
      if config.check_type_shape then
        assert(type:shape())
      end
      if type.cinclude then -- include headers before declaring
        self:ensure_include(type.cinclude)
      end
      -- only declare when needed
      if not type.nodecl then
        visitor(self, type)
      elseif type.ctypedef then
        local kind
        if type.is_record then kind = 'struct'
        elseif type.is_union then kind = 'union'
        elseif type.is_enum then kind = 'enum'
        end
        if kind then
          local code = 'typedef '..kind..' '..type.codename..' '..type.codename..';\n'
          table.insert(self.declarations, code)
        end
      end
    end
  end
  return type.codename
end

function CContext:ctype(type)
  local ctypes = self.ctypes
  local ctype = ctypes[type]
  if ctype then
    return ctype
  end
  ctype = cdefs.primitive_ctypes[type.codename]
  if luatype(ctype) == 'table' then -- has include
    self:ensure_include(ctype[2])
    ctype = ctype[1]
  elseif not ctype then
    local codename = self:typename(type)
    ctype = codename
  end
  ctypes[type] = ctype
  return ctype
end

function CContext:runctype(type)
  local typename = self:typename(type)
  self:ensure_builtin('nlruntype_', typename)
  return 'nlruntype_' .. typename
end

function CContext:funcretctype(functype)
  return self.typevisitors.FunctionReturnType(self, functype)
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

function CContext:ensure_include(name)
  local directives = self.directives
  if directives[name] then return end
  directives[name] = true
  directives[#directives+1] = '#include '..name..'\n'
end

function CContext:ensure_includes(...)
  for i=1,select('#',...) do
    self:ensure_include((select(i,...)))
  end
end

function CContext:ensure_type(type)
  self:ctype(type)
end

function CContext:ensure_define(name)
  local directives = self.directives
  if directives[name] then return end
  directives[name] = true
  directives[#directives+1] = '#define '..name..'\n'
end

function CContext:add_directive(code)
  table.insert(self.directives, code)
end

function CContext:define_builtin(name, deccode, defcode)
  if deccode then
    if deccode:sub(-1) ~= '\n' then
      deccode = deccode..'\n'
    end
    self:add_declaration(deccode)
  end
  if defcode then --luacov:disable
    if defcode:sub(-1) ~= '\n' then
      defcode = defcode..'\n'
    end
    self:add_definition(defcode)
  end --luacov:enable
  self.usedbuiltins[name] = true
end

function CContext:define_function_builtin(name, qualifier, ret, args, body)
  if self.usedbuiltins[name] then return end
  if traits.is_type(ret) then
    ret = self:ctype(ret)
  end
  if type(args) == 'table' then
    local emitter = CEmitter(self)
    emitter:add_one('(')
    for i=1,#args do
      if i > 1 then
        emitter:add_one(', ')
      end
      local arg = args[i]
      local argtype = arg[1] or arg.type
      local argname = arg[2] or arg.name
      emitter:add(argtype, ' ', argname)
    end
    emitter:add_one(')')
    args = emitter:generate()
  end
  self:add_declaration(qualifier..' '..ret..' '..name..args..';\n')
  self:add_definition(ret..' '..name..args..' '..body..'\n')
  self.usedbuiltins[name] = true
end

function CContext:emitter_join(...)
  local emitter = CEmitter(self)
  emitter:add(...)
  return emitter:generate()
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
