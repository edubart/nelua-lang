local builtins = {}
local fs = require 'nelua.utils.fs'
local config = require 'nelua.configer'.get()

function builtins.require(context, node)
  local attr = node.attr
  if attr.loadedast or attr.alreadyrequired then
    -- already loaded
    return
  end

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

  -- analyze it
  local typechecker = require 'nelua.typechecker'
  typechecker.analyze(ast, context.parser, context)
  attr.loadedast = ast

  context.requires[filepath] = node
end

return builtins
