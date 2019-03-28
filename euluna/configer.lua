local argparse = require 'argparse'
local tabler = require 'euluna.utils.tabler'
local metamagic = require 'euluna.utils.metamagic'
local except = require 'euluna.utils.except'

local configer = {}
local config = {}

local function create_parser(argv)
  local argparser = argparse("euluna", "Euluna v0.1")
  argparser:flag('-c --compile', "Compile the generated code only")
  argparser:flag('-b --compile-binary', "Compile the generated code and binaries only")
  --argparser:option('-o --output', "Output file when compiling")
  argparser:flag('-e --eval', 'Evaluate string code from input')
  argparser:flag('-l --lint', 'Only check syntax errors')
  argparser:flag('-q --quiet', "Don't print any information while compiling")
  argparser:flag('--strict', "Compile in strict mode (more checks)")
  argparser:flag('-a --analyze', 'Analyze the code only')
  argparser:flag('--no-cache', "Don't use any cached compilation")
  argparser:flag('--print-ast', 'Print the AST only')
  argparser:flag('--print-code', 'Print the generated code only')
  argparser:option('-g --generator', "Code generator to use (lua/c)", "lua")
  argparser:option('-s --standard', "Source standard (default/luacompat)", "default")
  argparser:option('--cc', "C compiler to use", "gcc")
  argparser:option('--cflags', "C flags to use on compilation", "-Wall -Wextra -std=c99")
  argparser:option('--lua', "Lua interpreter to use when runnning", "lua")
  argparser:option('--lua-options', "Lua options to use when running")
  argparser:option('--cache-dir', "Compilation cache directory", "euluna_cache")
  argparser:argument("input", "Input source file"):action(function(options, _, v)
    -- hacky way to stop handling options
    local index = tabler.find(argv, v) + 1
    local found_stop_index = tabler.find(argv, '--')
    if not found_stop_index or found_stop_index > index-1 then
      table.insert(argv, index, '--')
    end
    options.input = v
  end)
  argparser:argument("runargs"):args("*")
  return argparser
end

function configer.parse(args)
  local argparser = create_parser(tabler.copy(args))
  local ok, options = argparser:pparse(args)
  except.assertraise(ok, options)
  metamagic.setmetaindex(config, options, true)
  return config
end

function configer.get()
  return config
end

return configer
