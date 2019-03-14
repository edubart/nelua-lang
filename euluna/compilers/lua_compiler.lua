local pldir = require 'pl.dir'
local plfile = require 'pl.file'
local plpath = require 'pl.path'
local pltemplate = require 'pl.template'
local sha1 = require 'sha1'.sha1
local config = require 'euluna.configer'.get()
local lua_compiler = {}

function lua_compiler.choose_codefile_name(code, infile)
  local prefix = ''
  if infile then
    prefix = infile:gsub('%.[^.]+$','') .. '_'
  end

  local hash = sha1(prefix .. code)
  local sourcefile = plpath.join(config.cache_dir, prefix .. hash)
  return sourcefile
end

function lua_compiler.compile_code(ccode, outfile)
  local luafile = outfile .. '.lua'

  -- create output directory if needed
  local outdir = plpath.dirname(luafile)
  pldir.makepath(outdir)

  -- save sources to a file
  assert(plfile.write(luafile, ccode))
  if not config.quiet then
    print("generated " .. luafile)
  end

  return luafile
end

function lua_compiler.compile_binary(luafile)
  return luafile
end

function lua_compiler.get_run_command(binaryfile)
  -- generate compile command
  local env = {binaryfile = binaryfile}
  setmetatable(env, {__index = config})
  return pltemplate.substitute("$(lua) $(lua_options) $(binaryfile)", env)
end

return lua_compiler
