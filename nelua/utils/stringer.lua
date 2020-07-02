local stringx = require 'pl.stringx'
local hasher = require 'hasher'

local stringer = {}

function stringer.hash(s, len, key)
  len = len or 20
  local hash = hasher.blake2b(s, len, key)
  return hasher.base58encode(hash)
end

function stringer.pconcat(...)
  local t = table.pack(...)
  for i=1,t.n do
    t[i] = tostring(t[i])
  end
  return table.concat(t, '\t')
end

function stringer.pformat(format, ...)
  if select('#', ...) == 0 then
    return format
  end
  return string.format(format, ...)
end

stringer.startswith = stringx.startswith
stringer.endswith = stringx.endswith
stringer.split = stringx.split
stringer.rstrip = stringx.rstrip
stringer.count = stringx.count

return stringer
