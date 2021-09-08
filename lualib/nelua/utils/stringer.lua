--[[
Stringer module

Stringer module contains some utilities for working with lua strings.
]]

local hasher = require 'hasher'

local stringer = {}

--[[
Compute a hash with the desired length for a string.
The hash uses the Blake2B algorithm and is encoded in Base58.
This is used to generate unique names for large strings.
]]
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

-- Like `string.format` but skip format when not passing any argument.
function stringer.pformat(format, ...)
  if select('#', ...) == 0 then
    return format
  end
  return format:format(...)
end

-- Checks if a string starts with a prefix.
function stringer.startswith(s, prefix)
  return s:find(prefix,1,true) == 1
end

-- Checks if a string ends with a prefix.
function stringer.endswith(s, suffix)
  local init = #s - #suffix + 1
  return init >= 1 and s:find(suffix, init, true) ~= nil
end

-- Returns a string with right white spaces trimmed.
function stringer.rtrim(s)
  return (s:gsub("%s*$", ""))
end

-- Split a string into a table using a separator (default to space).
function stringer.split(s, sep)
  sep = sep or ' '
  local res = {}
  local pattern = ("([^%s]+)"):format(sep or ' ')
  for each in s:gmatch(pattern) do
    res[#res+1] = each
  end
  return res
end

-- Extract a specific line from a text.
function stringer.getline(text, lineno)
  if lineno <= 0 then return nil end
  local linestart = 1
  if lineno > 1 then
    local l = 1
    for pos in text:gmatch('\n()') do
      l = l + 1
      if l >= lineno then
        linestart = pos
        break
      end
    end
    if not linestart then return nil end -- not found
  end
  local lineend = text:find('\n', linestart, true)
  lineend = lineend and lineend-1 or nil
  return text:sub(linestart, lineend), linestart, lineend
end

-- Insert a text in the middle of string and return the new string.
function stringer.insert(s, pos, text)
  return s:sub(1, pos-1)..text..s:sub(pos)
end

-- Insert a text after another matched text and return the new string.
function stringer.insertafter(s, matchtext, text)
  local matchpos = s:find(matchtext, 1, true)
  if matchpos then
    return stringer.insert(s, matchpos+#matchtext, text)
  end
end

-- Ensures string `s` ends with a new line.
function stringer.ensurenewline(s)
  if not stringer.endswith(s, '\n') then
    return s..'\n'
  end
  return s
end

return stringer
