--[[
Preprocessor context.

The preprocess context is used to preprocess an AST node while traversing its nodes,
it visits a specialized function for each node tag.

It contains utilities to inject nodes and names into the AST.
]]

local traits = require 'nelua.utils.traits'
local class = require 'nelua.utils.class'
local memoize = require 'nelua.utils.memoize'
local except = require 'nelua.utils.except'
local errorer = require 'nelua.utils.errorer'
local stringer = require 'nelua.utils.stringer'
local fs = require 'nelua.utils.fs'
local types = require 'nelua.types'
local aster = require 'nelua.aster'
local typedefs = require 'nelua.typedefs'

-- The preprocess context class.
local PPContext = class()

-- Used to quickly check whether a table is an analyzer context.
PPContext._ppcontext = true

--[[
Creates environment table to be used inside a preprocessor context.
Any global variable assignment while preprocessing will be set in this table.
]]
local function make_ppenv(ppcontext)
  local context = ppcontext.context
  local pp_variables = typedefs.pp_variables
  local ppenv_mt = {}
  local genv = _G
  -- Function called when indexing a global variable from preprocessing environment.
  function ppenv_mt.__index(_, key)
    -- return value from the analyzer environment
    local v = genv[key]
    if v ~= nil then
      return v
    end
    -- return exported variable
    v = pp_variables[key]
    if v ~= nil then
      return v(ppcontext)
    end
    -- return visible symbol in the current scope
    return context.scope.symbols[key]
  end
  -- create the preprocessor environment
  local ppenv = setmetatable({}, ppenv_mt)
  -- export preprocessor constants
  for name, evalf in pairs(typedefs.pp_constants) do
    ppenv[name] = evalf(ppcontext)
  end
  -- export preprocessor functions
  for name, alias in pairs(typedefs.pp_methods) do
    local f = ppcontext[name] or ppcontext[alias]
    ppenv[name] = function(...)
      return f(ppcontext, ...)
    end
  end
  -- export preprocessor directives
  for name in pairs(typedefs.pp_directives) do
    ppenv[name] = function(...)
      ppcontext:inject_statement(aster.Directive{name, table.pack(...)}, true)
    end
  end
  return ppenv
end

--[[
Initializes a preprocessor context using `visitors` table to visit nodes while traversing,
and `context` to analyze injected statements right away.
]]
function PPContext:_init(visitors, context)
  self.visitors = visitors
  self.context = context
  self.registry = {}
  self.statnodestack = {}
  self.statnodes = nil -- will be set when processing
  self.codes = {}
  self.env = make_ppenv(self)
end

function PPContext:register_code(chunkname, ppcode)
  self.codes[chunkname] = ppcode
end

-- Traverses the node `node`, arguments `...` are forwarded to its visitor.
function PPContext:traverse_node(node, ...)
  return self.visitors[node.tag](self, node, ...)
end

-- Traverses list of nodes `nodes`.
function PPContext:traverse_nodes(nodes, emitter)
  for i=1,#nodes do
    self:traverse_node(nodes[i], emitter, nodes, i)
  end
end

