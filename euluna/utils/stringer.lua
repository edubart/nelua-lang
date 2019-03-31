local stringx = require 'pl.stringx'
local sha1 = require 'sha1'.sha1

local stringer = {}

stringer.sha1 = sha1
stringer.split = stringx.split
stringer.rstrip = stringx.rstrip

function stringer.print_concat(...)
  local t = {...}
  for i=1,select('#',...) do
    t[i] = tostring(t[i])
  end
  return table.concat(t, '\t')
end

return stringer
