--[[
Module used to detect current Nelua version.

This file will be patched when Nelua is installed via `make install` from a git clone,
according to the current repository commit.

When Nelua is not installed and is running from a cloned git repository,
then the git variables will be retrieved from it.
]]

local fs = require 'nelua.utils.fs'
local tabler = require 'nelua.utils.tabler'
local executor = require 'nelua.utils.executor'

-- The version module.
local version = {}

-- Major release number.
version.NELUA_VERSION_MAJOR = 0
-- Minor release number.
version.NELUA_VERSION_MINOR = 2
-- Patch release number.
version.NELUA_VERSION_PATCH = 0
-- Suffix for version (like '-dev', '-alpha' and '-beta')
version.NELUA_VERSION_SUFFIX = '-dev'
-- Nelua version in a string (like "Nelua 0.2.0-dev").
version.NELUA_VERSION = string.format("Nelua %d.%d.%d%s",
                                      version.NELUA_VERSION_MAJOR,
                                      version.NELUA_VERSION_MINOR,
                                      version.NELUA_VERSION_PATCH,
                                      version.NELUA_VERSION_SUFFIX)
-- Git build number (the number of commits in git history).
version.NELUA_GIT_BUILD = nil
-- Latest git commit hash.
version.NELUA_GIT_HASH = nil
-- Latest git commit date.
version.NELUA_GIT_DATE = nil

-- Execute a git command inside Nelua's git repository.
local function execute_git_command(args)
  -- try to detect nelua git directory using this script
  local gitdir = fs.abspath(fs.join(fs.dirname(fs.scriptname(), 3), '.git'))
  if fs.isdir(gitdir) then -- git directory found
    local execargs = tabler.insertvalues({'-C', gitdir}, args)
    local stdout = executor.evalex('git', execargs)
    if stdout and stdout ~= '' then
      return stdout
    end
  end
end

-- Detects git commit hash for a cloned Nelua installation.
local function detect_git_hash()
  local stdout = execute_git_command({'rev-parse', 'HEAD'})
  local res = "unknown"
  if stdout then
    local hash = stdout:match('%w+')
    if hash then
      res = hash
    end
  end
  version.NELUA_GIT_HASH = res
  return res
end

-- Detects git commit date for a cloned Nelua installation.
local function detect_git_date()
  local stdout = execute_git_command({'log', '-1', '--format=%ci'})
  local res = "unknown"
  if stdout then
    local date = stdout:match('[^\r\n]+')
    if date then
      res = date
    end
  end
  version.NELUA_GIT_DATE = res
  return res
end

-- Detects git build number for a cloned Nelua installation.
local function detect_git_build()
  local stdout = execute_git_command({'rev-list', 'HEAD', '--count'})
  local res = 0
  if stdout then
    local build = tonumber(stdout)
    if build then
      res = build
    end
  end
  version.NELUA_GIT_BUILD = res
  return res
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
