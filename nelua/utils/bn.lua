local bn = require 'bc'

bn.digits(309) -- `double` exponent can go up to 10^309
bn._bn = true

local function isfinite(v)
  if v ~= v then -- nan
    return false
  elseif math.abs(v) == math.huge then -- inf
    return false
  end
  return true
end

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
  assert(n)
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
    local r = tonumber(tostring(vint))
    assert(math.floor(r) == r)
    assert(isfinite(r), 'non finite number')
    return r
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

-- Convert to a string in decimal base
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

-- Convert to a string in decimal base, possibly
-- using scientific notation if the output is too big or too small
function bn.todecsci(v, maxdigits)
  local n = v:tonumber()
  assert(isfinite(n), 'non finite number')
  local an = math.abs(n)
  if an < 1e-4 or an >= 1e14 then
    maxdigits = maxdigits or 17
    -- '%g' use the shortest representation of a floating number
    -- '%.<number>g' is the maximum number of significant digits to be printed
    local vstr = string.format('%.' .. maxdigits .. 'g', n)
    return vstr
  else
    return bn.todec(v, maxdigits)
  end
end

function bn.floor(v)
  local q, r = v:quotrem(1)
  if q:isneg() and not r:iszero() then
    return q:add(-1)
  end
  return q
end

-- override bn.new() to preserve precision of double numbers
local orig_new = bn.new
function bn.new(v)
  if type(v) == 'number' then
    assert(isfinite(v), 'non finite number')
    -- use the shortest representation of a double floating number
    v = string.format('%.17g', v)
  end
  local r = orig_new(v)
  assert(r)
  return r
end

-- override default tostring() method to remove extra zeroes
local orig_tostring = bn.tostring
function bn.tostring(v)
  local vstr = orig_tostring(v)
  if vstr:find('%.') then
    -- remove extra zeros after the decimal point
    vstr = vstr:gsub('0+$', '')
    vstr = vstr:gsub('%.$', '')
  end
  return vstr
end
bn.__tostring = bn.tostring

return bn
