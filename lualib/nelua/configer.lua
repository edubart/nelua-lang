local argparse = require 'nelua.thirdparty.argparse'
local tabler = require 'nelua.utils.tabler'
local metamagic = require 'nelua.utils.metamagic'
local except = require 'nelua.utils.except'
local sstream = require 'nelua.utils.sstream'
local fs = require 'nelua.utils.fs'
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
  cache_dir = fs.getusercachepath('nelua'),
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

-- Build configs that depends on other configs.
local function build_configs(conf)
  -- fill missing configs
  merge_configs(conf, defconfig)

  if config.no_color then -- disable console coloring
    console.set_colors_enabled(false)
  end

  if config.verbose then -- print all loaded configs
    for _,file in ipairs(loadedconfigs) do
      print(string.format("using config file '%s'", file))
    end
  end

  if conf.print_code then
    conf.code = true
  elseif conf.print_assembly then
    conf.assembly = true
  end
  if config.code or conf.binary or conf.assembly or conf.object or
     conf.static_lib or conf.shared_lib then
    conf.compile_only = true
  elseif conf.output then --luacov:disable
    conf.compile_only = true
    local output = conf.output
    if output:find('%.[ch]$') then
      conf.generator = 'c'
      conf.code = true
    elseif output:find('%.lua$') then
      conf.generator = 'lua'
      conf.code = true
    elseif output:find('%.[sS]$') or output:find('%.mir$')  then
      conf.assembly = true
    elseif output:find('%.o$') or output:find('%.bmir$') then
      conf.object = true
    elseif output:find('%.so$') or output:find('%.dll$') or output:find('%.dylib$') then
      conf.shared_lib = true
    elseif output:find('%.a$') then
      conf.static_lib = true
    else
      conf.binary = true
    end
  end --luacov:enable

  conf.lua_path = package.path
  conf.lua_cpath = package.cpath

  if conf.add_path then
    local neluass = sstream()
    local luass = sstream()
    for _,addpath in ipairs(conf.add_path) do
      if addpath:find('?') then
        neluass:addmany(';', addpath)
        luass:addmany(platform.luapath_separator, addpath)
      else
        neluass:addmany(';', addpath, '/?.nelua;',
                        ';', addpath, '/?/init.nelua')
        luass:addmany(platform.luapath_separator, addpath, '/?.lua',
                      platform.luapath_separator, addpath, '/?/init.lua')
      end
    end
    -- try to insert the lib path after the local lib path
    do -- nelua
      local addpath = neluass:tostring()
      local localpath = fs.join('.','?.nelua')..';'..fs.join('.','?','init.nelua')
      conf.path = stringer.insertafter(conf.path, localpath, addpath) or
                  addpath:sub(2)..';'..conf.path
    end
    do -- lua
      local addpath = luass:tostring()
      local localpath = fs.join('.','?.lua')..platform.luapath_separator..fs.join('.','?','init.lua')
      conf.lua_path = stringer.insertafter(conf.lua_path, localpath, addpath) or
                      addpath:sub(2)..platform.luapath_separator..conf.lua_path
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

  -- determine output directory
  if config.output then
    conf.output_dir = fs.dirname(fs.abspath(config.output))
  else
    conf.output_dir = conf.cache_dir
  end

  if conf.maximum_performance or conf.release then --luacov:disable
    conf.pragmas.nochecks = true
  end --luacov:enable
end

