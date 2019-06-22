local stringx = require 'pl.stringx'
local tabler = require 'euluna.utils.tabler'
local metamagic = require 'euluna.utils.metamagic'
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

function stringer.pconcat(...)
  local t = tabler.pack(...)
  for i=1,t.n do
    t[i] = tostring(t[i])
  end
  return table.concat(t, '\t')
end

function stringer.pformat(format, ...)
  if select('#', ...) > 0 then
    return string.format(format, ...)
  else
    return format
  end
end

function stringer.pformat(format, ...)
  if select('#', ...) == 0 then
    return format
  end
  -- compability with lua5.1
  local args = tabler.pack(...)
  for i=1,args.n do
    if metamagic.hasmetamethod(args[i], '__tostring') then
      args[i] = tostring(args[i])
    end
  end
  return string.format(format, tabler.unpack(args))
end

return stringer
