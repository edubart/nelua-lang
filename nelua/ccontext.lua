local VisitorContext = require 'nelua.visitorcontext'
local class = require 'nelua.utils.class'
local cdefs = require 'nelua.cdefs'
local cbuiltins = require 'nelua.cbuiltins'
local traits = require 'nelua.utils.traits'
local CEmitter = require 'nelua.cemitter'
local errorer = require 'nelua.utils.errorer'
local fs = require 'nelua.utils.fs'
local tabler = require 'nelua.utils.tabler'
local config = require 'nelua.configer'.get()
local luatype = type

local CContext = class(VisitorContext)

CContext._ccontext = true

function CContext:_init(visitors, typevisitors, rootscope)
  if not self.context then
    VisitorContext._init(self, visitors, rootscope)
  end
  visitors.default_visitor = false
  self.visitors = visitors
  self.typevisitors = typevisitors
  self.declarations = {}
  self.definitions = {}
  self.cfiles = {}
  self.linklibs = {}
  self.directives = {}
  self.compileopts = {
    cflags = {},
    ldflags = {},
    linklibs = {},
    cfiles = {},
    incdirs = {},
  }
  self.stringliterals = {}
  self.quotedliterals = {}
  self.uniquecounters = {}
  self.printcache = {}
  self.typenames = {}
  self.usedbuiltins = {}
  self.builtins = cbuiltins.builtins
end

function CContext:declname(attr)
  if attr.declname then
    return attr.declname
  end
  local declname = attr.codename
  assert(attr._attr and attr.codename)
  if not attr.nodecl and not attr.cimport then
    declname = cdefs.quotename(declname)
    if attr.shadows and not attr.staticstorage then
      declname = self:genuniquename(declname, '%s_%d')
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
    fmt = '_%s%d'
  end
  return string.format(fmt, kind, count)
end

function CContext:typecodename(type)
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
          local ctype = traits.is_string(type.ctypedef) and type.ctypedef or type.codename
          local code = 'typedef '..kind..' '..ctype..' '..type.codename..';\n'
          table.insert(self.declarations, code)
        end
      end
    end
  end
  return type.codename
end

function CContext:typename(type)
  local typenames = self.typenames
  local typename = typenames[type]
  if typename then
    return typename
  end
  typename = cdefs.primitive_typenames[type.codename]
  if luatype(typename) == 'table' then -- has include
    self:ensure_include(typename[2])
    typename = typename[1]
  elseif not typename then
    typename = self:typecodename(type)
  end
  typenames[type] = typename
  return typename
end

function CContext:ensure_type(type)
  -- this will emit declarations/include of the type as needed
  self:typename(type)
end

function CContext:funcrettypename(functype)
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
  local incname = name
  local searchinc = false
  if not name:match('^["<].*[>"]$') then
    incname = '<'..name..'>'
    searchinc = true
  end
  local directives = self.directives
  if directives[incname] then return end
  directives[incname] = true
  directives[#directives+1] = '#include '..incname..'\n'

  if searchinc and not fs.isabs(name) then
    -- make sure to add the include directory for that file
    local dirpath = self:get_visiting_directory()
    if dirpath then
      local filepath = fs.join(dirpath, name)
      local incdirs = self.compileopts.incdirs
      if fs.isfile(filepath) and not tabler.ifind(incdirs, dirpath) then
        table.insert(incdirs, dirpath)
      end
    end
  end
end

function CContext:ensure_cfile(name)
  -- search the file relative to the current source file
  if not fs.isabs(name) then
    local dirpath = self:get_visiting_directory()
    if dirpath then
      local filepath = fs.join(dirpath, name)
      if fs.isfile(filepath) then
        name = filepath
      end
    end
  end

  local cfiles = self.cfiles
  if cfiles[name] then return end

  cfiles[name] = true
  cfiles[#cfiles+1] = name
  table.insert(self.compileopts.cfiles, name)
end

function CContext:ensure_linklib(name)
  local linklibs = self.linklibs
  if linklibs[name] then return end

  linklibs[name] = true
  linklibs[#linklibs+1] = name
  table.insert(self.compileopts.linklibs, name)
end

function CContext:ensure_includes(...)
  for i=1,select('#',...) do
    self:ensure_include((select(i,...)))
  end
end

function CContext:ensure_type(type)
  self:typename(type)
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

function CContext:ensure_builtin(name, ...)
  if select('#',...) == 0 and self.usedbuiltins[name] then
    return name
  end
  local func = self.builtins[name]
  errorer.assertf(func, 'builtin "%s" not defined', name)
  if func then
    local newname = func(self, ...)
    if newname then
      name = newname
    end
  end
  self.usedbuiltins[name] = true
  return name
end

function CContext:ensure_builtins(...)
  for i=1,select('#',...) do
    self:ensure_builtin((select(i, ...)))
  end
end

function CContext:define_builtin(name, code, section)
  if code:sub(-1) ~= '\n' then
    code = code..'\n'
  end
  if not section or section == 'declarations' then
    self:add_declaration(code)
  elseif section == 'definitions' then
    self:add_definition(code)
  elseif section == 'directives' then
    self:add_directive(code)
  end
  self.usedbuiltins[name] = true
end

function CContext:define_function_builtin(name, qualifier, ret, args, body)
  if self.usedbuiltins[name] then return end
  if traits.is_type(ret) then
    ret = self:typename(ret)
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
  if not self.pragmas.nostatic then
    if qualifier == '' then
      qualifier = 'static'
    else
      qualifier = 'static ' .. qualifier
    end
  end
  if qualifier ~= '' then
    qualifier = qualifier..' '
  end
  self:add_declaration(qualifier..ret..' '..name..args..';\n')
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
