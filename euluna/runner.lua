local stringer = require 'euluna.utils.stringer'
local fs = require 'euluna.utils.fs'
local except = require 'euluna.utils.except'
local executor = require 'euluna.utils.executor'
local errorer = require 'euluna.utils.errorer'
local configer = require 'euluna.configer'
local config = configer.get()
local runner = {}

local function run(argv)
  -- parse config
  config = configer.parse(argv)

  -- determine input
  local input = config.input
  local infile
  if not config.eval then
    infile = input
    input = fs.readfile(input)
  end

  -- parse ast
  local parser = require('euluna.parsers.euluna_std_' .. config.standard).parser
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
  local type_analizer = require 'euluna.analyzers.types.analyzer'
  ast = type_analizer.analyze(ast)

  if config.analyze then return 0 end

  -- generate the code
  local generator = require('euluna.generators.' .. config.generator .. '.generator')
  local code = generator.generate(ast)

  -- only printing generated code?
  if config.print_code then
    print(code)
    return 0
  end

  -- choose a infile for evals
  if not infile then infile = 'eval_' .. stringer.sha1(code) end

  -- save the generated code
  local outcachefile = fs.getcachepath(infile, config.cache_dir)
  local compiler = generator.compiler
  local sourcefile = compiler.compile_code(code, outcachefile)

  local dorun = not config.compile and not config.compile_binary
  local dobinarycompile = config.compile_binary or dorun

  -- compile the generated code
  local binaryfile
  if dobinarycompile then
    binaryfile = compiler.compile_binary(sourcefile, outcachefile)
  end

  -- run
  if dorun then
    local command = executor.build_command(compiler.get_run_command(binaryfile), config.runargs)
    if not config.quiet then print(command) end
    local success, status = executor.exec(command)
    return status
  end

  return 0
end

function runner.run(argv)
  local status
  except.try(function()
    status = run(argv)
  end, function(e)
    errorer.errprint(e:get_message())
    status = 1
    return true
  end)
  return status
end

return runner
