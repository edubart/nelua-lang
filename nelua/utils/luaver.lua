-- Luaver module
--
-- Module used to check if the compiler supports the running lua version.

local luaver = {}

-- Get lua version.
function luaver.getversion()
  return _VERSION:match('%w+ ([0-9.]+)')
end

-- List of supported lua version.
local supported_versions = {'5.4'}

-- Check if the running lua version is supported, throws an error if not.
function luaver.check()
  local v = luaver.getversion()
  for i=1,#supported_versions do
    if supported_versions[i] == v then
      return
    end
  end
  --luacov:disable
  error(string.format(
    '%s is not supported, please a supported Lua version like Lua %s',
    _VERSION, supported_versions[1]))
  --luacov:enable
end

return luaver
