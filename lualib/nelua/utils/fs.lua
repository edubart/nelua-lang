--[[
FS module

The fs (stands for filesystem) module is used to manage files and directories.
]]

local lfs = require 'lfs'
local except = require 'nelua.utils.except'
local stringer = require 'nelua.utils.stringer'
local memoize = require 'nelua.utils.memoize'
local platform = require 'nelua.utils.platform'
local fs = {}

-- Platform dependent variables.
fs.sep = _G.package.config:sub(1,1)
fs.othersep = fs.sep ~= '/' and '/' or nil
fs.winstyle = fs.sep == '\\'
fs.pathsep = fs.winstyle and ';' or ':'

-- Delete a file.
function fs.deletefile(file)
  return os.remove(file)
end

-- Return the contents of a file as a string.
function fs.readfile(filename, is_bin)
  local mode = is_bin and 'b' or ''
  local f,open_err = io.open(filename,'r'..mode)
  if not f then return nil, open_err end
  local res,read_err = f:read('*a')
  f:close()
  -- errors in io.open have "filename: " prefix, but errors in file:write don't, add it
  if not res then return nil, filename..": "..read_err end
  return res
end

-- Write a string to a file.
function fs.writefile(filename, str, is_bin)
  local mode = is_bin and 'b' or ''
  local f,err = io.open(filename,'w'..mode)
  if not f then return nil, err end
  local ok, write_err = f:write(str)
  f:close()
  -- errors in io.open have "filename: " prefix, but errors in file:write don't, add it
  if not ok then return nil, filename..": "..write_err end
  return true
end

--[[
Given a path, return the directory part and a file part.
If there's no directory part, the first value will be empty.
]]
function fs.splitpath(p)
  local i = #p
  local ch = p:sub(i,i)
  while i > 0 and ch ~= fs.sep and ch ~= fs.othersep do
    i = i - 1
    ch = p:sub(i,i)
  end
  if i == 0 then
    return '',p
  else
    return p:sub(1,i-1), p:sub(i+1)
  end
end

-- Return the directory part of a path.
function fs.dirname(p, level)
  level = level or 1
  while level > 0 do
    p = fs.splitpath(p)
    level = level - 1
  end
  return p
end

-- Return the file part of a path.
function fs.basename(p)
  local _,p2 = fs.splitpath(p)
  return p2
end

-- Is this an absolute path?
function fs.isabs(p)
  if p:find('^/') then return true end
  if fs.winstyle and p:find('^\\') or p:find('^.:') then return true end
  return false
end

--[[
Return the path resulting from combining the individual paths.
If the second (or later) path is absolute then we return the last absolute path
(joined with any non-absolute paths following).
Empty elements (except the last) will be ignored.
]]
function fs.join(p1, p2, ...)
  if select('#',...) > 0 then
    local p = fs.join(p1,p2)
    local args = {...}
    for i=1,#args do
      p = fs.join(p,args[i])
    end
    return p
  end
  if fs.isabs(p2) then return p2 end
  local endpos = #p1
  local endc = p1:sub(endpos,endpos)
  if endc ~= fs.sep and endc ~= fs.othersep and endc ~= "" then
    p1 = p1..fs.sep
  end
  return p1..p2
end

