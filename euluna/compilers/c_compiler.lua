local pldir = require 'pl.dir'
local plfile = require 'pl.file'
local plpath = require 'pl.path'
local plutil = require 'pl.utils'
local pltemplate = require 'pl.template'
local config = require 'euluna.configer'.get()
local sha1 = require 'sha1'.sha1
local assertf = require 'euluna.utils'.assertf
local c_compiler = {}

local function get_compile_command(infile, outfile)
  -- generate compile command
  local env = {infile = infile, outfile = outfile}
  env.exe = os.getenv('CC')
  env.cflags = os.getenv('CFLAGS')
  env.ldflags = os.getenv('LDFLAGS')
  setmetatable(env, {__index = config})
  local cmd = pltemplate.substitute("$(cc) $(cflags) -o $(outfile) $(ldflags) $(infile)", env)
  return cmd
end

local function hash_compilation(code, cmd)
  return sha1(code .. cmd)
end

function c_compiler.choose_codefile_name(code, infile)
  local prefix = ''
  if infile then
    prefix = infile:gsub('%.[^.]+$','') .. '_'
  end

  -- generate an outfile name from a hash
  local dummycmd = get_compile_command(prefix .. '.c', prefix)
  local hash = hash_compilation(code, dummycmd)
  local sourcefile = plpath.join(config.cache_dir, prefix .. hash)
  return sourcefile
end

function c_compiler.compile_code(ccode, outfile)
  local cfile = outfile .. '.c'

  -- create output directory if needed
  local outdir = plpath.dirname(cfile)
  pldir.makepath(outdir)

  -- save sources to a file
  assert(plfile.write(cfile, ccode))
  if not config.quiet then
    print("generated " .. cfile)
  end

  return cfile
end

function c_compiler.compile_binary(cfile, outfile)
  -- if the file with that hash already exists skip recompiling it
  if not config.no_cache and plpath.isfile(outfile) then
    if not config.quiet then
      print("using cached binary " .. outfile)
    end
    return outfile
  end

  -- create output directory if needed
  local outdir = plpath.dirname(outfile)
  pldir.makepath(outdir)

  -- generate compile command
  local cmd = get_compile_command(cfile, outfile)
  if not config.quiet then
    print(cmd)
  end

  -- compile the file
  local ok, ret, stdout, stderr = plutil.executeex(cmd)
  if stdout and not config.quiet and #stdout > 0 then io.stdout:write(stdout) end
  assertf(ok and ret == 0, "compilation failed:\n%s", stderr)

  return outfile
end

function c_compiler.get_run_command(binaryfile)
  return './' .. binaryfile
end

return c_compiler
