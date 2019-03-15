local euluna_parser = require 'euluna.parsers.euluna_parser'
local plfile = require 'pl.file'
local plutil = require 'pl.utils'
local tablex = require 'pl.tablex'
local configer = require 'euluna.configer'
local runner = {}

function runner.run(argv)
  local config = configer.parse(argv)

  local input = config.input
  local infile
  if not config.eval then
    infile = input
    input = assert(plfile.read(input))
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
  local dobinarycompile = config.compile_binary or dorun

  sourcefile = compiler.compile_code(code, outcachefile)

  if dobinarycompile then
    binaryfile = compiler.compile_binary(sourcefile, outcachefile)
  end

  if dorun then
    local cmd = compiler.get_run_command(binaryfile)
    if not config.quiet then
      print(cmd)
    end

    local runargs = tablex.copy(config.args)
    tablex.transform(function(a) return plutil.quote_arg(a) end, runargs)
    runargs = table.concat(runargs, ' ')

    local ok,status,sout,serr = plutil.executeex(cmd, runargs)
    assert(ok, "failed to run the compiled program!")
    if sout then io.stdout:write(sout) end
    if serr then io.stderr:write(serr) end
    return status
  end

  return 0
end

return runner
