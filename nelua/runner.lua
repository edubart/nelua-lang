local timer = require 'nelua.utils.nanotimer'()
local stringer = require 'nelua.utils.stringer'
local console = require 'nelua.utils.console'
local fs = require 'nelua.utils.fs'
local except = require 'nelua.utils.except'
local executor = require 'nelua.utils.executor'
local configer = require 'nelua.configer'
local syntaxdefs = require 'nelua.syntaxdefs'
local typechecker = require 'nelua.typechecker'

local runner = {}

local function run(argv, redirect)
  -- parse config
  local config = configer.parse(argv)
  local generator = require('nelua.' .. config.generator .. 'generator')
  if config.timing then
    console.debugf('startup         %.1f ms', timer:elapsed_restart())
  end

  local syntax = syntaxdefs(config.standard)
  if config.timing then
    console.debugf('compile grammar %.1f ms', timer:elapsed_restart())
  end


  -- determine input
  local input = config.input
  local infile
  if not config.eval then
    infile = input
    input = fs.readfile(input)
  end

  -- parse ast
  local parser = syntax.parser
  local ast = parser:parse(input, infile)

  if config.timing then
    console.debugf('parse AST       %.1f ms', timer:elapsed_restart())
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

  -- analyze the ast
  local context
  ast, context = typechecker.analyze(ast, parser.astbuilder)

  if config.timing then
    console.debugf('analyze AST     %.1f ms', timer:elapsed_restart())
  end

  if config.print_analyzed_ast then
    console.info(tostring(ast))
    return 0
  end

  if config.analyze then return 0 end

  -- generate the code
  local code, compileopts = generator.generate(ast, context)

  if config.timing then
    console.debugf('generate code   %.1f ms', timer:elapsed_restart())
  end

  -- only printing generated code?
  if config.print_code then
    console.info(code)
    return 0
  end

  -- choose a infile for evals
  if not infile then infile = 'eval_' .. stringer.hash(code) end

  -- save the generated code
  local outcachefile = fs.getcachepath(infile, config.cache_dir)
  local compiler = generator.compiler
  local sourcefile = compiler.compile_code(code, outcachefile, compileopts)

  if config.timing then
    console.debugf('compile code    %.1f ms', timer:elapsed_restart())
  end

  local dorun = not config.compile and not config.compile_binary
  local dobinarycompile = config.compile_binary or dorun

  -- compile the generated code
  local binaryfile
  if dobinarycompile then
    binaryfile = compiler.compile_binary(sourcefile, outcachefile, compileopts)

    if config.timing then
      console.debugf('compile binary  %.1f ms', timer:elapsed_restart())
    end
  end

  -- run
  if dorun then
    local exe, exeargs = compiler.get_run_command(binaryfile, config.runargs)
    if not config.quiet then console.info(exe .. ' ' .. table.concat(exeargs, ' ')) end
    local exec = redirect and executor.execex or executor.exec
    local success, status, sout, serr = exec(exe, exeargs, redirect)
    if sout then io.stdout:write(sout) io.stdout:flush() end
    if serr then io.stderr:write(serr) io.stderr:flush() end
    if config.timing then
      console.debugf('run             %.1f ms', timer:elapsed_restart())
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
