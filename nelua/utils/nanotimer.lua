-- Nanotimer class
--
-- The nano timer is a utility used to count elapsed time.
-- Used in the compiler to debug compile times.

local metamagic = require 'nelua.utils.metamagic'
local nanotime = require 'chronos'.nanotime

-- The nanotimer class is created here manually instead of using the class module
-- to have more efficiency.
local nanotimer = {}
local nanotimer_mt = {__index = nanotimer}
local function createnanotimer()
  return setmetatable({s = nanotime()}, nanotimer_mt)
end

--luacov:disable

-- Restart the timer.
function nanotimer.restart(t)
  t.s = nanotime()
end

-- Returns the elapsed time in milliseconds since last restart.
function nanotimer.elapsed(t)
  return (nanotime() - t.s) * 1000
end

--luacov:enable

-- Restart the timer and returns the elapsed time in milliseconds since last restart.
function nanotimer.elapsedrestart(t)
  local s = nanotime()
  local e = (s - t.s) * 1000
  t.s = s
  return e
end

-- Allow calling nanotimer to create a new timer.
metamagic.setmetacall(nanotimer, createnanotimer)

return nanotimer
