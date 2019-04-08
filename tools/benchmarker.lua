local argparse = require 'argparse'
local nanotime = require 'chronos'.nanotime
local executor = require 'euluna.utils.executor'

local benchmarks = {
  'ackermann',
  'fibonacci',
  'mandel',
  'sieve'
}

local config

local function parse_args()
  local argparser = argparse("benchmarker")
  argparser:option('-n --ntimes', "Number of times that each test is executed", 4)
  argparser:option('-b --benchmark', "Run a single benchmark")
  argparser:option('-l --lang', "List of languages to run benchmark", "lua,luajit,euluna,c")
  config = argparser:parse(arg)
end

local function printf(...)
  print(string.format(...))
end

local function measure_command(command)
  local timestart = nanotime()
  local success = executor.execex(command)
  assert(success, 'benchmark command run failed ' .. command)
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
    string.format('lua ./euluna_cache/benchmarks/%s.lua', name),
    config.ntimes)
  benchmark(
    string.format('| %12s | %9s', name, 'luajit'),
    string.format('luajit ./euluna_cache/benchmarks/%s.lua', name),
    config.ntimes)
  benchmark(
    string.format('| %12s | %9s', name, 'euluna c'),
    string.format('./euluna_cache/benchmarks/%s', name),
    config.ntimes)
  benchmark(
    string.format('| %12s | %9s', name, 'c'),
    string.format('./euluna_cache/benchmarks/c%s', name),
    config.ntimes)
end

local function euluna_compile(name, generator)
  local file = 'benchmarks/' .. name .. '.euluna'
  local flags = '-q -b -r --lua-version=5.1 --cflags="-march=native"'
  local command = string.format('lua ./euluna.lua %s -g %s %s', flags, generator, file)
  local success = executor.exec(command)
  assert(success, 'failed to compile euluna benchmark ' .. name)
end

local function c_compile(name)
  local cfile = 'benchmarks/c/' .. name .. '.c'
  local ofile = 'euluna_cache/benchmarks/c' .. name
  local cflags = "-pipe -std=c99 -pedantic -Wall -Wextra -fno-strict-aliasing -rdynamic " ..
                 "-O2 -fno-plt -flto -march=native -Wl,-O1,--sort-common,-z,relro,-z,now"
  local command = string.format('gcc %s -o %s %s', cflags, ofile, cfile)
  local success = executor.exec(command)
  assert(success, 'failed to compile c benchmark ' .. name)
end

local function compile_benchmark(name)
  printf('%11s  %s', name, 'euluna (lua)')
  euluna_compile(name, 'lua')
  printf('%11s  %s', name, 'euluna (c)')
  euluna_compile(name, 'c')
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
