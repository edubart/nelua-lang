local euluna_parser = require 'euluna.parsers.euluna_parser'
local plfile = require 'pl.file'
local plutil = require 'pl.utils'
local configer = require 'euluna.configer'
local runner = {}

function runner.run(argv)
  local config = configer.parse(argv)

  local input
  local infile
  if config.eval then
    input = config.input
  else
    input = assert(plfile.read(config.input))
    infile = config.input
  end

  local ast = assert(euluna_parser:parse(input))

  if config.lint then return end

  if config.print_ast then
    print(tostring(ast))
    return 0
  end

  local generator = require('euluna.generators.' .. config.generator .. '_generator')
  local code = generator:generate(ast)

  if config.print_code then
    io.stdout:write(code)
    return 0
  end

  local compiler = generator.compiler

  local outcachefile = compiler.choose_codefile_name(code, infile)
  local sourcefile
  local binaryfile
  local dorun = not config.compile and not config.compile_binary

  if config.compile_binary or config.compile or dorun then
    sourcefile = compiler.compile_code(code, outcachefile)
  end

  if config.compile_binary or dorun then
    binaryfile = compiler.compile_binary(sourcefile, outcachefile)
  end

  if dorun then
    local cmd = compiler.get_run_command(binaryfile)
    if not config.quiet then
      print(cmd)
    end

    local ok,status,sout,serr = plutil.executeex(cmd)
    assert(ok, "failed to run the compiled program!")
    if sout then io.stdout:write(sout) end
    if serr then io.stderr:write(serr) end
    return status
  end

  return 0
end

return runner
