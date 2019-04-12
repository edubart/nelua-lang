local stringx = require 'pl.stringx'
local hasher = require 'hasher'

local stringer = {}

function stringer.hash(s)
  local hash = hasher.blake2b(s, 20)
  return hasher.base58encode(hash)
end

stringer.startswith = stringx.startswith
stringer.split = stringx.split
stringer.rstrip = stringx.rstrip

function stringer.print_concat(...)
  local t = table.pack(...)
  for i=1,t.n do
    t[i] = tostring(t[i])
  end
  return table.concat(t, '\t')
end

return stringer
