--[[--
lua-bint - v0.5.1 - 26/Jun/2023
Eduardo Bart - edub4rt@gmail.com
https://github.com/edubart/lua-bint

Small portable arbitrary-precision integer arithmetic library in pure Lua for
computing with large integers.

Different from most arbitrary-precision integer libraries in pure Lua out there this one
uses an array of lua integers as underlying data-type in its implementation instead of
using strings or large tables, this make it efficient for working with fixed width integers
and to make bitwise operations.

## Design goals

The main design goal of this library is to be small, correct, self contained and use few
resources while retaining acceptable performance and feature completeness.

The library is designed to follow recent Lua integer semantics, this means that
integer overflow warps around,
signed integers are implemented using two-complement arithmetic rules,
integer division operations rounds towards minus infinity,
any mixed operations with float numbers promotes the value to a float,
and the usual division/power operation always promotes to floats.

The library is designed to be possible to work with only unsigned integer arithmetic
when using the proper methods.

All the lua arithmetic operators (+, -, *, //, /, %) and bitwise operators (&, |, ~, <<, >>)
are implemented as metamethods.

The integer size must be fixed in advance and the library is designed to be more efficient when
working with integers of sizes between 64-4096 bits. If you need to work with really huge numbers
without size restrictions then use another library. This choice has been made to have more efficiency
in that specific size range.

## Usage

First on you should require the bint file including how many bits the bint module will work with,
by calling the returned function from the require, for example:

```lua
local bint = require 'bint'(1024)
```

For more information about its arguments see @{newmodule}.
Then when you need create a bint, you can use one of the following functions:

* @{bint.fromuinteger} (convert from lua integers, but read as unsigned integer)
* @{bint.frominteger} (convert from lua integers, preserving the sign)
* @{bint.frombase} (convert from arbitrary bases, like hexadecimal)
* @{bint.fromstring} (convert from arbitrary string, support binary/hexadecimal/decimal)
* @{bint.trunc} (convert from lua numbers, truncating the fractional part)
* @{bint.new} (convert from anything, asserts on invalid integers)
* @{bint.tobint} (convert from anything, returns nil on invalid integers)
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

To output a very large integer with no loss you probably want to use @{bint.tobase}
or call `tostring` to get a string representation.

## Precautions

All library functions can be mixed with lua numbers,
this makes easy to mix operations between bints and lua numbers,
however the user should take care in some situations:

* Don't mix integers and float operations if you want to work with integers only.
* Don't use the regular equal operator ('==') to compare values from this library,
unless you know in advance that both values are of the same primitive type,
otherwise it will always return false, use @{bint.eq} to be safe.
* Don't pass fractional numbers to functions that an integer is expected
* Don't mix operations between bint classes with different sizes as this is not supported, this
will throw assertions.
* Remember that casting back to lua integers or numbers precision can be lost.
* For dividing while preserving integers use the @{bint.__idiv} (the '//' operator).
* For doing power operation preserving integers use the @{bint.ipow} function.
* Configure the proper integer size you intend to work with, otherwise large integers may wrap around.

]]

-- Returns number of bits of the internal lua integer type.
local function luainteger_bitsize()
  local n, i = -1, 0
  repeat
    n, i = n >> 16, i + 16
  until n==0
  return i
end

local math_type = math.type
local math_floor = math.floor
local math_abs = math.abs
local math_ceil = math.ceil
local math_modf = math.modf
local math_mininteger = math.mininteger
local math_maxinteger = math.maxinteger
local math_max = math.max
local math_min = math.min
local string_format = string.format
local table_insert = table.insert
local table_concat = table.concat
local table_unpack = table.unpack

local memo = {}

--- Create a new bint module representing integers of the desired bit size.
-- This is the returned function when `require 'bint'` is called.
-- @function newmodule
-- @param bits Number of bits for the integer representation, must be multiple of wordbits and
-- at least 64.
-- @param[opt] wordbits Number of the bits for the internal word,
-- defaults to half of Lua's integer size.
local function newmodule(bits, wordbits)

local intbits = luainteger_bitsize()
bits = bits or 256
wordbits = wordbits or (intbits // 2)

-- Memoize bint modules
local memoindex = bits * 64 + wordbits
if memo[memoindex] then
  return memo[memoindex]
end

-- Validate
assert(bits % wordbits == 0, 'bitsize is not multiple of word bitsize')
assert(2*wordbits <= intbits, 'word bitsize must be half of the lua integer bitsize')
assert(bits >= 64, 'bitsize must be >= 64')
assert(wordbits >= 8, 'wordbits must be at least 8')
assert(bits % 8 == 0, 'bitsize must be multiple of 8')

-- Create bint module
local bint = {}
bint.__index = bint

--- Number of bits representing a bint instance.
bint.bits = bits

-- Constants used internally
local BINT_BITS = bits
local BINT_BYTES = bits // 8
local BINT_WORDBITS = wordbits
local BINT_SIZE = BINT_BITS // BINT_WORDBITS
local BINT_WORDMAX = (1 << BINT_WORDBITS) - 1
local BINT_WORDMSB = (1 << (BINT_WORDBITS - 1))
local BINT_LEPACKFMT = '<'..('I'..(wordbits // 8)):rep(BINT_SIZE)
local BINT_MATHMININTEGER, BINT_MATHMAXINTEGER
local BINT_MININTEGER

--- Create a new bint with 0 value.
function bint.zero()
  local x = setmetatable({}, bint)
  for i=1,BINT_SIZE do
    x[i] = 0
  end
  return x
end
local bint_zero = bint.zero

--- Create a new bint with 1 value.
function bint.one()
  local x = setmetatable({}, bint)
  x[1] = 1
  for i=2,BINT_SIZE do
    x[i] = 0
  end
  return x
end
local bint_one = bint.one

-- Convert a value to a lua integer without losing precision.
local function tointeger(x)
  x = tonumber(x)
  local ty = math_type(x)
  if ty == 'float' then
    local floorx = math_floor(x)
    if floorx == x then
      x = floorx
      ty = math_type(x)
    end
  end
  if ty == 'integer' then
    return x
  end
end

--- Create a bint from an unsigned integer.
-- Treats signed integers as an unsigned integer.
-- @param x A value to initialize from convertible to a lua integer.
-- @return A new bint or nil in case the input cannot be represented by an integer.
-- @see bint.frominteger
function bint.fromuinteger(x)
  x = tointeger(x)
  if x then
    if x == 1 then
      return bint_one()
    elseif x == 0 then
      return bint_zero()
    end
    local n = setmetatable({}, bint)
    for i=1,BINT_SIZE do
      n[i] = x & BINT_WORDMAX
      x = x >> BINT_WORDBITS
    end
    return n
  end
end
local bint_fromuinteger = bint.fromuinteger

--- Create a bint from a signed integer.
-- @param x A value to initialize from convertible to a lua integer.
-- @return A new bint or nil in case the input cannot be represented by an integer.
-- @see bint.fromuinteger
function bint.frominteger(x)
  x = tointeger(x)
  if x then
    if x == 1 then
      return bint_one()
    elseif x == 0 then
      return bint_zero()
    end
    local neg = false
    if x < 0 then
      x = math_abs(x)
      neg = true
    end
    local n = setmetatable({}, bint)
    for i=1,BINT_SIZE do
      n[i] = x & BINT_WORDMAX
      x = x >> BINT_WORDBITS
    end
    if neg then
      n:_unm()
    end
    return n
  end
end
local bint_frominteger = bint.frominteger

local basesteps = {}

-- Compute the read step for frombase function
local function getbasestep(base)
  local step = basesteps[base]
  if step then
    return step
  end
  step = 0
  local dmax = 1
  local limit = math_maxinteger // base
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
  end
  return ipow(x * y, x * x, (n-1) // 2)
end

--- Create a bint from a string of the desired base.
-- @param s The string to be converted from,
-- must have only alphanumeric and '+-' characters.
-- @param[opt] base Base that the number is represented, defaults to 10.
-- Must be at least 2 and at most 36.
-- @return A new bint or nil in case the conversion failed.
function bint.frombase(s, base)
  if type(s) ~= 'string' then
    return
  end
  base = base or 10
  if not (base >= 2 and base <= 36) then
    -- number base is too large
    return
  end
  local step = getbasestep(base)
  if #s < step then
    -- string is small, use tonumber (faster)
    return bint_frominteger(tonumber(s, base))
  end
  local sign, int = s:lower():match('^([+-]?)(%w+)$')
  if not (sign and int) then
    -- invalid integer string representation
    return
  end
  local n = bint_zero()
  for i=1,#int,step do
    local part = int:sub(i,i+step-1)
    local d = tonumber(part, base)
    if not d then
      -- invalid integer string representation
      return
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
local bint_frombase = bint.frombase

--- Create a new bint from a string.
-- The string can by a decimal number, binary number prefixed with '0b' or hexadecimal number prefixed with '0x'.
-- @param s A string convertible to a bint.
-- @return A new bint or nil in case the conversion failed.
-- @see bint.frombase
function bint.fromstring(s)
  if type(s) ~= 'string' then
    return
  end
  if s:find('^[+-]?[0-9]+$') then
    return bint_frombase(s, 10)
  elseif s:find('^[+-]?0[xX][0-9a-fA-F]+$') then
    return bint_frombase(s:gsub('0[xX]', '', 1), 16)
  elseif s:find('^[+-]?0[bB][01]+$') then
    return bint_frombase(s:gsub('0[bB]', '', 1), 2)
  end
end
local bint_fromstring = bint.fromstring

--- Create a new bint from a buffer of little-endian bytes.
-- @param buffer Buffer of bytes, extra bytes are trimmed from the right, missing bytes are padded to the right.
-- @raise An assert is thrown in case buffer is not an string.
-- @return A bint.
function bint.fromle(buffer)
  assert(type(buffer) == 'string', 'buffer is not a string')
  if #buffer > BINT_BYTES then -- trim extra bytes from the right
    buffer = buffer:sub(1, BINT_BYTES)
  elseif #buffer < BINT_BYTES then -- add missing bytes to the right
    buffer = buffer..('\x00'):rep(BINT_BYTES - #buffer)
  end
  return setmetatable({BINT_LEPACKFMT:unpack(buffer)}, bint)
end

--- Create a new bint from a buffer of big-endian bytes.
-- @param buffer Buffer of bytes, extra bytes are trimmed from the left, missing bytes are padded to the left.
-- @raise An assert is thrown in case buffer is not an string.
-- @return A bint.
function bint.frombe(buffer)
  assert(type(buffer) == 'string', 'buffer is not a string')
  if #buffer > BINT_BYTES then -- trim extra bytes from the left
    buffer = buffer:sub(-BINT_BYTES, #buffer)
  elseif #buffer < BINT_BYTES then -- add missing bytes to the left
    buffer = ('\x00'):rep(BINT_BYTES - #buffer)..buffer
  end
  return setmetatable({BINT_LEPACKFMT:unpack(buffer:reverse())}, bint)
end

--- Create a new bint from a value.
-- @param x A value convertible to a bint (string, number or another bint).
-- @return A new bint, guaranteed to be a new reference in case needed.
-- @raise An assert is thrown in case x is not convertible to a bint.
-- @see bint.tobint
-- @see bint.parse
function bint.new(x)
  if getmetatable(x) ~= bint then
    local ty = type(x)
    if ty == 'number' then
      x = bint_frominteger(x)
    elseif ty == 'string' then
      x = bint_fromstring(x)
    end
    assert(x, 'value cannot be represented by a bint')
    return x
  end
  -- return a clone
  local n = setmetatable({}, bint)
  for i=1,BINT_SIZE do
    n[i] = x[i]
  end
  return n
end
local bint_new = bint.new

--- Convert a value to a bint if possible.
-- @param x A value to be converted (string, number or another bint).
-- @param[opt] clone A boolean that tells if a new bint reference should be returned.
-- Defaults to false.
-- @return A bint or nil in case the conversion failed.
-- @see bint.new
-- @see bint.parse
function bint.tobint(x, clone)
  if getmetatable(x) == bint then
    if not clone then
      return x
    end
    -- return a clone
    local n = setmetatable({}, bint)
    for i=1,BINT_SIZE do
      n[i] = x[i]
    end
    return n
  end
  local ty = type(x)
  if ty == 'number' then
    return bint_frominteger(x)
  elseif ty == 'string' then
    return bint_fromstring(x)
  end
end
local tobint = bint.tobint

--- Convert a value to a bint if possible otherwise to a lua number.
-- Useful to prepare values that you are unsure if it's going to be an integer or float.
-- @param x A value to be converted (string, number or another bint).
-- @param[opt] clone A boolean that tells if a new bint reference should be returned.
-- Defaults to false.
-- @return A bint or a lua number or nil in case the conversion failed.
-- @see bint.new
-- @see bint.tobint
function bint.parse(x, clone)
  local i = tobint(x, clone)
  if i then
    return i
  end
  return tonumber(x)
end
local bint_parse = bint.parse

--- Convert a bint to an unsigned integer.
-- Note that large unsigned integers may be represented as negatives in lua integers.
-- Note that lua cannot represent values larger than 64 bits,
-- in that case integer values wrap around.
-- @param x A bint or a number to be converted into an unsigned integer.
-- @return An integer or nil in case the input cannot be represented by an integer.
-- @see bint.tointeger
function bint.touinteger(x)
  if getmetatable(x) == bint then
    local n = 0
    for i=1,BINT_SIZE do
      n = n | (x[i] << (BINT_WORDBITS * (i - 1)))
    end
    return n
  end
  return tointeger(x)
end

--- Convert a bint to a signed integer.
-- It works by taking absolute values then applying the sign bit in case needed.
-- Note that lua cannot represent values larger than 64 bits,
-- in that case integer values wrap around.
-- @param x A bint or value to be converted into an unsigned integer.
-- @return An integer or nil in case the input cannot be represented by an integer.
-- @see bint.touinteger
function bint.tointeger(x)
  if getmetatable(x) == bint then
    local n = 0
    local neg = x:isneg()
    if neg then
      x = -x
    end
    for i=1,BINT_SIZE do
      n = n | (x[i] << (BINT_WORDBITS * (i - 1)))
    end
    if neg then
      n = -n
    end
    return n
  end
  return tointeger(x)
end
local bint_tointeger = bint.tointeger

local function bint_assert_tointeger(x)
  x = bint_tointeger(x)
  if not x then
    error('value has no integer representation')
  end
  return x
end

--- Convert a bint to a lua float in case integer would wrap around or lua integer otherwise.
-- Different from @{bint.tointeger} the operation does not wrap around integers,
-- but digits precision are lost in the process of converting to a float.
-- @param x A bint or value to be converted into a lua number.
-- @return A lua number or nil in case the input cannot be represented by a number.
-- @see bint.tointeger
function bint.tonumber(x)
  if getmetatable(x) == bint then
    if x <= BINT_MATHMAXINTEGER and x >= BINT_MATHMININTEGER then
      return x:tointeger()
    end
    return tonumber(tostring(x))
  end
  return tonumber(x)
end
local bint_tonumber = bint.tonumber

-- Compute base letters to use in bint.tobase
local BASE_LETTERS = {}
do
  for i=1,36 do
    BASE_LETTERS[i-1] = ('0123456789abcdefghijklmnopqrstuvwxyz'):sub(i,i)
  end
end

--- Convert a bint to a string in the desired base.
-- @param x The bint to be converted from.
-- @param[opt] base Base to be represented, defaults to 10.
-- Must be at least 2 and at most 36.
-- @param[opt] unsigned Whether to output as an unsigned integer.
-- Defaults to false for base 10 and true for others.
-- When unsigned is false the symbol '-' is prepended in negative values.
-- @return A string representing the input.
-- @raise An assert is thrown in case the base is invalid.
function bint.tobase(x, base, unsigned)
  x = tobint(x)
  if not x then
    -- x is a fractional float or something else
    return
  end
  base = base or 10
  if not (base >= 2 and base <= 36) then
    -- number base is too large
    return
  end
  if unsigned == nil then
    unsigned = base ~= 10
  end
  local isxneg = x:isneg()
  if (base == 10 and not unsigned) or (base == 16 and unsigned and not isxneg) then
    if x <= BINT_MATHMAXINTEGER and x >= BINT_MATHMININTEGER then
      -- integer is small, use tostring or string.format (faster)
      local n = x:tointeger()
      if base == 10 then
        return tostring(n)
      elseif unsigned then
        return string_format('%x', n)
      end
    end
  end
  local ss = {}
  local neg = not unsigned and isxneg
  x = neg and x:abs() or bint_new(x)
  local xiszero = x:iszero()
  if xiszero then
    return '0'
  end
  -- calculate basepow
  local step = 0
  local basepow = 1
  local limit = (BINT_WORDMSB - 1) // base
  repeat
    step = step + 1
    basepow = basepow * base
  until basepow >= limit
  -- serialize base digits
  local size = BINT_SIZE
  local xd, carry, d
  repeat
    -- single word division
    carry = 0
    xiszero = true
    for i=size,1,-1 do
      carry = carry | x[i]
      d, xd = carry // basepow, carry % basepow
      if xiszero and d ~= 0 then
        size = i
        xiszero = false
      end
      x[i] = d
      carry = xd << BINT_WORDBITS
    end
    -- digit division
    for _=1,step do
      xd, d = xd // base, xd % base
      if xiszero and xd == 0 and d == 0 then
        -- stop on leading zeros
        break
      end
      table_insert(ss, 1, BASE_LETTERS[d])
    end
  until xiszero
  if neg then
    table_insert(ss, 1, '-')
  end
  return table_concat(ss)
end

local function bint_assert_convert(x)
  return assert(tobint(x), 'value has not integer representation')
end

--- Convert a bint to a buffer of little-endian bytes.
-- @param x A bint or lua integer.
-- @param[opt] trim If true, zero bytes on the right are trimmed.
-- @return A buffer of bytes representing the input.
-- @raise Asserts in case input is not convertible to an integer.
function bint.tole(x, trim)
  x = bint_assert_convert(x)
  local s = BINT_LEPACKFMT:pack(table_unpack(x))
  if trim then
    s = s:gsub('\x00+$', '')
    if s == '' then
      s = '\x00'
    end
  end
  return s
end

--- Convert a bint to a buffer of big-endian bytes.
-- @param x A bint or lua integer.
-- @param[opt] trim If true, zero bytes on the left are trimmed.
-- @return A buffer of bytes representing the input.
-- @raise Asserts in case input is not convertible to an integer.
function bint.tobe(x, trim)
  x = bint_assert_convert(x)
  local s = BINT_LEPACKFMT:pack(table_unpack(x)):reverse()
  if trim then
    s = s:gsub('^\x00+', '')
    if s == '' then
      s = '\x00'
    end
  end
  return s
end

--- Check if a number is 0 considering bints.
-- @param x A bint or a lua number.
function bint.iszero(x)
  if getmetatable(x) == bint then
    for i=1,BINT_SIZE do
      if x[i] ~= 0 then
        return false
      end
    end
    return true
  end
  return x == 0
end

--- Check if a number is 1 considering bints.
-- @param x A bint or a lua number.
function bint.isone(x)
  if getmetatable(x) == bint then
    if x[1] ~= 1 then
      return false
    end
    for i=2,BINT_SIZE do
      if x[i] ~= 0 then
        return false
      end
    end
    return true
  end
  return x == 1
end

--- Check if a number is -1 considering bints.
-- @param x A bint or a lua number.
function bint.isminusone(x)
  if getmetatable(x) == bint then
    for i=1,BINT_SIZE do
      if x[i] ~= BINT_WORDMAX then
        return false
      end
    end
    return true
  end
  return x == -1
end
local bint_isminusone = bint.isminusone

--- Check if the input is a bint.
-- @param x Any lua value.
function bint.isbint(x)
  return getmetatable(x) == bint
end

--- Check if the input is a lua integer or a bint.
-- @param x Any lua value.
function bint.isintegral(x)
  return getmetatable(x) == bint or math_type(x) == 'integer'
end

--- Check if the input is a bint or a lua number.
-- @param x Any lua value.
function bint.isnumeric(x)
  return getmetatable(x) == bint or type(x) == 'number'
end

--- Get the number type of the input (bint, integer or float).
-- @param x Any lua value.
-- @return Returns "bint" for bints, "integer" for lua integers,
-- "float" from lua floats or nil otherwise.
function bint.type(x)
  if getmetatable(x) == bint then
    return 'bint'
  end
  return math_type(x)
end

--- Check if a number is negative considering bints.
-- Zero is guaranteed to never be negative for bints.
-- @param x A bint or a lua number.
function bint.isneg(x)
  if getmetatable(x) == bint then
    return x[BINT_SIZE] & BINT_WORDMSB ~= 0
  end
  return x < 0
end
local bint_isneg = bint.isneg

--- Check if a number is positive considering bints.
-- @param x A bint or a lua number.
function bint.ispos(x)
  if getmetatable(x) == bint then
    return not x:isneg() and not x:iszero()
  end
  return x > 0
end

--- Check if a number is even considering bints.
-- @param x A bint or a lua number.
function bint.iseven(x)
  if getmetatable(x) == bint then
    return x[1] & 1 == 0
  end
  return math_abs(x) % 2 == 0
end

--- Check if a number is odd considering bints.
-- @param x A bint or a lua number.
function bint.isodd(x)
  if getmetatable(x) == bint then
    return x[1] & 1 == 1
  end
  return math_abs(x) % 2 == 1
end

--- Create a new bint with the maximum possible integer value.
function bint.maxinteger()
  local x = setmetatable({}, bint)
  for i=1,BINT_SIZE-1 do
    x[i] = BINT_WORDMAX
  end
  x[BINT_SIZE] = BINT_WORDMAX ~ BINT_WORDMSB
  return x
end

--- Create a new bint with the minimum possible integer value.
function bint.mininteger()
  local x = setmetatable({}, bint)
  for i=1,BINT_SIZE-1 do
    x[i] = 0
  end
  x[BINT_SIZE] = BINT_WORDMSB
  return x
end

--- Bitwise left shift a bint in one bit (in-place).
function bint:_shlone()
  local wordbitsm1 = BINT_WORDBITS - 1
  for i=BINT_SIZE,2,-1 do
    self[i] = ((self[i] << 1) | (self[i-1] >> wordbitsm1)) & BINT_WORDMAX
  end
  self[1] = (self[1] << 1) & BINT_WORDMAX
  return self
end

--- Bitwise right shift a bint in one bit (in-place).
function bint:_shrone()
  local wordbitsm1 = BINT_WORDBITS - 1
  for i=1,BINT_SIZE-1 do
    self[i] = ((self[i] >> 1) | (self[i+1] << wordbitsm1)) & BINT_WORDMAX
  end
  self[BINT_SIZE] = self[BINT_SIZE] >> 1
  return self
end

-- Bitwise left shift words of a bint (in-place). Used only internally.
function bint:_shlwords(n)
  for i=BINT_SIZE,n+1,-1 do
    self[i] = self[i - n]
  end
  for i=1,n do
    self[i] = 0
  end
  return self
end

-- Bitwise right shift words of a bint (in-place). Used only internally.
function bint:_shrwords(n)
  if n < BINT_SIZE then
    for i=1,BINT_SIZE-n do
      self[i] = self[i + n]
    end
    for i=BINT_SIZE-n+1,BINT_SIZE do
      self[i] = 0
    end
  else
    for i=1,BINT_SIZE do
      self[i] = 0
    end
  end
  return self
end

--- Increment a bint by one (in-place).
function bint:_inc()
  for i=1,BINT_SIZE do
    local tmp = self[i]
    local v = (tmp + 1) & BINT_WORDMAX
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
  local ix = tobint(x, true)
  if ix then
    return ix:_inc()
  end
  return x + 1
end

--- Decrement a bint by one (in-place).
function bint:_dec()
  for i=1,BINT_SIZE do
    local tmp = self[i]
    local v = (tmp - 1) & BINT_WORDMAX
    self[i] = v
    if v <= tmp then
      break
    end
  end
  return self
end

--- Decrement a number by one considering bints.
-- @param x A bint or a lua number to decrement.
function bint.dec(x)
  local ix = tobint(x, true)
  if ix then
    return ix:_dec()
  end
  return x - 1
end

--- Assign a bint to a new value (in-place).
-- @param y A value to be copied from.
-- @raise Asserts in case inputs are not convertible to integers.
function bint:_assign(y)
  y = bint_assert_convert(y)
  for i=1,BINT_SIZE do
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
  local ix = tobint(x, true)
  if ix then
    return ix:_abs()
  end
  return math_abs(x)
end
local bint_abs = bint.abs

--- Take the floor of a number considering bints.
-- @param x A bint or a lua number to perform the floor operation.
function bint.floor(x)
  if getmetatable(x) == bint then
    return bint_new(x)
  end
  return bint_new(math_floor(tonumber(x)))
end

--- Take ceil of a number considering bints.
-- @param x A bint or a lua number to perform the ceil operation.
function bint.ceil(x)
  if getmetatable(x) == bint then
    return bint_new(x)
  end
  return bint_new(math_ceil(tonumber(x)))
end

--- Wrap around bits of an integer (discarding left bits) considering bints.
-- @param x A bint or a lua integer.
-- @param y Number of right bits to preserve.
function bint.bwrap(x, y)
  x = bint_assert_convert(x)
  if y <= 0 then
    return bint_zero()
  elseif y < BINT_BITS then
    return x & (bint_one() << y):_dec()
  end
  return bint_new(x)
end

--- Rotate left integer x by y bits considering bints.
-- @param x A bint or a lua integer.
-- @param y Number of bits to rotate.
function bint.brol(x, y)
  x, y = bint_assert_convert(x), bint_assert_tointeger(y)
  if y > 0 then
    return (x << y) | (x >> (BINT_BITS - y))
  elseif y < 0 then
    if y ~= math_mininteger then
      return x:bror(-y)
    else
      x:bror(-(y+1))
      x:bror(1)
    end
  end
  return x
end

--- Rotate right integer x by y bits considering bints.
-- @param x A bint or a lua integer.
-- @param y Number of bits to rotate.
function bint.bror(x, y)
  x, y = bint_assert_convert(x), bint_assert_tointeger(y)
  if y > 0 then
    return (x >> y) | (x << (BINT_BITS - y))
  elseif y < 0 then
    if y ~= math_mininteger then
      return x:brol(-y)
    else
      x:brol(-(y+1))
      x:brol(1)
    end
  end
  return x
end

--- Truncate a number to a bint.
-- Floats numbers are truncated, that is, the fractional port is discarded.
-- @param x A number to truncate.
-- @return A new bint or nil in case the input does not fit in a bint or is not a number.
function bint.trunc(x)
  if getmetatable(x) ~= bint then
    x = tonumber(x)
    if x then
      local ty = math_type(x)
      if ty == 'float' then
        -- truncate to integer
        x = math_modf(x)
      end
      return bint_frominteger(x)
    end
    return
  end
  return bint_new(x)
end

--- Take maximum between two numbers considering bints.
-- @param x A bint or lua number to compare.
-- @param y A bint or lua number to compare.
-- @return A bint or a lua number. Guarantees to return a new bint for integer values.
function bint.max(x, y)
  local ix, iy = tobint(x), tobint(y)
  if ix and iy then
    return bint_new(ix > iy and ix or iy)
  end
  return bint_parse(math_max(x, y))
end

--- Take minimum between two numbers considering bints.
-- @param x A bint or lua number to compare.
-- @param y A bint or lua number to compare.
-- @return A bint or a lua number. Guarantees to return a new bint for integer values.
function bint.min(x, y)
  local ix, iy = tobint(x), tobint(y)
  if ix and iy then
    return bint_new(ix < iy and ix or iy)
  end
  return bint_parse(math_min(x, y))
end

--- Add an integer to a bint (in-place).
-- @param y An integer to be added.
-- @raise Asserts in case inputs are not convertible to integers.
function bint:_add(y)
  y = bint_assert_convert(y)
  local carry = 0
  for i=1,BINT_SIZE do
    local tmp = self[i] + y[i] + carry
    carry = tmp >> BINT_WORDBITS
    self[i] = tmp & BINT_WORDMAX
  end
  return self
end

--- Add two numbers considering bints.
-- @param x A bint or a lua number to be added.
-- @param y A bint or a lua number to be added.
function bint.__add(x, y)
  local ix, iy = tobint(x), tobint(y)
  if ix and iy then
    local z = setmetatable({}, bint)
    local carry = 0
    for i=1,BINT_SIZE do
      local tmp = ix[i] + iy[i] + carry
      carry = tmp >> BINT_WORDBITS
      z[i] = tmp & BINT_WORDMAX
    end
    return z
  end
  return bint_tonumber(x) + bint_tonumber(y)
end

--- Subtract an integer from a bint (in-place).
-- @param y An integer to subtract.
-- @raise Asserts in case inputs are not convertible to integers.
function bint:_sub(y)
  y = bint_assert_convert(y)
  local borrow = 0
  local wordmaxp1 = BINT_WORDMAX + 1
  for i=1,BINT_SIZE do
    local res = self[i] + wordmaxp1 - y[i] - borrow
    self[i] = res & BINT_WORDMAX
    borrow = (res >> BINT_WORDBITS) ~ 1
  end
  return self
end

--- Subtract two numbers considering bints.
-- @param x A bint or a lua number to be subtracted from.
-- @param y A bint or a lua number to subtract.
function bint.__sub(x, y)
  local ix, iy = tobint(x), tobint(y)
  if ix and iy then
    local z = setmetatable({}, bint)
    local borrow = 0
    local wordmaxp1 = BINT_WORDMAX + 1
    for i=1,BINT_SIZE do
      local res = ix[i] + wordmaxp1 - iy[i] - borrow
      z[i] = res & BINT_WORDMAX
      borrow = (res >> BINT_WORDBITS) ~ 1
    end
    return z
  end
  return bint_tonumber(x) - bint_tonumber(y)
end

--- Multiply two numbers considering bints.
-- @param x A bint or a lua number to multiply.
-- @param y A bint or a lua number to multiply.
function bint.__mul(x, y)
  local ix, iy = tobint(x), tobint(y)
  if ix and iy then
    local z = bint_zero()
    local sizep1 = BINT_SIZE+1
    local s = sizep1
    local e = 0
    for i=1,BINT_SIZE do
      if ix[i] ~= 0 or iy[i] ~= 0 then
        e = math_max(e, i)
        s = math_min(s, i)
      end
    end
    for i=s,e do
      for j=s,math_min(sizep1-i,e) do
        local a = ix[i] * iy[j]
        if a ~= 0 then
          local carry = 0
          for k=i+j-1,BINT_SIZE do
            local tmp = z[k] + (a & BINT_WORDMAX) + carry
            carry = tmp >> BINT_WORDBITS
            z[k] = tmp & BINT_WORDMAX
            a = a >> BINT_WORDBITS
          end
        end
      end
    end
    return z
  end
  return bint_tonumber(x) * bint_tonumber(y)
end

--- Check if bints are equal.
-- @param x A bint to compare.
-- @param y A bint to compare.
function bint.__eq(x, y)
  for i=1,BINT_SIZE do
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
  local ix, iy = tobint(x), tobint(y)
  if ix and iy then
    return ix == iy
  end
  return x == y
end
local bint_eq = bint.eq

local function findleftbit(x)
  for i=BINT_SIZE,1,-1 do
    local v = x[i]
    if v ~= 0 then
      local j = 0
      repeat
        v = v >> 1
        j = j + 1
      until v == 0
      return (i-1)*BINT_WORDBITS + j - 1, i
    end
  end
end

-- Single word division modulus
local function sudivmod(nume, deno)
  local rema
  local carry = 0
  for i=BINT_SIZE,1,-1 do
    carry = carry | nume[i]
    nume[i] = carry // deno
    rema = carry % deno
    carry = rema << BINT_WORDBITS
  end
  return rema
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
  local nume = bint_new(x)
  local deno = bint_assert_convert(y)
  -- compute if high bits of denominator are all zeros
  local ishighzero = true
  for i=2,BINT_SIZE do
    if deno[i] ~= 0 then
      ishighzero = false
      break
    end
  end
  if ishighzero then
    -- try to divide by a single word (optimization)
    local low = deno[1]
    assert(low ~= 0, 'attempt to divide by zero')
    if low == 1 then
      -- denominator is one
      return nume, bint_zero()
    elseif low <= (BINT_WORDMSB - 1) then
      -- can do single word division
      local rema = sudivmod(nume, low)
      return nume, bint_fromuinteger(rema)
    end
  end
  if nume:ult(deno) then
    -- denominator is greater than numerator
    return bint_zero(), nume
  end
  -- align leftmost digits in numerator and denominator
  local denolbit = findleftbit(deno)
  local numelbit, numesize = findleftbit(nume)
  local bit = numelbit - denolbit
  deno = deno << bit
  local wordmaxp1 = BINT_WORDMAX + 1
  local wordbitsm1 = BINT_WORDBITS - 1
  local denosize = numesize
  local quot = bint_zero()
  while bit >= 0 do
    -- compute denominator <= numerator
    local le = true
    local size = math_max(numesize, denosize)
    for i=size,1,-1 do
      local a, b = deno[i], nume[i]
      if a ~= b then
        le = a < b
        break
      end
    end
    -- if the portion of the numerator above the denominator is greater or equal than to the denominator
    if le then
      -- subtract denominator from the portion of the numerator
      local borrow = 0
      for i=1,size do
        local res = nume[i] + wordmaxp1 - deno[i] - borrow
        nume[i] = res & BINT_WORDMAX
        borrow = (res >> BINT_WORDBITS) ~ 1
      end
      -- concatenate 1 to the right bit of the quotient
      local i = (bit // BINT_WORDBITS) + 1
      quot[i] = quot[i] | (1 << (bit % BINT_WORDBITS))
    end
    -- shift right the denominator in one bit
    for i=1,denosize-1 do
      deno[i] = ((deno[i] >> 1) | (deno[i+1] << wordbitsm1)) & BINT_WORDMAX
    end
    local lastdenoword = deno[denosize] >> 1
    deno[denosize] = lastdenoword
    -- recalculate denominator size (optimization)
    if lastdenoword == 0 then
      while deno[denosize] == 0 do
        denosize = denosize - 1
      end
      if denosize == 0 then
        break
      end
    end
    -- decrement current set bit for the quotient
    bit = bit - 1
  end
  -- the remaining numerator is the remainder
  return quot, nume
end
local bint_udivmod = bint.udivmod

--- Perform unsigned division between two integers considering bints.
-- @param x The numerator, must be a bint or a lua integer.
-- @param y The denominator, must be a bint or a lua integer.
-- @return The quotient, a bint.
-- @raise Asserts on attempt to divide by zero
-- or if inputs are not convertible to integers.
function bint.udiv(x, y)
  return (bint_udivmod(x, y))
end

--- Perform unsigned integer modulo operation between two integers considering bints.
-- @param x The numerator, must be a bint or a lua integer.
-- @param y The denominator, must be a bint or a lua integer.
-- @return The remainder, a bint.
-- @raise Asserts on attempt to divide by zero
-- or if the inputs are not convertible to integers.
function bint.umod(x, y)
  local _, rema = bint_udivmod(x, y)
  return rema
end
local bint_umod = bint.umod

--- Perform integer truncate division and modulo operation between two numbers considering bints.
-- This is effectively the same of @{bint.tdiv} and @{bint.tmod}.
-- @param x The numerator, a bint or lua number.
-- @param y The denominator, a bint or lua number.
-- @return The quotient following the remainder, both bint or lua number.
-- @raise Asserts on attempt to divide by zero or on division overflow.
-- @see bint.tdiv
-- @see bint.tmod
function bint.tdivmod(x, y)
  local ax, ay = bint_abs(x), bint_abs(y)
  local ix, iy = tobint(ax), tobint(ay)
  local quot, rema
  if ix and iy then
    assert(not (bint_eq(x, BINT_MININTEGER) and bint_isminusone(y)), 'division overflow')
    quot, rema = bint_udivmod(ix, iy)
  else
    quot, rema = ax // ay, ax % ay
  end
  local isxneg, isyneg = bint_isneg(x), bint_isneg(y)
  if isxneg ~= isyneg then
    quot = -quot
  end
  if isxneg then
    rema = -rema
  end
  return quot, rema
end
local bint_tdivmod = bint.tdivmod

--- Perform truncate division between two numbers considering bints.
-- Truncate division is a division that rounds the quotient towards zero.
-- @param x The numerator, a bint or lua number.
-- @param y The denominator, a bint or lua number.
-- @return The quotient, a bint or lua number.
-- @raise Asserts on attempt to divide by zero or on division overflow.
function bint.tdiv(x, y)
  return (bint_tdivmod(x, y))
end

--- Perform integer truncate modulo operation between two numbers considering bints.
-- The operation is defined as the remainder of the truncate division
-- (division that rounds the quotient towards zero).
-- @param x The numerator, a bint or lua number.
-- @param y The denominator, a bint or lua number.
-- @return The remainder, a bint or lua number.
-- @raise Asserts on attempt to divide by zero or on division overflow.
function bint.tmod(x, y)
  local _, rema = bint_tdivmod(x, y)
  return rema
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
  local ix, iy = tobint(x), tobint(y)
  if ix and iy then
    local isnumeneg = ix[BINT_SIZE] & BINT_WORDMSB ~= 0
    local isdenoneg = iy[BINT_SIZE] & BINT_WORDMSB ~= 0
    if isnumeneg then
      ix = -ix
    end
    if isdenoneg then
      iy = -iy
    end
    local quot, rema = bint_udivmod(ix, iy)
    if isnumeneg ~= isdenoneg then
      quot:_unm()
      -- round quotient towards minus infinity
      if not rema:iszero() then
        quot:_dec()
        -- adjust the remainder
        if isnumeneg and not isdenoneg then
          rema:_unm():_add(y)
        elseif isdenoneg and not isnumeneg then
          rema:_add(y)
        end
      end
    elseif isnumeneg then
      -- adjust the remainder
      rema:_unm()
    end
    return quot, rema
  end
  local nx, ny = bint_tonumber(x), bint_tonumber(y)
  return nx // ny, nx % ny
end
local bint_idivmod = bint.idivmod

--- Perform floor division between two numbers considering bints.
-- Floor division is a division that rounds the quotient towards minus infinity,
-- resulting in the floor of the division of its operands.
-- @param x The numerator, a bint or lua number.
-- @param y The denominator, a bint or lua number.
-- @return The quotient, a bint or lua number.
-- @raise Asserts on attempt to divide by zero.
function bint.__idiv(x, y)
  local ix, iy = tobint(x), tobint(y)
  if ix and iy then
    local isnumeneg = ix[BINT_SIZE] & BINT_WORDMSB ~= 0
    local isdenoneg = iy[BINT_SIZE] & BINT_WORDMSB ~= 0
    if isnumeneg then
      ix = -ix
    end
    if isdenoneg then
      iy = -iy
    end
    local quot, rema = bint_udivmod(ix, iy)
    if isnumeneg ~= isdenoneg then
      quot:_unm()
      -- round quotient towards minus infinity
      if not rema:iszero() then
        quot:_dec()
      end
    end
    return quot, rema
  end
  return bint_tonumber(x) // bint_tonumber(y)
end

--- Perform division between two numbers considering bints.
-- This always casts inputs to floats, for integer division only use @{bint.__idiv}.
-- @param x The numerator, a bint or lua number.
-- @param y The denominator, a bint or lua number.
-- @return The quotient, a lua number.
function bint.__div(x, y)
  return bint_tonumber(x) / bint_tonumber(y)
end

--- Perform integer floor modulo operation between two numbers considering bints.
-- The operation is defined as the remainder of the floor division
-- (division that rounds the quotient towards minus infinity).
-- @param x The numerator, a bint or lua number.
-- @param y The denominator, a bint or lua number.
-- @return The remainder, a bint or lua number.
-- @raise Asserts on attempt to divide by zero.
function bint.__mod(x, y)
  local _, rema = bint_idivmod(x, y)
  return rema
end

--- Perform integer power between two integers considering bints.
-- If y is negative then pow is performed as an unsigned integer.
-- @param x The base, an integer.
-- @param y The exponent, an integer.
-- @return The result of the pow operation, a bint.
-- @raise Asserts in case inputs are not convertible to integers.
-- @see bint.__pow
-- @see bint.upowmod
function bint.ipow(x, y)
  y = bint_assert_convert(y)
  if y:iszero() then
    return bint_one()
  elseif y:isone() then
    return bint_new(x)
  end
  -- compute exponentiation by squaring
  x, y = bint_new(x),  bint_new(y)
  local z = bint_one()
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
    return bint_zero()
  end
  x, y = bint_new(x),  bint_new(y)
  local z = bint_one()
  x = bint_umod(x, m)
  while not y:iszero() do
    if y:isodd() then
      z = bint_umod(z*x, m)
    end
    y:_shrone()
    x = bint_umod(x*x, m)
  end
  return z
end

--- Perform numeric power between two numbers considering bints.
-- This always casts inputs to floats, for integer power only use @{bint.ipow}.
-- @param x The base, a bint or lua number.
-- @param y The exponent, a bint or lua number.
-- @return The result of the pow operation, a lua number.
-- @see bint.ipow
function bint.__pow(x, y)
  return bint_tonumber(x) ^ bint_tonumber(y)
end

--- Bitwise left shift integers considering bints.
-- @param x An integer to perform the bitwise shift.
-- @param y An integer with the number of bits to shift.
-- @return The result of shift operation, a bint.
-- @raise Asserts in case inputs are not convertible to integers.
function bint.__shl(x, y)
  x, y = bint_new(x), bint_assert_tointeger(y)
  if y == math_mininteger or math_abs(y) >= BINT_BITS then
    return bint_zero()
  end
  if y < 0 then
    return x >> -y
  end
  local nvals = y // BINT_WORDBITS
  if nvals ~= 0 then
    x:_shlwords(nvals)
    y = y - nvals * BINT_WORDBITS
  end
  if y ~= 0 then
    local wordbitsmy = BINT_WORDBITS - y
    for i=BINT_SIZE,2,-1 do
      x[i] = ((x[i] << y) | (x[i-1] >> wordbitsmy)) & BINT_WORDMAX
    end
    x[1] = (x[1] << y) & BINT_WORDMAX
  end
  return x
end

--- Bitwise right shift integers considering bints.
-- @param x An integer to perform the bitwise shift.
-- @param y An integer with the number of bits to shift.
-- @return The result of shift operation, a bint.
-- @raise Asserts in case inputs are not convertible to integers.
function bint.__shr(x, y)
  x, y = bint_new(x), bint_assert_tointeger(y)
  if y == math_mininteger or math_abs(y) >= BINT_BITS then
    return bint_zero()
  end
  if y < 0 then
    return x << -y
  end
  local nvals = y // BINT_WORDBITS
  if nvals ~= 0 then
    x:_shrwords(nvals)
    y = y - nvals * BINT_WORDBITS
  end
  if y ~= 0 then
    local wordbitsmy = BINT_WORDBITS - y
    for i=1,BINT_SIZE-1 do
      x[i] = ((x[i] >> y) | (x[i+1] << wordbitsmy)) & BINT_WORDMAX
    end
    x[BINT_SIZE] = x[BINT_SIZE] >> y
  end
  return x
end

--- Bitwise AND bints (in-place).
-- @param y An integer to perform bitwise AND.
-- @raise Asserts in case inputs are not convertible to integers.
function bint:_band(y)
  y = bint_assert_convert(y)
  for i=1,BINT_SIZE do
    self[i] = self[i] & y[i]
  end
  return self
end

--- Bitwise AND two integers considering bints.
-- @param x An integer to perform bitwise AND.
-- @param y An integer to perform bitwise AND.
-- @raise Asserts in case inputs are not convertible to integers.
function bint.__band(x, y)
  return bint_new(x):_band(y)
end

--- Bitwise OR bints (in-place).
-- @param y An integer to perform bitwise OR.
-- @raise Asserts in case inputs are not convertible to integers.
function bint:_bor(y)
  y = bint_assert_convert(y)
  for i=1,BINT_SIZE do
    self[i] = self[i] | y[i]
  end
  return self
end

--- Bitwise OR two integers considering bints.
-- @param x An integer to perform bitwise OR.
-- @param y An integer to perform bitwise OR.
-- @raise Asserts in case inputs are not convertible to integers.
function bint.__bor(x, y)
  return bint_new(x):_bor(y)
end

--- Bitwise XOR bints (in-place).
-- @param y An integer to perform bitwise XOR.
-- @raise Asserts in case inputs are not convertible to integers.
function bint:_bxor(y)
  y = bint_assert_convert(y)
  for i=1,BINT_SIZE do
    self[i] = self[i] ~ y[i]
  end
  return self
end

--- Bitwise XOR two integers considering bints.
-- @param x An integer to perform bitwise XOR.
-- @param y An integer to perform bitwise XOR.
-- @raise Asserts in case inputs are not convertible to integers.
function bint.__bxor(x, y)
  return bint_new(x):_bxor(y)
end

--- Bitwise NOT a bint (in-place).
function bint:_bnot()
  for i=1,BINT_SIZE do
    self[i] = (~self[i]) & BINT_WORDMAX
  end
  return self
end

--- Bitwise NOT a bint.
-- @param x An integer to perform bitwise NOT.
-- @raise Asserts in case inputs are not convertible to integers.
function bint.__bnot(x)
  local y = setmetatable({}, bint)
  for i=1,BINT_SIZE do
    y[i] = (~x[i]) & BINT_WORDMAX
  end
  return y
end

--- Negate a bint (in-place). This effectively applies two's complements.
function bint:_unm()
  return self:_bnot():_inc()
end

--- Negate a bint. This effectively applies two's complements.
-- @param x A bint to perform negation.
function bint.__unm(x)
  return (~x):_inc()
end

--- Compare if integer x is less than y considering bints (unsigned version).
-- @param x Left integer to compare.
-- @param y Right integer to compare.
-- @raise Asserts in case inputs are not convertible to integers.
-- @see bint.__lt
function bint.ult(x, y)
  x, y = bint_assert_convert(x), bint_assert_convert(y)
  for i=BINT_SIZE,1,-1 do
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
  for i=BINT_SIZE,1,-1 do
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
  local ix, iy = tobint(x), tobint(y)
  if ix and iy then
    local xneg = ix[BINT_SIZE] & BINT_WORDMSB ~= 0
    local yneg = iy[BINT_SIZE] & BINT_WORDMSB ~= 0
    if xneg == yneg then
      for i=BINT_SIZE,1,-1 do
        local a, b = ix[i], iy[i]
        if a ~= b then
          return a < b
        end
      end
      return false
    end
    return xneg and not yneg
  end
  return bint_tonumber(x) < bint_tonumber(y)
end

--- Compare if number x is less or equal than y considering bints and signs.
-- @param x Left value to compare, a bint or lua number.
-- @param y Right value to compare, a bint or lua number.
-- @see bint.ule
function bint.__le(x, y)
  local ix, iy = tobint(x), tobint(y)
  if ix and iy then
    local xneg = ix[BINT_SIZE] & BINT_WORDMSB ~= 0
    local yneg = iy[BINT_SIZE] & BINT_WORDMSB ~= 0
    if xneg == yneg then
      for i=BINT_SIZE,1,-1 do
        local a, b = ix[i], iy[i]
        if a ~= b then
          return a < b
        end
      end
      return true
    end
    return xneg and not yneg
  end
  return bint_tonumber(x) <= bint_tonumber(y)
end

--- Convert a bint to a string on base 10.
-- @see bint.tobase
function bint:__tostring()
  return self:tobase(10)
end

-- Allow creating bints by calling bint itself
setmetatable(bint, {
  __call = function(_, x)
    return bint_new(x)
  end
})

BINT_MATHMININTEGER, BINT_MATHMAXINTEGER = bint_new(math.mininteger), bint_new(math.maxinteger)
BINT_MININTEGER = bint.mininteger()
memo[memoindex] = bint

return bint

end

return newmodule