-- Pushes statements `statnodes` to be processed, effectively overriding current statements.
function PPContext:push_statnodes(statnodes)
  local statnodestack = self.statnodestack
  statnodestack[#statnodestack+1] = self.statnodes
  self.statnodes = statnodes
  return statnodes
end

-- Pops the current statements being processed, effectively restoring previous statements.
function PPContext:pop_statnodes()
  local statnodestack = self.statnodestack
  local index = #statnodestack
  self.statnodes = statnodestack[index]
  statnodestack[index] = nil
end

--[[
Gets registry index for value `what` from the registry table.
If the value is not registered yet then it will be registered on the first call.
]]
function PPContext:get_registry_index(what)
  local registry = self.registry
  local regindex = registry[what]
  if not regindex then -- not in registry yet
    regindex = #registry+1 -- generate a new registry key
    registry[regindex] = what
    registry[what] = regindex
  end
  return regindex
end

--[[
Injects string `name` at `dest[destpos]`.
The node `orignode` is used as reference for source location.
]]
function PPContext.inject_name(_, name, dest, destpos, orignode)
  local ty = type(name)
  if ty ~= 'string' then
    orignode:raisef('cannot convert preprocess value of lua type "%s" to a name', ty)
  end
  dest[destpos] = name
end

--[[
Converts value `val` to an AST node (if not one yet), and injects at `dest[destpos]`,
possibly unpacking many values in case of varargs.
The node `orignode` is used as reference for source location.
]]
function PPContext.inject_value(self, value, dest, destpos, orignode)
  local valueluatype = type(value)
  if valueluatype == 'table' and value._astunpack then -- multiple values (unpack varargs)
    while #dest >= destpos do -- clean dest positions before injecting
      dest[#dest] = nil
    end
    for i=1,#value do -- unpack all values
      dest[destpos+i-1] = aster.value(value[i], orignode)
    end
  else -- a single value
    if valueluatype == 'function' and dest.is_Call then
      -- parse arguments to compile-time values where possible
      local argnodes = dest[1]
      self.context:traverse_nodes(argnodes)
      local args = {}
      for i=1,#argnodes do
        args[i] = argnodes[i]:get_simplified_value()
      end
      -- evaluate replacement macro
      local ret = value(table.unpack(args))
      if ret == nil then -- no returns, probably a statement replacement
        local noop = aster.DoExpr{aster.Block{aster.Return{aster.Nil{}}}, pattr={noop=true}}
        dest:transform(noop)
      else -- expression replacement
        dest:transform(aster.value(ret, orignode))
      end
    else
      dest[destpos] = aster.value(value, orignode)
    end
  end
end

--[[
Injects statement determined by `node` into the current statements being processed.
The `node` be automatically cloned (deep copied), unless `noclone` is set true.
]]
function PPContext:inject_statement(node, noclone)
  if not noclone then
    node = node:clone()
  end
  local statnodes = self.statnodes
  if statnodes.addindex then -- we must inject at a specific location
    local addindex = statnodes.addindex
    statnodes.addindex = addindex + 1
    table.insert(self.statnodes, addindex, node)
  else -- just append
    self.statnodes[#statnodes+1] = node
  end
  -- analyze the node right away, because we want to have its type information when processing
  self.context:traverse_node(node)
end

--[[
Creates a generic evaluated by function `func` returning its generic type.
Every time the generic is type instantiated,
`func` is called with the instantiation arguments,
and returned value by `func` is used as the final type.
]]
function PPContext:generic(func)
  local type = types.GenericType(func)
  type.node = self.context:get_visiting_node()
  return type
end

--[[
Creates concept evaluated by function `func` returning its concept type.
Every time a type tries to match the concept, `func` is called.
A concept only matches if `func` returns `true` or a type.
In case the match fails `func` can return a `nil` followed by an optional error message.
]]
function PPContext:concept(func, desiredfunc)
  local type = types.ConceptType(func, desiredfunc)
  type.node = self.context:get_visiting_node()
  return type
end

--[[
Wraps a function to into a hygienized function.
A hygienized function can see only symbols and pragmas that were
available at the time `hygienize` is called.
See also [higienic macros](https://en.wikipedia.org/wiki/Hygienic_macro).
]]
function PPContext:hygienize(func)
  local context = self.context
  local scope = context.scope
  local funcscope = context.state.funcscope
  local checkpoint = scope:make_checkpoint()
  local statnodes = self.statnodes
  local addindex = #statnodes+1
  local pragmas = context.pragmas
  return function(...)
    -- restore saved state
    statnodes.addindex = addindex
    self:push_statnodes(statnodes)
    scope:push_checkpoint(checkpoint)
    local oldscope = context.scope
    context:push_scope(scope)
    context:push_forked_state{funcscope=funcscope}
    context:push_pragmas(pragmas)
    -- evaluate func
    local rets = table.pack(func(...))
    -- restore current state
    context:pop_pragmas()
    context:pop_state()
    context:pop_scope()
    scope:pop_checkpoint()
    self:pop_statnodes()
    if addindex ~= statnodes.addindex then -- new statement nodes were added
      -- must delay resolution to fully parse the new added nodes later
      oldscope:find_shared_up_scope(scope):delay_resolution()
      addindex = statnodes.addindex
    end
    statnodes.addindex = nil
    return table.unpack(rets)
  end
end

--[[
Like `generic` but `func` is memoized and hygienized.
Effectively the same as `generic(memoize(hygienize(func)))`.
]]
function PPContext:generalize(func)
  return self:generic(memoize(self:hygienize(func)))
end

--[[
Wraps function `func` into a "do expression".
Useful to create arbitrary substitution of expressions.
]]
function PPContext:expr_macro(func)
  return function(...)
    local args = table.pack(...)
    return aster.DoExpr{aster.Block{
      preprocess = function(blocknode)
        self:push_statnodes(blocknode)
        func(table.unpack(args))
        self:pop_statnodes()
      end
    }}
  end
end

--[[
Calls `func` after first analyze phase is completed.
Useful when needing to execute some code after the AST has been fully traversed.
]]
function PPContext:after_analyze(func)
  if not traits.is_function(func) then
    self:raisef("invalid arguments for preprocess function")
  end
  table.insert(self.context.afteranalyzes, {f=func, node=self.context:get_visiting_node()})
end

--[[
Calls `func` after type inference phase is completed.
Useful when needing to execute some code after the AST has been fully traversed,
and all symbol types are fully resolved.
]]
function PPContext:after_inference(func)
  if not traits.is_function(func) then
    self:raisef("invalid arguments for preprocess function")
  end
  local context = self.context
  local oldscope = context.scope
  local function fproxy()
    context:push_scope(oldscope)
    func()
    context:pop_scope()
  end
  table.insert(context.afterinfers, fproxy)
end

--[[
Raises a compile-time error using optional formatted message `msg`.
The error message will have a pretty traceback of the error location.
]]
function PPContext:static_error(msg, ...)
  if not msg then
    msg = 'static error!'
  end
  self:raisef(msg, ...)
end

--[[
If `cond` is falsy, then raises a compile-time error using optional formatted message `msg`,
otherwise returns `cond`.
The error message will have a pretty traceback of the error location.
]]
function PPContext:static_assert(cond, msg, ...)
  if not cond then
    if not msg then
      msg = 'static assertion failed!'
    end
    self:raisef(msg, ...)
  end
  return cond
end

--[[
Raises a compile-time error using formatted message `msg`.
The error message will have a pretty traceback of the error location.
]]
function PPContext:raisef(msg, ...)
  msg = stringer.pformat(msg, ...)
  local info = debug.getinfo(3)
  local lineno = info.currentline
  local code = self.codes[info.source]
  local src = {content=code, name='preprocessor'}
  msg = errorer.get_pretty_source_line_errmsg(src, lineno, msg, 'error')
  except.raise(msg, 2)
end

--[[
This is just like Lua's require but it will use the preprocessor
context environment to load the module, so all preprocessor
methods are available in the required filed.
]]
function PPContext:require(reqname)
  local modname = reqname
  local reqpath = fs.reqrelpath(reqname, 'lua')
  if reqpath then
    local scriptname = fs.scriptname(3)
    if not scriptname then
      error("module '"..reqname.."' not found:\n\tfailed to retrieve current script directory")
    end
    reqpath = fs.abspath(reqpath, fs.dirname(scriptname))
    modname = reqpath
  end
  local mod = package.loaded[modname] -- lookup for a loaded module
  if mod then return mod end -- module already loaded? return it
  local loader, loaderdata
  local loaderrs = {}
  local found = false
  if reqpath then
    local contents, err = fs.readfile(reqpath)
    if contents then
      loader, err = load(contents, '@'..reqpath)
    end
    if err then
      loaderrs[1] = err
    elseif type(loader) == 'function' then -- module found
      loaderdata = reqpath
      found = true
    end
  else
    for _,searcher in ipairs(package.searchers) do
      loader, loaderdata = searcher(modname)
      local ty = type(loader)
      if ty == 'function' then -- module found
        found = true
        break
      elseif ty == 'string' then -- append search error
        loaderrs[#loaderrs+1] = loader
      end
    end
  end
  if not found then -- module not found
    error("module '"..reqname.."' not found:\n\t"..table.concat(loaderrs, '\n\t'), 2)
  end
  -- check if module was already loaded by full path
  local modpath = type(loaderdata) == 'string' and fs.abspath(loaderdata)
  mod = package.loaded[modpath]
  if mod then -- already loaded under a different name
    package.loaded[modname] = mod
    return mod
  end
  -- load the module
  debug.setupvalue(loader, 1, self.env) -- patch _ENV
  mod = loader(modname, loaderdata) -- load the module
  if mod == nil then mod = true end -- module set no value? use true as result
  package.loaded[modname] = mod -- cache module by name
  if modpath then package.loaded[modpath] = mod end -- cache module by path
  return mod, loaderdata
end

return PPContext
