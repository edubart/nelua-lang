local argparse = require 'nelua.thirdparty.argparse'
local inspect = require 'nelua.thirdparty.inspect'
local tabler = require 'nelua.utils.tabler'
local metamagic = require 'nelua.utils.metamagic'
local except = require 'nelua.utils.except'
local sstream = require 'nelua.utils.sstream'
local fs = require 'nelua.utils.fs'
local cdefs = require 'nelua.cdefs'
local console = require 'nelua.utils.console'

local configer = {}
local config = {}
local defconfig = {
  generator = 'c',
  lua = 'lua',
  lua_version = _VERSION:match('%d+%.%d+'),
  cache_dir = 'nelua_cache',
  cpu_bits = 64
}
metamagic.setmetaindex(config, defconfig)

local function convert_param(param)
  if param:match('^%a[_%w]*$') then
    param = param .. ' = true'
  end
  local f, err = load(param, '@define', "t")
  if err then
    return nil, string.format("failed parsing parameter '%s':\n  %s", param, err)
  end
  return param
end

local function convert_add_path(param)
  if not fs.isdir(param) and not param:match('%?') then
    return nil, string.format("path '%s' is not a valid directory", param)
  end
  return param
end

local function merge_configs(conf, pconf)
  for k,v in pairs(pconf) do
    if conf[k] == nil then
      conf[k] = v
    end
  end

  if conf.lib_path then
    local ss = sstream()
    for _,libpath in ipairs(conf.lib_path) do
      if libpath:find('?') then
        ss:add(libpath, ';')
      else
        ss:add(libpath, '/?.nelua;')
        ss:add(libpath, '/?/init.nelua;')
      end
    end
    -- try to insert the lib path after the local lib path
    local libpath = ss:tostring()
    local localpath = fs.join('.','?.nelua')..';'..fs.join('.','?','init.nelua')
    local localpathpos = conf.path:find(localpath, 1, true)
    if localpathpos then
      localpathpos = #localpath+1
      conf.path = conf.path:sub(1,localpathpos) .. libpath .. conf.path:sub(localpathpos+1)
    else
      conf.path = libpath .. conf.path
    end
  end

  if conf.pragma then
    local pragmas = {}
    for _,code in ipairs(conf.pragma) do
      local f, err = load(code, '@pragma', "t", pragmas)
      local ok
      if f then
        ok, err = pcall(f)
      end
      except.assertraisef(ok, "failed parsing pragma '%s':\n  %s", code, err)
    end
    conf.pragma = pragmas
  end
end

local function action_print_config(options) --luacov:disable
  merge_configs(options, defconfig)
  console.info(inspect(options))
  os.exit(0)
end --luacov:enable

local function create_parser(args)
  local argparser = argparse("nelua", "Nelua 0.1")
  argparser:flag('-c --compile', "Compile the generated code only", defconfig.compile)
  argparser:flag('-b --compile-binary', "Compile the generated code and binaries only", defconfig.compile_binary)
  --argparser:option('-o --output', "Output file when compiling")
  argparser:flag('-e --eval', 'Evaluate string code from input', defconfig.eval)
  argparser:flag('-l --lint', 'Only check syntax errors', defconfig.lint)
  argparser:flag('-q --quiet', "Don't print any information while compiling", defconfig.quiet)
  argparser:flag('-a --analyze', 'Analyze the code only', defconfig.analyze)
  argparser:flag('-r --release', 'Release mode build', defconfig.release)
  argparser:flag('-t --timing', 'Debug compile timing information', defconfig.timing)
  argparser:flag('--no-cache', "Don't use any cached compilation", defconfig.no_cache)
  argparser:option('-D --define', 'Define values in the preprocessor')
    :count("*"):convert(convert_param, tabler.copy(defconfig.define or {}))
  argparser:option('-P --pragma', 'Set initial compiler pragma')
    :count("*"):convert(convert_param, tabler.copy(defconfig.pragma or {}))
  argparser:option('-g --generator', "Code generator to use (lua/c)", defconfig.generator)
  argparser:option('-p --path', "Set module search path", defconfig.path)
  argparser:option('-L --lib-path', "Add module search path", tabler.copy(defconfig.lib_path or {}))
    :count("*"):convert(convert_add_path)
  argparser:option('--cc', "C compiler to use", defconfig.cc)
  argparser:option('--cpu-bits', "Target CPU architecture bit size (64/32)", defconfig.cpu_bits)
  argparser:option('--cflags', "Additional C flags to use on compilation", defconfig.cflags)
  argparser:option('--cache-dir', "Compilation cache directory", defconfig.cache_dir)
  argparser:option('--lua', "Lua interpreter to use when runnning", defconfig.lua)
  argparser:option('--lua-version', "Target lua version for lua generator", defconfig.lua_version)
  argparser:option('--lua-options', "Lua options to use when running", defconfig.lua_options)
  argparser:flag('--print-ast', 'Print the AST only')
  argparser:flag('--print-analyzed-ast', 'Print the analyzed AST only')
  argparser:flag('--print-code', 'Print the generated code only')
  argparser:flag('--print-config', "Print config variables only"):action(action_print_config)
  argparser:argument("input", "Input source file")
    :action(function(options, _, v)
    -- hacky way to stop handling options
    if v then
      local index = tabler.ifind(args, v) + 1
      local found_stop_index = tabler.ifind(args, '--')
      if not found_stop_index or found_stop_index > index-1 then
        table.insert(args, index, '--')
      end
      options.input = v
    end
  end)
  argparser:argument("runargs"):args("*")
  return argparser
end

local function get_cc()
  local envcc = os.getenv('CC')
  if envcc and fs.findbinfile(envcc) then return envcc end
  local cc = 'cc'
  for _,candidate in ipairs(cdefs.search_compilers) do
    if fs.findbinfile(candidate) then
      cc = candidate
      break
    end
  end
  return cc
end

local function get_search_path(datapath)
  local path = os.getenv('NELUA_PATH')
  if path then return path end
  local libdir = fs.join(datapath, 'lib')
  path = fs.join('.','?.nelua')..';'..
         fs.join('.','?','init.nelua')..';'..
         fs.join(libdir,'?.nelua')..';'..
         fs.join(libdir,'?','init.nelua')
  return path
end

function configer.parse(args)
  defconfig.data_path = fs.getdatapath(args[0])
  defconfig.path = get_search_path(defconfig.data_path)
  local argparser = create_parser(tabler.copy(args))
  local ok, options = argparser:pparse(args)
  except.assertraise(ok, options)
  merge_configs(options, defconfig)
  metamagic.setmetaindex(config, options, true)
  return config
end

function configer.get()
  return config
end

function configer.get_default()
  return defconfig
end

local function load_configs(configfile)
  if not fs.isfile(configfile) then return end
  local homeconfig = dofile(configfile)
  tabler.update(defconfig, homeconfig)
end

local function init_default_configs()
  defconfig.data_path = fs.getdatapath()
  defconfig.path = get_search_path(defconfig.data_path)
  defconfig.cc = get_cc()
  defconfig.cflags = os.getenv('CFLAGS') or ''

  load_configs(fs.getuserconfpath('neluacfg.lua'))
  load_configs('.neluacfg.lua')
end

init_default_configs()

return configer
