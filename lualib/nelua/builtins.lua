local builtins = {}
local fs = require 'nelua.utils.fs'
local config = require 'nelua.configer'.get()
local preprocessor = require 'nelua.preprocessor'
local typedefs = require 'nelua.typedefs'
local types = require 'nelua.types'
local Attr = require 'nelua.attr'
local Symbol = require 'nelua.symbol'
local primtypes = typedefs.primtypes
local pegger = require 'nelua.utils.pegger'
local stringer = require 'nelua.utils.stringer'
local aster = require 'nelua.aster'

function builtins.require(context, node, argnodes)
  local attr = node.attr
  if attr.alreadyrequired then
    -- already tried to load
    return attr.functype
  end

  local justloaded = false
  if not attr.loadedast then
    context:traverse_nodes(argnodes)
    local argnode = argnodes[1]

    -- load it and parse
    local reqname = argnode.attr.value
    if not reqname then
      node:raisef('runtime require unsupported, use require with a compile time string')
    end
    local reldir = argnode.src.name and fs.dirname(argnode.src.name) or nil
    local libpath = config.path
    if #context.libpaths > 0 then -- try to insert the lib path after the local lib path
      local addpath = ';'..table.concat(context.libpaths, ';')
      local localpath = fs.join('.','?.nelua')..';'..fs.join('.','?','init.nelua')
      libpath = stringer.insertafter(libpath, localpath, addpath) or
                  addpath:sub(2)..';'..libpath
    end
    local filepath, err = fs.findmodule(reqname, libpath, reldir, 'nelua')
    if not filepath then
      if context.generator == 'lua' then
        return
      else
        node:raisef("in require: module '%s' not found:\n%s", reqname, err)
      end
    end

    local origunitname = pegger.filename_to_unitname(reqname..'.nelua')
    if context.pragmas.unitname == origunitname then
      node:raisef("in require: module '%s' cannot require itself", reqname)
    end

    local unitname = origunitname
    -- nelua internal libs have unit name of just 'nelua'
    if filepath:find(config.lib_path, 1, true) then
      unitname = 'nelua'
    end

    attr.requirename = reqname
    attr.unitname = unitname

    local reqnode = context.requires[filepath]
    if reqnode and reqnode ~= node then
      -- already required
      local reqattr = reqnode.attr
      reqattr.multiplerequire = true
      attr.alreadyrequired = true
      attr.functype = reqattr.functype
      attr.funcname = reqattr.funcname
      attr.value = reqattr.value
      return attr.functype
    end

    attr.funcname = context.rootscope:generate_name('nelua_require_'..origunitname, true)

    local input
    input, err = fs.readfile(filepath)
    if not input then
      node:raisef("in require: while loading module '%s': %s", reqname, err)
    end
    local ast = aster.parse(input, filepath)
    attr.loadedast = ast
    ast.attr.filename = filepath

    justloaded = true

    context.requires[filepath] = node
  end

  -- analyze it
  local ast = attr.loadedast
  attr.pragmas = attr.pragmas or {unitname = attr.unitname}
  context:push_scope(context.rootscope)

  local funcscope, funcsym
  repeat
    funcscope = context:push_forked_cleaned_scope(node)
    funcsym = funcscope.funcsym
    if not funcsym then
      if not context.reqscopes[funcscope] then
        context.reqscopes[funcscope] = true
        table.insert(context.reqscopes, funcscope)
      end
      funcsym = Symbol{
        name = attr.funcname,
        codename = attr.funcname,
        scope = context.rootscope,
        reqfunc = true,
      }
      funcscope.funcsym = funcsym
      funcscope.is_require = true
      funcscope.is_function = true
      funcscope.is_resultbreak = true
      funcsym:add_use_by()
    end
    context:push_forked_state{funcscope=funcscope}
    context:push_forked_pragmas(attr.pragmas)
    if justloaded then
      preprocessor.preprocess(context, ast)
      justloaded = false
    end
    context:traverse_node(ast)
    context:pop_pragmas()
    local resolutions_count = funcscope:resolve()
    context:pop_state()
    context:pop_scope()
  until resolutions_count == 0 or #funcscope.rettypes == 0

  context:pop_scope()

  local type = types.FunctionType({{name='modname', type=primtypes.string, comptime=true}}, funcscope.rettypes, node)
  type.sideeffect = true
  attr.functype = type
  attr.value = funcscope.retvalues and funcscope.retvalues[1]
  funcsym.type = type
  return type
end

function builtins.error(context, node, argnodes)
  context:traverse_nodes(argnodes)
  local argtypes = types.argtypes_from_argnodes(argnodes, 2)
  if not argtypes then -- wait last argument type resolution
    return false
  end
  local nargs = #argtypes
  local argattrs
  if nargs == 1 then
    argattrs = {Attr{name='msg', type=primtypes.string}}
  elseif nargs == 0 then
    argattrs = {}
  end
  local type = types.FunctionType(argattrs, {}, node)
  type.sideeffect = true
  type.noreturn = true
  return type
end

function builtins.assert(context, node, argnodes)
  local attr = node.attr
  local statement = attr.checkbuiltin or context:get_visiting_node(1).is_Block
  if statement then
    local firstargnode = argnodes[1]
    if firstargnode then
      context:traverse_node(firstargnode, {desiredtype=primtypes.boolean})
    end
    for i=2,#argnodes do
      context:traverse_node(argnodes[i])
    end
  else
    context:traverse_nodes(argnodes)
  end
  local argtypes = types.argtypes_from_argnodes(argnodes, 2)
  if not argtypes then -- wait last argument type resolution
    return false
  end
  local nargs = #argtypes
  local argattrs, rettypes
  if nargs > 2 then
    node:raisef('expected at most 2 arguments')
  elseif nargs > 0 then
    local condtype
    if statement then
      condtype = primtypes.boolean
    else
      condtype = argtypes[1]
      rettypes = {condtype}
    end
    if nargs == 2 then
      argattrs = {Attr{name='cond', type=condtype}, Attr{name='msg', type=primtypes.string}}
    elseif nargs == 1 then
      argattrs = {Attr{name='cond', type=condtype}}
    end
  end
  argattrs = argattrs or {}
  rettypes = rettypes or {}
  local type = types.FunctionType(argattrs, rettypes, node)
  type.sideeffect = true
  return type
end

function builtins.check(context, node, argnodes)
  local attr = node.attr
  attr.checkbuiltin = true
  return builtins.assert(context, node, argnodes)
end

function builtins.print(context, node, argnodes)
  context:traverse_nodes(argnodes)
  local argtypes = types.argtypes_from_argnodes(argnodes)
  if not argtypes then -- wait last argument type resolution
    return false
  end
  local argattrs = {}
  for i=1,#argtypes do
    local argtype = argtypes[i]
    local objtype = argtype:implicit_deref_type()
    local metafields = objtype.metafields
    local metamethod
    if metafields then
      if metafields.__tostringview then
        metamethod = '__tostringview'
      elseif metafields.__tostring then
        metamethod = '__tostring'
      end
    end
    if metamethod then
      argtype = primtypes.string
      if not argnodes[i] then
        node:raisef('cannot forward multiple returns to print in this context')
      end
      argnodes[i] = aster.CallMethod{metamethod, {}, argnodes[i]}
    end
    argattrs[i] = {name='a'..i, type=argtype}
  end
  local type = types.FunctionType(argattrs, {}, node)
  type.sideeffect = true
  return type
end

return builtins
