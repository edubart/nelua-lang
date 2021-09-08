--[[
Runner module.

This module is used to run the compiler from a set of arguments,
it's the first required module when running the compiler.
]]

-- We expect to be running in Lua 5.4.
if _VERSION ~= 'Lua 5.4' then
  error 'Please use Lua 5.4'
end

-- Make the lua garbage collector less aggressive to speed up compilation.
collectgarbage("incremental", 800, 400, 16)

-- Timers must be the first loaded module.
local nanotimer = require 'nelua.utils.nanotimer'
local globaltimer = nanotimer.globaltimer
local timer = nanotimer()

local tracker = require 'nelua.utils.tracker'
local stringer = require 'nelua.utils.stringer'
local console = require 'nelua.utils.console'
local fs = require 'nelua.utils.fs'
local except = require 'nelua.utils.except'
local executor = require 'nelua.utils.executor'
local configer = require 'nelua.configer'
local aster = require 'nelua.aster'
local version = require 'nelua.version'
local config = configer.get()
local profiler

local runner = {}

-- Show compiler version.
function runner.show_version()
  console.info(version.NELUA_VERSION)
  console.info('Build number: '..version.NELUA_GIT_BUILD)
  console.info('Git date: '..version.NELUA_GIT_DATE)
  console.info('Git hash: '..version.NELUA_GIT_HASH)
  console.info('Semantic version: '..version.NELUA_SEMVER)
  console.info('Copyright (C) 2019-2021 Eduardo Bart (https://nelua.io/)')
  return 0
end

-- Show semantic version.
function runner.show_semver()
  console.info(version.NELUA_SEMVER)
  return 0
end

-- Show current loaded configuration.
function runner.show_config(options)
  local inspect = require 'nelua.thirdparty.inspect'
  options.config = nil -- remove this flag from the config table
  console.info(inspect(options))
  return 0
end

-- Runs a Lua script.
function runner.run_script()
  -- overwrite global arguments
  local arg = _G.arg
  for i=1,math.max(#arg,#config.runargs) do
    arg[i] = config.runargs[i]
  end
  -- run the script
  if not config.input then
    console.error('Missing input file name, please pass a source file as an argument.')
    return 1
  end
  if config.input == '-' then
    dofile()
  else
    dofile(config.input)
  end
  return 0
end

-- Executes the Lua chunk from 'NELUA_INIT' environment variable.
local function load_nelua_init()
  local initeval = os.getenv('NELUA_INIT')
  if not initeval then return end
  local ok = false
  local initfunc, err = load(initeval, '@NELUA_INIT')
  if initfunc then
    ok, err = pcall(initfunc)
  end
  if not ok then
    except.raisef('error while executing NELUA_INIT: %s', tostring(err))
  end
end

-- Starts profiling the compiler.
function runner.start_profiling()
  profiler = require 'nelua.utils.profiler'
  collectgarbage()
  profiler.start()
end

-- Stops profiling the compiler and show profiling statistics.
function runner.stop_profiling()
  if not profiler then return end
  profiler.stop()
  profiler.report{incl=true, min_usage=0.1}
  profiler.report{self=true, min_usage=0.1}
end

local function run(args, redirect)
  load_nelua_init()
  local options = configer.parse(args) -- parse options
  -- handle actions that exits early
  if config.version then
    return runner.show_version()
  elseif config.semver then
    return runner.show_semver()
  elseif config.config then
    return runner.show_config(options)
  elseif config.script then
    return runner.run_script()
  end
  -- this is required here because the config may affect how they load
  local generator = require('nelua.'..config.generator..'generator')
  local preprocessor = require 'nelua.preprocessor'
  local analyzer = require 'nelua.analyzer'
  local AnalyzerContext = require 'nelua.analyzercontext'
  local compiler = generator.compiler
  if config.timing then
    console.debugf('startup      %.1f ms', timer:elapsedrestart())
  end
  -- determine input
  local input, inputname
  if config.eval then -- source from input argument
    inputname = 'eval_'..stringer.hash(config.input, 8)
    input = config.input
  elseif config.input == '-' then -- source from stdin
    --luacov:disable
    inputname = 'stdin_'..stringer.hash(config.input, 8)
    input = io.read('*a')
  else --luacov:enable
    inputname = config.input
    if not inputname then
      console.error('Missing input, please pass a source file as an argument.')
      return 1
    end
    local err
    input, err = fs.readfile(inputname)
    if not input then
      console.errorf("Failed to read input file: %s", err)
      return 1
    end
  end
  -- execute arbitrary code from config before parsing
  if config.before_parse then
    config.before_parse()
  end
  -- we are only interested in profiling since this point
  if config.profile_compiler then runner.start_profiling() end
  -- parse ast
  local ast = aster.parse(input, inputname)
  -- only checking syntax?
  if config.lint then
    return 0
  end
  -- only printing ast?
  if config.print_ast then
    console.info(tostring(ast))
    return 0
  end
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
    return 0
  end
  -- choose a inputname for evals
  if not inputname then inputname = 'eval_' .. stringer.hash(code, 8) end
  -- save the generated code
  local outcacheprefix = fs.normcachepath(inputname, config.cache_dir)
  local sourcefile = config.compile_code and config.output or outcacheprefix
  if not compiler.has_source_extension(sourcefile) then
    sourcefile = sourcefile .. compiler.source_extension
  end
  compiler.compile_code(code, sourcefile, context.compileopts)
  -- only compiling code?
  if config.code then
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
    return 0
  end
  -- execute binary
  local exe, exeargs = compiler.get_run_command(outfile, config.runargs, context.compileopts)
  if config.verbose then console.info(exe .. ' ' .. table.concat(exeargs, ' ')) end
  local _, status = executor.rexec(exe, exeargs, redirect)
  if config.timing then
    console.debugf('run          %.1f ms', timer:elapsedrestart())
  end
  return status
end

function runner.run(args, redirect)
  local status
  except.try(function()
    status = run(args, redirect)
    if config.on_finish then config.on_finish() end
    if config.timing then -- show total timing statistics
      console.debug2f('total time   %.1f ms', globaltimer:elapsedrestart())
    end
    tracker.report() -- show tracker statistics in case of any
  end, function(e) -- got a compile error
    console.logerr(e:get_message())
    status = 1
  end)
  runner.stop_profiling()
  return status
end

return runner
