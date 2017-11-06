local util = {}

function util.tohex(s)
	return (string.gsub(s, ".", function (c)
		return string.format("%.2x", string.byte(c))
	end))
end

function util.sha1sum(s)
  return require('lsha2').hash256(s)
end

return util