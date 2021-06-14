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
local stringer = require 'nelua.utils.stringer'
local version = require 'nelua.version'

local configer = {}
local config = {}
local loadedconfigs = {}
local defconfig = {
  lua_version = _VERSION:match('%d+%.%d+'),
  generator = 'c',
  gdb = 'gdb',
  cache_dir = 'nelua_cache',
  pragmas = {}
}
metamagic.setmetaindex(config, defconfig)

-- Convert defines and pragmas to lua assignment code.
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

-- Combine two configs into one, merging tables as necessary.
local function merge_configs(conf, baseconf)
  for basekey,baseval in pairs(baseconf) do
    local newval = conf[basekey]
    if newval == nil then
      conf[basekey] = baseval
    elseif type(newval) == 'table' then
      assert(type(baseval) == 'table')
      tabler.insertvalues(newval, baseval)
    end
  end
end

local function detect_cpu_bits(cc)
  local cpu_bits = tonumber(os.getenv('NELUA_CPUBITS'))
  if not cpu_bits then
    if cc and cc:match('emcc') then
      return 32
    else
      return platform.cpu_bits
    end
  end
  return cpu_bits
end

-- Build configs that depends on other configs.
local function build_configs(conf)
  if conf.cc and not conf.cpu_bits then
    -- compiler changed, try to detect CPU bits again
    conf.cpu_bits = detect_cpu_bits(conf.cc)
  end

  -- fill missing configs
  merge_configs(conf, defconfig)

  if conf.output then --luacov:disable
    if conf.output:match('%.[ch]$') then
      conf.generator = 'c'
      conf.generate_code = true
      conf.compile_binary = false
    elseif conf.output:match('%.lua$') then
      conf.generator = 'lua'
      conf.generate_code = true
      conf.compile_binary = false
    elseif conf.output:match('%.so$') or conf.output:match('%.dll$') or conf.output:match('%.dylib$') then
      conf.generator = 'c'
      conf.shared = true
      conf.compile_binary = true
      conf.generate_code = false
    elseif conf.output:match('%.a$') then
      conf.generator = 'c'
      conf.static = true
      conf.compile_binary = true
      conf.generate_code = false
    end
  end --luacov:enable

  if conf.static or conf.shared then
    conf.compile_binary = true
  end

  conf.lua_path = package.path
  conf.lua_cpath = package.cpath

  if conf.add_path then
    local neluass = sstream()
    local luass = sstream()
    for _,addpath in ipairs(conf.add_path) do
      if addpath:find('?') then
        neluass:addmany(addpath, ';')
        luass:addmany(addpath, platform.luapath_separator)
      else
        neluass:addmany(addpath, '/?.nelua;',
                        addpath, '/?/init.nelua;')
        luass:addmany(addpath, '/?.lua', platform.luapath_separator,
                      addpath, '/?/init.lua', platform.luapath_separator)
      end
    end
    -- try to insert the lib path after the local lib path
    do -- nelua
      local addpath = neluass:tostring()
      local localpath = fs.join('.','?.nelua')..';'..fs.join('.','?','init.nelua')
      conf.path = stringer.insertafter(conf.path, localpath, addpath) or
                  addpath..conf.path
    end
    do -- lua
      local addpath = luass:tostring()
      local localpath = fs.join('.','?.lua')..platform.luapath_separator..fs.join('.','?','init.lua')
      conf.lua_path = stringer.insertafter(conf.lua_path, localpath, addpath) or
                      addpath..conf.lua_path
      package.path = conf.lua_path
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
    tabler.update(conf.pragmas, pragmas)
  end

  if conf.maximum_performance or conf.release then --luacov:disable
    conf.pragmas.nochecks = true
  end --luacov:enable
end

--luacov:disable
local function action_version()
  version.detect_git_info()
  console.info(version.NELUA_VERSION)
  console.infof('Build number: %s', version.NELUA_GIT_BUILD)
  console.infof('Git date: %s', version.NELUA_GIT_DATE)
  console.infof('Git hash: %s', version.NELUA_GIT_HASH)
  console.info('Copyright (C) 2019-2021 Eduardo Bart (https://nelua.io/)')
  os.exit(0)
end

local function print_verbose()
  for _,file in ipairs(loadedconfigs) do
    print(string.format("using config file '%s'", file))
  end
end

local function action_print_config(options)
  build_configs(options)
  console.info(inspect(options))
  os.exit(0)
end
--luacov:enable

