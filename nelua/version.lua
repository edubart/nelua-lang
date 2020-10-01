local fs = require 'nelua.utils.fs'
local tabler = require 'nelua.utils.tabler'
local version = {}

-- Version number.
version.NELUA_VERSION_MAJOR = 0
version.NELUA_VERSION_MINOR = 2
version.NELUA_VERSION_PATCH = 0
version.NELUA_VERSION_SUFFIX = 'dev'

-- This values are replaced on install.
version.NELUA_GIT_BUILD = 0
version.NELUA_GIT_HASH = "unknown"
version.NELUA_GIT_DATE = "unknown"

-- Version string.
version.NELUA_VERSION = string.format("Nelua %d.%d.%d",
  version.NELUA_VERSION_MAJOR,
  version.NELUA_VERSION_MINOR,
  version.NELUA_VERSION_PATCH)
if #version.NELUA_VERSION_SUFFIX > 0 then
  version.NELUA_VERSION = version.NELUA_VERSION..'-'..version.NELUA_VERSION_SUFFIX
end

-- Execute git commands inside Nelua's git repository.
local function execute_git_command(args)
  -- try to detect nelua git directory using this script
  local gitdir = fs.abspath(fs.join(fs.dirname(fs.dirname(fs.scriptname())), '.git'))
  if fs.isdir(gitdir) then
    local executor = require 'nelua.utils.executor'
    local execargs = tabler.insertvalues({'-C', gitdir}, args)
    local ok, status, stdout, stderr = executor.execex('git', execargs)
    if ok and #stdout > 0 then
      return stdout
    end
  end
end

-- Try to detect information from git repository clones.
function version.detect_git_info()
  -- git hash
  if version.NELUA_GIT_HASH == "unknown" then
    local stdout = execute_git_command({'rev-parse', 'HEAD'})
    if stdout then
      local hash = stdout:match('%w+')
      if hash then
        version.NELUA_GIT_HASH = hash
      end
    end
  end

  -- git date
  if version.NELUA_GIT_DATE == "unknown" then
    local stdout = execute_git_command({'log', '-1', '--format=%ci'})
    if stdout then
      local date = stdout:match('[^\r\n]+')
      if date then
        version.NELUA_GIT_DATE = date
      end
    end
  end

  -- git build
  if version.NELUA_GIT_BUILD == 0 then
    local stdout = execute_git_command({'rev-list', 'HEAD', '--count'})
    if stdout then
      local build = tonumber(stdout)
      if build then
        version.NELUA_GIT_BUILD = build
      end
    end
  end
end

return version
