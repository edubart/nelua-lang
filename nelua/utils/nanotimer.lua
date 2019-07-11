local metamagic = require 'nelua.utils.metamagic'
local nanotime = require 'chronos'.nanotime

local nanotimer = {}
local nanotimer_mt = {__index = nanotimer}

local function createnanotimer()
  return setmetatable({s = nanotime()}, nanotimer_mt)
end

--luacov:disable
function nanotimer.restart(t)
  t.s = nanotime()
end

function nanotimer.elapsed(t)
  return (nanotime() - t.s) * 1000
end
--luacov:enable

function nanotimer.elapsedrestart(t)
  local s = nanotime()
  local e = (s - t.s) * 1000
  t.s = s
  return e
end

metamagic.setmetacall(nanotimer, createnanotimer)

return nanotimer
