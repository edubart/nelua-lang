--[[
This script just patches 'package.path' to find Nelua compiler files.
It is actually compiled into 'luainit.c', and always run on Lua on startup.
]]

-- Require LuaFileSystem
local lfsok, lfs = pcall(require, 'lfs')
if not lfsok then
  error 'Failed to find the LFS module, is your installation broken?'
end

--[[
FS module, this is a copy of some functions from 'nelua.utils.fs',
because we cannot require it before Lua package path is set.
]]

local fs = {}

-- Platform dependent variables.
fs.sep = _G.package.config:sub(1,1)
fs.othersep = fs.sep ~= '/' and '/' or nil
fs.winstyle = fs.sep == '\\'
fs.pathsep = fs.winstyle and ';' or ':'

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

-- Return the path for the current running Lua interpreter.
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

-- Is this a directory?
function fs.isdir(p)
  return lfs.attributes(p, 'mode') == 'directory'
end

-- Is this a file?
function fs.isfile(p)
  return lfs.attributes(p, 'mode') == 'file'
end

-- Follow file symbolic links.
function fs.readlink(p) --luacov:disable
  local fileat = lfs.symlinkattributes(p)
  while fileat and fileat.target do
    local target = fileat.target
    if fs.winstyle and target:find('^UNC\\') then
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

-------------------------------------------------------------------------

-- Setup package path (to make the compiler lua files visible)
local exe_path = fs.realpath(fs.findluabin())
local exe_dir = fs.dirname(exe_path)

-- Find compiler lua files
local nelua_lualib = fs.join(exe_dir, 'lualib')
if fs.basename(exe_dir) == 'bin' then -- in a system install
  local system_lualib = fs.join(fs.dirname(exe_dir),'lib','nelua','lualib')
  if fs.isdir(system_lualib) then
    nelua_lualib = system_lualib
  end
end

-- Inject package path
if fs.isdir(nelua_lualib) then
  package.path=fs.join(nelua_lualib,'?.lua')..';'..package.path
  package.path=fs.join(nelua_lualib,'nelua','thirdparty','?.lua')..';'..package.path
end
