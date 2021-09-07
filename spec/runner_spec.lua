local lester = require 'nelua.thirdparty.lester'
local describe, it = lester.describe, lester.it

local expect = require 'spec.tools.expect'
local configer = require 'nelua.configer'
local version = require 'nelua.version'
local ccompiler = require 'nelua.ccompiler'

describe("runner", function()

it("version numbers" , function()
  expect.equal(#version.NELUA_GIT_HASH, 40)
  assert(version.NELUA_GIT_BUILD > 0)
  assert(version.NELUA_GIT_DATE ~= 'unknown')
end)

it("compile simple programs" , function()
  expect.run('--no-cache --code examples/helloworld.nelua')
  expect.run('--generator lua --no-cache --code examples/helloworld.nelua')
  expect.run('--generator lua --binary examples/helloworld.nelua')
  -- force reusing the cache:
  expect.run('--binary examples/helloworld.nelua')
end)

it("run simple programs", function()
  expect.run({'--no-cache', '--timing', '--more-timing', '--eval', "##[[assert(true)]] return 0"})
  expect.run('--generator lua examples/helloworld.nelua', 'hello world')
  expect.run(' examples/helloworld.nelua', 'hello world')
  expect.run({'--generator', 'lua', '--eval', ""}, '')
  expect.run({'--lint', '--eval', ""})
  expect.run({'--generator', 'lua', '--eval', "print(_G.arg[1])", "hello"}, 'hello')
  expect.run({'--eval', ""})
  local ccinfo = ccompiler.get_cc_info()
  if ccinfo.is_gcc and not ccinfo.is_clang and ccinfo.is_linux then
    expect.run({'--eval', "## cflags '-w -g' linklib 'm' ldflags '-s'"})
  end
end)

it("error on parsing an invalid program" , function()
  expect.run_error('--aninvalidflag', 'unknown option')
  expect.run_error('--lint --eval invalid')
  expect.run_error('--lint invalid', 'invalid: No such file or directory')
  --expect.run_error({'--eval', "f()"}, 'undefined')
  expect.run_error({'--generator', 'lua', '--eval', "local a = 1_x"}, "literal suffix '_x' is undefined")
  expect.run_error('--no-cache --cc invgcc examples/helloworld.nelua')
end)

it("print correct generated AST" , function()
  expect.run('--print-ast examples/helloworld.nelua', [[Block {
  Call {
    {
      String {
        "hello world"
      }
    },
    Id {
      "print"
    }
  }
}]])
  expect.run('--print-analyzed-ast examples/helloworld.nelua', [[type = "string"]])
end)

it("print correct code", function()
  expect.run({'--print-ppcode', '--eval', "##print(1)"}, 'print(1)')
  expect.run('--generator lua --print-code examples/helloworld.nelua', 'print("hello world")')
end)

it("define option", function()
  expect.run({
    '--generator', 'lua',
    '--analyze',
    '--define', 'DEF1',
    '-DDEF2',
    '-D', 'DEF3=1',
    "-DDEF4='asd'",
    '--eval',[[
      ## assert(DEF1 == true)
      ## assert(DEF2 == true)
      ## assert(DEF3 == 1)
      ## assert(DEF4 == 'asd')
    ]]})
  expect.run_error('-D1 examples/helloworld.nelua', "failed parsing parameter '1'")
end)

it("pragma option", function()
  expect.run({
    '--generator', 'lua',
    '--analyze',
    '--pragma', 'DEF1',
    '-PDEF2',
    '-P', 'DEF3=1',
    "-PDEF4='asd'",
    '--eval',[[
      ## assert(context.pragmas.DEF1 == true)
      ## assert(context.pragmas.DEF2 == true)
      ## assert(context.pragmas.DEF3 == 1)
      ## assert(context.pragmas.DEF4 == 'asd')
    ]]})
end)

it("configure module search paths", function()
  expect.run({'-L', './examples', '--eval',[[
    require 'helloworld'
  ]]}, 'hello world')
  expect.run_error({'--eval',[[
    require 'helloworld'
  ]]}, "module 'helloworld' not found")

  expect.run_error({'-L', './examples/invalid', '--analyze', '--eval',[[--nothing]]}, 'is not a valid directory')
  expect.run({'-L', './examples/?.lua', '--analyze', '--eval',[[
    ## assert(config.path:find('examples'))
  ]]})

  local defconfig = configer.get_default()
  local oldaddpath = defconfig.add_path
  defconfig.add_path = {'/tests'}
  expect.run({'-L', './examples', '--analyze', '--eval',[[
    ## assert(config.path:find('examples'))
    ## assert(config.path:find('tests'))
  ]]})
  defconfig.add_path = oldaddpath

  expect.run({'--path', './examples', '--analyze', '--eval',[[
    ## assert(config.path:match('examples'))
  ]]})
end)

it("debug options", function()
  expect.run({'--debug-resolve', '--analyze', '--eval',[[
    local x = 1
  ]]}, "symbol 'x' resolved to type 'int64'")
  expect.run({'--debug-scope-resolve', '--analyze', '--eval',[[
    local x = 1
  ]]}, "scope resolved 1 symbols")
end)

it("program arguments", function()
  expect.run({'--eval',[[
    require 'arg'
    assert(arg[1] == 'a')
    assert(arg[2] == 'b')
    assert(arg[3] == 'c')
    assert(#arg == 3)
  ]], 'a', 'b', 'c'})
end)

it("shared libraries", function()
  local ccinfo = ccompiler.get_cc_info()
  if ccinfo.is_gcc then
    expect.run({'--shared-lib', 'tests/libmylib.nelua'})
    expect.run({'tests/mylib_test.nelua'},[[
mylib - init
mylib - in top scope
mylib - sum
the sum is:
3
mylib - terminate]])
  end
end)

it("bundled C libraries", function()
  expect.run({'tests/myclib_test.nelua'}, [[hello from C]])
end)

it("static libraries", function()
  local ccinfo = ccompiler.get_cc_info()
  if ccinfo.is_gcc then
    expect.run({'--static-lib', 'tests/libmylib_static.nelua'})
    expect.run({'tests/mylib_test.nelua', '-DSTATIC'},[[
mylib - init
mylib - in top scope
mylib - sum
the sum is:
3
mylib - terminate]])
  end
end)

it("verbose", function()
  expect.run({'--verbose','--eval',[[
    ## assert(true)
    assert(true)
  ]]})
end)

it("error tracebacks", function()
  expect.run_error({'--eval',[[
    local function f(x: auto)
      ## static_error('fail')
    end
    f(1)
  ]]}, "polymorphic function instantiation")
end)

end)
