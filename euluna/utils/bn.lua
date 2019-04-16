local bn = require 'bc'
bn.digits(64)

function bn.fromhex(s)
  assert(s:match('^[0-9a-fA-F]+$'), 'invalid hexadecimal number')
  local n = bn.new(0)
  for i=1,#s do
    n = (n * 16) + tonumber(s:sub(i,i), 16)
  end
  return n:trunc()
end

function bn.frombin(s)
  assert(s:match('^[01]+$'), 'invalid binary number')
  local n = bn.new(0)
  for i=1,#s do
    n = (n * 2) + tonumber(s:sub(i,i), 2)
  end
  return n:trunc()
end

function bn.tohex(v)
  local n = bn.new(v)
  assert(n == n:trunc(), 'cannot convert fractional numbers to hex')
  local t = {}
  while not n:iszero() do
    local d = (n % 16):tonumber()
    table.insert(t, 1, string.format('%x', d))
    n = (n / 16):trunc()
  end
  return table.concat(t)
end

function bn.todec(v)
  local vstr = v:tostring()
  if vstr:find('%.') then
    vstr = vstr:gsub('0+$', '')
  end
  return vstr
end

return bn
