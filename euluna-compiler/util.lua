local util = {}

function util.sha1sum(s)
  return require('lsha2').hash256(s)
end

return util
