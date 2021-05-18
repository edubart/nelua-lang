local tracker = {}

local nanotime = require 'sys'.rdtscp
local tracing = {}
local timings = {}
local counts = {}

function tracker.start(name)
  local trace = tracing[name]
  if trace then
    local depth = trace[2]
    trace[2] = depth + 1
    counts[name] = counts[name] + 1
    if depth == 0 then
      trace[1] = nanotime()
    end
  else
    trace = {0, 1}
    tracing[name] = trace
    timings[name] = 0
    counts[name] = 1
    trace[1] = nanotime()
  end
end

function tracker.finish(name)
  local now = nanotime()
  local trace = tracing[name]
  local depth = trace[2]
  trace[2] = depth - 1
  if depth == 1 then
    timings[name] = timings[name] + (now - trace[1])
  end
end

function tracker.track(name)
  if not counts[name] then
    counts[name] = 1
  else
    counts[name] = counts[name] + 1
  end
end

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

function tracker.trackers()
  return tracker.start, tracker.finish
end

_G.tracker = tracker

return tracker
