-- Nanotimer class
--
-- The nano timer is a utility used to count elapsed time in milliseconds.
-- Used in the compiler to debug compile times.

local metamagic = require 'nelua.utils.metamagic'

-- Find nanotime function in 'sys' or 'chronos' module.
local function get_nanotime() --luacov:disable
  local has_sys, sys = pcall(require, 'sys')
  if has_sys and sys.nanotime then
    return sys.nanotime
  else
    local has_chronos, chronos = pcall(require, 'chronos')
    if has_chronos and chronos.nanotime then
      return chronos.nanotime
    end
    return os.clock
  end
end --luacov:enable

local nanotime = get_nanotime()

-- The nanotimer class is created here manually instead of using the class module
-- to have more efficiency.
local nanotimer = {nanotime = nanotime}
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
