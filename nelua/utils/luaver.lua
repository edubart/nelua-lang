local luaver = {}

function luaver.getversion()
  return _VERSION:match('%w+ ([0-9.]+)')
end

local supported_versions = {'5.3', '5.4'}
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
