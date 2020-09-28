local argparse = require 'nelua.thirdparty.argparse'
local inspect = require 'nelua.thirdparty.inspect'
local tabler = require 'nelua.utils.tabler'
local metamagic = require 'nelua.utils.metamagic'
local except = require 'nelua.utils.except'
local sstream = require 'nelua.utils.sstream'
local fs = require 'nelua.utils.fs'
local cdefs = require 'nelua.cdefs'
local platform = require 'nelua.utils.platform'
local console = require 'nelua.utils.console'

local configer = {}
local config = {}
local defconfig = {
  lua = 'lua',
  lua_version = _VERSION:match('%d+%.%d+'),
  lua_path = package.path,
  lua_cpath = package.cpath,
  generator = 'c',
  gdb = 'gdb',
  cache_dir = 'nelua_cache',
  cpu_bits = platform.cpu_bits
}
metamagic.setmetaindex(config, defconfig)

local function convert_param(param)
  if param:match('^%a[_%w]*$') then
    param = param .. ' = true'
  end
  local _, err = load(param, '@define', "t")
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

  if conf.add_path then
    local ss = sstream()
    for _,addpath in ipairs(conf.add_path) do
      if addpath:find('?') then
        ss:add(addpath, ';')
      else
        ss:add(addpath, '/?.nelua;')
        ss:add(addpath, '/?/init.nelua;')
      end
    end
    -- try to insert the lib path after the local lib path
    local addpath = ss:tostring()
    local localpath = fs.join('.','?.nelua')..';'..fs.join('.','?','init.nelua')
    local localpathpos = conf.path:find(localpath, 1, true)
    if localpathpos then
      localpathpos = #localpath+1
      conf.path = conf.path:sub(1,localpathpos) .. addpath .. conf.path:sub(localpathpos+1)
    else
      conf.path = addpath .. conf.path
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
  argparser:flag('-e --eval', 'Evaluate string code from input', defconfig.eval)
  argparser:flag('-l --lint', 'Only check syntax errors', defconfig.lint)
  argparser:flag('-q --quiet', "Don't print any information while compiling", defconfig.quiet)
  argparser:flag('-a --analyze', 'Analyze the code only', defconfig.analyze)
  argparser:flag('-r --release', 'Release mode build', defconfig.release)
  argparser:flag('-t --timing', 'Inform compile processing time', defconfig.timing)
  argparser:flag('-d --debug', 'Run through GDB to get crash backtraces', defconfig.debug)
  argparser:flag('--no-cache', "Don't use any cached compilation", defconfig.no_cache)
  argparser:flag('--no-color', 'Disable colorized output in the terminal.', defconfig.no_color)
  argparser:option('-o --output', 'Copy output file to desired path.')
  argparser:option('-D --define', 'Define values in the preprocessor')
    :count("*"):convert(convert_param, tabler.copy(defconfig.define or {}))
  argparser:option('-P --pragma', 'Set initial compiler pragma')
    :count("*"):convert(convert_param, tabler.copy(defconfig.pragma or {}))
  argparser:option('-g --generator', "Code generator backend to use (lua/c)", defconfig.generator)
  argparser:option('-p --path', "Set module search path", defconfig.path)
  argparser:option('-L --add-path', "Add module search path", tabler.copy(defconfig.add_path or {}))
    :count("*"):convert(convert_add_path)
  argparser:option('--cc', "C compiler to use", defconfig.cc)
  argparser:option('--cpu-bits', "Target CPU architecture bit size (64/32)", defconfig.cpu_bits)
    :convert(function(x) return math.floor(x) end)
  argparser:option('--cflags', "Additional C flags to use on compilation", defconfig.cflags)
  argparser:option('--cache-dir', "Compilation cache directory", defconfig.cache_dir)
  -- argparser:option('--lua', "Lua interpreter to use when runnning", defconfig.lua)
  -- argparser:option('--lua-version', "Target lua version for lua generator", defconfig.lua_version)
  -- argparser:option('--lua-options', "Lua options to use when running", defconfig.lua_options)
  argparser:flag('--script', "Run lua a script instead of compiling")
  argparser:flag('--static', "Compile as a static library")
  argparser:flag('--shared', "Compile as a shared library")
  argparser:flag('--print-ast', 'Print the AST only')
  argparser:flag('--print-analyzed-ast', 'Print the analyzed AST only')
  argparser:flag('--print-code', 'Print the generated code only')
  argparser:flag('--print-config', "Print config variables only"):action(action_print_config)
  argparser:flag('--debug-resolve', "Print information about resolved types")
  argparser:flag('--debug-scope-resolve', "Print number of resolved types per scope")
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

-- Detect where is the Nelua's lib directory.
-- First it detects if this is a Nelua repository clone,
-- a system wide install or a luarocks install.
-- Then returns the appropriate path for the Nelua's lib directory.
local function get_nelua_lib_path()
  local thispath = debug.getinfo(1).source:sub(2)
  local dirpath = fs.dirname(fs.dirname(thispath))
  local libpath
  --luacov:disable
  if fs.isfile(fs.join(dirpath, 'lib', 'math.nelua')) then
    -- in a repository clone
    libpath = fs.join(dirpath, 'lib')
  elseif fs.basename(dirpath) == 'lualib' then
    -- in a system install
    -- this file should be in a path like "/usr/lib/nelua/lualib/nelua/configer.lua"
    libpath = fs.join(fs.dirname(dirpath), "lib")
  else
    -- we should be in a luarocks install,
    -- arg 0 is probably in "bin/" thus we should go to "../conf/lib"
    libpath = fs.join(fs.dirname(fs.dirname(_G.arg[0])), 'conf', 'lib')
  end
  libpath = fs.abspath(libpath)
  if fs.isfile(fs.join(libpath, 'math.nelua')) then
    return libpath
  end
  --luacov:enable
end

local function get_search_path(libpath)
  local path = os.getenv('NELUA_PATH')
  if path then return path end
  path = fs.join('.','?.nelua')..';'..
         fs.join('.','?','init.nelua')..';'..
         fs.join(libpath,'?.nelua')..';'..
         fs.join(libpath,'?','init.nelua')
  return path
end


function configer.parse(args)
  local argparser = create_parser(tabler.icopy(args))
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
  local libpath = get_nelua_lib_path()
  if not libpath then --luacov:disable
    console.error('Nelua installation is broken, lib path was not found!')
    os.exit(1)
  end --luacov:enable
  defconfig.lib_path = libpath
  defconfig.path = get_search_path(defconfig.lib_path)
  defconfig.cc = get_cc()
  defconfig.cflags = os.getenv('CFLAGS') or ''

  load_configs(fs.getuserconfpath(fs.join('nelua', 'neluacfg.lua')))
  load_configs('.neluacfg.lua')
end

init_default_configs()

return configer
