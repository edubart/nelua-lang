local pegger = require 'nelua.utils.pegger'
local stringer = require 'nelua.utils.stringer'
local fs = require 'nelua.utils.fs'
local except = require 'nelua.utils.except'
local executor = require 'nelua.utils.executor'
local tabler = require 'nelua.utils.tabler'
local sstream = require 'nelua.utils.sstream'
local console = require 'nelua.utils.console'
local config = require 'nelua.configer'.get()
local cdefs = require 'nelua.cdefs'
local memoize = require 'nelua.utils.memoize'
local version = require 'nelua.version'
local iterators = require 'nelua.utils.iterators'
local platform = require 'nelua.utils.platform'

local compiler = {
  source_extension = '.c'
}

function compiler.has_source_extension(filename)
  return filename:find('%.[ch]$')
end

local function get_compiler_flags(cc)
  local foundccflags, foundccname
  for ccname,ccflags in iterators.ospairs(cdefs.compilers_flags) do
    if cc == ccname then
      return ccflags
    end
    if stringer.endswith(cc, ccname) and (not foundccname or #ccname > #foundccname) then
      foundccflags, foundccname = ccflags, ccname
    end
  end
  --luacov:disable
  return foundccflags or cdefs.compilers_flags.cc
end --luacov: enable

local function get_compiler_cflags(compileopts)
  local ccinfo = compiler.get_cc_info()
  local ccflags = get_compiler_flags(config.cc)
  local cflags = sstream()
  --luacov:disable
  for _,cfile in ipairs(compileopts.cfiles) do
    cflags:add(' "'..cfile..'"')
  end
  for _,incdir in ipairs(compileopts.incdirs) do
    cflags:add(' -I "'..incdir..'"')
  end
  cflags:add(' '..ccflags.cflags_base)
  if config.sanitize then
    if ccflags.cflags_sanitize and #ccflags.cflags_sanitize > 0 then
      cflags:add(' '..ccflags.cflags_sanitize)
    end
    if config.cflags_sanitize and #config.cflags_sanitize then
      cflags:add(' '..config.cflags_sanitize)
    end
  end
  if config.maximum_performance then
    if ccflags.cflags_maximum_performance and #ccflags.cflags_maximum_performance > 0 then
      cflags:add(' '..ccflags.cflags_maximum_performance)
    end
    if config.cflags_maximum_performance and #config.cflags_maximum_performance > 0 then
      cflags:add(' '..config.cflags_maximum_performance)
    end
  elseif config.release then
    if ccflags.cflags_release and #ccflags.cflags_release > 0 then
      cflags:add(' '..ccflags.cflags_release)
    end
    if config.cflags_release and #config.cflags_release then
      cflags:add(' '..config.cflags_release)
    end
  elseif config.debug then
    if ccflags.cflags_debug and #ccflags.cflags_debug > 0 then
      cflags:add(' '..ccflags.cflags_debug)
    end
    if config.cflags_debug and #config.cflags_debug > 0 then
      cflags:add(' '..config.cflags_debug)
    end
  else
    if ccflags.cflags_devel and #ccflags.cflags_devel > 0 then
      cflags:add(' '..ccflags.cflags_devel)
    end
    if config.cflags_devel and #config.cflags_devel > 0 then
      cflags:add(' '..config.cflags_devel)
    end
  end
  if config.shared then
    cflags:add(' '..ccflags.cflags_shared)
  elseif config.static then
    cflags:add(' '..ccflags.cflags_static)
  end
  if #config.cflags > 0 then
    cflags:add(' '..config.cflags)
  end
  --luacov:enable
  if #compileopts.cflags > 0 then
    cflags:add(' ')
    cflags:addlist(compileopts.cflags, ' ')
  end
  if not config.static then
    if #compileopts.ldflags > 0 then
      cflags:add(' -Wl,')
      cflags:addlist(compileopts.ldflags, ',')
    end
    if #compileopts.linklibs > 0 then
      cflags:add(' -l')
      cflags:addlist(compileopts.linklibs, ' -l')
    end
    if ccinfo.is_linux and not ccinfo.is_mirc then -- always link math library on linux
      cflags:add(' -lm')
    end
  end
  return cflags:tostring():sub(2)
end

local function get_compile_args(cfile, binfile, cflags)
  local ccflags = get_compiler_flags(config.cc)
  local templatedefs = {
    cfile = cfile,
    binfile = binfile,
    cflags = cflags,
    cc = config.cc
  }
  local cmd = ccflags.cmd_compile
  while true do
    local newcmd = pegger.substitute(cmd, templatedefs)
    if newcmd == cmd then break end
    cmd = newcmd
  end
  return cmd
end

local function gen_source_file(cc, code)
  local ccflags = get_compiler_flags(cc)
  local cfile = fs.tmpname()
  fs.deletefile(cfile)
  cfile = cfile..ccflags.ext
  fs.ewritefile(cfile, code)
  return cfile
end

local function get_cc_defines(cc, cflags, ...)
  local ccflags = get_compiler_flags(cc)
  local code = {}
  for i=1,select('#', ...) do
    local header = select(i, ...)
    code[#code+1] = '#include ' .. header
  end
  code = table.concat(code, '\n')
  local cfile = gen_source_file(cc, code)
  local cccmd = pegger.substitute(ccflags.cmd_defines, {
    cfile = cfile,
    cflags = cflags,
    cc = config.cc
  })
  local stdout, stderr = executor.evalex(cccmd)
  fs.deletefile(cfile)
  if not stdout then --luacov:disable
    except.raisef("failed to retrieve compiler defines: %s", stderr)
  end --luacov:enable
  return pegger.parse_c_defines(stdout)
end
get_cc_defines = memoize(get_cc_defines)

function compiler.get_cc_defines(...)
  return get_cc_defines(config.cc, config.cflags, ...)
end

local function get_cc_info(cc, cflags)
  -- parse compiler information and target features
  local cfile = gen_source_file(cc, cdefs.target_info_code)
  local ccflags = get_compiler_flags(cc)
  local cccmd = pegger.substitute(ccflags.cmd_info, {
    cfile = cfile,
    cflags = cflags,
    cc = config.cc
  })
  local stdout, stderr = executor.evalex(cccmd)
  fs.deletefile(cfile)
  if not stdout then
    except.raisef("failed to retrieve compiler information: %s", stderr)
  end
  local ccinfo = {}
  for name,value in stdout:gmatch('([a-zA-Z0-9_]+)%s*=%s*([^;\n]+);') do
    if value:match('^[0-9]+L$') then
      value = tonumber(value:sub(1,-2))
    elseif value:match('^[0-9]+$') then
      value = tonumber(value)
    elseif value == 'true' then
      value = true
    elseif value:match('^".*"$') then
      value = value:sub(2,-2)
    end
    ccinfo[name] = value
  end
  ccinfo.sizeof_pointer = ccinfo.sizeof_pointer or platform.cpu_bits // 8
  ccinfo.sizeof_int = ccinfo.sizeof_int or math.max(math.min(ccinfo.sizeof_pointer, 4), 2)
  ccinfo.sizeof_short = ccinfo.sizeof_short or 2
  ccinfo.sizeof_long = ccinfo.sizeof_long or math.max(ccinfo.sizeof_pointer, 4)
  ccinfo.sizeof_long_long = ccinfo.sizeof_long_long or 8
  ccinfo.sizeof_long_double = ccinfo.sizeof_long_double or 16
  ccinfo.sizeof_float = ccinfo.sizeof_float or 4
  ccinfo.sizeof_double = ccinfo.sizeof_double or 8
  ccinfo.flt_decimal_dig = ccinfo.flt_decimal_dig or 9
  ccinfo.flt_dig = ccinfo.flt_dig or 6
  ccinfo.flt_mant_dig = ccinfo.flt_mant_dig or 24
  ccinfo.dbl_decimal_dig = ccinfo.dbl_decimal_dig or 17
  ccinfo.dbl_dig = ccinfo.dbl_dig or 15
  ccinfo.dbl_mant_dig = ccinfo.dbl_mant_dig or 53
  ccinfo.ldbl_decimal_dig = ccinfo.ldbl_decimal_dig or 21
  ccinfo.ldbl_dig = ccinfo.ldbl_dig or 18
  ccinfo.ldbl_mant_dig = ccinfo.ldbl_mant_dig or 64
  ccinfo.flt128_decimal_dig = ccinfo.flt128_decimal_dig or 36
  ccinfo.flt128_dig = ccinfo.flt128_dig or 33
  ccinfo.flt128_mant_dig = ccinfo.flt128_mant_dig or 113
  ccinfo.biggest_alignment = ccinfo.biggest_alignment or
    math.max(ccinfo.sizeof_long_double, ccinfo.sizeof_long_long)
  if ccinfo.sizeof_pointer then -- ensure some primitive sizes3 have the expected sizes
    except.assertraisef(not ccinfo.char_bit or ccinfo.char_bit == 8,
      "target C 'char' is not 8 bits")
    except.assertraisef(not ccinfo.sizeof_ptrdiff_t or ccinfo.sizeof_ptrdiff_t == ccinfo.sizeof_pointer,
      "target C 'ptrdiff_t' size is different from the pointer size")
    except.assertraisef(not ccinfo.sizeof_size_t or ccinfo.sizeof_size_t == ccinfo.sizeof_pointer,
      "target C 'size_t' size is different from the pointer size")
  end
  return ccinfo
end
get_cc_info = memoize(get_cc_info)

function compiler.get_cc_info()
  return get_cc_info(config.cc, config.cflags)
end

function compiler.generate_code(ccode, cfile, compileopts)
  local ccinfo = compiler.get_cc_info().text
  local cflags = get_compiler_cflags(compileopts)
  local binfile = cfile:gsub('.c$','')
  local ccmd = get_compile_args(cfile, binfile, cflags)
  -- file heading
  local hash = stringer.hash(string.format("%s%s%s", ccode, ccinfo, ccmd))
  local heading = string.format(
[[/* Generated by %s */
/* Compile command: %s */
/* Compile hash: %s */
]], version.NELUA_VERSION, ccmd, hash)
  local sourcecode = heading .. ccode
  -- check if write is actually needed
  local current_sourcecode = fs.readfile(cfile)
  if not config.no_cache and current_sourcecode and current_sourcecode == sourcecode then
    if config.verbose then console.info("using cached generated " .. cfile) end
    return cfile
  end
  -- create file
  fs.eensurefilepath(cfile)
  fs.ewritefile(cfile, sourcecode)
  if config.verbose then console.info("generated " .. cfile) end
end

local function detect_binary_extension(outfile, ccinfo)
  --luacov:disable
  if ccinfo.is_wasm then
    if outfile:match('%.wasm$') then
      return '.wasm', true
    else
      return '.html', true
    end
  elseif ccinfo.is_windows or ccinfo.is_cygwin then
    if config.shared then
      return '.dll'
    elseif config.static then
      return '.a'
    else
      return '.exe', true
    end
  elseif ccinfo.is_apple then
    if config.shared then
      return '.dylib'
    elseif config.static then
      return '.a'
    else
      return '', true
    end
  elseif ccinfo.is_mirc then
    return '.bmir', true
  else
    if config.shared then
      return '.so'
    elseif config.static then
      return '.a'
    else
      return '', true
    end
  end
  --luacov:enable
end

local function find_ar()
  local ar = config.cc..'-ar' -- try cc-ar first
  --luacov:disable
  if not fs.findbinfile(ar) then
    local subar = config.cc:gsub('[%w+]+$', 'ar')
    if subar:find('ar$') then
      ar = subar
    end
  end
  if not fs.findbinfile(ar) then
    ar = 'ar'
  end
  --luacov:enable
  return ar
end

function compiler.compile_static_library(objfile, outfile)
  local ar = find_ar()
  local arcmd = string.format('%s rcs %s %s', ar, outfile, objfile)
  if config.verbose then console.info(arcmd) end
  -- compile the file
  local stdout, stderr = executor.evalex(arcmd)
  if not stdout then --luacov:disable
    except.raisef("static library compilation for '%s' failed:\n%s", outfile, stderr)
  end --luacov:enable
  if stderr then
    io.stderr:write(stderr)
  end
end

function compiler.setup_env(cflags)
  if config.sanitize or cflags:match('%-fsanitize=[%w_,-]*undefined') then
    -- enable sanitizer tracebacks for better debugging experience
    local sys = _G.sys
    if sys and sys.setenv then
      if not os.getenv('UBSAN_OPTIONS') then
        sys.setenv('UBSAN_OPTIONS', 'print_stacktrace=1')
      end
    end
  end
end

function compiler.compile_binary(cfile, outfile, compileopts)
  local cflags = get_compiler_cflags(compileopts)
  compiler.setup_env(cflags)
  local ccinfo = compiler.get_cc_info()
  local binext, isexe = detect_binary_extension(outfile, ccinfo)
  local binfile = outfile
  if not stringer.endswith(binfile, binext) then binfile = binfile .. binext end
  -- if the file with that hash already exists skip recompiling it
  if not config.no_cache then
    local cfile_mtime = fs.getmodtime(cfile)
    local binfile_mtime = fs.getmodtime(binfile)
    if cfile_mtime and binfile_mtime and cfile_mtime <= binfile_mtime then
      if config.verbose then console.info("using cached binary " .. binfile) end
      return binfile, isexe
    end
  end
  -- ensure the directory exists for the binary file
  fs.eensurefilepath(binfile)
  -- we may use an intermediary file
  local midfile = binfile
  if config.static then -- compile to an object first for static libraries
    midfile = binfile:gsub('.[a-z]+$', '.o')
  end
  -- generate compile command
  local cccmd = get_compile_args(cfile, midfile, cflags)
  if config.verbose then console.info(cccmd) end
  -- compile the file
  local stdout, stderr = executor.evalex(cccmd)
  if not stdout then --luacov:disable
    except.raisef("C compilation for '%s' failed:\n%s", binfile, stderr)
  end --luacov:enable
  if stderr then
    io.stderr:write(stderr)
  end
  -- compile static library
  if config.static then
    compiler.compile_static_library(midfile, binfile)
    fs.deletefile(midfile)
  end
  return binfile, isexe
end

function compiler.get_gdb_version() --luacov:disable
  local stdout = executor.evalex(config.gdb .. ' -v')
  if stdout and stdout:match("GNU gdb") then
    return stdout:match('%d+%.%d+')
  end
end --luacov:enable

function compiler.get_run_command(binaryfile, runargs, compileopts)
  binaryfile = fs.abspath(binaryfile)
  -- run with a gdb?
  if config.debug then --luacov:disable
    local gdbver = compiler.get_gdb_version()
    if gdbver then
      local gdbargs = {
        '-q',
        '-ex', 'set confirm off',
        '-ex', 'set breakpoint pending on',
        '-ex', 'break abort',
        '-ex', 'run',
        '-ex', 'bt -frame-info source-and-location',
        '-ex', 'quit',
        '--args', binaryfile,
      }
      tabler.insertvalues(gdbargs, runargs)
      return config.gdb, gdbargs
    end
  end --luacov:enable
  -- choose the runner
  local exe, args
  if binaryfile:match('%.html$') then  --luacov:disable
    exe = 'emrun'
    args = tabler.insertvalues({binaryfile}, runargs)
  elseif binaryfile:match('%.wasm$') then
    exe = 'wasmer'
    args = tabler.insertvalues({binaryfile}, runargs)
  elseif binaryfile:match('%.bmir') then
    exe = 'c2m'
    args = {}
    for _,libname in ipairs(compileopts.linklibs) do
      table.insert(args, '-l'..libname)
    end
    tabler.insertvalues(args, {binaryfile, '-el'})
    tabler.insertvalues(args, runargs)
  else --luacov:enable
    exe = binaryfile
    args = tabler.icopy(runargs)
  end
  return exe, args
end

return compiler
