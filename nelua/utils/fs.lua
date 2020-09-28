-- FS module
--
-- The fs (stands for filesystem) module is used to manage files and directories.

local lfs = require 'lfs'
local platform = require 'nelua.utils.platform'
local except = require 'nelua.utils.except'
local stringer = require 'nelua.utils.stringer'
local fs = {}

-- Platform dependent variables.
fs.sep = platform.dir_separator
fs.pathsep = platform.path_separator
fs.othersep = fs.sep ~= '/' and '/' or nil

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

-- Given a path, return the directory part and a file part.
-- If there's no directory part, the first value will be empty.
function fs.splitpath(p)
  local i = #p
  local ch = stringer.at(p,i)
  while i > 0 and ch ~= fs.sep and ch ~= fs.othersep do
    i = i - 1
    ch = stringer.at(p,i)
  end
  if i == 0 then
    return '',p
  else
    return string.sub(p,1,i-1), string.sub(p,i+1)
  end
end

-- Return the directory part of a path.
function fs.dirname(p)
  local p1 = fs.splitpath(p)
  return p1
end

-- Return the file part of a path.
function fs.basename(p)
  local _,p2 = fs.splitpath(p)
  return p2
end

-- Is this an absolute path?
function fs.isabs(p)
  if stringer.at(p,1) == '/' then return true end
  if platform.is_windows and stringer.at(p,1)=='\\' or stringer.at(p,2)==':' then return true end
  return false
end

