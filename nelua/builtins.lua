local builtins = {}
local fs = require 'nelua.utils.fs'
local config = require 'nelua.configer'.get()
local preprocessor = require 'nelua.preprocessor'
local pegger = require 'nelua.utils.pegger'

function builtins.require(context, node)
  local attr = node.attr
  if attr.alreadyrequired or attr.runtime_require then
    -- already tried to load
    return
  end

  local justloaded = false
  if not attr.loadedast then
    local argnode = node[1][1]
    if not (argnode and
            argnode.attr.type and argnode.attr.type:is_string() and
            argnode.attr.comptime) then
      -- not a compile time require
      attr.runtime_require = true
      return
    end

    local modulename = argnode.attr.value
    attr.modulename = modulename

    -- load it and parse
    local filepath = fs.findmodulefile(modulename, config.path)
    if not filepath then
      -- maybe it would succeed at runtime
      attr.runtime_require = true
      return
    end

    local reqnode = context.requires[filepath]
    if reqnode and reqnode ~= node then
      -- already required
      attr.alreadyrequired = true
      return
    end

    local input = fs.readfile(filepath)
    local ast = context.parser:parse(input, filepath)
    attr.loadedast = ast

    justloaded = true

    context.requires[filepath] = node
  end

  -- analyze it
  local ast = attr.loadedast
  local state = context:push_state()
  if ast.srcname then
    state.modname = pegger.filename_to_modulename(ast.srcname)
  end
  context:push_scope(context.rootscope)
  context:push_pragmas()
  context:reset_pragmas()
  state.inrequire = true
  if justloaded then
    preprocessor.preprocess(context, ast)
  end
  context:traverse(ast)
  context:pop_scope()
  context:pop_state()
  context:pop_pragmas()
end

return builtins
