local util = {}
local digest = require 'openssl.digest'

function util.tohex(s)
	return (string.gsub(s, ".", function (c)
		return string.format("%.2x", string.byte(c))
	end))
end

function util.sha1sum(s)
  return util.tohex(digest.new('sha1'):final(s))
end

return util