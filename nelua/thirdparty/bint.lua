-- source taken from https://github.com/edubart/lua-bint
-- lua-bint 0.2
--[[
The MIT License (MIT)

Copyright (c) 2020 Eduardo Bart (https://github.com/edubart)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

--[[--
Small portable arbitrary-precision integer arithmetic library in pure Lua for
computing with large integers.

Different from most arbitrary precision integer libraries in pure Lua out there this one
uses an array of lua integers as underlying data-type in its implementation instead of
using strings or large tables, so regarding that aspect this library should be more efficient.

## Design goals

The main design goal of this library is to be small, correct, self contained and use few
resources while retaining acceptable performance and feature completeness.

The library is designed to follow recent Lua integer semantics, this means that
integer overflow warps around,
signed integers are implemented using two-complement arithmetic rules,
integer division operations rounds towards minus infinity,
any mixed operations with float numbers promotes the value to a float,
and the usual division/power operation always promote to floats.

The library is designed to be possible to work with only unsigned integer arithmetic
when using the proper methods.

All the lua arithmetic operators (+, -, *, //, /, %) and bitwise operators (&, |, ~, <<, >>)
are implemented as metamethods.

## Usage

First on you should configure how many bits the library will work with,
to do that call @{bint.scale} once on startup with the desired number of bits in multiples of 32,
for example bint.scale(1024).
By default bint uses 256 bits integers in case you never call scale.

Then when you need create a bint, you can use one of the following functions:

* @{bint.fromuinteger} (convert from lua integers, but read as unsigned integer)
* @{bint.frominteger} (convert from lua integers, preserving the sign)
* @{bint.frombase} (convert from arbitrary bases, like hexadecimal)
* @{bint.trunc} (convert from lua numbers, truncating the fractional part)
* @{bint.new} (convert from anything, asserts on invalid integers)
* @{bint.tobint} (convert form anything, returns nil on invalid integers)
* @{bint.parse} (convert from anything, returns a lua number as fallback)
* @{bint.zero}
* @{bint.one}
* `bint`

You can also call `bint` as it is an alias to `bint.new`.
In doubt use @{bint.new} to create a new bint.

Then you can use all the usual lua numeric operations on it,
all the arithmetic metamethods are implemented.
When you are done computing and need to get the result,
get the output from one of the following functions:

* @{bint.touinteger} (convert to a lua integer, wraps around as an unsigned integer)
* @{bint.tointeger} (convert to a lua integer, wraps around, preserves the sign)
* @{bint.tonumber} (convert to lua float, losing precision)
* @{bint.tobase} (convert to a string in any base)
* @{bint.__tostring} (convert to a string in base 10)

To output very large integer with no loss you probably want to use @{bint.tobase}
or call `tostring` to get a string representation.

## Precautions

All library functions can be mixed with lua numbers,
this makes easy to mix operations between bints and lua numbers,
however the user should take care in some situations:

* Don't mix integers and float operations if you want to work with integers only.
* Don't use the regular equal operator ('==') to compare values from this library,
unless you know in advance that both values are of the same primitive type,
otherwise it will always returns false, use @{bint.eq} to be safe.
* Don't pass fractional numbers to functions that an integer is expected
as this will throw assertions.
* Remember that casting back to lua integers or numbers precision can be lost.
* For dividing while preserving integers use the @{bint.__idiv} (the '//' operator).
* For doing power operation preserving integers use the @{bint.ipow} function.
* Configure the internal integer fixed width using @{bint.scale}
to the proper size you intend to work with, otherwise large integers may wraps around.

]]

local bint = {}
bint.__index = bint

-- Constants used internally and modified by bint.scale
local BIGINT_BITS
local BIGINT_SIZE
local BIGINT_WORDBITS
local BIGINT_WORDMAX
local BIGINT_WORDMSB
local BIGINT_MATHMININTEGER
local BIGINT_MATHMAXINTEGER

-- Returns number of bits of the internal lua integer type.
local function luainteger_bitsize()
  local n = -1
  local i = 0
  repeat
    i = i + 1
    n = n >> 1
  until n==0
  return i
end

--- Scale bint's integer width to represent integers of the desired bit size.
-- Must be called only once on startup.
-- @param bits Number of bits for the integer representation, must be multiple of wordbits and
-- at least 64.
-- @param[opt] wordbits Number of the bits for the internal world, defaults to 32.
function bint.scale(bits, wordbits)
  wordbits = wordbits or 32
  assert(bits % wordbits == 0, 'bitsize is not multiple of word bitsize')
  assert(2*wordbits <= luainteger_bitsize(), 'word bitsize must be half of the lua integer bitsize')
  assert(bits >= 64, 'bitsize must be >= 64')
  BIGINT_BITS = bits
  BIGINT_SIZE = bits // wordbits
  BIGINT_WORDBITS = wordbits
  BIGINT_WORDMAX = (1 << BIGINT_WORDBITS) - 1
  BIGINT_WORDMSB = (1 << (BIGINT_WORDBITS - 1))
  BIGINT_MATHMININTEGER = bint.new(math.mininteger)
  BIGINT_MATHMAXINTEGER = bint.new(math.maxinteger)
end

-- Create a new bint without initializing.
local function bint_newempty()
  return setmetatable({}, bint)
end

-- Convert a value to a lua integer without losing precision.
local function tointeger(x)
  x = tonumber(x)
  local ty = math.type(x)
  if ty == 'float' then
    local floorx = math.floor(x)
    if floorx ~= x then
      return nil
    end
    x = floorx
    ty = math.type(x)
  end
  if ty == 'integer' then
    return x
  else
    return nil
  end
end

-- Check if the input is a bint.
local function isbint(x)
  return getmetatable(x) == bint
end

-- Assign bint to an unsigned integer.  Used only internally.
function bint:_fromuinteger(x)
  for i=1,BIGINT_SIZE do
    self[i] = x & BIGINT_WORDMAX
    x = x >> BIGINT_WORDBITS
  end
  return self
end

--- Create a bint from an unsigned integer.
-- Treats signed integers as an unsigned integer.
-- @param x A value to initialize from convertible to a lua integer.
-- @return A new bint or nil in case the input cannot be represented by an integer.
-- @see bint.frominteger
function bint.fromuinteger(x)
  x = tointeger(x)
  if not x then
    return nil
  elseif x == 1 then
    return bint.one()
  elseif x == 0 then
    return bint.zero()
  end
  return bint_newempty():_fromuinteger(x)
end

--- Create a bint from a signed integer.
-- @param x A value to initialize from convertible to a lua integer.
-- @return A new bint or nil in case the input cannot be represented by an integer.
-- @see bint.fromuinteger
function bint.frominteger(x)
  x = tointeger(x)
  if not x then
    return nil
  elseif  x == 1 then
    return bint.one()
  elseif x == 0 then
    return bint.zero()
  end
  local neg = false
  if x < 0 then
    x = math.abs(x)
    neg = true
  end
  local n = bint_newempty():_fromuinteger(x)
  if neg then
    n:_unm()
  end
  return n
end

local basesteps = {}

-- Compute the read/write step for frombase/tobase functions.
local function getbasestep(base)
  local step = basesteps[base]
  if step then
    return step
  end
  step = 0
  local dmax = 1
  local limit = math.maxinteger // base
  repeat
    step = step + 1
    dmax = dmax * base
  until dmax >= limit
  basesteps[base] = step
  return step
end

-- Compute power with lua integers.
local function ipow(y, x, n)
  if n == 1 then
    return y * x
  elseif n & 1 == 0 then --even
    return ipow(y, x * x, n // 2)
  else
    return ipow(x * y, x * x, (n-1) // 2)
  end
end

--- Create a bint from a string of the desired base.
-- @param s The string to be converted from,
-- must have only alphanumeric and '+-' characters.
-- @param[opt] base Base that the number is represented, defaults to 10.
-- Must be at least 2 and at most 36.
-- @return A new bint or nil in case the conversion failed.
function bint.frombase(s, base)
  if type(s) ~= 'string' then
    return nil
  end
  base = base or 10
  if not (base >= 2 and base <= 36) then
    -- number base is too large
    return nil
  end
  local step = getbasestep(base)
  if #s < step then
    -- string is small, use tonumber (faster)
    return bint.frominteger(tonumber(s, base))
  end
  local sign, int = s:lower():match('^([+-]?)(%w+)$')
  if not (sign and int) then
    -- invalid integer string representation
    return nil
  end
  local n = bint.zero()
  for i=1,#int,step do
    local part = int:sub(i,i+step-1)
    local d = tonumber(part, base)
    if not d then
      -- invalid integer string representation
      return nil
    end
    if i > 1 then
      n = n * ipow(1, base, #part)
    end
    if d ~= 0 then
      n:_add(d)
    end
  end
  if sign == '-' then
    n:_unm()
  end
  return n
end

--- Convert a bint to an unsigned integer.
-- Note that large unsigned integers may be represented as negatives in lua integers.
-- Note that lua cannot represent values larger than 64 bits,
-- in that case integer values wraps around.
-- @param x A bint or a number to be converted into an unsigned integer.
-- @return An integer or nil in case the input cannot be represented by an integer.
-- @see bint.tointeger
function bint.touinteger(x)
  if isbint(x) then
    local n = 0
    for i=1,BIGINT_SIZE do
      n = n | (x[i] << (BIGINT_WORDBITS * (i - 1)))
    end
    return n
  else
    return tointeger(x)
  end
end

--- Convert a bint to a signed integer.
-- It works by taking absolute values then applying the sign bit in case needed.
-- Note that lua cannot represent values larger than 64 bits,
-- in that case integer values wraps around.
-- @param x A bint or value to be converted into an unsigned integer.
-- @return An integer or nil in case the input cannot be represented by an integer.
-- @see bint.touinteger
function bint.tointeger(x)
  if isbint(x) then
    local n = 0
    local neg = x:isneg()
    if neg then
      x = -x
    end
    for i=1,BIGINT_SIZE do
      n = n | (x[i] << (BIGINT_WORDBITS * (i - 1)))
    end
    if neg then
      n = -n
    end
    return n
  else
    return tointeger(x)
  end
end

local function bint_assert_tointeger(x)
  return assert(bint.tointeger(x), 'value has no integer representation')
end

--- Convert a bint to a lua float in case integer would wrap around or lua integer otherwise.
-- Different from @{bint.tointeger} the operation does not wraps around integers,
-- but digits precision are lost in the process of converting to a float.
-- @param x A bint or value to be converted into a lua number.
-- @return A lua number or nil in case the input cannot be represented by a number.
-- @see bint.tointeger
function bint.tonumber(x)
  if isbint(x) then
    if x >= BIGINT_MATHMININTEGER and x <= BIGINT_MATHMAXINTEGER then
      return x:tointeger()
    else
      return tonumber(tostring(x))
    end
  else
    return tonumber(x)
  end
end

-- Compute base letters to use in bint.tobase
local BASE_LETTERS = {}
do
  for i=1,36 do
    BASE_LETTERS[i-1] = ('0123456789abcdefghijklmnopqrstuvwxyz'):sub(i,i)
  end
end

-- Get the quotient and remainder for a lua integer division
local function idivmod(x, y)
  local quot = x // y
  local rem = x - (quot * y)
  return quot, rem
end

--- Convert a bint to a string in the desired base.
-- @param x The bint to be converted from.
-- @param[opt] base Base to be represented, defaults to 10.
-- Must be at least 2 and at most 36.
-- @param[opt] unsigned Whether to output as unsigned integer.
-- Defaults to false for base 10 and true for others.
-- When unsigned is false the symbol '-' is prepended in negative values.
-- @return A string representing the input.
-- @raise An assert is thrown in case the base is invalid.
function bint.tobase(x, base, unsigned)
  x = bint.tobint(x)
  if not x then
    -- x is a fractional float or something else
    return nil
  end
  base = base or 10
  if not (base >= 2 and base <= 36) then
    -- number base is too large
    return nil
  end
  if unsigned == nil then
    unsigned = base ~= 10
  end
  if base == 10 or base == 16 then
    local inluarange = x >= BIGINT_MATHMININTEGER and x <= BIGINT_MATHMAXINTEGER
    if inluarange then
      -- integer is small, use tostring or string.format (faster)
      local n = x:tointeger()
      if base == 10 then
        return tostring(n)
      elseif unsigned then
        return string.format('%x', n)
      end
    end
  end
  local ss = {}
  local neg = not unsigned and x:isneg()
  if neg then
    x = x:abs()
  end
  local step = getbasestep(base)
  local divisor = bint.new(ipow(1, base, step))
  local stop = x:iszero()
  if stop then
    return '0'
  end
  while not stop do
    local ix
    x, ix = bint.udivmod(x, divisor)
    ix = ix:tointeger()
    stop = x:iszero()
    for _=1,step do
      local d
      ix, d = idivmod(ix, base)
      if stop and ix == 0 and d == 0 then
        -- stop on leading zeros
        break
      end
      table.insert(ss, 1, BASE_LETTERS[d])
    end
  end
  if neg then
    table.insert(ss, 1, '-')
  end
  return table.concat(ss)
end

-- Convert lua numbers and strings to a bint
local function bint_fromvalue(x)
  local ty = type(x)
  if ty == 'number' then
    return bint.frominteger(x)
  elseif ty == 'string' then
    return bint.frombase(x, 10)
  end
  return nil
end

--- Create a new bint from a value.
-- @param x A value convertible to a bint (string, number or another bint).
-- @return A new bint, guaranteed to be a new reference in case needed.
-- @raise An assert is thrown in case x is not convertible to a bint.
-- @see bint.tobint
-- @see bint.parse
function bint.new(x)
  if isbint(x) then
    -- return a clone
    local n = bint_newempty()
    for i=1,BIGINT_SIZE do
      n[i] = x[i]
    end
    return n
  else
    x = bint_fromvalue(x)
  end
  assert(x, 'value cannot be represented by a bint')
  return x
end

--- Convert a value to a bint if possible.
-- @param x A value to be converted (string, number or another bint).
-- @param[opt] clone A boolean that tells if a new bint reference should be returned.
-- Defaults to false.
-- @return A bint or nil in case the conversion failed.
-- @see bint.new
-- @see bint.parse
function bint.tobint(x, clone)
  if isbint(x) then
    if not clone then
      return x
    else
      return bint.new(x)
    end
  else
    return bint_fromvalue(x)
  end
end

local function bint_assert_convert(x)
  return assert(bint.tobint(x), 'value has not integer representation')
end

--- Convert a value to a bint if possible otherwise to a lua number.
-- Useful to prepare values that you are unsure if its going to be a integer or float.
-- @param x A value to be converted (string, number or another bint).
-- @param[opt] clone A boolean that tells if a new bint reference should be returned.
-- Defaults to false.
-- @return A bint or a lua number or nil in case the conversion failed.
-- @see bint.new
-- @see bint.tobint
function bint.parse(x, clone)
  local i = bint.tobint(x, clone)
  if i then
    return i
  else
    return tonumber(x)
  end
end

--- Check if a number is 0 considering bints.
-- @param x A bint or a lua number.
function bint.iszero(x)
  if isbint(x) then
    for i=1,BIGINT_SIZE do
      if x[i] ~= 0 then
        return false
      end
    end
    return true
  else
    return x == 0
  end
end

--- Check if a number is 1 considering bints.
-- @param x A bint or a lua number.
function bint.isone(x)
  if isbint(x) then
    if x[1] ~= 1 then
      return false
    end
    for i=2,BIGINT_SIZE do
      if x[i] ~= 0 then
        return false
      end
    end
    return true
  else
    return x == 1
  end
end

--- Check if a number is -1 considering bints.
-- @param x A bint or a lua number.
function bint.isminusone(x)
  if isbint(x) then
    for i=1,BIGINT_SIZE do
      if x[i] ~= BIGINT_WORDMAX then
        return false
      end
    end
    return true
  else
    return x == -1
  end
end

--- Check if the input is a bint.
-- @param x Any lua value.
function bint.isbint(x)
  return isbint(x)
end

--- Check if the input is a lua integer or a bint.
-- @param x Any lua value.
function bint.isintegral(x)
  return isbint(x) or math.type(x) == 'integer'
end

--- Check if the input is a bint or a lua number.
-- @param x Any lua value.
function bint.isnumeric(x)
  return isbint(x) or type(x) == 'number'
end

--- Check the number type of the input (bint, integer or float).
-- @param x Any lua value.
-- Returns "bint" for bints, "integer" fot lua integers,
-- "float" from lua floats or nil otherwise.
function bint.type(x)
  if isbint(x) then
    return 'bint'
  else
    return math.type(x)
  end
end

--- Check if a number is negative considering bints.
-- Zero is guaranteed to never be negative for bints.
-- @param x A bint or a lua number.
function bint.isneg(x)
  if isbint(x) then
    return x[BIGINT_SIZE] & BIGINT_WORDMSB ~= 0
  else
    return x < 0
  end
end

--- Check if a number is positive considering bints.
-- @param x A bint or a lua number.
function bint.ispos(x)
  if isbint(x) then
    return not x:isneg() and not x:iszero()
  else
    return x > 0
  end
end

--- Check if a number is even considering bints.
-- @param x A bint or a lua number.
function bint.iseven(x)
  if isbint(x) then
    return x[1] & 1 == 0
  else
    return math.abs(x) % 2 == 0
  end
end

--- Check if a number is odd considering bints.
-- @param x A bint or a lua number.
function bint.isodd(x)
  if isbint(x) then
    return x[1] & 1 == 1
  else
    return math.abs(x) % 2 == 1
  end
end

--- Create a new bint with 0 value.
function bint.zero()
  local x = bint_newempty()
  for i=1,BIGINT_SIZE do
    x[i] = 0
  end
  return x
end

--- Create a new bint with 1 value.
function bint.one()
  local x = bint_newempty()
  x[1] = 1
  for i=2,BIGINT_SIZE do
    x[i] = 0
  end
  return x
end

--- Create a new bint with the maximum possible integer value.
function bint.maxinteger()
  local x = bint_newempty()
  for i=1,BIGINT_SIZE-1 do
    x[i] = BIGINT_WORDMAX
  end
  x[BIGINT_SIZE] = BIGINT_WORDMAX ~ BIGINT_WORDMSB
  return x
end

--- Create a new bint with the minimum possible integer value.
function bint.mininteger()
  local x = bint_newempty()
  for i=1,BIGINT_SIZE-1 do
    x[i] = 0
  end
  x[BIGINT_SIZE] = BIGINT_WORDMSB
  return x
end

--- Bitwise left shift a bint in one bit (in-place).
function bint:_shlone()
  local wordbitsm1 = BIGINT_WORDBITS - 1
  for i=BIGINT_SIZE,2,-1 do
    self[i] = ((self[i] << 1) | (self[i-1] >> wordbitsm1)) & BIGINT_WORDMAX
  end
  self[1] = (self[1] << 1) & BIGINT_WORDMAX
  return self
end

--- Bitwise right shift a bint in one bit (in-place).
function bint:_shrone()
  local wordbitsm1 = BIGINT_WORDBITS - 1
  for i=1,BIGINT_SIZE-1 do
    self[i] = ((self[i] >> 1) | (self[i+1] << wordbitsm1)) & BIGINT_WORDMAX
  end
  self[BIGINT_SIZE] = self[BIGINT_SIZE] >> 1
  return self
end

-- Bitwise left shift words of a bint (in-place). Used only internally.
function bint:_shlwords(n)
  for i=BIGINT_SIZE,n+1,-1 do
    self[i] = self[i - n]
  end
  for i=1,n do
    self[i] = 0
  end
  return self
end

-- Bitwise right shift words of a bint (in-place). Used only internally.
function bint:_shrwords(n)
  if n < BIGINT_SIZE then
    for i=1,BIGINT_SIZE-n+1 do
      self[i] = self[i + n]
    end
    for i=BIGINT_SIZE-n,BIGINT_SIZE do
      self[i] = 0
    end
  else
    for i=1,BIGINT_SIZE do
      self[i] = 0
    end
  end
  return self
end

--- Increment a bint by one (in-place).
function bint:_inc()
  for i=1,BIGINT_SIZE do
    local tmp = self[i]
    local v = (tmp + 1) & BIGINT_WORDMAX
    self[i] = v
    if v > tmp then
      break
    end
  end
  return self
end

--- Increment a number by one considering bints.
-- @param x A bint or a lua number to increment.
function bint.inc(x)
  local ix = bint.tobint(x, true)
  if ix then
    return ix:_inc()
  else
    return x + 1
  end
end

--- Decrement a bint by one (in-place).
function bint:_dec()
  for i=1,BIGINT_SIZE do
    local tmp = self[i]
    local v = (tmp - 1) & BIGINT_WORDMAX
    self[i] = v
    if not (v > tmp) then
      break
    end
  end
  return self
end

--- Decrement a number by one considering bints.
-- @param x A bint or a lua number to decrement.
function bint.dec(x)
  local ix = bint.tobint(x, true)
  if ix then
    return ix:_dec()
  else
    return x - 1
  end
end

--- Assign a bint to a new value (in-place).
-- @param y A value to be copied from.
-- @raise Asserts in case inputs are not convertible to integers.
function bint:_assign(y)
  y = bint_assert_convert(y)
  for i=1,BIGINT_SIZE do
    self[i] = y[i]
  end
  return self
end

--- Take absolute of a bint (in-place).
function bint:_abs()
  if self:isneg() then
    self:_unm()
  end
  return self
end

--- Take absolute of a number considering bints.
-- @param x A bint or a lua number to take the absolute.
function bint.abs(x)
  local ix = bint.tobint(x, true)
  if ix then
    return ix:_abs()
  else
    return math.abs(x)
  end
end

--- Take floor of a number considering bints.
-- @param x A bint or a lua number to perform the floor.
function bint.floor(x)
  if isbint(x) then
    return bint.new(x)
  else
    return bint.new(math.floor(tonumber(x)))
  end
end

--- Take ceil of a number considering bints.
-- @param x A bint or a lua number to perform the ceil.
function bint.ceil(x)
  if isbint(x) then
    return bint.new(x)
  else
    return bint.new(math.ceil(tonumber(x)))
  end
end

-- Wrap around bits of an integer (discarding left bits) considering bints.
-- @param x A bint or a lua integer.
-- @param y Number of right bits to preserve.
function bint.bwrap(x, y)
  x = bint_assert_convert(x)
  if y <= 0 then
    return bint.zero()
  elseif y < BIGINT_BITS then
    return x & (bint.one() << y):_dec()
  else
    return bint.new(x)
  end
end

--- Truncate a number to a bint.
-- Floats numbers are truncated, that is, the fractional port is discarded.
-- @param x A number to truncate.
-- @return A new bint or nil in case the input does not fit in a bint or is not a number.
function bint.trunc(x)
  if not isbint(x) then
    x = tonumber(x)
    if not x then
      return nil
    end
    local ty = math.type(x)
    if ty == 'float' then
      -- truncate to integer
      x = math.modf(x)
    end
    return bint.frominteger(x)
  else
    return bint.new(x)
  end
end

--- Take maximum between two numbers considering bints.
-- @param x A bint or lua number to compare.
-- @param y A bint or lua number to compare.
-- @return A bint or a lua number. Guarantees to return a new bint for integer values.
function bint.max(x, y)
  local ix, iy = bint.tobint(x), bint.tobint(y)
  if ix and iy then
    return bint.new(ix > iy and ix or iy)
  else
    return bint.parse(math.max(x, y))
  end
end

--- Take minimum between two numbers considering bints.
-- @param x A bint or lua number to compare.
-- @param y A bint or lua number to compare.
-- @return A bint or a lua number. Guarantees to return a new bint for integer values.
function bint.min(x, y)
  local ix, iy = bint.tobint(x), bint.tobint(y)
  if ix and iy then
    return bint.new(ix < iy and ix or iy)
  else
    return bint.parse(math.min(x, y))
  end
end

--- Add an integer to a bint (in-place).
-- @param y An integer to be added.
-- @raise Asserts in case inputs are not convertible to integers.
function bint:_add(y)
  y = bint_assert_convert(y)
  local carry = 0
  for i=1,BIGINT_SIZE do
    local tmp = self[i] + y[i] + carry
    carry = tmp > BIGINT_WORDMAX and 1 or 0
    self[i] = tmp & BIGINT_WORDMAX
  end
  return self
end

--- Add two numbers considering bints.
-- @param x A bint or a lua number to be added.
-- @param y A bint or a lua number to be added.
function bint.__add(x, y)
  local ix, iy = bint.tobint(x), bint.tobint(y)
  if ix and iy then
    local z = bint_newempty()
    local carry = 0
    for i=1,BIGINT_SIZE do
      local tmp = ix[i] + iy[i] + carry
      carry = tmp > BIGINT_WORDMAX and 1 or 0
      z[i] = tmp & BIGINT_WORDMAX
    end
    return z
  else
    return bint.tonumber(x) + bint.tonumber(y)
  end
end

--- Subtract an integer from a bint (in-place).
-- @param y An integer to subtract.
-- @raise Asserts in case inputs are not convertible to integers.
function bint:_sub(y)
  y = bint_assert_convert(y)
  local borrow = 0
  local wordmaxp1 = BIGINT_WORDMAX + 1
  for i=1,BIGINT_SIZE do
    local res = (self[i] + wordmaxp1) - (y[i] + borrow)
    self[i] = res & BIGINT_WORDMAX
    borrow = res <= BIGINT_WORDMAX and 1 or 0
  end
  return self
end

--- Subtract two numbers considering bints.
-- @param x A bint or a lua number to be subtract from.
-- @param y A bint or a lua number to subtract.
function bint.__sub(x, y)
  local ix, iy = bint.tobint(x), bint.tobint(y)
  if ix and iy then
    local z = bint_newempty()
    local borrow = 0
    local wordmaxp1 = BIGINT_WORDMAX + 1
    for i=1,BIGINT_SIZE do
      local res = (ix[i] + wordmaxp1) - (iy[i] + borrow)
      z[i] = res & BIGINT_WORDMAX
      borrow = res <= BIGINT_WORDMAX and 1 or 0
    end
    return z
  else
    return bint.tonumber(x) - bint.tonumber(y)
  end
end

--- Multiply two numbers considering bints.
-- @param x A bint or a lua number to multiply.
-- @param y A bint or a lua number to multiply.
function bint.__mul(x, y)
  local ix, iy = bint.tobint(x), bint.tobint(y)
  if ix and iy then
    local z = bint.zero()
    local sizep1 = BIGINT_SIZE+1
    local s = sizep1
    local e = 0
    for i=1,BIGINT_SIZE do
      if ix[i] ~= 0 or iy[i] ~= 0 then
        e = math.max(e, i)
        s = math.min(s, i)
      end
    end
    for i=s,e do
      for j=s,math.min(sizep1-i,e) do
        local a = ix[i] * iy[j]
        if a ~= 0 then
          local carry = 0
          for k=i+j-1,BIGINT_SIZE do
            local tmp = z[k] + (a & BIGINT_WORDMAX) + carry
            carry = tmp > BIGINT_WORDMAX and 1 or 0
            z[k] = tmp & BIGINT_WORDMAX
            a = a >> BIGINT_WORDBITS
          end
        end
      end
    end
    return z
  else
    return bint.tonumber(x) * bint.tonumber(y)
  end
end

local function findleftbit(x)
  for i=BIGINT_SIZE,1,-1 do
    local v = x[i]
    if v ~= 0 then
      local j = 0
      repeat
        v = v >> 1
        j = j + 1
      until v == 0
      return (i-1)*BIGINT_WORDBITS + j - 1, i
    end
  end
end

--- Perform unsigned division and modulo operation between two integers considering bints.
-- This is effectively the same of @{bint.udiv} and @{bint.umod}.
-- @param x The numerator, must be a bint or a lua integer.
-- @param y The denominator, must be a bint or a lua integer.
-- @return The quotient following the remainder, both bints.
-- @raise Asserts on attempt to divide by zero
-- or if inputs are not convertible to integers.
-- @see bint.udiv
-- @see bint.umod
function bint.udivmod(x, y)
  local dividend = bint.new(x)
  local divisor = bint_assert_convert(y)
  local quot = bint.zero()
  assert(not divisor:iszero(), 'attempt to divide by zero')
  if dividend:ult(divisor) then
    return quot, dividend
  end
  -- align leftmost digits in dividend and divisor
  local divisorlbit = findleftbit(divisor)
  local divdendlbit, size = findleftbit(dividend)
  local bit = divdendlbit - divisorlbit
  divisor = divisor << bit
  local wordmaxp1 = BIGINT_WORDMAX + 1
  local wordbitsm1 = BIGINT_WORDBITS - 1
  while bit >= 0 do
    -- compute divisor <= dividend
    local le = true
    for i=size,1,-1 do
      local a, b = divisor[i], dividend[i]
      if a ~= b then
        le = a < b
        break
      end
    end
    -- if the portion of the dividend above the divisor is greater or equal than to the divisor
    if le then
      -- subtract divisor from the portion of the dividend
      local borrow = 0
      for i=1,size do
        local res = (dividend[i] + wordmaxp1) - (divisor[i] + borrow)
        dividend[i] = res & BIGINT_WORDMAX
        borrow = res <= BIGINT_WORDMAX and 1 or 0
      end
      -- concatenate 1 to the right bit of the quotient
      local i = (bit // BIGINT_WORDBITS) + 1
      quot[i] = quot[i] | (1 << (bit % BIGINT_WORDBITS))
    end
    -- shift right the divisor in one bit
    for i=1,size-1 do
      divisor[i] = ((divisor[i] >> 1) | (divisor[i+1] << wordbitsm1)) & BIGINT_WORDMAX
    end
    divisor[size] = divisor[size] >> 1
    -- decrement current set bit for the quotient
    bit = bit - 1
  end
  -- the remaining dividend is the remainder
  return quot, dividend
end

--- Perform unsigned division between two integers considering bints.
-- @param x The numerator, must be a bint or a lua integer.
-- @param y The denominator, must be a bint or a lua integer.
-- @return The quotient, a bint.
-- @raise Asserts on attempt to divide by zero
-- or if inputs are not convertible to integers.
function bint.udiv(x, y)
  return (bint.udivmod(x, y))
end

--- Perform unsigned integer modulo operation between two integers considering bints.
-- @param x The numerator, must be a bint or a lua integer.
-- @param y The denominator, must be a bint or a lua integer.
-- @return The remainder, a bint.
-- @raise Asserts on attempt to divide by zero
-- or if the inputs are not convertible to integers.
function bint.umod(x, y)
  local _, rem = bint.udivmod(x, y)
  return rem
end

--- Perform integer floor division and modulo operation between two numbers considering bints.
-- This is effectively the same of @{bint.__idiv} and @{bint.__mod}.
-- @param x The numerator, a bint or lua number.
-- @param y The denominator, a bint or lua number.
-- @return The quotient following the remainder, both bint or lua number.
-- @raise Asserts on attempt to divide by zero.
-- @see bint.__idiv
-- @see bint.__mod
function bint.idivmod(x, y)
  local ix, iy = bint.tobint(x), bint.tobint(y)
  if ix and iy then
    if iy:isminusone() then
      return -ix, bint.zero()
    end
    local quot, rem = bint.udivmod(ix:abs(), iy:abs())
    local isnumneg, isdenomneg = ix:isneg(), iy:isneg()
    if isnumneg ~= isdenomneg then
      quot:_unm()
      -- round quotient towards minus infinity
      if not rem:iszero() then
        quot:_dec()
        -- adjust the remainder
        if isnumneg and not isdenomneg then
          rem:_unm():_add(y)
        elseif isdenomneg and not isnumneg then
          rem:_add(y)
        end
      end
    elseif isnumneg then
      -- adjust the remainder
      rem:_unm()
    end
    return quot, rem
  else
    return idivmod(bint.tonumber(x), bint.tonumber(y))
  end
end

--- Perform floor division between two numbers considering bints.
-- Floor division is a division that rounds the quotient towards minus infinity,
-- resulting in the floor of the division of its operands.
-- @param x The numerator, a bint or lua number.
-- @param y The denominator, a bint or lua number.
-- @return The quotient, a bint or lua number.
-- @raise Asserts on attempt to divide by zero.
function bint.__idiv(x, y)
  return (bint.idivmod(x, y))
end

--- Perform division between two numbers considering bints.
-- This always cast inputs to floats, for integer division only use @{bint.__idiv}.
-- @param x The numerator, a bint or lua number.
-- @param y The denominator, a bint or lua number.
-- @return The quotient, a lua number.
function bint.__div(x, y)
  return bint.tonumber(x) / bint.tonumber(y)
end

--- Perform integer floor modulo operation between two numbers considering bints.
-- The operation is defined as the remainder of the floor division
-- (division that rounds the quotient towards minus infinity).
-- @param x The numerator, a bint or lua number.
-- @param y The denominator, a bint or lua number.
-- @return The remainder, a bint or lua number.
-- @raise Asserts on attempt to divide by zero.
function bint.__mod(x, y)
  local _, rem = bint.idivmod(x, y)
  return rem
end

--- Perform integer power between two integers considering bints.
-- If y is negative then pow is performed as unsigned integers.
-- @param x The base, an integer.
-- @param y The exponent, an integer.
-- @return The result of the pow operation, a bint.
-- @raise Asserts in case inputs are not convertible to integers.
-- @see bint.__pow
-- @see bint.upowmod
function bint.ipow(x, y)
  y = bint_assert_convert(y)
  if y:iszero() then
    return bint.one()
  elseif y:isone() then
    return bint.new(x)
  end
  -- compute exponentiation by squaring
  x, y = bint.new(x),  bint.new(y)
  local z = bint.one()
  repeat
    if y:iseven() then
      x = x * x
      y:_shrone()
    else
      z = x * z
      x = x * x
      y:_dec():_shrone()
    end
  until y:isone()
  return x * z
end

--- Perform integer power between two unsigned integers over a modulus considering bints.
-- @param x The base, an integer.
-- @param y The exponent, an integer.
-- @param m The modulus, an integer.
-- @return The result of the pow operation, a bint.
-- @raise Asserts in case inputs are not convertible to integers.
-- @see bint.__pow
-- @see bint.ipow
function bint.upowmod(x, y, m)
  m = bint_assert_convert(m)
  if m:isone() then
    return bint.zero()
  else
    x, y = bint.new(x),  bint.new(y)
    local z = bint.one()
    x = bint.umod(x, m)
    while not y:iszero() do
      if y:isodd() then
        z = bint.umod(z*x, m)
      end
      y:_shrone()
      x = bint.umod(x*x, m)
    end
    return z
  end
end

--- Perform numeric power between two numbers considering bints.
-- This always cast inputs to floats, for integer power only use @{bint.ipow}.
-- @param x The base, a bint or lua number.
-- @param y The exponent, a bint or lua number.
-- @return The result of the pow operation, a lua number.
-- @see bint.ipow
function bint.__pow(x, y)
  return bint.tonumber(x) ^ bint.tonumber(y)
end

--- Bitwise left shift integers considering bints.
-- @param x An integer to perform the bitwise shift.
-- @param y An integer with the number of bits to shift.
-- @return The result of shift operation, a bint.
-- @raise Asserts in case inputs are not convertible to integers.
function bint.__shl(x, y)
  x, y = bint.new(x), bint_assert_tointeger(y)
  if y < 0 then
    return x >> -y
  end
  local nvals = y // BIGINT_WORDBITS
  if nvals ~= 0 then
    x:_shlwords(nvals)
    y = y - nvals * BIGINT_WORDBITS
  end
  if y ~= 0 then
    local wordbitsmy = BIGINT_WORDBITS - y
    for i=BIGINT_SIZE,2,-1 do
      x[i] = ((x[i] << y) | (x[i-1] >> wordbitsmy)) & BIGINT_WORDMAX
    end
    x[1] = (x[1] << y) & BIGINT_WORDMAX
  end
  return x
end

--- Bitwise right shift integers considering bints.
-- @param x An integer to perform the bitwise shift.
-- @param y An integer with the number of bits to shift.
-- @return The result of shift operation, a bint.
-- @raise Asserts in case inputs are not convertible to integers.
function bint.__shr(x, y)
  x, y = bint.new(x), bint_assert_tointeger(y)
  if y < 0 then
    return x << -y
  end
  local nvals = y // BIGINT_WORDBITS
  if nvals ~= 0 then
    x:_shrwords(nvals)
    y = y - nvals * BIGINT_WORDBITS
  end
  if y ~= 0 then
    local wordbitsmy = BIGINT_WORDBITS - y
    for i=1,BIGINT_SIZE-1 do
      x[i] = ((x[i] >> y) | (x[i+1] << wordbitsmy)) & BIGINT_WORDMAX
    end
    x[BIGINT_SIZE] = x[BIGINT_SIZE] >> y
  end
  return x
end

--- Bitwise AND bints (in-place).
-- @param y An integer to perform bitwise AND.
-- @raise Asserts in case inputs are not convertible to integers.
function bint:_band(y)
  y = bint_assert_convert(y)
  for i=1,BIGINT_SIZE do
    self[i] = self[i] & y[i]
  end
  return self
end

--- Bitwise AND two integers considering bints.
-- @param x An integer to perform bitwise AND.
-- @param y An integer to perform bitwise AND.
-- @raise Asserts in case inputs are not convertible to integers.
function bint.__band(x, y)
  return bint.new(x):_band(y)
end

--- Bitwise OR bints (in-place).
-- @param y An integer to perform bitwise OR.
-- @raise Asserts in case inputs are not convertible to integers.
function bint:_bor(y)
  y = bint_assert_convert(y)
  for i=1,BIGINT_SIZE do
    self[i] = self[i] | y[i]
  end
  return self
end

--- Bitwise OR two integers considering bints.
-- @param x An integer to perform bitwise OR.
-- @param y An integer to perform bitwise OR.
-- @raise Asserts in case inputs are not convertible to integers.
function bint.__bor(x, y)
  return bint.new(x):_bor(y)
end

--- Bitwise XOR bints (in-place).
-- @param y An integer to perform bitwise XOR.
-- @raise Asserts in case inputs are not convertible to integers.
function bint:_bxor(y)
  y = bint_assert_convert(y)
  for i=1,BIGINT_SIZE do
    self[i] = self[i] ~ y[i]
  end
  return self
end

--- Bitwise XOR two integers considering bints.
-- @param x An integer to perform bitwise XOR.
-- @param y An integer to perform bitwise XOR.
-- @raise Asserts in case inputs are not convertible to integers.
function bint.__bxor(x, y)
  return bint.new(x):_bxor(y)
end

--- Bitwise NOT a bint (in-place).
function bint:_bnot()
  for i=1,BIGINT_SIZE do
    self[i] = (~self[i]) & BIGINT_WORDMAX
  end
  return self
end

--- Bitwise NOT a bint.
-- @param x An integer to perform bitwise NOT.
-- @raise Asserts in case inputs are not convertible to integers.
function bint.__bnot(x)
  local y = bint_newempty()
  for i=1,BIGINT_SIZE do
    y[i] = (~x[i]) & BIGINT_WORDMAX
  end
  return y
end

--- Negate a bint (in-place). This apply effectively apply two's complements.
function bint:_unm()
  return self:_bnot():_inc()
end

--- Negate a bint. This apply effectively apply two's complements.
-- @param x A bint to perform negation.
function bint.__unm(x)
  return (~x):_inc()
end

--- Check if bints are equal.
-- @param x A bint to compare.
-- @param y A bint to compare.
function bint.__eq(x, y)
  for i=1,BIGINT_SIZE do
    if x[i] ~= y[i] then
      return false
    end
  end
  return true
end

--- Check if numbers are equal considering bints.
-- @param x A bint or lua number to compare.
-- @param y A bint or lua number to compare.
function bint.eq(x, y)
  return bint.tobint(x) == bint.tobint(y)
end

--- Compare if integer x is less than y considering bints (unsigned version).
-- @param x Left integer to compare.
-- @param y Right integer to compare.
-- @raise Asserts in case inputs are not convertible to integers.
-- @see bint.__lt
function bint.ult(x, y)
  x, y = bint_assert_convert(x), bint_assert_convert(y)
  for i=BIGINT_SIZE,1,-1 do
    local a, b = x[i], y[i]
    if a ~= b then
      return a < b
    end
  end
  return false
end

--- Compare if bint x is less or equal than y considering bints (unsigned version).
-- @param x Left integer to compare.
-- @param y Right integer to compare.
-- @raise Asserts in case inputs are not convertible to integers.
-- @see bint.__le
function bint.ule(x, y)
  x, y = bint_assert_convert(x), bint_assert_convert(y)
  for i=BIGINT_SIZE,1,-1 do
    local a, b = x[i], y[i]
    if a ~= b then
      return a < b
    end
  end
  return true
end

--- Compare if number x is less than y considering bints and signs.
-- @param x Left value to compare, a bint or lua number.
-- @param y Right value to compare, a bint or lua number.
-- @see bint.ult
function bint.__lt(x, y)
  local ix, iy = bint.tobint(x), bint.tobint(y)
  if ix and iy then
    local xneg = ix[BIGINT_SIZE] & BIGINT_WORDMSB ~= 0
    local yneg = iy[BIGINT_SIZE] & BIGINT_WORDMSB ~= 0
    if xneg == yneg then
      for i=BIGINT_SIZE,1,-1 do
        local a, b = ix[i], iy[i]
        if a ~= b then
          return a < b
        end
      end
      return false
    else
      return xneg and not yneg
    end
  else
    return bint.tonumber(x) < bint.tonumber(y)
  end
end

--- Compare if number x is less or equal than y considering bints and signs.
-- @param x Left value to compare, a bint or lua number.
-- @param y Right value to compare, a bint or lua number.
-- @see bint.ule
function bint.__le(x, y)
  local ix, iy = bint.tobint(x), bint.tobint(y)
  if ix and iy then
    local xneg = ix[BIGINT_SIZE] & BIGINT_WORDMSB ~= 0
    local yneg = iy[BIGINT_SIZE] & BIGINT_WORDMSB ~= 0
    if xneg == yneg then
      for i=BIGINT_SIZE,1,-1 do
        local a, b = ix[i], iy[i]
        if a ~= b then
          return a < b
        end
      end
      return true
    else
      return xneg and not yneg
    end
  else
    return bint.tonumber(x) <= bint.tonumber(y)
  end
end

--- Convert a bint to a string on base 10.
-- @see bint.tobase
function bint:__tostring()
  return self:tobase(10)
end

setmetatable(bint, {
  __call = function(_, x)
    return bint.new(x)
  end
})

-- set default scale
bint.scale(256)

return bint
