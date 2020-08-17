-- Stringer module
--
-- Stringer module contains some utilities used in the compiler for working with lua strings.

local hasher = require 'hasher'

local stringer = {}

-- Compute a hash with the desired length for a string.
-- The hash uses the Blake2B algorithm and is encoded in Base58.
-- This is used to generate unique names for large strings.
function stringer.hash(s, len, key)
  len = len or 20
  local hash = hasher.blake2b(s, len, key)
  return hasher.base58encode(hash)
end

-- Concatenate many arguments into a string separated by tabular (similar to lua print).
function stringer.pconcat(...)
  local t = table.pack(...)
  for i=1,t.n do
    t[i] = tostring(t[i])
  end
  return table.concat(t, '\t')
end

-- Like string.format but skip format when not passing any argument.
function stringer.pformat(format, ...)
  if select('#', ...) == 0 then
    return format
  end
  return string.format(format, ...)
end

-- Checks if a string starts with a prefix.
function stringer.startswith(s, prefix)
  return string.find(s,prefix,1,true) == 1
end

-- Checks if a string ends with a prefix.
function stringer.endswith(s, suffix)
  return #s >= #suffix and string.find(s, suffix, #s-#suffix+1, true) and true or false
end

-- Returns a string with right white spaces trimmed.
function stringer.rtrim(s)
  return (s:gsub("%s*$", ""))
end

-- Split a string into a table using a separator (default to space).
function stringer.split(s, sep)
  sep = sep or ' '
  local res = {}
  local pattern = string.format("([^%s]+)", sep or ' ')
  for each in s:gmatch(pattern) do
    table.insert(res, each)
  end
  return res
end

-- Returns the character at position `i` of a string.
function stringer.at(s, i)
  return string.sub(s, i, i)
end

return stringer
