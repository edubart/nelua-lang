local builtins = {}
local fs = require 'nelua.utils.fs'
local config = require 'nelua.configer'.get()
local preprocessor = require 'nelua.preprocessor'
local typedefs = require 'nelua.typedefs'
local types = require 'nelua.types'
local Attr = require 'nelua.attr'
local primtypes = typedefs.primtypes
local pegger = require 'nelua.utils.pegger'
local aster = require 'nelua.aster'

function builtins.require(context, node, argnodes)
  local attr = node.attr
  if attr.alreadyrequired or attr.runtime_require then
    -- already tried to load
    return
  end

  local justloaded = false
  if not attr.loadedast then
    local canloadatruntime = context.generator == 'lua'
    context:traverse_nodes(argnodes)
    local argnode = argnodes[1]
    if not (argnode and
            argnode.attr.type and argnode.attr.type.is_string and
            argnode.attr.comptime) or not context.scope.is_topscope then
      -- not a compile time require
      if canloadatruntime then
        attr.runtime_require = true
        return
      else
        node:raisef('runtime require unsupported, use require with a compile time string in top scope')
      end
    end

    -- load it and parse
    local unitpath = argnode.attr.value
    local reldir = argnode.src.name and fs.dirname(argnode.src.name) or nil
    local filepath, err = fs.findmodulefile(unitpath, config.path, reldir)
    if not filepath then
      if canloadatruntime then
        -- maybe it would succeed at runtime
        attr.runtime_require = true
        return
      else
        node:raisef("in require: module '%s' not found:\n%s", unitpath, err)
      end
    end

    -- nelua internal libs have unit name of just 'nelua'
    local unitname = pegger.filename_to_unitname(unitpath)
    if context.pragmas.unitname == unitname then
      node:raisef("in require: module '%s' cannot require itself", unitpath)
    end

    attr.requirename = unitpath
    if filepath:find(config.lib_path, 1, true) then
      unitname = 'nelua'
    end
    attr.unitname = unitname

    local reqnode = context.requires[filepath]
    if reqnode and reqnode ~= node then
      -- already required
      attr.alreadyrequired = true
      return
    end

    local input = fs.ereadfile(filepath)
    local ast = aster.parse(input, filepath)
    attr.loadedast = ast

    justloaded = true

    context.requires[filepath] = node
  end

  -- analyze it
  local ast = attr.loadedast
  context:push_state{inrequire = true}
  context:push_scope(context.rootscope)
  context:push_pragmas()
  context.pragmas.unitname = attr.unitname
  if justloaded then
    preprocessor.preprocess(context, ast)
  end
  context:traverse_node(ast)
  context:pop_scope()
  context:pop_state()
  context:pop_pragmas()
end

function builtins.assert(context, node, argnodes)
  local attr = node.attr
  local statement = attr.checkbuiltin or context:get_parent_node().tag == 'Block'
  if statement then
    local argnode = argnodes[1]
    if argnode then
      argnode.desiredtype = primtypes.boolean
    end
  end
  context:traverse_nodes(argnodes)
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
  if context.pragmas.nochecks then
    attr.omitcall = true
  end
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
    if objtype.is_record then
      local metafields = objtype.metafields
      if metafields.__tostring then
        argtype = primtypes.string
        argnodes[i] = aster.CallMethod{'__tostring', {}, argnodes[i]}
      end
    end
    argattrs[i] = {name='a'..i, type=argtype}
  end
  local type = types.FunctionType(argattrs, {}, node)
  type.sideeffect = true
  return type
end

return builtins
