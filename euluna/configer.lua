local argparse = require 'argparse'
local tablex = require 'pl.tablex'
local plutil = require 'pl.utils'
local configer = {}

local arg
local argparser = argparse("euluna", "Euluna v0.1")
argparser:flag('-c --compile', "Compile the generated code only")
argparser:flag('-b --compile-binary', "Compile the generated code and binaries only")
--argparser:option('-o --output', "Output file when compiling")
argparser:flag('-e --eval', 'Evaluate string code from input')
argparser:flag('-l --lint', 'Only check syntax errors')
argparser:flag('-q --quiet', "Don't print any information while compiling")
argparser:flag('--no-cache', "Don't use any cached compilation")
argparser:flag('--print-ast', 'Print the AST only')
argparser:flag('--print-code', 'Print the generated code only')
argparser:option('-g --generator', "Code generator to use (lua/c)", "lua")
argparser:option('--cc', "C compiler to use", "gcc")
argparser:option('--cflags', "C flags to use on compilation", "-Wall -Wextra -std=c1x")
argparser:option('--lua', "Lua interpreter to use when runnning", "lua")
argparser:option('--lua-options', "Lua options to use when running")
argparser:option('--cache-dir', "Compilation cache directory", "euluna_cache")
argparser:argument("input", "Input source file"):action(function(options, _, v)
  -- hacky way to stop handling options
  local index = tablex.find(arg, v) + 1
  local found_stop_index  = tablex.find(arg, '--')
  if not found_stop_index or found_stop_index > index-1 then
    table.insert(arg, index, '--')
  end
  options.input = v
end)
argparser:argument("args"):args("*")
local config = {}

function configer.parse(argv)
  arg = tablex.copy(argv)
  local ok, options = argparser:pparse(argv)
  if not ok then return nil, options end
  setmetatable(config, {__index = options})
  return config
end

function configer.get()
  return config
end

function configer.get_run_args()
  local runargs = tablex.copy(config.args)
  tablex.transform(function(a) return plutil.quote_arg(a) end, runargs)
  return table.concat(runargs, ' ')
end

return configer
