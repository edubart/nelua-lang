local bn = require 'bc'
bn.digits(64)

function bn.fromhex(s)
  s = s:lower()
  assert(s:match('^[0-9a-f]+$'), 'invalid hexadecimal number')
  local n = bn.number(0)
  for i=1,#s do
    n = (n * 16) + tonumber(s:sub(i,i), 16)
  end
  return n:trunc()
end

function bn.frombin(s)
  s = s:lower()
  assert(s:match('^[01]+$'), 'invalid binary number')
  local n = bn.number(0)
  for i=1,#s do
    n = (n * 2) + tonumber(s:sub(i,i), 2)
  end
  return n:trunc()
end

function bn.tohex(v)
  local n = bn.number(v)
  local zero = bn.number(0)
  local t = {}
  while n > zero do
    local d = (n % 16):tonumber()
    table.insert(t, 1, string.format('%x', d))
    n = (n / 16):trunc()
  end
  return table.concat(t)
end

function bn.todec(v)
  return v:tostring():gsub('0+$', '')
end

return bn
