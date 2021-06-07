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
local platform = require 'nelua.utils.platform'
local aster = require 'nelua.aster'
local profiler
local runner = {}

local function run(argv, redirect)
  -- parse config
  local config = configer.parse(argv)

  if config.no_color then console.set_colors_enabled(false) end

  --luacov:disable
  if config.script then
    -- inject script directory into lua package path
    local scriptdir = fs.dirname(fs.abspath(config.input))
    package.path = package.path..platform.luapath_separator..
                   fs.join(scriptdir,'?.lua')..platform.luapath_separator..
                   fs.join(scriptdir,'?','init.lua')

    -- run the script
    dofile(config.input)
    return 0
  end
  local initeval = os.getenv('NELUA_INIT')
  if initeval then
    local ok = false
    local initfunc, err = load(initeval, '@NELUA_INIT')
    if initfunc then
      ok, err = pcall(initfunc)
    end
    except.assertraisef(ok, tostring(err))
  end
  --luacov:enable

  local generator = require('nelua.' .. config.generator .. 'generator')
  local compiler = generator.compiler
  local preprocessor = require 'nelua.preprocessor'

  if config.timing then
    console.debugf('startup      %.1f ms', timer:elapsedrestart())
  end

  if not config.turbo then
    collectgarbage("restart")
  end

  -- determine input
  local input, infile
  if config.eval then
    infile = 'eval_' .. stringer.hash(config.input, 8)
    input = config.input
  else
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
    return 0
  end

  -- only printing ast?
  if config.print_ast then
    console.info(tostring(ast))
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
    e.message = context:traceback() .. e:get_message()
  end)

  if config.timing then
    local elapsed = timer:elapsedrestart()
    console.debugf('parse        %.1f ms', aster.parsing_time)
    console.debugf('preprocess   %.1f ms', preprocessor.working_time)
    console.debugf('analyze      %.1f ms', elapsed - aster.parsing_time - preprocessor.working_time)
  end

  if config.print_analyzed_ast then
    console.info(tostring(ast))
    return 0
  end

  if config.analyze then return 0 end

  -- generate the code
  local code, compileopts = generator.generate(ast, context)

  if config.timing then
    console.debugf('generate     %.1f ms', timer:elapsedrestart())
  end

  -- only printing generated code?
  if config.print_code then
    console.info(code)
    return 0
  end

  -- choose a infile for evals
  if not infile then infile = 'eval_' .. stringer.hash(code) end

  -- save the generated code
  local outcacheprefix = fs.getcachepath(infile, config.cache_dir)
  local sourcefile = config.generate_code and config.output or outcacheprefix
  if not compiler.has_source_extension(sourcefile) then
    sourcefile = sourcefile .. compiler.source_extension
  end
  compiler.generate_code(code, sourcefile, compileopts)

  local dorun = not config.generate_code and not config.compile_binary
  local dobinarycompile = config.compile_binary or dorun

  -- compile the generated code
  local binaryfile, isexe
  if dobinarycompile then
    local binfile = config.output or outcacheprefix
    binaryfile, isexe = compiler.compile_binary(sourcefile, binfile, compileopts)

    if config.timing then
      console.debugf('compile      %.1f ms', timer:elapsedrestart())
    end
  end

  if config.timing then
    console.debug2f('total build  %.1f ms', globaltimer:elapsedrestart())
  end

  -- run
  if dorun and isexe then
    local exe, exeargs = compiler.get_run_command(binaryfile, config.runargs)
    if config.verbose then console.info(exe .. ' ' .. table.concat(exeargs, ' ')) end
    local exec = redirect and executor.execex or executor.exec
    local _, status, sout, serr = exec(exe, exeargs)
    if sout then io.stdout:write(sout) io.stdout:flush() end
    if serr then io.stderr:write(serr) io.stderr:flush() end
    if config.timing then
      console.debugf('run          %.1f ms', timer:elapsedrestart())
    end
    return status
  end

  return 0
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
    profiler.report({self=true, min_usage=0.1})
    profiler.report({incl=true, min_usage=0.1})
  end --luacov:enable

  return status
end

return runner
