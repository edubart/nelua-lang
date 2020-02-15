local argparse = require 'argparse'
local tabler = require 'nelua.utils.tabler'
local metamagic = require 'nelua.utils.metamagic'
local except = require 'nelua.utils.except'
local fs = require 'nelua.utils.fs'
local cdefs = require 'nelua.cdefs'

local configer = {}
local config = {}
local defconfig = {
  generator = 'c',
  lua = 'lua',
  lua_version = _VERSION:match('%d+%.%d+'),
  cache_dir = 'nelua_cache',
  standard = 'default',
  cpu_bits = 64
}

local function create_parser(argv)
  local argparser = argparse("nelua", "Nelua 0.1")
  local d = defconfig
  argparser:flag('-c --compile', "Compile the generated code only")
  argparser:flag('-b --compile-binary', "Compile the generated code and binaries only")
  --argparser:option('-o --output', "Output file when compiling")
  argparser:flag('-e --eval', 'Evaluate string code from input', d.eval)
  argparser:flag('-l --lint', 'Only check syntax errors', d.lint)
  argparser:flag('-q --quiet', "Don't print any information while compiling", d.quiet)
  argparser:flag('-a --analyze', 'Analyze the code only', d.analyze)
  argparser:flag('-r --release', 'Release mode build', d.release)
  argparser:flag('-t --timing', 'Debug compile timing information', d.timing)
  argparser:flag('--no-cache', "Don't use any cached compilation", d.no_cache)
  argparser:flag('--print-ast', 'Print the AST only')
  argparser:flag('--print-analyzed-ast', 'Print the analyzed AST only')
  argparser:flag('--print-code', 'Print the generated code only')
  argparser:option('-g --generator', "Code generator to use (lua/c)", d.generator)
  argparser:option('-d --standard', "Source standard (default/luacompat)", d.standard)
  argparser:option('--cc', "C compiler to use", d.cc)
  argparser:option('--cpu-bits', "Target CPU architecture bit size", d.cpu_bits)
  argparser:option('--cflags', "Additional C flags to use on compilation", d.cflags)
  argparser:option('--lua', "Lua interpreter to use when runnning", d.lua)
  argparser:option('--lua-version', "Target lua version for lua generator", d.lua_version)
  argparser:option('--lua-options', "Lua options to use when running", d.lua_options)
  argparser:option('--cache-dir', "Compilation cache directory", d.cache_dir)
  argparser:option('--path', "Nelua modules search path", d.path)
  argparser:argument("input", "Input source file"):action(function(options, _, v)
    -- hacky way to stop handling options
    local index = tabler.ifind(argv, v) + 1
    local found_stop_index = tabler.ifind(argv, '--')
    if not found_stop_index or found_stop_index > index-1 then
      table.insert(argv, index, '--')
    end
    options.input = v
  end)
  argparser:argument("runargs"):args("*")
  return argparser
end

local function get_path(data_path)
  local libdir = fs.join(data_path, 'lib')
  return
    fs.join(libdir,'?.nelua')..';'..
    fs.join(libdir,'?','init.nelua')..';'..
    fs.join('.','?.nelua')..';'..
    fs.join('.','?','init.nelua')
end

local function get_cc()
  local envcc = os.getenv('CC')
  if envcc and fs.findbinfile(envcc) then return envcc end
  local cc = 'cc'
  for _,candidate in ipairs(cdefs.search_compilers) do
    if fs.findbinfile(candidate) then
      cc = candidate
    end
  end
  return cc
end

function configer.parse(args)
  local argparser = create_parser(tabler.copy(args))
  local ok, options = argparser:pparse(args)
  except.assertraise(ok, options)
  config.data_path = fs.getdatapath(args[0])
  config.path = get_path(config.data_path)
  metamagic.setmetaindex(options, defconfig)
  metamagic.setmetaindex(config, options, true)
  return config
end

function configer.get()
  return config
end

local function init_default_configs()
  defconfig.data_path = fs.getdatapath()
  defconfig.path = get_path(defconfig.data_path)
  defconfig.cc = get_cc()
  defconfig.cflags = os.getenv('CFLAGS') or ''
  metamagic.setmetaindex(config, defconfig)
end

local function load_configs(configfile)
  if not fs.isfile(configfile) then return end
  local homeconfig = dofile(configfile)
  tabler.update(defconfig, homeconfig)
end

init_default_configs()
load_configs(fs.getuserconfpath('neluacfg.lua'))
load_configs('.neluacfg.lua')

return configer
