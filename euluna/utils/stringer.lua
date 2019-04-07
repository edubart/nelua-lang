local stringx = require 'pl.stringx'
local sha1 = require 'sha1'.sha1

local stringer = {}

function stringer.hash(s)
  -- ! FIXME: use only luazen once upstream is fixed (its faster)
  --luacov:disable
  local lz
  pcall(function()
    local m = require 'luazen'
    if m.ascon_encrypt then lz = m end
  end)
  if lz then
    return lz.b58encode(lz.blake2b(s, 20))
  else
    return sha1(s)
  end
  --luacov:enable
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
