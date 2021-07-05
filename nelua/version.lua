--[[
Module used to detect current Nelua version.

This file will be patched when Nelua is installed via `make install` from a git clone,
according to the current repository commit.

When Nelua is not installed and is running from a cloned git repository,
then information will be retrieved from it.
]]

local fs = require 'nelua.utils.fs'
local tabler = require 'nelua.utils.tabler'
local executor = require 'nelua.utils.executor'
local version = {}

-- Major release number.
version.NELUA_VERSION_MAJOR = 0
-- Minor release number.
version.NELUA_VERSION_MINOR = 2
-- Patch release number.
version.NELUA_VERSION_PATCH = 0
-- Suffix for version (like 'dev', 'alpha' and beta')
version.NELUA_VERSION_SUFFIX = 'dev'

-- Nelua version in a string (like "Nelua 0.2.0-dev").
version.NELUA_VERSION = string.format("Nelua %d.%d.%d",
                                      version.NELUA_VERSION_MAJOR,
                                      version.NELUA_VERSION_MINOR,
                                      version.NELUA_VERSION_PATCH)
if #version.NELUA_VERSION_SUFFIX > 0 then
  version.NELUA_VERSION = version.NELUA_VERSION..'-'..version.NELUA_VERSION_SUFFIX
end

-- Git build number (the number of commits in git history).
version.NELUA_GIT_BUILD = nil
-- Latest git commit hash.
version.NELUA_GIT_HASH = nil
-- Latest git commit date.
version.NELUA_GIT_DATE = nil

-- Execute a git command inside Nelua's git repository.
local function execute_git_command(args)
  -- try to detect nelua git directory using this script
  local gitdir = fs.abspath(fs.join(fs.dirname(fs.dirname(fs.scriptname())), '.git'))
  if fs.isdir(gitdir) then -- git directory found
    local execargs = tabler.insertvalues({'-C', gitdir}, args)
    local ok, status, stdout = executor.execex('git', execargs)
    if ok and status and stdout ~= '' then
      return stdout
    end
  end
end

-- Detects git commit hash for a cloned Nelua installation.
local function detect_git_hash()
  local stdout = execute_git_command({'rev-parse', 'HEAD'})
  if stdout then
    local hash = stdout:match('%w+')
    if hash then
      version.NELUA_GIT_HASH = hash
      return hash
    end
  end
  return "unknown"
end

-- Detects git commit date for a cloned Nelua installation.
local function detect_git_date()
  local stdout = execute_git_command({'log', '-1', '--format=%ci'})
  if stdout then
    local date = stdout:match('[^\r\n]+')
    if date then
      version.NELUA_GIT_DATE = date
      return date
    end
  end
  return "unknown"
end

-- Detects git build number for a cloned Nelua installation.
local function detect_git_build()
  local stdout = execute_git_command({'rev-list', 'HEAD', '--count'})
  if stdout then
    local build = tonumber(stdout)
    if build then
      version.NELUA_GIT_BUILD = build
      return build
    end
  end
  return 0
end

-- Allow gathering git information only when requested.
setmetatable(version, {__index = function(_, k)
  if k == 'NELUA_GIT_HASH' then
    return detect_git_hash()
  elseif k == 'NELUA_GIT_DATE' then
    return detect_git_date()
  elseif k == 'NELUA_GIT_BUILD' then
    return detect_git_build()
  end
end})

return version
