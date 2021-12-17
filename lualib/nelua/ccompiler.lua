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
    if cc:find(ccname,1,true) and (not foundccname or #ccname > #foundccname) then
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
  if ccinfo.is_gcc and not ccinfo.is_clang and ccinfo.gnuc < 5 then
    cflags:add(' -std=gnu99')  -- enable C99 in old GCC compilers
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
  if config.shared_lib then
    local shared_cflags = ccflags.cflags_shared_lib
    if ccinfo.is_windows then
      if ccinfo.is_msc and ccflags.cflags_shared_lib_windows_msc then
        shared_cflags = ccflags.cflags_shared_lib_windows_msc
      elseif ccflags.cflags_shared_lib_windows_gcc then
        shared_cflags = ccflags.cflags_shared_lib_windows_gcc
      end
    end
    cflags:add(' '..shared_cflags)
  elseif config.static_lib or config.object then
    cflags:add(' '..ccflags.cflags_object)
  elseif config.assembly then
    cflags:add(' '..ccflags.cflags_assembly)
  end
  if #config.cflags > 0 then
    cflags:add(' '..config.cflags)
  end
  --luacov:enable
  if #compileopts.cflags > 0 then
    cflags:add(' ')
    cflags:addlist(compileopts.cflags, ' ')
  end
  if not config.static_lib and not config.object and not config.assembly then
    for _,linkdir in ipairs(compileopts.linkdirs) do
      cflags:add(' -L "'..linkdir..'"')
    end
    if #config.ldflags > 0 then
      cflags:add(' '..config.ldflags)
    end
    if #compileopts.ldflags > 0 then
      cflags:add(' ')
      cflags:addlist(compileopts.ldflags, ' ')
    end
    if #compileopts.linklibs > 0 then
      cflags:add(' -l')
      cflags:addlist(compileopts.linklibs, ' -l')
    end
    if ccinfo.is_unix and -- always link math library on unix
      (not ccinfo.is_mirc and not ccinfo.is_apple) then
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
  fs.deletefile(cfile) -- we have to delete the tmp file
  cfile = cfile..ccflags.ext
  local ok, err = fs.makefile(cfile, code)
  except.assertraisef(ok, "failed to create C source file: %s", err)
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
    except.raisef("failed to retrieve C compiler defines: %s", stderr)
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
    except.raisef("failed to retrieve C compiler information: %s", stderr)
  end
  local text = stdout:gsub('#[^\n]*\n', ''):gsub('\n%s+','\n')
  local ccinfo = {text=text}
  for name,value in text:gmatch('%s*([a-zA-Z0-9_]+)%s*=%s*([^;\n]+);') do
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
  ccinfo.alignof_long_long = math.min(ccinfo.alignof_long_long or 8, ccinfo.biggest_alignment)
  ccinfo.alignof_double = math.min(ccinfo.alignof_double or 8, ccinfo.biggest_alignment)
  ccinfo.alignof_long_double = math.min(ccinfo.alignof_long_double or 16, ccinfo.biggest_alignment)

  if ccinfo.sizeof_pointer then -- ensure some primitive sizes have the expected sizes
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

function compiler.compile_code(ccode, cfile, compileopts)
  local ccinfotext = compiler.get_cc_info().text
  local cflags = get_compiler_cflags(compileopts)
  local binfile = cfile:gsub('.c$','')
  local ccmd = get_compile_args(cfile, binfile, cflags)
  -- file heading
  local hash = stringer.hash(ccode..ccinfotext..ccmd)
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
  local ok, err = fs.makefile(cfile, sourcecode)
  except.assertraisef(ok, 'failed to create C source file: %s', err)
  if config.verbose then console.info("generated " .. cfile) end
end

local function detect_output_extension(outfile, ccinfo)
  --luacov:disable
  if config.object then
    if ccinfo.is_mirc then
      return '.bmir'
    else
      return '.o'
    end
  elseif config.assembly then
    if ccinfo.is_mirc then
      return '.mir'
    else
      return '.s'
    end
  elseif config.static_lib then
    if ccinfo.is_msc and ccinfo.is_clang then
      return '.lib'
    else
      return '.a'
    end
  elseif config.shared_lib then
    if ccinfo.is_windows or ccinfo.is_cygwin then
      return '.dll'
    elseif ccinfo.is_apple then
      return '.dylib'
    else
      return '.so'
    end
  else -- binary executable
    if ccinfo.is_wasm then
      if outfile:find('%.wasm$') then
        return '.wasm', true
      else
        return '.html', true
      end
    elseif ccinfo.is_windows or ccinfo.is_cygwin then
      return '.exe', true
    elseif ccinfo.is_mirc then
      return '.bmir', true
    else
      return '', true
    end
  end
  --luacov:enable
end

--[[
Find C compiler binary utilities in system's path for the given C compiler.
For example, this function can be used to find 'ar', 'strip', 'objdump', etc..
]]
function compiler.find_binutil(binname) --luacov:disable
  local cc = config.cc
  local ccinfo = compiler.get_cc_info()
  local bin = cc..'-'..binname
  if fs.findbinfile(bin) then return bin end
  if ccinfo.is_msc and ccinfo.is_clang then -- try llvm tools for MSC clang on windows
    bin = 'llvm-'..binname
    if fs.findbinfile(bin) then return bin end
  end
  -- transform for example 'x86_64-pc-linux-gnu-gcc-11.1.0' -> 'x86_64-pc-linux-gnu-ar'
  bin = cc:gsub('%-[0-9.]+$',''):gsub('[%w+_.]+$', binname)
  if bin:find(binname..'$') and fs.findbinfile(bin) then return bin end
  return binname
end --luacov:enable

function compiler.compile_static_lib(objfile, outfile)
  local ar = compiler.find_binutil('ar')
  local arcmd = string.format('%s rcs "%s" "%s"', ar, outfile, objfile)
  if config.verbose then console.info(arcmd) end
  -- compile the file
  if not executor.rexec(arcmd, nil, config.redirect_exec) then --luacov:disable
    except.raisef("static library compilation for '%s' failed", outfile)
  end --luacov:enable
end

function compiler.strip_binary(binfile)
  local strip = compiler.find_binutil('strip')
  local stripcmd = string.format('%s -x "%s"', strip, binfile)
  if config.verbose then console.info(stripcmd) end
  if not executor.rexec(stripcmd, nil, config.redirect_exec) then --luacov:disable
    except.raisef("strip for '%s' failed", binfile)
  end --luacov:enable
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
  local binext, isexe = detect_output_extension(outfile, ccinfo)
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
  do -- ensure the directory exists for the binary file
    local bindir = fs.dirname(binfile)
    local ok, err = fs.makepath(bindir)
    if not ok then -- maybe it's a binary, lets remove it
      fs.deletefile(bindir)
      ok, err = fs.makepath(bindir)
    end
    except.assertraisef(ok, 'failed to create directory for output binary: %s', err)
  end
  -- we may use an intermediary file
  local midfile = binfile
  if config.static_lib then -- compile to an object first for static libraries
    midfile = binfile:gsub('.[a-z]+$', '.o')
  end
  -- generate compile command
  local cccmd = get_compile_args(cfile, midfile, cflags)
  if config.verbose then console.info(cccmd) end
  -- compile the file
  if not executor.rexec(cccmd, nil, config.redirect_exec) then --luacov:disable
    except.raisef("C compilation for '%s' failed", binfile)
  end --luacov:enable
  -- compile static library
  if config.static_lib then
    compiler.compile_static_lib(midfile, binfile)
    fs.deletefile(midfile)
  end
  if config.strip and (config.shared_lib or isexe) and (not ccinfo.is_mirc or ccinfo.is_wasm) then
    compiler.strip_binary(binfile)
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
        '-ex', 'set print frame-info source-and-location',
        '-ex', 'break abort',
        '-ex', 'run',
        '-ex', 'bt',
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
