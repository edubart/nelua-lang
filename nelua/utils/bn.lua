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
  return bn.new(s)
end

function bn.isintegral(v)
  return v == v:trunc()
end

function bn.tointeger(v)
  local vint = v:trunc()
  if v == vint then
    return tonumber(tostring(vint))
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
  if #t == 0 then
    return '0'
  end
  return table.concat(t)
end

local function remove_extra_zeros(vstr)
  if vstr:find('%.') then
    -- remove extra zeros after the decimal point
    vstr = vstr:gsub('0+$', '')
    vstr = vstr:gsub('%.$', '')
  end
  return vstr
end

function bn.todec(v, maxdigits)
  local vstr = v:tostring()
  if maxdigits then
    -- limit number of significant digits
    local significantdigits = vstr:gsub('[-.]',''):gsub('^0+','')
    local extradigits = #vstr - #significantdigits
    return vstr:sub(1, extradigits + maxdigits)
  end
  return vstr
end

function bn.floor(v)
  local q, r = v:quotrem(1)
  if q:isneg() and not r:iszero() then
    return q:add(-1)
  end
  return q
end

local orig_tostring = bn.tostring
function bn.tostring(v)
  return remove_extra_zeros(orig_tostring(v))
end
bn.__tostring = bn.tostring

return bn