--[[
Normalize a path name.
E.g. `A//B`, `A/./B`, and `A/foo/../B` all become `A/B`
]]
function fs.normpath(p)
  -- split path into anchor and relative path.
  local anchor = ''
  --luacov:disable
  if fs.winstyle then
    if p:find '^\\\\' then -- UNC
      anchor = '\\\\'
      p = p:sub(3)
    elseif p:find '^[/\\]' then
      anchor = '\\'
      p = p:sub(2)
    elseif p:find '^.:' then
      anchor = p:sub(1, 2)
      p = p:sub(3)
      if p:find '^[/\\]' then
        anchor = anchor..'\\'
        p = p:sub(2)
      end
    end
    p = p:gsub('/','\\')
  else
    -- according to POSIX, in path start '//' and '/' are distinct, but '///+' is equivalent to '/'
    if p:find '^//[^/]' then
      anchor = '//'
      p = p:sub(3)
    elseif p:find '^/' then
      anchor = '/'
      p = p:match '^/*(.*)$'
    end
  end
  local parts = {}
  for part in p:gmatch('[^'..fs.sep..']+') do
    if part == '..' then
      if #parts ~= 0 and parts[#parts] ~= '..' then
        parts[#parts] = nil
      else
        parts[#parts+1] = part
      end
    elseif part ~= '.' then
      parts[#parts+1] = part
    end
  end
  --luacov:enable
  p = anchor..table.concat(parts, fs.sep)
  if p == '' then p = '.' end
  return p
end

-- Return an absolute path.
function fs.abspath(p, pwd)
  local use_pwd = pwd ~= nil
  p = p:gsub('[\\/]$','')
  if not fs.isabs(p) then
    pwd = pwd or lfs.currentdir()
    p = fs.join(pwd,p)
  elseif fs.winstyle and not use_pwd and
         p:find '^.[^:\\]' then --luacov:disable
    pwd = pwd or lfs.currentdir()
    p = pwd:sub(1,2)..p -- attach current drive to path like '\\fred.txt'
  end --luacov:enable
  return fs.normpath(p)
end

-- Return relative path from current directory or optional start point.
function fs.relpath(p, start)
  start = start or lfs.currentdir()
  p = fs.abspath(p, start)
  local compare
  if fs.winstyle then --luacov:disable
    p = p:gsub("/","\\")
    start = start:gsub("/","\\")
    compare = function(v) return v:lower() end
  else
    compare = function(v) return v end
  end --luacov:enable
  local startl, pl = stringer.split(start,fs.sep), stringer.split(p,fs.sep)
  local n = math.min(#startl,#pl)
  if fs.winstyle and n > 0 and pl[1]:sub(2,2) == ':' and pl[1] ~= startl[1] then --luacov:disable
    return p
  end --luacov:enable
  local k = n+1 -- default value if this loop doesn't bail out!
  for i = 1,n do
    if compare(startl[i]) ~= compare(pl[i]) then k = i break end
  end
  local rell = {}
  for i = 1, #startl-k+1 do rell[i] = '..' end
  if k <= #pl then
    for i = k,#pl do rell[#rell+1] = pl[i] end
  end
  return table.concat(rell,fs.sep)
end

-- Replace a starting '~' with the user's home directory.
function fs.expanduser(p)
  assert(p:find('^~'))
  local home = os.getenv('HOME')
  if not home then --luacov:disable
    -- has to be Windows
    home = os.getenv 'USERPROFILE' or (os.getenv 'HOMEDRIVE' .. os.getenv 'HOMEPATH')
  end --luacov:enable
  return home..p:sub(2)
end

-- Return a temporary file name.
function fs.tmpname()
  local ok, res = pcall(os.tmpname)
  --luacov:disable
  if not ok then -- failed to create the temporary file on Linux
    -- probably on lights and /tmp does not exist,
    -- try to use mktemp on $TMPDIR (cross platform way)
    local file = assert(io.popen('mktemp "${TMPDIR:-/tmp}/lua_XXXXXX"'))
    res = file:read('l')
    file:close()
    return res
  end
  -- on Windows if Lua is compiled using MSVC14 `os.tmpname`
  -- already returns an absolute path within TEMP env variable directory,
  -- no need to prepend it
  if fs.winstyle and not res:find(':') then
    res = os.getenv('TEMP')..res
  end
  --luacov:enable
  return res
end

-- Is this a directory?
function fs.isdir(p)
  return lfs.attributes(p, 'mode') == 'directory'
end

-- Is this a file?
function fs.isfile(p)
  return lfs.attributes(p, 'mode') == 'file'
end

-- Return the time of last modification time.
function fs.getmodtime(p)
  return lfs.attributes(p, 'modification')
end

-- Follow file symbolic links.
function fs.readlink(p) --luacov:disable
  local fileat = lfs.symlinkattributes(p)
  while fileat and fileat.target do
    local target = fileat.target
    if fs.winstyle then
      target = target:gsub('^UNC\\', '\\\\') -- UNC
    end
    if target == p then break end
    p = target
    fileat = lfs.symlinkattributes(p)
  end
  return p
end --luacov:enable

-- Returns the absolute real path of `p` (following links).
function fs.realpath(p) --luacov:disable
  return fs.readlink(fs.abspath(p))
end --luacov:enable

-- Create a directory path.
function fs.makepath(path)
  if fs.winstyle then --luacov:disable
    path:gsub('/', fs.sep)
  end --luacov:enable

  path = fs.abspath(path)

  -- windows root drive case
  if fs.winstyle and path:find('^%a:[\\]*$') then return true end

  if not fs.isdir(path) then --luacov:disable
    local dirpat = fs.winstyle and '(.+)\\[^\\]+$' or '(.+)/[^/]+$'
    local subpath = path:match(dirpat)
    local ok, err = fs.makepath(subpath)
    if not ok then return nil, err end
    return lfs.mkdir(path)
  else --luacov:enable
    return true
  end
end

--[[
Ensure directory exists for a file.
Raises an exception in case of an error.
]]
function fs.eensurefilepath(file)
  local outdir = fs.dirname(file)
  local ok, err = fs.makepath(outdir)
  except.assertraisef(ok, 'failed to create path for file "%s": %s', file, err)
end

--[[
Return the contents of a file as a string.
Raises an exception in case of an error.
]]
function fs.ereadfile(file)
  local content, err = fs.readfile(file)
  return except.assertraisef(content, 'failed to read file "%s": %s', file, err)
end

--[[
Write a string to a file.
Raises an exception in case of an error.
]]
function fs.ewritefile(file, content)
  local ok, err = fs.writefile(file, content)
  except.assertraisef(ok, 'failed to create file "%s": %s', file, err)
end

-- Choose file path inside a cache directory for an input file path.
function fs.normcachepath(infile, cachedir)
  local path = infile:gsub('%.[^./\\]+$','')
  path = fs.relpath(path)
  path = path:gsub('%.%.[/\\]+', '')
  path = fs.join(cachedir, path)
  path = fs.normpath(path)
  return path
end

-- Prefix a path with the user config path.
function fs.getuserconfpath(path)
  return fs.expanduser(fs.join('~', '.config', path))
end

-- Prefix a path with the cache path.
function fs.getusercachepath(path)
  return fs.expanduser(fs.join('~', '.cache', path))
end

-- Search for a file inside the system's PATH variable.
function fs.findbinfile(name) --luacov:disable
  if name == fs.basename(name) then
    local path_pattern = string.format('[^%s]+', fs.pathsep)
    for d in os.getenv'PATH':gmatch(path_pattern) do
      local binpath = fs.abspath(fs.join(d, name))
      if fs.isfile(binpath) then return binpath end
      if fs.winstyle then
        binpath = binpath..'.exe'
        if fs.isfile(binpath) then return binpath end
      end
    end
  else
    local binpath = fs.abspath(name)
    if fs.isfile(binpath) then
      return binpath
    end
    if fs.winstyle and not binpath:find('%.exe$') then
      binpath = binpath..'.exe'
    end
    if fs.isfile(binpath) then
      return binpath
    end
  end
end --luacov:enable

--[[
Returns the absolute path for the current Lua interpreter if possible,
otherwise a command suitable to use with `os.execute`.
]]
function fs.findluabin()
  local luabin = _G.arg[0]
  local minargi = 0
  for argi,v in pairs(_G.arg) do
    if argi < minargi then
      minargi = argi
      luabin = v
    end
  end
  local luabinabs = fs.abspath(luabin)
  if fs.isfile(luabinabs) then return luabinabs end
  local binpath = fs.findbinfile(luabin)
  if binpath then return binpath end
  return luabin
end

--[[
Return a suitable full path for a new temporary file name.
Unlike `os.tmpname()`, it always gives you a writable path
(uses TEMP environment variable on Windows).
]]
function fs.tmpfile()
  local name = fs.tmpname()
  local f = io.open(name, 'a+b')
  return f, name
end

-- Return the relative path for the calling script.
function fs.scriptname(level)
  level = level or 2
  return debug.getinfo(level, 'S').source:sub(2)
end

-- Iterate entries of a directory that matches the given pattern.
function fs.dirmatch(path, patt)
  local nextentry, state = lfs.dir(path)
  return function(s, entry)
    repeat
      entry = nextentry(s, entry)
    until not entry or entry:match(patt)
    return entry
  end, state
end

-- Helper for `fs.findmodule`, found modules are cached.
local function findmodule(name, pathstr)
  name = name:gsub('%.', fs.sep)
  local triedpaths = {}
  local modpath
  for trypath in pathstr:gmatch('[^;]+') do
    trypath = trypath:gsub('%?', name)
    trypath = fs.abspath(trypath)
    if fs.isfile(trypath) then
      modpath = trypath
      break
    end
    triedpaths[#triedpaths+1] = trypath
  end
  return modpath, triedpaths
end
findmodule = memoize(findmodule)

--[[
Search for a module using a path string or relative path.
The path string must be a string like './?.nelua;./?/init.nelua'.
]]
function fs.findmodule(name, searchpath, relpath, ext)
  local fullpath
  if relpath then
    if fs.isabs(name) then -- absolute path
      fullpath = fs.abspath(name)
    elseif name:find('^%.%.?[/\\]') then -- relative with '../'
      fullpath = fs.abspath(fs.join(relpath, name))
    elseif name:find('^%.+') then -- relative with '.'
      local dots, rest = name:match('^(%.+)(.*)')
      rest = rest:gsub('%.', fs.sep)
      if #dots == 1 then
        fullpath = fs.abspath(fs.join(relpath, rest))
      else
        fullpath = fs.abspath(fs.join(relpath, string.rep('..'..fs.sep, #dots-1), rest))
      end
    end
  end
  local triedpaths
  local modpath
  if fullpath then -- full path of the file is known
    local paths
    if not fullpath:find('%.%w+$') then
      paths = {
        fullpath..'.'..ext,
        fs.join(fullpath,'init.'..ext)
      }
    else
      paths = {fullpath}
    end
    triedpaths = {}
    for _,trypath in ipairs(paths) do
      if fs.isfile(trypath) then
        modpath = fs.abspath(trypath)
        break
      end
      triedpaths[#triedpaths+1] = trypath
    end
  else -- search for a file in searchpath
    if name:find('^~') then -- revert the path search order
      name = name:sub(2)
      local rpath = {}
      for trypath in searchpath:gmatch('[^;]+') do
        table.insert(rpath, 1, trypath)
      end
      searchpath = table.concat(rpath,';')
    end
    modpath, triedpaths = findmodule(name, searchpath)
  end
  local err
  if not modpath then
    err = "\tno file '" .. table.concat(triedpaths, "'\n\tno file '") .. "'"
  end
  return modpath, err, triedpaths
end

--[[
Make packages search path.
When `ext` is 'nelua', it returns the NELUA_PATH system environment variable if present,
otherwise make a default one from `libpath` and `ext`.
]]
function fs.makesearchpath(libpath, ext)
  local path = os.getenv(ext:upper()..'_PATH')
  if path then return path end
  path = fs.join('.','?.'..ext)..';'..
         fs.join('.','?','init.'..ext)..';'..
         fs.join(libpath,'?.'..ext)..';'..
         fs.join(libpath,'?','init.'..ext)
  return path
end

-- Find where is the Nelua's lib directory.
function fs.findnelualib()
  local lualibpath = fs.dirname(fs.realpath(fs.scriptname()), 3)
  local libpath = fs.join(fs.dirname(lualibpath), 'lib')
  if fs.isdir(libpath) then
    return libpath, lualibpath
  end
end

--[[
Find an available C compiler in the system.
First reads the CC system environment variable,
then try to search in the user binary directory.
]]
function fs.findcc()
  local envcc = os.getenv('CC')
  if envcc and fs.findbinfile(envcc) then return envcc end
  local search_ccs
  if platform.is_msys then --luacov:disable
    search_ccs = {platform.msystem_chost..'-gcc'}
  elseif platform.is_cygwin then
    search_ccs = {'x86_64-w64-mingw32-gcc', 'i686-w64-mingw32-gcc'}
  else
    search_ccs = {}
  end --luacov:enable
  table.insert(search_ccs, 'gcc')
  table.insert(search_ccs, 'clang')
  for _,candidate in ipairs(search_ccs) do
    if fs.findbinfile(candidate) then
      return candidate
    end
  end
  return nil
end

-- Find C compiler binutil (e.g: ar, strip) for the given C compiler.
function fs.findccbinutil(cc, binname)
  local bin = cc..'-'..binname
  --luacov:disable
  if not fs.findbinfile(binname) then
    -- transform for example 'x86_64-pc-linux-gnu-gcc-11.1.0' -> 'x86_64-pc-linux-gnu-ar'
    local possiblebin = cc:gsub('%-[0-9.]+$',''):gsub('[%w+_.]+$', binname)
    if possiblebin:find(binname..'$') then
      bin = possiblebin
    end
  end
  if not fs.findbinfile(bin) then
    bin = binname
  end
  --luacov:enable
  return bin
end

return fs
