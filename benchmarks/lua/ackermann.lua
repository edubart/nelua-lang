if debug.setcstacklimit then -- to work with Lua 5.4
  debug.setcstacklimit(30000)
end

local function ack(m, n)
  if m == 0 then
    return n + 1
  end
  if n == 0 then
    return ack(m - 1, 1)
  end
  return ack(m - 1, ack(m, n - 1))
end

local res = ack(3,10)
print(res)
assert(res == 8189)
