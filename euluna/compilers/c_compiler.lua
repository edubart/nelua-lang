local pldir = require 'pl.dir'
local plfile = require 'pl.file'
local plutil = require 'pl.utils'
local plpath = require 'pl.path'
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
  setmetatable(env, {__index = config})
  local cmd = pltemplate.substitute("$(cc) $(cflags) -o $(outfile) $(infile)", env)
  return cmd
end

local function hash_compilation(code, cmd)
  return sha1(code .. cmd)
end

function c_compiler.compile(code, outfile)
  local infile = outfile .. '.c'
  local outdir = plpath.dirname(outfile)

  --[[
  local cache_dir = config.cache_dir
  local tocache = stringx.startswith(outdir, cache_dir)
  if not tocache then
    outdir = plpath.join(cache_dir, plpath.dirname(outfile))
    infile = plpath.join(cache_dir, infile)
  end
  ]]

  -- create output directory if needed
  pldir.makepath(outdir)

  -- save sources to a file
  assert(plfile.write(infile, code))

  -- generate compile command
  local cmd = get_compile_command(infile, outfile)
  if not config.quiet then
    print(cmd)
  end

  -- compile the file
  local ok, ret, stdout, stderr = plutil.executeex(cmd)
  if stdout and not config.quiet then
    if #stdout > 0 then io.stdout:write(stdout) end
  end
  assertf(ok and ret == 0, "compilation failed:\n%s", stderr)
end

function c_compiler.run(code, infile, outfile) --, run_args)
  local skip_compilation = false

  local prefix = ''
  if infile then
    prefix = infile:gsub('%.[^.]+$','') .. '_'
  end

  -- generate an outfile name from a hash
  if outfile == nil then
    local dummycmd = get_compile_command(prefix .. '.c', prefix, config)
    local hash = hash_compilation(code, dummycmd)
    outfile = plpath.join(config.cache_dir, prefix .. hash)

    -- if the file with that hash already exists skip recompiling it
    if not config.no_cache and plpath.isfile(outfile) then
      skip_compilation = true
    end
  end

  if not skip_compilation then
    -- create output directory if needed
    local outdir = plpath.dirname(outfile)
    if outdir ~= '' then pldir.makepath(outdir) end

    -- compile
    c_compiler.compile(code, outfile, config)
  end

  -- run
  local cmd = './' .. outfile
  --if run_args then
  --  cmd = cmd .. run_args
  --end

  if not config.quiet then
    print(cmd)
  end

  return plutil.executeex(cmd)
end

return c_compiler
