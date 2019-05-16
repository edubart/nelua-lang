local stringx = require 'pl.stringx'
local hasher = require 'hasher'

local stringer = {}

function stringer.hash(s, len, key)
  len = len or 20
  local hash = hasher.blake2b(s, len, key)
  return hasher.base58encode(hash)
end

stringer.startswith = stringx.startswith
stringer.endswith = stringx.endswith
stringer.split = stringx.split
stringer.rstrip = stringx.rstrip
stringer.count = stringx.count

function stringer.print_concat(...)
  local t = table.pack(...)
  for i=1,t.n do
    t[i] = tostring(t[i])
  end
  return table.concat(t, '\t')
end

return stringer
