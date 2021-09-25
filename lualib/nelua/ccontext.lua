--[[
C Context.

The C context is used to traverse an AST while generating C code,
it works similar to the analyzer context, visiting a specialized function for each node tag.

It contains many functions to assist generating C code.
]]

local VisitorContext = require 'nelua.visitorcontext'
local class = require 'nelua.utils.class'
local cdefs = require 'nelua.cdefs'
local cbuiltins = require 'nelua.cbuiltins'
local traits = require 'nelua.utils.traits'
local CEmitter = require 'nelua.cemitter'
local stringer = require 'nelua.utils.stringer'
local fs = require 'nelua.utils.fs'
local tabler = require 'nelua.utils.tabler'
local pegger = require 'nelua.utils.pegger'
local config = require 'nelua.configer'.get()
local luatype = type

-- The C context class.
local CContext = class(VisitorContext)

-- Used to quickly check whether a table is a C context.
CContext._ccontext = true

--[[
Initializes a C context context using `visitors` table to visit AST nodes,
and `typevisitors` table to visit types classes.
]]
function CContext:_init(visitors, typevisitors)
  assert(self.context, 'initialization from a promotion expected')
  self.visitors = visitors
  self.typevisitors = typevisitors
  self.latedecls = {}
  self.typedecldepth = 0
  self.declarations = {}
  self.ctypedefs = {}
  self.definitions = {}
  self.cfiles = {}
  self.linklibs = {}
  self.directives = {}
  self.compileopts = {
    cflags = {},
    ldflags = {},
    linklibs = {},
    linkdirs = {},
    cfiles = {},
    incdirs = {},
  }
  self.stringliterals = {}
  self.quotedliterals = {}
  self.uniquecounters = {}
  self.printcache = {}
  self.usedbuiltins = {}
  self.builtins = cbuiltins
end

function CContext:genuniquename(kind)
  local count = self.uniquecounters[kind] or 0
  count = count + 1
  self.uniquecounters[kind] = count
  return string.format('%s_%d', kind, count)
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
      declname = self:genuniquename(declname)
    end
  end
  attr.declname = declname
  return declname
end

function CContext:funcrettypename(functype)
  return self.typevisitors.FunctionReturnType(self, functype)
end