local function create_parser(args)
  local argparser = argparse("nelua", version.NELUA_VERSION)
  argparser:flag('-c --generate-code', "Generate the code only", defconfig.compile)
  argparser:flag('-b --compile-binary', "Compile the binaries only", defconfig.compile_binary)
  argparser:flag('-e --eval', 'Evaluate string code from input', defconfig.eval)
  argparser:flag('-l --lint', 'Only check syntax errors', defconfig.lint)
  argparser:flag('-a --analyze', 'Analyze the code only', defconfig.analyze)
  argparser:flag('-r --release', 'Release build (optimize for speed and disable runtime checks)', defconfig.release)
  argparser:flag('-d --debug', 'Run through GDB to get crash backtraces', defconfig.debug)
  argparser:flag('-t --timing', 'Show compile timing information', defconfig.timing)
  argparser:flag('-T --more-timing', 'Show detailed compile timing information', defconfig.more_timing)
  argparser:flag('-V --verbose', 'Show compile related information')
  argparser:flag('-v --version', 'Print detailed version information'):action(action_version)
  argparser:flag('-w --no-warning', "Suppress all warning messages", defconfig.no_warning)
  argparser:flag('-M --maximum-performance', "Maximum performance build (use for benchmarking)")
  argparser:flag('-j --turbo', "Compile faster by disabling the garbage collector (uses more MEM)")
  argparser:option('-o --output', 'Output file.', defconfig.output)
  argparser:option('-D --define', 'Define values in the preprocessor')
    :count("*"):convert(convert_param)
  argparser:option('-P --pragma', 'Set initial compiler pragma')
    :count("*"):convert(convert_param)
  argparser:option('-g --generator', "Code generator backend to use (lua/c)", defconfig.generator)
  argparser:option('-p --path', "Set module search path", defconfig.path)
  argparser:option('-L --add-path', "Add module search path")
    :count("*"):convert(convert_add_path)
  argparser:option('--cc', "C compiler to use", defconfig.cc)
  argparser:option('--cpu-bits', "Target CPU architecture bit size (64/32)")
    :convert(function(x) return math.floor(x) end)
  argparser:option('--cflags', "Additional C flags to use on compilation", defconfig.cflags)
  argparser:option('--cache-dir', "Compilation cache directory", defconfig.cache_dir)
  -- argparser:option('--lua', "Lua interpreter to use when runnning", defconfig.lua)
  -- argparser:option('--lua-version', "Target lua version for lua generator", defconfig.lua_version)
  -- argparser:option('--lua-options', "Lua options to use when running", defconfig.lua_options)
  argparser:flag('--script', "Run lua a script instead of compiling", defconfig.script)
  argparser:flag('--static', "Compile as a static library", defconfig.static)
  argparser:flag('--shared', "Compile as a shared library", defconfig.shared)
  argparser:flag('--print-ast', 'Print the AST only')
  argparser:flag('--print-analyzed-ast', 'Print the analyzed AST only')
  argparser:flag('--print-code', 'Print the generated code only')
  argparser:flag('--print-config', "Print config variables only"):action(action_print_config)
  argparser:flag('--no-cache', "Don't use any cached compilation", defconfig.no_cache)
  argparser:flag('--no-color', 'Disable colorized output in the terminal.', defconfig.no_color)
  argparser:flag('--profile-compiler', 'Print profiling for the compiler', defconfig.profile)
  argparser:flag('--debug-resolve', "Print information about resolved types"):hidden(true)
  argparser:flag('--debug-scope-resolve', "Print number of resolved types per scope"):hidden(true)
  argparser:flag('-q --quiet', "Be quiet (deprecated)", defconfig.quiet):hidden(true)
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

-- Detect the default C compiler in the user system.
-- First reads the CC system environment variable,
-- then try to search in the user binary directory.
local function detect_cc()
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
-- First it detects if this is a Nelua repository clone or a system wide install.
-- Then returns the appropriate path for the Nelua's lib directory.
local function detect_nelua_lib_path()
  local thispath = fs.scriptname()
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
  end
  libpath = fs.abspath(libpath)
  if fs.isfile(fs.join(libpath, 'math.nelua')) then
    return libpath
  end
  --luacov:enable
end

-- Detect nelua's package path.
-- It reads the NELUA_PATH system environment variable,
-- otherwise build a default one.
local function detect_search_path(libpath)
  local path = os.getenv('NELUA_PATH')
  if path then return path end
  path = fs.join('.','?.nelua')..';'..
         fs.join('.','?','init.nelua')..';'..
         fs.join(libpath,'?.nelua')..';'..
         fs.join(libpath,'?','init.nelua')
  return path
end

local function detect_lua_bin()
  local lua = 'lua'
  local minargi = 0
  for argi,v in pairs(arg) do
    if argi < minargi then
      minargi = argi
      lua = v
    end
  end
  return lua
end

-- Build configs that depends on other configs.
function configer.build(options)
  options = options or {}
  build_configs(options)
  metamagic.setmetaindex(config, options, true)
  return config
end

-- Parse and build config from program arguments.
function configer.parse(args)
  local argparser = create_parser(tabler.icopy(args))
  local ok, options = argparser:pparse(args)
  except.assertraise(ok, options)
  configer.build(options)
  if config.verbose then
    print_verbose()
  end
  return config
end

-- Get config.
function configer.get()
  return config
end

function configer.get_default()
  return defconfig
end

-- Load a config file and merge into default configs.
local function load_config(configfile)
  if not fs.isfile(configfile) then return end
  local ok, err = pcall(function()
    local conf = dofile(configfile)
    merge_configs(conf, defconfig)

    -- overwrite defconfig without making a new reference
    tabler.update(defconfig, conf)

  end)
  if ok then
    table.insert(loadedconfigs, configfile)
  else --luacov:disable
    console.errorf('failed to load config "%s": %s', configfile, err)
  end --luacov:enable
end

-- Initializes default config by detecting system variables,
-- and reading user and project configurations files.
local function init_default_configs()
  local libpath = detect_nelua_lib_path()
  if not libpath then --luacov:disable
    console.error('Nelua installation is broken, lib path was not found!')
    os.exit(1)
  end --luacov:enable
  defconfig.lib_path = libpath
  defconfig.lua = detect_lua_bin()
  defconfig.path = detect_search_path(libpath)
  defconfig.cc = detect_cc()
  defconfig.cflags = os.getenv('CFLAGS') or ''

  -- load global user config
  load_config(fs.getuserconfpath(fs.join('nelua', 'neluacfg.lua')))

  -- load project plugins configs
  for f in fs.dirmatch('.', '%.neluacfg.[-_%w]+.lua') do --luacov:disable
    load_config(f)
  end --luacov:enable

  -- load project config
  load_config('.neluacfg.lua')

  defconfig.cpu_bits = detect_cpu_bits(defconfig.cc)

  configer.build()
end

init_default_configs()

return configer
