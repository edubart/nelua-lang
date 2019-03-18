local plfile = require 'pl.file'
local plutil = require 'pl.utils'
local plpath = require 'pl.path'
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

local function succeed(msg)
  io.stdout:write(msg)
  io.stdout:write('\n')
  io.stdout:flush()
  return 0
end

local function fail(err)
  io.stderr:write(err)
  io.stderr:write('\n')
  io.stderr:flush()
  return 1
end

function runner.run(argv)
  -- parse config
  local err
  config, err = configer.parse(argv)
  if not config then return fail(err) end

  -- determine input
  local input = config.input
  local infile
  if not config.eval then
    infile = input
    print(infile)
    input,err = plfile.read(input)
    if not input then return fail(err) end
  end

  -- parse ast
  local ast
  local parser = require('euluna.parsers.euluna_std_' .. config.standard).parser
  ast, err = parser:parse(input)
  if not ast then return fail(err) end

  -- only checking syntax?
  if config.lint then return 0 end

  -- only printing ast?
  if config.print_ast then return succeed(tostring(ast)) end

  -- generate the code
  local generator = require('euluna.generators.' .. config.generator .. '_generator')
  local code
  code, err = generator:generate(ast)
  if not ast then return fail(err) end

  -- only printing generated code?
  if config.print_code then return succeed(code) end

  -- choose a infile for evals
  if not infile then infile = 'eval_' .. sha1(code) end

  -- save the generated code
  local outcachefile = get_outcachepath(infile)
  local sourcefile, binaryfile
  local compiler = generator.compiler
  sourcefile, err = compiler.compile_code(code, outcachefile)
  if not sourcefile then return fail(err) end

  local dorun = not config.compile and not config.compile_binary
  local dobinarycompile = config.compile_binary or dorun

  -- compile the generated code
  if dobinarycompile then
    binaryfile, err = compiler.compile_binary(sourcefile, outcachefile)
    if not binaryfile then return fail(err) end
  end

  -- run
  if dorun then
    local cmd = compiler.get_run_command(binaryfile)
    local runargs = configer.get_run_args()
    if not config.quiet then print(cmd .. ' ' .. runargs) end

    local ok,status,sout,serr = plutil.executeex(cmd, runargs)
    if sout then io.stdout:write(sout) end
    if serr then io.stderr:write(serr) end
    if not ok then return 1 end
    return status
  end

  return 0
end

return runner
