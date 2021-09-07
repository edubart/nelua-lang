require 'nelua.utils.luaver'.check()

-- make the lua garbage collector less aggressive to speed up compilation
collectgarbage("incremental", 800, 400, 16)
collectgarbage("stop")

local tracker = require 'nelua.utils.tracker'
local nanotimer = require 'nelua.utils.nanotimer'
local globaltimer = nanotimer.globaltimer
local timer = nanotimer()
local stringer = require 'nelua.utils.stringer'
local console = require 'nelua.utils.console'
local fs = require 'nelua.utils.fs'
local except = require 'nelua.utils.except'
local executor = require 'nelua.utils.executor'
local configer = require 'nelua.configer'
local config = configer.get()
local platform = require 'nelua.utils.platform'
local aster = require 'nelua.aster'
local version = require 'nelua.version'
local profiler
local runner = {}

local function print_total_build()
  if config.timing then
    console.debug2f('total time   %.1f ms', globaltimer:elapsedrestart())
  end
end

local function action_show_version()
  console.info(version.NELUA_VERSION)
  console.infof('Build number: %s', version.NELUA_GIT_BUILD)
  console.infof('Git date: %s', version.NELUA_GIT_DATE)
  console.infof('Git hash: %s', version.NELUA_GIT_HASH)
  console.infof('Semantic version: %s', version.NELUA_SEMVER)
  console.info('Copyright (C) 2019-2021 Eduardo Bart (https://nelua.io/)')
  return 0
end

local function action_show_semver()
  console.info(version.NELUA_SEMVER)
  return 0
end

local function action_show_config(options)
  local inspect = require 'nelua.thirdparty.inspect'
  console.info(inspect(options))
  return 0
end

local function action_run_script()
  -- replace arguments
  local arg = _G.arg
  for i=1,math.max(#arg,#config.runargs) do
    arg[i] = config.runargs[i]
  end
  -- run the script
  dofile(config.input)
  return 0
end

local function load_nelua_init()
  local initeval = os.getenv('NELUA_INIT')
  if not initeval then return end
  local ok = false
  local initfunc, err = load(initeval, '@NELUA_INIT')
  if initfunc then
    ok, err = pcall(initfunc)
  end
  if not ok then
    except.raisef('error while evaluation NELUA_INIT: %s', tostring(err))
  end
end

local function run(argv, redirect)
  load_nelua_init()

  -- parse config
  local options = configer.parse(argv)

  if config.version then
    return action_show_version()
  elseif config.semver then
    return action_show_semver()
  elseif config.config then
    return action_show_config(options)
  elseif config.script then
    return action_run_script()
  end

  if config.no_color ~= nil then
    console.set_colors_enabled(false)
  end

  local generator = require('nelua.' .. config.generator .. 'generator')
  local compiler = generator.compiler
  local preprocessor = require 'nelua.preprocessor'

  if config.timing then
    console.debugf('startup      %.1f ms', timer:elapsedrestart())
  end

  collectgarbage("restart")

  -- determine input
  local input, infile
  if config.eval then -- source from input argument
    infile = 'eval_'..stringer.hash(config.input, 8)
    input = config.input
  elseif config.input == '-' then -- source from stdin
    --luacov:disable
    infile = 'stdin_'..stringer.hash(config.input, 8)
    input = io.read('*a')
  else --luacov:enable
    infile = config.input
    input = fs.ereadfile(infile)
  end

  if config.before_parse then config.before_parse() end

  if config.profile_compiler then --luacov:disable
    profiler = require 'nelua.utils.profiler'
    profiler.start()
  end --luacov:enable

  -- parse ast
  local ast = aster.parse(input, infile)

  -- only checking syntax?
  if config.lint then
    print_total_build()
    return 0
  end

  -- only printing ast?
  if config.print_ast then
    console.info(tostring(ast))
    print_total_build()
    return 0
  end

  -- this is required here because the config may affect how they load
  local analyzer = require 'nelua.analyzer'
  local AnalyzerContext = require 'nelua.analyzercontext'

  -- analyze the ast
  local context = AnalyzerContext(analyzer.visitors, ast, config.generator)
  except.try(function()
    context = analyzer.analyze(context)
  end, function(e)
    e.message = context:get_visiting_traceback(1) .. e:get_message()
  end)

  -- setup benchmark timers
  if config.timing then
    local elapsed = timer:elapsedrestart()
    console.debugf('parse        %.1f ms', aster.parsing_time)
    console.debugf('preprocess   %.1f ms', preprocessor.working_time)
    console.debugf('analyze      %.1f ms', elapsed - aster.parsing_time - preprocessor.working_time)
  end

  -- only analyzing ast?
  if config.analyze or config.print_analyzed_ast or config.print_ppcode then
    if config.print_analyzed_ast then
      console.info(tostring(ast))
    end
    print_total_build()
    return 0
  end

  -- generate the code
  local code = generator.generate(context)
  if config.timing then
    console.debugf('generate     %.1f ms', timer:elapsedrestart())
  end

  -- only printing generated code?
  if config.print_code then
    console.info(code)
    print_total_build()
    return 0
  end

  -- choose a infile for evals
  if not infile then infile = 'eval_' .. stringer.hash(code, 8) end

  -- save the generated code
  local outcacheprefix = fs.normcachepath(infile, config.cache_dir)
  local sourcefile = config.compile_code and config.output or outcacheprefix
  if not compiler.has_source_extension(sourcefile) then
    sourcefile = sourcefile .. compiler.source_extension
  end
  compiler.compile_code(code, sourcefile, context.compileopts)

  -- only compiling code?
  if config.code then
    print_total_build()
    return 0
  end

  -- compile the generated code
  local binfile = config.output or outcacheprefix
  local outfile, isexe = compiler.compile_binary(sourcefile, binfile, context.compileopts)
  if config.timing then
    console.debugf('compile      %.1f ms', timer:elapsedrestart())
  end

  -- only printing assembly code?
  if config.print_assembly then
    console.info(fs.readfile(outfile))
    return 0
  end

  -- only compiling binaries?
  if config.compile_only or not isexe then
    print_total_build()
    return 0
  end

  -- execute binary
  dump(config.runargs)
  local exe, exeargs = compiler.get_run_command(outfile, config.runargs, context.compileopts)
  if config.verbose then console.info(exe .. ' ' .. table.concat(exeargs, ' ')) end
  local _, status = executor.rexec(exe, exeargs, redirect)
  if config.timing then
    console.debugf('run          %.1f ms', timer:elapsedrestart())
  end
  return status
end

function runner.run(argv, redirect)
  local status
  except.try(function()
    status = run(argv, redirect)

    local config = configer.get()
    if config.on_finish then config.on_finish() end
    tracker.report()
  end, function(e)
    console.logerr(e:get_message())
    status = 1
    return true
  end)

  if profiler then --luacov:disable
    profiler.stop()
    profiler.report({incl=true, min_usage=0.1})
    profiler.report({self=true, min_usage=0.1})
  end --luacov:enable

  return status
end

return runner
