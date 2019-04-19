local bn = require 'bc'

bn.digits(64)
bn._bn = true

local function frombase(base, expbase, int, frac, exp)
  local n = bn.new(0)
  for i=1,#int do
    n = (n * base) + tonumber(int:sub(i,i), base)
  end
  if frac then
    local fracnum = frombase(base, expbase, frac)
    local fracdiv = bn.pow(base, #frac)
    n = n + fracnum / fracdiv
  end
  if exp then
    n = n * bn.pow(expbase, tonumber(exp))
  end
  local nint = n:trunc()
  if nint == n then
    n = nint
  end
  return n
end

function bn.fromhex(int, frac, exp)
  return frombase(16, 2, int, frac, exp)
end

function bn.frombin(int, frac, exp)
  return frombase(2, 2, int, frac, exp)
end

function bn.fromdec(int, frac, exp)
  local s = int
  if frac then
    s = s .. '.' .. frac
  end
  if exp then
    s = s .. 'e' .. exp
  end
  local n = bn.new(s)
  local nint = n:trunc()
  if nint == n then
    n = nint
  end
  return n
end

function bn.isintegral(v)
  return v == v:trunc()
end

function bn.tointeger(v)
  if v:isintegral() then
    return tonumber(tostring(v:trunc()))
  end
end

function bn.tohex(v)
  local n = bn.new(v)
  assert(n:isintegral(), 'cannot convert fractional numbers to hex')
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
    vstr = vstr:gsub('%.$', '')
  end
  return vstr
end

return bn
