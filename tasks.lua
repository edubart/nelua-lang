#!/usr/bin/lua

local tasker = require 'tools.tasker'
local utils = require 'pl.utils'
local file = require 'pl.file'

tasker.task('test', 'Run tests with coverage', function()
  return utils.execute('busted')
end)

tasker.task('fulltest', 'Run tests with coverage', function()
  -- clean any previous coverage
  file.delete('luacov.report.out')
  file.delete('luacov.stats.out')

  -- run with coverage
  if not utils.execute('busted --coverage') then
    return false
  end

  if not utils.execute('luacov') then
    return false
  end

  -- print coverage to stdout
  local gencovreport = require 'tools.covreporter'
  local ok = gencovreport('luacov.report.out')

  -- clean coverage again
  if ok then
    file.delete('luacov.report.out')
  end
  file.delete('luacov.stats.out')

  -- run luacheck
  io.write('luacheck ')
  io.flush()
  if not utils.execute('luacheck -q .') then
    return false
  end

  -- run simm
  return true
end)

tasker.task('livedev' , 'Live devel', function()
  return utils.execute('nodemon -e lua -q -x "./tasks.lua fulltest"')
end)

tasker.task('help', 'Print this help', function()
  print('Usage:')
  for name,task in pairs(tasker.tasks) do
    print(string.format('%12s    %s', name, task.desc))
  end
end)

return tasker.run()