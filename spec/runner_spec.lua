local runner = require 'euluna.runner'
--local assert = require 'utils.assert'

local stderr = io.stderr
local stdout = io.stdout

local function run(...)
  local tmperr, tmpout = io.tmpfile(), io.tmpfile()
  runner.stderr, runner.stdout = tmperr, tmpout
  local status = runner.run(...)
  runner.stderr, runner.stdout = stderr, stdout
  tmperr:seek('cur') tmpout:seek('cur')
  local serr, sout = tmperr:read("*a"), tmpout:read("*a")
  tmperr:close() tmpout:close()
  return status, sout, serr
end

describe("Euluna runner should run", function()

it("simple program", function()
--runner('examples/helloworld.euluna', '--print-ast')
  run('--print-code', 'examples/helloworld.euluna')
  run('examples/helloworld.euluna')
  run('invalid', '--lint', '--eval')
end)


it("as standalone", function()
  run('--print-code', 'examples/helloworld.euluna')
  run('examples/helloworld.euluna')
  run('invalid', '--lint', '--eval')
end)

end)
