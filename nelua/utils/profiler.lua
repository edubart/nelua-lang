local debug_getinfo = debug.getinfo
local debug_sethook = debug.sethook
local sys = require'sys'
local cycles = sys.rdtscp or sys.rdtsc or os.clock
local nanotime = sys.nanotime
local profiler = {}
local descs = {}
local calls = {}
local funcmodules = {}
local funcnames = {}
local depth = 0
local cyclesbeg, cyclesend = 0, 0
local timebeg, timeend = 0, 0

-- Hook, called before and after every function call.
local function hook(event)
  if event == 'return' then
    local now = cycles()
    if depth > 0 then
      local call = calls[depth]
      local desc = call.d
      local t = now - call.t
      depth = depth - 1
      desc.lvl = desc.lvl - 1
      desc.self = desc.self + t - call.o
      if desc.lvl == 0 then
        desc.incl = desc.incl + t
      end
      if depth > 0 then
        call = calls[depth]
        call.o = call.o + t
      end
    end
  elseif event == 'call' then
    local info = debug_getinfo(2)
    local desc = descs[info.func]
    if desc then
      desc.cnt = desc.cnt + 1
      desc.lvl = desc.lvl + 1
    else
      desc = {
        name=info.name,
        src=info.source,
        shtsrc = info.short_src,
        line=info.linedefined,
        func=info.func,
        self=0, incl=0,
        cnt=1, lvl=1
      }
      descs[info.func] = desc
    end
    depth = depth + 1
    local call = calls[depth]
    if not call then
      call = {}
      calls[depth] = call
    end
    call.d = desc
    call.o = 0
    call.t = cycles()
  elseif event == 'tail call' then
    local desc = descs[debug_getinfo(2).func]
    if desc then
      desc.cnt = desc.cnt + 1
    end
  end
end

-- Populate functions names from a module.
local function populate_module_functions(module, prefix)
  if module == package.loaded then return end
  if funcmodules[module] and #prefix >= #funcmodules[module] then
    return
  end
  local mt = getmetatable(module)
  if mt and type(mt.__index) == 'function' then return end
  funcmodules[module] = prefix
  for k,v in pairs(module) do
    if type(k) == 'string' then
      local typev = type(v)
      if typev == 'function' then
        local funcname = prefix..k
        local curname = funcnames[v]
        if not curname or #funcname < #curname then
          funcnames[v] = funcname
        end
      elseif typev == 'table' and not package.loaded[v] then
        populate_module_functions(v, prefix..k..'.')
      end
    end
  end
end

-- Populate functions names from the global environment.
local function populate_globals()
  populate_module_functions(_G, '')
  for k,v in pairs(package.loaded) do
    local typev = type(v)
    if typev == 'table' then
      populate_module_functions(v, k..'.')
    elseif typev == 'function' then
      funcnames[v] = k
    end
  end
end


-- Start the profiler.
function profiler.start()
  depth = 0
  timebeg = nanotime()
  cyclesbeg = cycles()
  debug_sethook(hook, 'cr', 0)
end

-- Stop the profiler.
function profiler.stop()
  debug_sethook()
  cyclesend = cycles()
  timeend = nanotime()
end

-- Report the profile statistics.
function profiler.report(options)
  options = options or {}
  local cyclesfield = options.incl and 'incl' or 'self'
  local threshold = options.threshold or 0
  local sorted_entries = {}
  local entries = {}
  local totcycles = cyclesend - cyclesbeg
  local tottime = timeend - timebeg
  populate_globals()
  for _,desc in pairs(descs) do
    if desc.self > 0 or desc.incl > 0 then
      local name = funcnames[desc.func] or desc.name or '<annonymous>'
      if name == 'for iterator' then
        name = '<iterator>'
      end
      local src
      if desc.src:match('^@') or desc.src:match('^=') then
        src = desc.src
      else
        src = desc.shtsrc
      end
      local k = src..':'..desc.line..' '..name
      if cyclesfield == 'incl' then
        k = k..tostring(desc.func)
      end
      local entry = entries[k]
      if not entry then
        entry = {
          name = name,
          line = desc.line,
          src = src,
          count = desc.cnt,
          self = desc.self,
          incl = desc.incl,
        }
        entries[k] = entry
        sorted_entries[#sorted_entries+1] = entry
      else
        entry.incl = entry.incl + desc.incl
        entry.self = entry.self + desc.self
        entry.count = entry.count + desc.cnt
        if not entry.closure then
          entry.closure = 1
        end
        entry.closure = entry.closure + 1
      end
    end
  end
  table.sort(sorted_entries, function(a, b) return a[cyclesfield] < b[cyclesfield] end)
  local fname = cyclesfield:sub(1,1):upper()..cyclesfield:sub(2)
  print(' '..fname..' Cycles   | Usage  | Time (ms) | Count      | Closure |'..
    ' Function                                                                         | Source')
  print(       '---------------|--------|-----------|------------|---------|'..
    '----------------------------------------------------------------------------------|-------')
  local sum = 0
  for _,e in ipairs(sorted_entries) do
    local ecycles = e[cyclesfield]
    local usage = (ecycles/totcycles)*100
    sum = sum + e.self
    if usage >= threshold then
      local time = usage * tottime * 10
      local name = e.name
      if #name > 80 then
        name = '..'..name:sub(-78)
      end
      print(string.format('%14d | %6.2f | %9.3f | %10d | %7s | %-80s | %s:%d',
        ecycles, usage, time, e.count, e.closure or '', name, e.src, e.line))
    end
  end
  local usage = (sum/totcycles)*100
  local time = usage * tottime * 10
  print(string.format('%14d | %6.2f | %9.3f | %10d | %7s | %-80s | %s', totcycles, usage, time, 1, '', 'TOTAL', 'N/A'))
  print()
end

return profiler
