local bn = require 'nelua.thirdparty.bint'(128)

bn._bn = true

local function from(base, expbase, int, frac, exp)
  local neg = false
  if int:match('^%-') then
    neg = true
    int = int:sub(2)
  end
  if int == 'inf' then
    return not neg and math.huge or -math.huge
  elseif int == 'nan' then
    return 0.0/0.0
  end
  local n = bn.zero()
  for i=1,#int do
    local d = tonumber(int:sub(i,i), base)
    assert(d)
    n = (n * base) + d
  end
  if frac then
    local fracnum = from(base, expbase, frac)
    local fracdiv = bn.ipow(base, #frac)
    n = n + fracnum / fracdiv
  end
  if exp then
    n = n * bn.ipow(expbase, tonumber(exp))
  end
  if neg then
    n = -n
  end
  return n
end

function bn.fromhex(int, frac, exp)
  if frac and exp then
    return tonumber(string.format('0x%s.%sp%s', int, frac, exp))
  elseif frac then
    return tonumber(string.format('0x%s.%s', int, frac))
  elseif exp then
    return tonumber(string.format('0x%sp%s', int, exp))
  else
    return from(16, 2, int)
  end
end

function bn.frombin(int, frac, exp)
  return from(2, 2, int, frac, exp)
end

function bn.fromdec(int, frac, exp)
  if frac and exp then
    return tonumber(string.format('%s.%se%s', int, frac, exp))
  elseif frac then
    return tonumber(string.format('%s.%s', int, frac))
  elseif exp then
    return tonumber(string.format('%se%s', int, exp))
  else
    return from(10, 10, int)
  end
end

function bn.splitdecsci(s)
  if s == 'inf' or s == '-inf' or s == 'nan' or s == '-nan' then
    return s
  end
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

-- Convert to hexadecimal base (integers only)
function bn.tohex(v, bits)
  if bits then
    v = v:bwrap(bits)
  end
  return bn.tobase(v, 16, true)
end

-- Convert to binary base (integers only)
function bn.tobin(v, bits)
  if bits then
    v = v:bwrap(bits)
  end
  return bn.tobase(v, 2, true)
end

-- Convert to decimal base (integers only)
function bn.todec(v)
  return bn.tobase(v, 10, false)
end

-- Convert to a string in decimal base considering fractional values,
-- possibly using scientific notation if the output is too big or too small
function bn.todecsci(v, maxdigits)
  if bn.isbint(v) then
    return tostring(v)
  end
  v = tonumber(v)
  local ty = math.type(v)
  if ty == 'integer' then
    return tostring(v)
  end
  assert(ty == 'float')
  maxdigits = maxdigits or 17

  -- choose the smallest float representation
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
  return string.format('%.'..maxdigits..'g', v)
end

function bn.isnan(x)
  return x ~= x
end

function bn.isinfinite(x)
  return math.type(x) == 'float' and math.abs(x) == math.huge
end

return bn
