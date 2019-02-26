local argparse = require 'argparse'
local euluna_parser = require 'euluna.parsers.euluna_parser'
local lua_generator = require 'euluna.generators.lua_generator'
local lua_compiler = require 'euluna.compilers.lua_compiler'
local plfile = require 'pl.file'

local runner = {}

runner.stderr = io.stderr
runner.stdout = io.stdout

function runner.run(...)
  local argv = nil
  if select(1, ...) then
    argv = {...}
  end

  local argparser = argparse("euluna", "Euluna v0.1")
  argparser:argument("input", "Input source file")
  --argparser:flag('--print-ast', 'Print the AST only')
  argparser:flag('-e --eval', 'Evaluate string code from input')
  argparser:flag('-l --lint', 'Only check syntax errors')
  argparser:flag('-g --print-code', 'Print the generated code only')
  local options = argparser:parse(argv)

  local input
  if options.eval then
    input = options.input
  else
    input = assert(plfile.read(options.input))
  end

  local ast, err = euluna_parser:parse(input)

  if not ast then
    runner.stderr:write(err)
    return 1
  end

  if options.lint then return end

  --[[
  if options.print_ast then
    print(ast:tostring())
    return
  end
  ]]

  local code = lua_generator:generate(ast)

  if options.print_code then
    runner.stdout:write(code)
    return 0
  end

  local ok,status,sout,serr = lua_compiler.run(code)

  if sout then runner.stdout:write(sout) end
  if serr then runner.stderr:write(serr) end
  return status
end

return runner