function CContext:add_directive(code)
  local directives = self.directives
  directives[#directives+1] = code
end

function CContext:add_declaration(code, name)
  local declarations = self.declarations
  if name then
    assert(not declarations[name], name)
    self.declarations[name] = true
  end
  declarations[#declarations+1] = code
end

function CContext:add_definition(code, name)
  local definitions = self.definitions
  if name then
    assert(not definitions[name])
    definitions[name] = true
  end
  definitions[#definitions+1] = code
end

function CContext:is_declared(name)
  return self.declarations[name] == true
end

-- Ensures type `type` is declared and returns its C typedef name.
function CContext:ensure_type(type)
  local codename = type.codename
  local declarations = self.declarations
  local typename = declarations[codename]
  if typename then -- already declared
    return typename
  end
  -- translate codename for primitive types
  typename = cdefs.primitive_typenames[codename]
  if typename then
    if luatype(typename) == 'table' then -- has include
      self:ensure_include(typename[2])
      typename = typename[1]
    end
    declarations[codename] = typename -- mark as declared
    return typename
  end
  self.typedecldepth = self.typedecldepth + 1
  declarations[codename] = codename -- mark as declared
  -- search visitor for any inherited type class
  local typevisitors = self.typevisitors
  local mt, visitor = getmetatable(type)
  repeat
    local mtindex = rawget(mt, '__index')
    if not mtindex then break end
    visitor = typevisitors[mtindex]
    mt = getmetatable(mtindex)
    if not mt then break end
  until visitor
  -- visit the declaration function
  if visitor then
    if config.check_type_shape then
      assert(type:shape())
    end
    local cinclude = type.cinclude
    if cinclude then -- include headers before declaring
      self:ensure_include(cinclude)
    end
    if not type.nodecl then -- only declare when needed
      visitor(self, type)
    elseif type.ctypedef then
      local kind
      if type.is_record then kind = 'struct'
      elseif type.is_union then kind = 'union'
      elseif type.is_enum then kind = 'enum'
      end
      if kind then
        local ctype = luatype(type.ctypedef) == 'string' and type.ctypedef or codename
        local code = 'typedef '..kind..' '..ctype..' '..codename..';\n'
        declarations[#declarations+1] = code
      end
    end
  end
  self.typedecldepth = self.typedecldepth - 1
  if self.typedecldepth == 0 then
    local latedecls = self.latedecls
    while #latedecls > 0 do -- declare struct/union of pointers
      self:ensure_type(table.remove(latedecls))
    end
  end
  return codename
end

--[[
Ensures C header file `filename` is included when compiling.
If the file name is not an absolute path and not between `<>` or `""`,
then looks for files in the current source file directory.
]]
function CContext:ensure_include(name)
  local directives = self.directives
  if directives[name] then return end
  local inccode
  local searchinc = false
  if cdefs.include_hooks[name] then
    inccode = cdefs.include_hooks[name]
  else -- normalize include code
    inccode = name
    if not inccode:find('[#\n]') then
      if not name:match('^".*"$') and not name:match('^<.*>$') then
        inccode = '<'..name..'>'
        searchinc = true
      end
      inccode = '#include '..inccode
    end
    if not inccode:find('\n$') then
      inccode = inccode..'\n'
    end
    if directives[inccode] then return end
  end
  -- add include directive
  directives[inccode] = true
  directives[name] = true
  directives[#directives+1] = inccode
  -- make sure to add the include directory for that file
  if searchinc and not fs.isabspath(name) then
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

-- Ensures a C directory is added to include path when compiling.
function CContext:ensure_cincdir(dirpath)
  local incdirs = self.compileopts.incdirs
  if not tabler.ifind(incdirs, dirpath) then
    table.insert(incdirs, dirpath)
  end
end

-- Ensures a library directory is added to library path when linking.
function CContext:ensure_linkdir(dirpath)
  local linkdirs = self.compileopts.linkdirs
  if not tabler.ifind(linkdirs, dirpath) then
    table.insert(linkdirs, dirpath)
  end
end

-- Ensures function `name` from C math library included.
function CContext:ensure_cmath_func(name, type)
  if type.is_cfloat then
    name = name..'f'
  elseif type.is_clongdouble then
    name = name..'l'
  elseif type.is_float128 then
    name = name..'q'
    self:ensure_linklib('quadmath')
  end
  self:ensure_builtin(name)
  return name
end

--[[
Ensures C source file `filename` is compiled and linked when compiling the application binary.
If the file name is not an absolute path, then looks for files in the current source file directory.
]]
function CContext:ensure_cfile(filename)
  -- search the file relative to the current source file
  if not fs.isabspath(filename) then
    local dirpath = self:get_visiting_directory()
    if dirpath then
      local filepath = fs.join(dirpath, filename)
      if fs.isfile(filepath) then
        filename = filepath
      end
    end
  end
  -- add cfile to compile options
  local cfiles = self.cfiles
  if cfiles[filename] then return end
  cfiles[filename] = true
  cfiles[#cfiles+1] = filename
  table.insert(self.compileopts.cfiles, filename)
end

-- Ensures library `libname` is marked be linked when compiling the application binary.
function CContext:ensure_linklib(libname)
  local linklibs = self.linklibs
  if linklibs[libname] then return end
  linklibs[libname] = true
  linklibs[#linklibs+1] = libname
  table.insert(self.compileopts.linklibs, libname)
end

-- Ensures `defname` is defined in the C preprocessor.
function CContext:ensure_define(defname)
  local directives = self.directives
  if directives[defname] then return end
  directives[defname] = true
  directives[#directives+1] = '#define '..defname..'\n'
end

--[[
Ensures builtin `name` is declared and defined and returns the defined builtin name.
Arguments `...` are forwarded to the function that defines the builtin.
The returned name is the `name` with a suffix depending on the extra arguments.
]]
function CContext:ensure_builtin(name, ...)
  if select('#',...) == 0 and self.usedbuiltins[name] then
    return name
  end
  local func = self.builtins[name]
  assert(func, 'builtin not defined')
  local newname = func(self, ...)
  name = newname or name
  self.usedbuiltins[name] = true
  return name
end

-- Like `ensure_builtin`, but accept many builtins (it's a shortcut).
function CContext:ensure_builtins(...)
  for i=1,select('#',...) do
    self:ensure_builtin((select(i, ...)))
  end
end

-- Defines C builtin macro `name` with source code `code`.
function CContext:define_builtin_macro(name, code)
  assert(not self.usedbuiltins[name])
  self:add_directive(stringer.ensurenewline(code))
  self.usedbuiltins[name] = true
end

-- Defines C builtin declaration `name` with source code `code`.
function CContext:define_builtin_decl(name, code)
  assert(not self.usedbuiltins[name])
  self:add_declaration(stringer.ensurenewline(code))
  self.usedbuiltins[name] = true
end

-- Defines C builtin function `name` with source code `code`.
function CContext:define_function_builtin(name, qualifier, ret, args, body)
  if self.usedbuiltins[name] then return end
  local heademitter, declemitter, defnemitter = CEmitter(self), CEmitter(self), CEmitter(self)
  -- build return part
  if traits.is_type(ret) then
    ret = self:ensure_type(ret)
  end
  heademitter:add(ret, ' ', name)
  -- build arguments part
  if #args > 0 then
    heademitter:add_text('(')
    for i=1,#args do
      if i > 1 then
        heademitter:add_text(', ')
      end
      local arg = args[i]
      local argtype = arg[1] or arg.type
      local argname = arg[2] or arg.name
      heademitter:add(argtype, ' ', argname)
    end
    heademitter:add_text(')')
  else
    heademitter:add_text('(void)')
  end
  -- build qualifier part
  if not self.pragmas.nocstatic then
    declemitter:add_text('static ')
  end
  if qualifier and qualifier ~= '' and
     not (qualifier == 'NELUA_INLINE' and self.pragmas.nocinlines) then
    declemitter:add_builtin(qualifier)
    declemitter:add_text(' ')
  end
  -- build head part
  defnemitter:add(heademitter)
  declemitter:add(heademitter)
  declemitter:add_ln(';')
  -- build body part
  defnemitter:add_text(' ')
  if type(body) == 'table' then
    defnemitter:add(table.unpack(body))
  else
    defnemitter:add(body)
  end
  defnemitter:add_ln()
  -- add function declaration and definition
  self:add_declaration(declemitter:generate())
  self:add_definition(defnemitter:generate())
  self.usedbuiltins[name] = true
end

--[[
Concatenate all generated code chunks into the final generated C source code.
Called when finalizing the code generation.
]]
function CContext:concat_chunks(template)
  return pegger.substitute(template, {
    directives = table.concat(self.directives):sub(1, -2),
    declarations = table.concat(self.declarations):sub(1, -2),
    definitions = table.concat(self.definitions):sub(1, -2)
  })
end

return CContext
