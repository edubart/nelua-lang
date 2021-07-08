--[[
Tacker module

This is an utility used internally to optimize/debug compiler code paths.
]]

local tracker = {}

local cpucycles = require 'nelua.utils.nanotimer'.cpucycles
local tracing = {}
local timings = {}
local counts = {}

--luacov:disable

-- Start tracking cycles for section `name`.
function tracker.start(name)
  local trace = tracing[name]
  if trace then
    local depth = trace[2]
    trace[2] = depth + 1
    counts[name] = counts[name] + 1
    if depth == 0 then
      trace[1] = cpucycles()
    end
  else
    trace = {0, 1}
    tracing[name] = trace
    timings[name] = 0
    counts[name] = 1
    trace[1] = cpucycles()
  end
end

-- Finish tracking cycles for section `name`.
function tracker.finish(name)
  local now = cpucycles()
  local trace = tracing[name]
  local depth = trace[2]
  trace[2] = depth - 1
  if depth == 1 then
    timings[name] = timings[name] + (now - trace[1])
  end
end

-- Track call count for section `name`.
function tracker.track(name)
  if not counts[name] then
    counts[name] = 1
  else
    counts[name] = counts[name] + 1
  end
end

-- Report all measured sections.
function tracker.report()
  local list = {}
  for name,count in pairs(counts) do
    list[#list+1] = {name, count}
  end
  table.sort(list, function(a,b) return a[2] < b[2] end)
  for _,item in ipairs(list) do
    local name, count = table.unpack(item)
    local timing = timings[name]
    if timing then
      print(string.format('%s %d %.1f cycles', name, count, timing / count))
    else
      print(string.format('%s %d', name, count))
    end
  end
end

--luacov:enable

-- Make tracker module available in globally (so it's quick to use it).
_G.tracker = tracker

return tracker
