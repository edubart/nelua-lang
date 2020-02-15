local function fibmod(n, m)
  local a, b = 0, 1
  for i=1,n do
    a, b = b, (a + b) % m
  end
  return a
end

local res = fibmod(100000000, 1000000000000)
print(res)
assert(res == 167760546875)
