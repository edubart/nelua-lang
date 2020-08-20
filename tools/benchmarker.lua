local argparse = require 'nelua.thirdparty.argparse'
local nanotime = require 'nelua.utils.nanotimer'.nanotime
local executor = require 'nelua.utils.executor'

local benchmarks = {
  'ackermann',
  'fibonacci',
  'mandel',
  'sieve',
  'heapsort'
}

local config
local luabin = arg[-1]

local function parse_args()
  local argparser = argparse("benchmarker")
  argparser:option('-n --ntimes', "Number of times that each test is executed", 4)
  config = argparser:parse(arg)
end

local function printf(...)
  print(string.format(...))
end

local function measure_command(command)
  local timestart = nanotime()
  local success, _, _, err = executor.execex(command)
  assert(success, 'benchmark command run failed ' .. err)
  local timeend = nanotime()
  local elapsed = timeend - timestart
  return elapsed * 1000
end

local function benchmark(prefix, command, ntimes)
  local min = math.huge
  local max = 0
  local avg = 0
  local measurements = {}
  for i=1,ntimes do
    local elapsed = measure_command(command)
    min = math.min(elapsed, min)
    max = math.max(elapsed, max)
    avg = avg + elapsed
    measurements[i] = elapsed
  end
  avg = avg / ntimes
  local std = 0
  for i=1,ntimes do
    local elapsed = measurements[i]
    std = std + math.pow(elapsed - avg, 2)
  end
  std = math.sqrt(std/ntimes)
  printf('%s | %10.3f | %10.3f | %10.3f | %10.3f |', prefix, min, avg, max, std)
end

local function run_benchmark(name)
  benchmark(
    string.format('| %12s | %9s', name, 'lua'),
    string.format('lua ./benchmarks/lua/%s.lua', name),
    config.ntimes)
  benchmark(
    string.format('| %12s | %9s', name, 'luajit'),
    string.format('luajit ./benchmarks/lua/%s.lua', name),
    config.ntimes)
  benchmark(
    string.format('| %12s | %9s', name, 'nelua'),
    string.format('./nelua_cache/benchmarks/%s', name),
    config.ntimes)
  benchmark(
    string.format('| %12s | %9s', name, 'c'),
    string.format('./nelua_cache/benchmarks/c%s', name),
    config.ntimes)
end

local function nelua_compile(name, generator)
  local file = 'benchmarks/' .. name .. '.nelua'
  local flags = '-q -b -r -Pnochecks \
 "--lua-version=5.1" \
 --cache-dir nelua_cache \
 --cflags="-march=native -flto"'
  local command = string.format(luabin .. ' ./nelua.lua %s -g %s %s', flags, generator, file)
  local success = executor.exec(command)
  assert(success, 'failed to compile nelua benchmark ' .. name)
end

local function c_compile(name)
  local cfile = 'benchmarks/c/' .. name .. '.c'
  local ofile = 'nelua_cache/benchmarks/c' .. name
  local cflags = "-Wall -lm -O3 -fno-plt -march=native -flto"
  local command = string.format('gcc %s -o %s %s', cflags, ofile, cfile)
  local success = executor.exec(command)
  assert(success, 'failed to compile c benchmark ' .. name)
end

local function compile_benchmark(name)
  --printf('%11s  %s', name, 'nelua (lua)')
  --nelua_compile(name, 'lua')
  printf('%11s  %s', name, 'nelua (c)')
  nelua_compile(name, 'c')
  printf('%11s  %s', name, 'c')
  c_compile(name)
end

local function run_benchmarks()
  print('Compiling benchmarks...')
  for _,name in ipairs(benchmarks) do
    compile_benchmark(name)
  end
  print('Running benchmarks...')
  printf('| %12s | %9s | %10s | %10s | %10s | %10s |',
         'benchmark', 'language', 'min (ms)', 'avg (ms)', 'max (ms)', 'std (ms)')
  print('|--------------|-----------|------------|------------|------------|------------|')
  for _,name in ipairs(benchmarks) do
    run_benchmark(name)
  end
end

parse_args()
run_benchmarks()
