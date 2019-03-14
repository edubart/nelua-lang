local argparse = require 'argparse'
local configer = {}

local argparser = argparse("euluna", "Euluna v0.1")
argparser:argument("input", "Input source file")
argparser:flag('-c --compile', "Compile the generated code only")
argparser:flag('-b --compile-binary', "Compile the generated code and binaries only")
--argparser:option('-o --output', "Output file when compiling")
argparser:flag('-e --eval', 'Evaluate string code from input')
argparser:flag('-l --lint', 'Only check syntax errors')
argparser:option('-g --generator', "Code generator to use (lua/c)", "lua")
argparser:option('--cc', "C compiler to use", "gcc")
argparser:option('--cflags', "C flags to use on compilation", "-Wall -Wextra -std=c1x")
argparser:option('--lua', "Lua interpreter to use when runnning", "lua")
argparser:option('--lua-options', "Lua options to use when running")
argparser:flag('-q --quiet', "Don't print any information while compiling")
argparser:option('--cache-dir', "Compilation cache directory", "euluna_cache")
argparser:flag('--no-cache', "Don't use any cached compilation")
argparser:flag('--print-ast', 'Print the AST only')
argparser:flag('--print-code', 'Print the generated code only')
local config = {}

function configer.parse(argv)
  local ok, options = assert(argparser:pparse(argv))
  setmetatable(config, {__index = options})
  return config
end

function configer.get()
  return config
end

return configer
