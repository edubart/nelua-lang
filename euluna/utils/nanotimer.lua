local metamagic = require 'euluna.utils.metamagic'
local nanotime = require 'chronos'.nanotime

local nanotimer = {}
local nanotimer_mt = {__index = nanotimer}

local function nanotimer_init()
  return setmetatable({s = nanotime()}, nanotimer_mt)
end

--luacov:disable
function nanotimer.restart(t)
  t.s = nanotime()
end

function nanotimer.elapsed(t)
  return (nanotime() - t.s) * 1000
end

function nanotimer.elapsed_restart(t)
  local s = nanotime()
  local e = (s - t.s) * 1000
  t.s = s
  return e
end
--luacov:enable

metamagic.setmetacall(nanotimer, nanotimer_init)

return nanotimer
