-- Edit this file on REPL.it to try out Nelua in the browser,
-- go to https://repl.it/@edubart/nelua-lang#examples/replit.lua
-- find this file and run

print 'Hello from REPL.it!'

-- require string library to allow concatenating strings
require 'string'

local function factorial(n: integer): integer
  if n == 0 then
    return 1
  else
    return n * factorial(n - 1)
  end
end

local n = 5
local res = factorial(n)

print(n .. ' factorial is ' .. res)
