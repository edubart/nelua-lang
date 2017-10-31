local util = {}
local digest = require 'openssl.digest'

function util.tohex(s)
	return (string.gsub(s, ".", function (c)
		return string.format("%.2x", string.byte(c))
	end))
end

function util.sha1sum(s, raw)
  local sum = digest.new('sha1'):final(s)
  if not raw then
    return util.tohex(sum)
  end
  return sum
end

return util