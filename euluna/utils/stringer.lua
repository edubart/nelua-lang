local stringx = require 'pl.stringx'
local sha1 = require 'sha1'.sha1

local stringer = {}

function stringer.hash(s)
  --local lz = require 'luazen'
  --return lz.b58encode(lz.blake2b(s, 16))
  return sha1(s)
end

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
