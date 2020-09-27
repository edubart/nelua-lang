require 'nelua.utils.luaver'.check()
-- local profiler = require 'play.tools.profiler'

-- make the lua garbage collector less aggressive to speed up compilation
collectgarbage("setpause", 800)
collectgarbage("setstepmul", 400)

local timer = require 'nelua.utils.nanotimer'()
local stringer = require 'nelua.utils.stringer'
local console = require 'nelua.utils.console'
local fs = require 'nelua.utils.fs'
local except = require 'nelua.utils.except'
local executor = require 'nelua.utils.executor'
local configer = require 'nelua.configer'
local syntaxdefs = require 'nelua.syntaxdefs'

local runner = {}

local function run(argv, redirect)
  -- parse config
  local config = configer.parse(argv)
  if config.no_color then console.set_colors_enabled(false) end

  if config.script then
    dofile(config.input)
    return 0
  end

  local generator = require('nelua.' .. config.generator .. 'generator')
  if config.timing then
    console.debugf('startup         %.1f ms', timer:elapsedrestart())
  end

  local syntax = syntaxdefs()
  if config.timing then
    console.debugf('compile grammar %.1f ms', timer:elapsedrestart())
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

  -- parse ast
  local parser = syntax.parser
  local ast = parser:parse(input, infile)

  if config.timing then
    console.debugf('parse AST       %.1f ms', timer:elapsedrestart())
  end

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
  -- profiler.start()
  local context = AnalyzerContext(analyzer.visitors, parser, ast, config.generator)
  except.try(function()
    context = analyzer.analyze(context)
  end, function(e)
    e.message = context:traceback() .. e:get_message()
  end)
  -- profiler.stop()
  -- profiler.report('profile.log')

  if config.timing then
    console.debugf('analyze AST     %.1f ms', timer:elapsedrestart())
  end

  if config.print_analyzed_ast then
    console.info(tostring(ast))
    return 0
  end

  if config.analyze then return 0 end

  -- generate the code
  local code, compileopts = generator.generate(ast, context)

  if config.timing then
    console.debugf('generate code   %.1f ms', timer:elapsedrestart())
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
  local outfile = config.output or outcacheprefix
  local compiler = generator.compiler
  local sourcefile = compiler.compile_code(code, outcacheprefix, compileopts)

  if config.timing then
    console.debugf('compile code    %.1f ms', timer:elapsedrestart())
  end

  local dorun = not config.compile and not config.compile_binary
  local dobinarycompile = config.compile_binary or dorun

  -- compile the generated code
  local binaryfile, isexe
  if dobinarycompile then
    binaryfile, isexe = compiler.compile_binary(sourcefile, outfile, compileopts)

    if not isexe then
      if not config.quiet then console.info('library compiled!') end
      return 0
    end
    if config.timing then
      console.debugf('compile binary  %.1f ms', timer:elapsedrestart())
    end
  end

  -- run
  if dorun then
    local exe, exeargs = compiler.get_run_command(binaryfile, config.runargs)
    if not config.quiet then console.info(exe .. ' ' .. table.concat(exeargs, ' ')) end
    local exec = redirect and executor.execex or executor.exec
    local _, status, sout, serr = exec(exe, exeargs, redirect)
    if sout then io.stdout:write(sout) io.stdout:flush() end
    if serr then io.stderr:write(serr) io.stderr:flush() end
    if config.timing then
      console.debugf('run             %.1f ms', timer:elapsedrestart())
    end
    return status
  end

  return 0
end

function runner.run(argv, redirect)
  local status
  except.try(function()
    status = run(argv, redirect)
  end, function(e)
    console.logerr(e:get_message())
    status = 1
    return true
  end)
  return status
end

return runner
