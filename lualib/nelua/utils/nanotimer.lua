--[[
Nanotimer class

The nanotimer is a utility used to count elapsed time in milliseconds.
Used in the compiler to debug compiling time and profiling.
]]

-- Find nanotime function in 'sys' or 'chronos' module.
local function get_nanotime() --luacov:disable
  local sys = _G.sys
  if sys and sys.nanotime then
    return sys.nanotime
  end
  local has_chronos, chronos = pcall(require, 'chronos')
  if has_chronos and chronos.nanotime then
    return chronos.nanotime
  end
  return os.clock
end --luacov:enable

local function get_cpucycles() --luacov:disable
  local sys = _G.sys
  if sys then
    local cpucycles = sys.rdtscp or sys.rdtsc
    if cpucycles then
      return cpucycles
    end
  end
  local clock, floor = os.clock, math.floor
  return function()
    return floor(clock() * 1000000)
  end
end --luacov:enable

local nanotime = get_nanotime()
local cpucycles = get_cpucycles()

-- The nanotimer class is manually instead of using the `class` module to have more efficiency.
local nanotimer = {nanotime = nanotime, cpucycles = cpucycles}
local nanotimer_mt = {__index = nanotimer}

-- Allow calling nanotimer to create a new timer.
setmetatable(nanotimer, {__call = function(_)
  return setmetatable({s = nanotime()}, nanotimer_mt)
end})

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

-- Global timer, used to track overall run time.
nanotimer.globaltimer = nanotimer()

return nanotimer
