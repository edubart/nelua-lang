local pldir = require 'pl.dir'
local plfile = require 'pl.file'
local plutil = require 'pl.utils'
local plpath = require 'pl.path'
local pltemplate = require 'pl.template'
local cpp_compiler = {}

local compilers = {
  gcc = {
    exe = "g++",
    cppflags = "-Wall -Wextra -std=c++17",
    compile_obj = "$(exe) $(cppflags) -o $(outfile) -c $(inputfile)",
    compile_program = "$(exe) $(cppflags) -o $(outfile) $(inputfile)"
  }
}

function cpp_compiler.compile(code, outfile, args)
  local compiler = compilers.gcc

  pldir.makepath('euluna_cache')

  local sourcefile = plpath.join('euluna_cache', outfile .. '.cpp')
  assert(plfile.write(sourcefile, code))

  local env = {inputfile = sourcefile, outfile = outfile}
  setmetatable(env, {__index = compiler})
  local cmd = pltemplate.substitute(compiler.compile_program, env)
  --print(cmd)
  local ok, ret, stdout, stderr = plutil.executeex(cmd)
  assert(stderr == '', stderr)
  assert(ok and ret == 0, "compilation failed")
end

function cpp_compiler.compile_and_run(code, outfile, compile_args, run_args)
  if outfile == nil then
    outfile = 'a.out'
  end
  cpp_compiler.compile(code, outfile, compile_args)
  local cmd = './' .. outfile
  if run_args then
    cmd = cmd .. run_args
  end
  --print(cmd)
  return plutil.executeex(cmd)
end

return cpp_compiler