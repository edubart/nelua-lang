-- BN class
--
-- The BN (stands for big number) is used to represent either float or big integers.
-- It uses the lua-bint library to perform operations on large integers.
-- The compiler needs this class because Lua cannot work with integers large than 64 bits.
-- Large integers are required to work with uint64,
-- to mix operation between different integers ranges at compile time,
-- and to do error checking on invalid large integers.

-- BN is actually a bint class created with 128bits and with some extensions.
local bn = require 'nelua.thirdparty.bint'(128)

-- This is used to check if a table is a 'bn'.
bn._bn = true

-- Helper to convert a number composed of strings parts in any base to a big number.
local function from(base, expbase, int, frac, exp)
  local neg = false
  -- we need to read as positive, we can negate later
  if int:match('^%-') then
    neg = true
    int = int:sub(2)
  end
  -- handle infs and nans
  if int == 'inf' then
    return not neg and math.huge or -math.huge
  elseif int == 'nan' then
    -- 0.0/0.0 always is a nan in lua
    return 0.0/0.0
  end
  -- parse the integral part
  local n = bn.zero()
  for i=1,#int do
    local d = tonumber(int:sub(i,i), base)
    assert(d)
    n = (n * base) + d
  end
  -- parse the fractional part
  if frac then
    local fracnum = from(base, expbase, frac)
    local fracdiv = bn.ipow(base, #frac)
    n = n + fracnum / fracdiv
  end
  -- parse the exponential part
  if exp then
    n = n * bn.ipow(expbase, tonumber(exp))
  end
  -- negate if needed
  if neg then
    n = -n
  end
  return n
end

-- Converts a hexadecimal number composed of string parts to a big number.
function bn.fromhex(int, frac, exp)
  if frac and exp then -- hexadecimal float with fraction and exponent
    return tonumber(string.format('0x%s.%sp%s', int, frac, exp))
  elseif frac then -- hexadecimal float with fraction
    return tonumber(string.format('0x%s.%s', int, frac))
  elseif exp then -- hexadecimal float  with exponent
    return tonumber(string.format('0x%sp%s', int, exp))
  else -- hexadecimal integral
    return from(16, 2, int)
  end
end

-- Converts a binary number composed of string parts to a big number.
function bn.frombin(int, frac, exp)
  return from(2, 2, int, frac, exp)
end

-- Converts a decimal number composed of string parts strings to a big number.
function bn.fromdec(int, frac, exp)
  if frac and exp then -- decimal float with fraction and exponent
    return tonumber(string.format('%s.%se%s', int, frac, exp))
  elseif frac then -- decimal float with fraction
    return tonumber(string.format('%s.%s', int, frac))
  elseif exp then -- decimal float with exponent
    return tonumber(string.format('%se%s', int, exp))
  else -- decimal integral
    return from(10, 10, int)
  end
end

-- Split a number string into string parts.
function bn.splitdecsci(s)
  -- handle nans and infs
  if s == 'inf' or s == '-inf' or s == 'nan' or s == '-nan' then
    return s
  end
  -- split into string parts
  local int, frac, exp = s:match('^(-?%d+)[.]?(%d+)[eE]?([+-]?%d*)$')
  if not int then
    int, exp = s:match('^(-?%d+)[eE]?([+-]?%d*)$')
  end
  assert(int)
  if exp == '' then
    exp = nil
  end
  return int, frac, exp
end

-- Convert a number composed of string parts in a specific base to a big number.
function bn.from(base, int, frac, exp)
  if base == 'dec' then
    return bn.fromdec(int, frac, exp)
  elseif base == 'hex' then
    return bn.fromhex(int, frac, exp)
  else
    assert(base == 'bin')
    return bn.frombin(int, frac, exp)
  end
end

-- Convert an integral number to a string in hexadecimal base.
function bn.tohex(v, bits)
  if bits then -- wrap around
    v = v:bwrap(bits)
  end
  return bn.tobase(v, 16, true)
end

-- Convert an integral number to a string in binary base.
function bn.tobin(v, bits)
  if bits then -- wrap around
    v = v:bwrap(bits)
  end
  return bn.tobase(v, 2, true)
end

-- Convert an integral number to a string in decimal base.
function bn.todec(v)
  return bn.tobase(v, 10, false)
end

-- Convert to a string in decimal base considering fractional values,
-- possibly using scientific notation for float numbers, to have a shorter output.
function bn.todecsci(v, maxdigits)
  if bn.isbint(v) then
    -- in case of bints we can just it as string
    return tostring(v)
  end

  -- force converting it to a number
  v = tonumber(v)
  local ty = math.type(v)

  if ty == 'integer' then
    -- in case of lua integers we can return it as string
    return tostring(v)
  end

  -- can only be a float from now on
  assert(ty == 'float')

  -- 64 bit floats can only be uniquely represented by 17 decimals digits
  maxdigits = maxdigits or 17

  -- try to use a small float representation if possible
  if maxdigits >= 16 then
    local s = string.format('%.15g', v)
    if tonumber(s) == v then
      return s
    end
    s = string.format('%.16g', v)
    if tonumber(s) == v then
      return s
    end
  end

  -- return the float represented in a string
  return string.format('%.'..maxdigits..'g', v)
end

-- Check if the input is a NaN (not a number).
function bn.isnan(x)
  -- a nan is never equals to itself
  return x ~= x
end

-- Check if the input is infinite.
function bn.isinfinite(x)
  return math.type(x) == 'float' and math.abs(x) == math.huge
end

return bn
