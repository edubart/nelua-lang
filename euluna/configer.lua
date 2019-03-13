local argparse = require 'argparse'
local configer = {}

local argparser = argparse("euluna", "Euluna v0.1")
argparser:argument("input", "Input source file")
argparser:flag('-c --compile', "Just compile and generated code (don't run)")
argparser:option('-o --output', "Output file when compiling")
argparser:flag('-e --eval', 'Evaluate string code from input')
argparser:flag('-l --lint', 'Only check syntax errors')
argparser:option('-g --generator', "Generator to use (lua/c)", "lua")
argparser:option('--cc', "C compiler to use", "gcc")
argparser:option('--cflags', "C flags to use on compilation", "-Wall -Wextra -std=c1x")
argparser:flag('-q --quiet', "Don't print any information to stdout")
argparser:option('--cache-dir', "Compilation cache directory", "euluna_cache")
argparser:flag('--no-cache', "Don't use any cached compilation")
argparser:flag('--print-ast', 'Print the AST only')
argparser:flag('--print-code', 'Print the generated code only')
local config = {}

function configer.parse(argv)
  local options = argparser:parse(argv)
  setmetatable(config, {__index = options})
  return config
end

function configer.get()
  return config
end

return configer