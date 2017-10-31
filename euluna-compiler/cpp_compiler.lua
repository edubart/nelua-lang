local pldir = require 'pl.dir'
local plfile = require 'pl.file'
local plutil = require 'pl.utils'
local plpath = require 'pl.path'
local pltemplate = require 'pl.template'
local stringx = require 'pl.stringx'
local util = require 'euluna-compiler.util'
local cpp_compiler = {}

local cache_dir = 'euluna_cache'
local compilers = {
  gcc = {
    exe = "g++",
    cppflags = "-Wall -Wextra -std=c++14",
    compile_obj = "$(exe) $(cppflags) -o $(outfile) -c $(inputfile)",
    compile_program = "$(exe) $(cppflags) -o $(outfile) $(inputfile)"
  }
}

local function get_compile_command(inputfile, outfile, options)
  -- choose the compiler
  local compiler = compilers.gcc
  if options.compiler and compilers[options.compiler] then
    compiler = compilers[options.compiler]
  end

  -- generate compile command
  local env = {inputfile = inputfile, outfile = outfile}
  setmetatable(env, {__index = compiler})
  local cmd = pltemplate.substitute(compiler.compile_program, env)
  return cmd
end

function cpp_compiler.compile(code, outfile, options)
  options = options or {}

  local inputfile = outfile .. '.cpp'
  local outdir = plpath.dirname(outfile)
  local tocache = stringx.startswith(outdir, cache_dir)
  if not tocache then
    outdir = plpath.join(cache_dir, plpath.dirname(outfile))
    inputfile = plpath.join(cache_dir, inputfile)
  end

  -- create output directory if needed
  pldir.makepath(outdir)

  -- save sources to a file
  assert(plfile.write(inputfile, code))

  -- generate compile command
  local cmd = get_compile_command(inputfile, outfile, options)
  if not options.quiet then
    print(cmd)
  end

  -- compile the file
  local ok, ret, stdout, stderr = plutil.executeex(cmd)
  assert(stderr == '', stderr)
  assert(ok and ret == 0, "compilation failed")
end

local function hash_compilation(code, cmd)
  return util.sha1sum(code .. cmd)
end

function cpp_compiler.compile_and_run(code, outfile, options, run_args)
  options = options or {}

  local skip_compilation = false

  -- generate an outfile name from a hash
  if outfile == nil then
    local dummycmd = get_compile_command('dummy.cpp', 'dummy', options)
    outfile = plpath.join(cache_dir, hash_compilation(code, dummycmd))

    -- if the file with that hash already exists skip recompiling it
    if plpath.isfile(outfile) then
      skip_compilation = true
    end
  end

  if not skip_compilation then
    -- create output directory if needed
    local outdir = plpath.dirname(outfile)
    if outdir ~= '' then
      pldir.makepath(outdir)
    end

    -- compile
    cpp_compiler.compile(code, outfile, options)
  end

  -- run
  local cmd = './' .. outfile
  if run_args then
    cmd = cmd .. run_args
  end

  if not options.quiet then
    print(cmd)
  end

  return plutil.executeex(cmd)
end

return cpp_compiler