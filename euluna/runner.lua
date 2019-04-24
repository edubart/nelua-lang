local stringer = require 'euluna.utils.stringer'
local fs = require 'euluna.utils.fs'
local except = require 'euluna.utils.except'
local executor = require 'euluna.utils.executor'
local errorer = require 'euluna.utils.errorer'
local configer = require 'euluna.configer'
local syntaxdefs = require 'euluna.syntaxdefs'
local typechecker = require 'euluna.typechecker'

local runner = {}

local function run(argv, redirect)
  -- parse config
  local config = configer.parse(argv)

  -- determine input
  local input = config.input
  local infile
  if not config.eval then
    infile = input
    input = fs.readfile(input)
  end

  -- parse ast
  local syntax = syntaxdefs(config.standard)
  local parser = syntax.parser
  local ast = parser:parse(input, infile)

  -- only checking syntax?
  if config.lint then
    return 0
  end

  -- only printing ast?
  if config.print_ast then
    print(tostring(ast))
    return 0
  end

  -- analyze the ast
  ast = typechecker.analyze(ast, parser.astbuilder)

  if config.print_analyzed_ast then
    print(tostring(ast))
    return 0
  end

  if config.analyze then return 0 end

  -- generate the code
  local generator = require('euluna.' .. config.generator .. 'generator')
  local code, compileopts = generator.generate(ast)

  -- only printing generated code?
  if config.print_code then
    print(code)
    return 0
  end

  -- choose a infile for evals
  if not infile then infile = 'eval_' .. stringer.hash(code) end

  -- save the generated code
  local outcachefile = fs.getcachepath(infile, config.cache_dir)
  local compiler = generator.compiler
  local sourcefile = compiler.compile_code(code, outcachefile, compileopts)

  local dorun = not config.compile and not config.compile_binary
  local dobinarycompile = config.compile_binary or dorun

  -- compile the generated code
  local binaryfile
  if dobinarycompile then
    binaryfile = compiler.compile_binary(sourcefile, outcachefile, compileopts)
  end

  -- run
  if dorun then
    local exe, exeargs = compiler.get_run_command(binaryfile, config.runargs)
    if not config.quiet then print(exe .. ' ' .. table.concat(exeargs, ' ')) end
    local exec = redirect and executor.execex or executor.exec
    local success, status, sout, serr = exec(exe, exeargs, redirect)
    if sout then io.stdout:write(sout) io.stdout:flush() end
    if serr then io.stderr:write(serr) io.stderr:flush() end
    return status
  end

  return 0
end

function runner.run(argv, redirect)
  local status
  except.try(function()
    status = run(argv, redirect)
  end, function(e)
    errorer.errprint(e:get_message())
    status = 1
    return true
  end)
  return status
end

return runner