local function create_parser()
  local argparser = argparse("nelua", version.NELUA_VERSION)
  argparser:help_max_width(80)
  argparser:usage_margin(2)
  argparser:help_usage_margin(2)
  argparser:help_description_margin(28)
  argparser:mutex(
    argparser:flag('-c --code', "Compile the backend code only", defconfig.compile_code),
    argparser:flag('-a --analyze', 'Analyze the code only', defconfig.analyze),
    argparser:flag('-b --binary', "Compile the binary only", defconfig.compile_binary),
    argparser:flag('-B --object', "Compile as an object file", defconfig.compile_object),
    argparser:flag('-Y --assembly', "Compile as an assembly file", defconfig.compile_assembly),
    argparser:flag('-A --static-lib', "Compile as a static library", defconfig.compile_static_lib),
    argparser:flag('-H --shared-lib', "Compile as a shared library", defconfig.compile_shared_lib),
    argparser:flag('--script', "Run lua a script instead of compiling", defconfig.script),
    argparser:flag('--lint', 'Check for syntax errors only', defconfig.lint),
    argparser:flag('--print-ast', 'Print the AST only'),
    argparser:flag('--print-analyzed-ast', 'Print the analyzed AST only'),
    argparser:flag('--print-ppcode', 'Print the generated Lua preprocessing code only'),
    argparser:flag('--print-code', 'Print the generated code only'),
    argparser:flag('--print-assembly', 'Print the assembly generated code only')
  )
  argparser:mutex(
    argparser:argument("input", "Input source file"):args("?"),
    argparser:flag('--config', 'Print config variables only'),
    argparser:flag('-v --version', 'Print compiler detailed version'),
    argparser:flag('--semver', 'Print compiler semantic version')
  )
  argparser:flag('-i --eval', 'Evaluate string code from input', defconfig.eval)
  argparser:flag('-d --debug', 'Run through GDB to get crash backtraces', defconfig.debug)
  argparser:flag('-S --sanitize', 'Enable undefined/address sanitizers at runtime', defconfig.sanitize)
  argparser:flag('-r --release', 'Release build (optimize for speed and disable runtime checks)', defconfig.release)
  argparser:flag('-M --maximum-performance', "Maximum performance build (use for benchmarking)")
  argparser:flag('-s --strip', 'Remove symbols from the compiled binary (reduce its size)', defconfig.strip)
  -- argparser:flag('-O --optimize', 'Optimize level', defconfig.optimize)
  argparser:flag('-t --timing', 'Show compile timing information', defconfig.timing)
  argparser:flag('-T --more-timing', 'Show detailed compile timing information', defconfig.more_timing)
  argparser:flag('-V --verbose', 'Show compile related information')
  argparser:flag('-w --no-warning', "Suppress all warning messages", defconfig.no_warning)
  argparser:flag('-C --no-cache', "Don't use any cached compilation", defconfig.no_cache)
  argparser:flag('--no-color', 'Disable colorized output in the terminal.', defconfig.no_color)
  argparser:option('-o --output', 'Output file.', defconfig.output)
  argparser:option('-D --define', 'Define values in the preprocessor')
    :count("*"):convert(convert_param)
  argparser:option('-P --pragma', 'Set initial compiler pragma')
    :count("*"):convert(convert_param)
  argparser:option('-g --generator', "Code generator backend to use (lua/c)", defconfig.generator)
  argparser:option('-L --add-path', "Add module search path")
    :count("*"):convert(convert_add_path)
  argparser:option('--cc', "C compiler to use", defconfig.cc)
  argparser:option('--cflags', "Additional C flags to use on compilation", defconfig.cflags)
  argparser:option('--cache-dir', "Compilation cache directory", defconfig.cache_dir)
  argparser:option('--path', "Set module search path", defconfig.path)
  -- the following are used only to debug/optimize the compiler
    argparser:flag('--profile-compiler', 'Print profiling for the compiler'):hidden(true)
    argparser:flag('--debug-resolve', "Print information about resolved types"):hidden(true)
    argparser:flag('--debug-scope-resolve', "Print number of resolved types per scope"):hidden(true)
  -- the following are deprecated
    argparser:option('--lua', "Lua interpreter to use when runnning", defconfig.lua):hidden(true)
    argparser:option('--lua-version', "Target lua version for lua generator", defconfig.lua_version):hidden(true)
    argparser:option('--lua-options', "Lua options to use when running", defconfig.lua_options):hidden(true)
    argparser:flag('-q --quiet', "Be quiet", defconfig.quiet):hidden(true)
    argparser:flag('-j --turbo', "Compile faster by disabling the garbage collector (uses more MEM)"):hidden(true)
  argparser:argument("runargs", "Arguments passed to the application\n\z
                                 Use '--' to is passed)")
    :args("*")
  return argparser
end


-- Build configs that depends on other configs.
function configer.build(options)
  options = options or {}
  for k,v in pairs(config) do
    options[k] = v
  end
  build_configs(options)
  metamagic.setmetaindex(config, options, true)
  return config
end

-- Parse and build config from program arguments.
function configer.parse(args)
  local argparser = create_parser(args)
  if not args[1] then -- no arguments? show help and exit
    --luacov:disable
    print(argparser:get_help())
    os.exit(0)
    --luacov:enable
  end
  local ok, options = argparser:pparse(args)
  except.assertraise(ok, options)
  configer.build(options)
  return options
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

--[[
Initializes default config by detecting system variables,
and reading user and project configurations files.
]]
local function init_default_configs()
  local libpath, lualibpath = fs.findnelualib()
  if not libpath then --luacov:disable
    console.error('Nelua installation is broken, lib path was not found!')
    os.exit(1)
  end --luacov:enable
  defconfig.lib_path = libpath
  defconfig.lualib_path = lualibpath
  defconfig.lua = fs.findluabin()
  defconfig.path = fs.makesearchpath(libpath, 'nelua')
  defconfig.cc = fs.findcc() or 'cc'
  defconfig.cflags = os.getenv('CFLAGS') or ''

  -- load global user config
  load_config(fs.getuserconfpath(fs.join('nelua', 'neluacfg.lua')))

  -- load project plugins configs
  for f in fs.dirmatch('.', '%.neluacfg.[-_%w]+.lua') do --luacov:disable
    load_config(f)
  end --luacov:enable

  -- load project config
  load_config('.neluacfg.lua')

  configer.build()
end

init_default_configs()

return configer
