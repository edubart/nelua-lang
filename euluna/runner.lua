local plutil = require 'pl.utils'
local stringer = require 'euluna.utils.stringer'
local fs = require 'euluna.utils.fs'
local except = require 'euluna.utils.except'
local configer = require 'euluna.configer'
local config = configer.get()
local runner = {}

local function succeed(msg)
  if msg then
    io.stdout:write(msg)
    io.stdout:write('\n')
    io.stdout:flush()
  end
  return 0
end

local function fail(err)
  io.stderr:write(tostring(err))
  io.stderr:write('\n')
  io.stderr:flush()
  return 1
end

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
  if config.lint then return succeed() end

  -- only printing ast?
  if config.print_ast then return succeed(tostring(ast)) end

  -- analyze the ast
  local type_analizer = require 'euluna.analyzers.types.analyzer'
  ast = type_analizer.analyze(ast)

  if config.analyze then return succeed() end

  -- generate the code
  local generator = require('euluna.generators.' .. config.generator .. '.generator')
  local code = generator.generate(ast)

  -- only printing generated code?
  if config.print_code then return succeed(code) end

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
    local cmd = compiler.get_run_command(binaryfile)
    local runargs = configer.get_run_args()
    if not config.quiet then print(cmd .. ' ' .. runargs) end

    local ok,status,sout,serr = plutil.executeex(cmd, runargs)
    if sout then io.stdout:write(sout) end
    if serr then io.stderr:write(serr) end
    if not ok then return fail('execution failed') end
    return status
  end

  return succeed()
end

function runner.run(argv)
  local status
  except.try(function()
    status = run(argv)
  end, function(e)
    status = fail(e)
    return true
  end)
  return status
end

return runner