-- Return the path resulting from combining the individual paths.
-- If the second (or later) path is absolute then we return the last absolute path
-- (joined with any non-absolute paths following).
-- Empty elements (except the last) will be ignored.
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
  local endc = stringer.at(p1,#p1)
  if endc ~= fs.sep and endc ~= fs.othersep and endc ~= "" then
    p1 = p1..fs.sep
  end
  return p1..p2
end

-- Normalize a path name.
-- E.g. `A//B`, `A/./B`, and `A/foo/../B` all become `A/B`
function fs.normpath(p)
  -- split path into anchor and relative path.
  local anchor = ''
   --luacov:disable
  if platform.is_windows then
    if p:match '^\\\\' then -- UNC
      anchor = '\\\\'
      p = p:sub(3)
    elseif stringer.at(p, 1) == '/' or stringer.at(p, 1) == '\\' then
      anchor = '\\'
      p = p:sub(2)
    elseif stringer.at(p, 2) == ':' then
      anchor = p:sub(1, 2)
      p = p:sub(3)
      if stringer.at(p, 1) == '/' or stringer.at(p, 1) == '\\' then
        anchor = anchor..'\\'
        p = p:sub(2)
      end
    end
    p = p:gsub('/','\\')
  else
    -- according to POSIX, in path start '//' and '/' are distinct,
    -- but '///+' is equivalent to '/'.
    if p:match '^//' and stringer.at(p, 3) ~= '/' then
      anchor = '//'
      p = p:sub(3)
    elseif stringer.at(p, 1) == '/' then
      anchor = '/'
      p = p:match '^/*(.*)$'
    end
  end
  local parts = {}
  for part in p:gmatch('[^'..fs.sep..']+') do
    if part == '..' then
      if #parts ~= 0 and parts[#parts] ~= '..' then
        table.remove(parts)
      else
        table.insert(parts, part)
      end
    elseif part ~= '.' then
      table.insert(parts, part)
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
  pwd = pwd or lfs.currentdir()
  if not fs.isabs(p) then
    p = fs.join(pwd,p)
  elseif platform.is_windows and not use_pwd and
         stringer.at(p,2) ~= ':' and stringer.at(p,2) ~= '\\' then --luacov:disable
    p = pwd:sub(1,2)..p -- attach current drive to path like '\\fred.txt'
  end --luacov:enable
  return fs.normpath(p)
end

-- Return relative path from current directory or optional start point.
function fs.relpath(p, start)
  p = fs.abspath(p,start)
  start = start or lfs.currentdir()
  local compare
  if platform.is_windows then --luacov:disable
    p = p:gsub("/","\\")
    start = start:gsub("/","\\")
    compare = function(v) return v:lower() end
  else
    compare = function(v) return v end
  end --luacov:enable
  local startl, pl = stringer.split(start,fs.sep), stringer.split(p,fs.sep)
  local n = math.min(#startl,#pl)
  if platform.is_windows and n > 0 and stringer.at(pl[1],2) == ':' and pl[1] ~= startl[1] then --luacov:disable
    return p
  end --luacov:enable
  local k = n+1 -- default value if this loop doesn't bail out!
  for i = 1,n do
    if compare(startl[i]) ~= compare(pl[i]) then k = i break end
  end
  local rell = {}
  for i = 1, #startl-k+1 do rell[i] = '..' end
  if k <= #pl then
    for i = k,#pl do table.insert(rell,pl[i]) end
  end
  return table.concat(rell,fs.sep)
end

-- Replace a starting '~' with the user's home directory.
function fs.expanduser(p)
  assert(stringer.at(p,1) == '~')
  local home = os.getenv('HOME')
  if not home then --luacov:disable
    -- has to be Windows
    home = os.getenv 'USERPROFILE' or (os.getenv 'HOMEDRIVE' .. os.getenv 'HOMEPATH')
  end --luacov:enable
  return home..string.sub(p,2)
end

-- Return a temporary file name.
function fs.tmpname()
  local res = os.tmpname()
  -- on Windows if Lua is compiled using MSVC14 os.tmpname
  -- already returns an absolute path within TEMP env variable directory,
  -- no need to prepend it
  if platform.is_windows and not res:find(':') then --luacov:disable
    res = os.getenv('TEMP')..res
  end --luacov:enable
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

-- Create a directory path.
function fs.makepath(path)
  if platform.is_windows then --luacov:disable
    path:gsub('/', fs.sep)
  end --luacov:enable

  path = fs.abspath(path)

  -- windows root drive case
  if platform.is_windows and path:find('^%a:[\\]*$') then return true end

  if not fs.isdir(path) then --luacov:disable
    local dirpat = platform.is_windows and '(.+)\\[^\\]+$' or '(.+)/[^/]+$'
    local subpath = path:match(dirpat)
    local ok, err = fs.makepath(subpath)
    if not ok then return nil, err end
    return lfs.mkdir(path)
  else --luacov:enable
    return true
  end
end

-- Ensure directory exists for a file.
-- Raises an exception in case of an error.
function fs.eensurefilepath(file)
  local outdir = fs.dirname(file)
  local ok, err = fs.makepath(outdir)
  except.assertraisef(ok, 'failed to create path for file "%s": %s', file, err)
end

-- Return the contents of a file as a string.
-- Raises an exception in case of an error.
function fs.ereadfile(file)
  local content, err = fs.readfile(file)
  return except.assertraisef(content, 'failed to read file "%s": %s', file, err)
end

-- Write a string to a file.
-- Raises an exception in case of an error.
function fs.ewritefile(file, content)
  local ok, err = fs.writefile(file, content)
  except.assertraisef(ok, 'failed to create file "%s": %s', file, err)
end

-- Choose file path inside a cache directory for an input file path.
function fs.getcachepath(infile, cachedir)
  local path = infile:gsub('%.[^.]+$','')
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

-- Search for a module using a path string.
-- The path string must be a string like './?.nelua;./?/init.nelua'.
function fs.findmodulefile(name, pathstr)
  name = name:gsub('%.', fs.sep)
  local paths = stringer.split(pathstr, ';')
  local triedpaths = {}
  for i=1,#paths do
    local trypath = paths[i]:gsub('%?', name)
    if fs.isfile(trypath) then
      return fs.abspath(trypath)
    end
    table.insert(triedpaths, trypath)
  end
  return nil, "\tno file '" .. table.concat(triedpaths, "'\n\tno file '") .. "'"
end

-- Search for a file inside the system's PATH variable.
function fs.findbinfile(name)
  if name == fs.basename(name) then
    local path_pattern = string.format('[^%s]+', fs.pathsep)
    for d in os.getenv("PATH"):gmatch(path_pattern) do
      local binpath = fs.abspath(fs.join(d, name))
      if fs.isfile(binpath) then return binpath end
      binpath = binpath .. '.exe'
      if fs.isfile(binpath) then return binpath end
    end
  else --luacov:disable
    local binpath = fs.abspath(name)
    if fs.isfile(binpath) then
      return binpath
    end
  end --luacov:enable
end

-- Return a suitable full path for a new temporary file name.
-- Unlike os.tmpname(), it always gives you a writeable path
-- (uses TEMP environment variable on Windows).
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

return fs
