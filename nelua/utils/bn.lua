local bn = require 'bc'

bn.digits(324) -- `double` exponent can be represent from 10^-324
bn._bn = true

local ZERO = bn.new(0)
local ONE = bn.new(1)
local TWO = bn.new(2)

--------------------------------------------------------------------------------
-- Utilities

local function isfinite(v)
  if v ~= v then -- nan
    return false
  elseif math.abs(v) == math.huge then -- inf
    return false
  end
  return true
end

local function checkin(x)
  local xtype = type(x)
  if xtype == 'number' then
    x = bn.new(x)
  else
    assert(xtype == 'userdata' and x._bn == true, 'not a big number')
  end
  return x
end

--------------------------------------------------------------------------------
-- Metamethod overrides

-- Override bn.new() to preserve precision of double numbers
local orig_new = bn.new
function bn.new(v)
  if type(v) == 'number' then
    assert(isfinite(v), 'non finite number')
    -- use the shortest representation of a double floating number
    v = string.format('%.17g', v)
  end
  local r = orig_new(v)
  assert(r)
  local rint = r:trunc()
  if r == rint then
    return rint
  end
  return r
end

-- Override default tostring() method to remove extra zeroes
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

--------------------------------------------------------------------------------
-- Conversions

local function frombase(base, expbase, int, frac, exp)
  local n = ZERO
  local neg = false
  if int:match('^%-') then
    neg = true
    int = int:sub(2)
  end
  for i=1,#int do
    local d = tonumber(int:sub(i,i), base)
    assert(d)
    n = (n * base) + d
  end
  if frac then
    local fracnum = frombase(base, expbase, frac)
    local fracdiv = bn.pow(base, #frac)
    n = n + fracnum / fracdiv
  end
  if exp then
    n = n * bn.pow(expbase, tonumber(exp))
  end
  if neg then
    n = n:neg()
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

function bn.frombase(base, int, frac, exp)
  if base == 'dec' then
    return bn.fromdec(int, frac, exp)
  elseif base == 'hex' then
    return bn.fromhex(int, frac, exp)
  else
    assert(base == 'bin')
    return bn.frombin(int, frac, exp)
  end
end

local baseletters = '0123456789abcdefghijklmnopqrstuvwxyz'
function bn.tobase(v, base)
  assert(base <= 16)
  assert(v:isintegral(), 'cannot convert fractional numbers to hex')
  local n = v:abs()
  local t = {}
  while not n:iszero() do
    local d = (n % base):tonumber()
    assert(d)
    table.insert(t, 1, baseletters:sub(d+1,d+1))
    n = (n / base):trunc()
  end
  if #t == 0 then
    return '0'
  end
  if v:isneg() then
    table.insert(t, 1, '-')
  end
  return table.concat(t)
end

function bn.tohex(v)
  return bn.tobase(v, 16)
end

function bn.tobin(v)
  return bn.tobase(v, 2)
end

function bn.todec(v, maxdigits)
  v = checkin(v)
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
  v = checkin(v)
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

function bn.tointeger(v)
  v = checkin(v)
  local vint = v:trunc()
  if v == vint then
    local r = tonumber(tostring(vint))
    assert(math.floor(r) == r)
    assert(isfinite(r), 'non finite number')
    assert(bn.new(r) == vint)
    return r
  end
end

local orig_tonumber = bn.tonumber
function bn.tonumber(v)
  local vint = v:trunc()
  if v == vint then
    return tonumber(tostring(vint))
  end
  return orig_tonumber(v)
end

--------------------------------------------------------------------------------
-- Utilities

function bn.isintegral(v)
  return v == v:trunc()
end

function bn.floor(v)
  local q, r = v:quotrem(1)
  if r:isneg() and not r:iszero() then
    return q:add(-1)
  end
  return q
end

--------------------------------------------------------------------------------
-- Binary operations

function bn.bnorm(x, bits)
  x = checkin(x)
  assert(x:isintegral(), 'not a unsigned binary number')
  -- wrap around bits modulo
  local mod = TWO:pow(bits)
  x = x % mod
  if x:isneg() then
    -- use two complement on negative values
    x = mod + x
  end
  return x:trunc()
end

function bn.bor(a,b,bits)
  a, b = bn.bnorm(a, bits), bn.bnorm(b, bits)
  local p,c=ONE,ZERO
  while a+b>ZERO do
    local ra,rb=a%2,b%2
    if ra+rb>ZERO then c=c+p end
    a,b,p=(a-ra)/2,(b-rb)/2,p*2
  end
  return c
end

function bn.band(a,b,bits)
  a, b = bn.bnorm(a, bits), bn.bnorm(b, bits)
  local p,c=ONE,ZERO
  while a>ZERO and b>ZERO do
    local ra,rb=a%2,b%2
    if ra+rb>ONE then c=c+p end
    a,b,p=(a-ra)/2,(b-rb)/2,p*2
  end
  return c
end

function bn.bnot(n,bits)
  n = bn.bnorm(n, bits)
  local p,c=ONE,ZERO
  for _=1,bits do
    local r=n%2
    if r<ONE then c=c+p end
    n,p=(n-r)/2,p*2
  end
  return c
end

function bn.bxor(a,b,bits)
  return bn.band(bn.bor(a,b,bits), bn.bnot(bn.band(a,b,bits), bits),bits)
end

local function checkshift(x)
  x = bn.tointeger(x)
  assert(x, 'not an integral number in exponent')
  return x
end

function bn.lshift(x, by, bits)
  x, by = bn.bnorm(x,bits), checkshift(by)
  if by < 0 then
    return bn.rshift(x, -by, bits)
  end
  x = x * TWO:pow(by)
  return bn.bnorm(x,bits)
end

function bn.rshift(x, by, bits)
  x, by = bn.bnorm(x, bits), checkshift(by)
  if by < 0 then
    return bn.lshift(x, -by, bits)
  end
  return (x / TWO:pow(by)):floor()
end

return bn
