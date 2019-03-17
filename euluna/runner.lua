local euluna_parser = require 'euluna.parsers.euluna_parser'
local plfile = require 'pl.file'
local plutil = require 'pl.utils'
local plpath = require 'pl.path'
local tablex = require 'pl.tablex'
local configer = require 'euluna.configer'
local config = configer.get()
local sha1 = require 'sha1'.sha1
local runner = {}

local function get_outcachepath(infile)
  local path = infile:gsub('%.[^.]+$','')
  path = plpath.relpath(path)
  path = path:gsub('%.%.[/\\]+', '')
  path = plpath.join(config.cache_dir, path)
  path = plpath.normpath(path)
  return path
end

function runner.run(argv)
  configer.parse(argv)

  local input = config.input
  local infile
  if not config.eval then
    infile = input
    input = assert(plfile.read(input))
  end

  local ast, parseerr = euluna_parser:parse(input)
  if not ast then
    io.stderr:write(parseerr)
    return 1
  end

  if config.lint then return 0 end

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

  if not infile then
    infile = 'eval_' .. sha1(code)
  end

  local outcachefile = get_outcachepath(infile)
  local sourcefile = compiler.compile_code(code, outcachefile)

  local dorun = not config.compile and not config.compile_binary
  local dobinarycompile = config.compile_binary or dorun
  local binaryfile

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
