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

function stringer.startswith(s, prefix)
  return string.find(s,prefix,1,true) == 1
end

function stringer.endswith(s, suffix)
  return #s >= #suffix and string.find(s, suffix, #s-#suffix+1, true) and true or false
end

function stringer.rtrim(s)
  return (s:gsub("%s*$", ""))
end

function stringer.split(s, sep)
  sep = sep or ' '
  local res = {}
  local regex = string.format("([^%s]+)", sep or ' ')
  for each in s:gmatch(regex) do
    table.insert(res, each)
  end
  return res
end

function stringer.at(s,i)
  return string.sub(s,i,i)
end

return stringer
