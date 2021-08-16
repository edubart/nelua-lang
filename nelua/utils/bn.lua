--[[
BN class

The BN (stands for Big Number) is used to represent either float or big integers.
It uses the lua-bint library to perform operations on large integers.
The compiler needs this class because Lua cannot work with integers large than 64 bits.
Large integers are required to work with `uint64`, `int128` and `uint128`,
to mix operation between different integers ranges at compile time,
and to do error checking on integer overflows.
]]

-- BN is actually a `bint` class created with 160bits with some extensions.
local bn = require 'nelua.thirdparty.bint'(160)

local rex = require 'nelua.thirdparty.lpegrex'

-- Pattern to extract `neg`, `int`, `frac`, and `exp` parts from a binary number.
local binpatt = rex.compile[[
bin <- ('-' $true / '+'? $false)
  '0' [bB]
  (b ('.' (b / $'0'))~? / '.' $'0' b)
  ([pP] {[+-]? [0-9]+})?  !.
b <- {[01]+}
]]

-- Pattern to extract `neg`, `int`, `frac`, and `exp` parts from a hexadecimal number.
local hexpatt = rex.compile[[
hex <- ('-' $true / '+'? $false)
  '0' [xX]
  (h ('.' (h / $'0'))~? / '.' $'0' h)
  ([pP] {[+-]? [0-9]+})?  !.
h <- {[0-9a-fA-F]+}
]]

-- Used to check if a table is a 'bn'.
bn._bn = true

-- Helper to convert a number composed of strings parts in any base to a big number.
local function from(base, expbase, int, frac, exp)
  -- parse the integral part
  local n = bn.zero()
  for i=1,#int do
    local d = tonumber(int:sub(i,i), base)
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
    local e = tonumber(exp)
    local s = bn.ipow(expbase, math.abs(e))
    if e < 0 then s = 1/s end
    n = n * s
  end
  return n
end

-- Convert a string number to a big number. Returns the number and its base.
function bn.from(v)
  if type(v) == 'string' then
    if v:find('^[-+]?0[bB]') then -- binary number
      local neg, int, frac, exp = binpatt:match(v)
      assert(int, 'malformed binary number')
      local n = from(2, 2, int, frac, exp)
      if neg then n = -n end
      return n, 2
    elseif v:find('^[-+]?0[xX]') then -- hexadecimal number
      if v:find('[.pP]') then -- has a fraction or exponent
        return tonumber(v), 16
      else -- integral
        local neg, int, frac, exp = hexpatt:match(v)
        assert(int and not frac and not exp, 'malformed hexadecimal number')
        local n = bn.frombase(int, 16)
        if neg then n = -n end
        return n, 16
      end
    elseif v == 'inf' then
      return math.huge, 10
    elseif v == '-inf' then
      return -math.huge, 10
    elseif v == 'nan' or v == '-nan' then
      return 0.0/0.0, 10
    else -- should be a decimal number
      local n = bn.parse(v)
      assert(n, 'malformed number')
      return n, 10
    end
  else -- should already be a number
    local n = bn.parse(v)
    assert(n, 'malformed number')
    return n, 10
  end
end

-- Convert an integral number to a string in hexadecimal base.
function bn.tohexint(v, bits)
  if bits then -- wrap around
    v = bn.bwrap(v, bits)
  end
  return bn.tobase(v, 16, true)
end

-- Convert an integral number to a string in binary base.
function bn.tobinint(v, bits)
  if bits then -- wrap around
    v = bn.bwrap(v, bits)
  end
  return bn.tobase(v, 2, true)
end

-- Convert an integral number to a string in decimal base.
function bn.todecint(v)
  return bn.tobase(v, 10, false)
end

--[[
Convert to a string in decimal base considering fractional values,
possibly using scientific notation for float numbers.
]]
function bn.todecsci(v, decimaldigits, forcefract)
  local s
  if bn.isbint(v) then
    -- in case of bints we can just convert to a string
    s = tostring(v)
  else
    -- force converting it to a number
    v = tonumber(v)
    local ty = math.type(v)
    if ty == 'integer' then
      -- in case of lua integers we can return it as string
      s = tostring(v)
    elseif ty == 'float' then
      -- 64 bit floats can only be uniquely represented by 17 decimals digits
      decimaldigits = decimaldigits or 17
      -- try to use a small float representation if possible
      if decimaldigits >= 16 then
        s = string.format('%.15g', v)
        if tonumber(s) ~= v then
          s = string.format('%.16g', v)
          if tonumber(s) ~= v then
            s = string.format('%.'..decimaldigits..'g', v)
          end
        end
      else
        s = string.format('%.'..decimaldigits..'g', v)
      end
      forcefract = true
    end
  end
  -- make sure it has decimals
  if forcefract and s:find('^-?[0-9]+$') then
    s = s..'.0'
  end
  return s
end

-- Convert a number to a string in decimal base, it may have fraction or exponent.
function bn.todec(v)
  if bn.isintegral(v) then
    return bn.todecint(v)
  end
  return bn.todecsci(v)
end

-- Check if the input is a NaN (not a number).
function bn.isnan(x)
  return x ~= x -- a nan is never equal to itself
end

-- Check if the input is infinite.
function bn.isinfinite(x)
  return math.type(x) == 'float' and math.abs(x) == math.huge
end

-- Convert a bn number to a lua integer/number without loss of precision.
function bn.compress(x)
  if bn.isbint(x) then
    if x <= math.maxinteger and x >= math.mininteger then
      return x:tointeger()
    end
    return x
  end
  return tonumber(x)
end

--[[
Demote a float to an integral number if there is not loss of precision.
Returns `x` as a lua integer on success, otherwise `x`.
]]
function bn.demotefloat(x)
  if math.type(x) == 'float' then
    local i = math.floor(x)
    if i == x then
      return i
    end
  end
  return x
end

return bn
