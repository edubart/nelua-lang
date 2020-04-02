require 'busted.runner'()

local assert = require 'spec.tools.assert'
local configer = require 'nelua.configer'

describe("Nelua runner should", function()

it("compile simple programs" , function()
  assert.run('--generator lua --no-cache --compile examples/helloworld.nelua')
  assert.run(' --no-cache --compile examples/helloworld.nelua')
  assert.run('--generator lua --compile-binary examples/helloworld.nelua')
  -- force reusing the cache:
  assert.run(' --compile-binary examples/helloworld.nelua')
end)

it("run simple programs", function()
  assert.run({'--no-cache', '--timing', '--eval', "return 0"})
  assert.run('--generator lua examples/helloworld.nelua', 'hello world')
  assert.run(' examples/helloworld.nelua', 'hello world')
  assert.run({'--generator', 'lua', '--eval', ""}, '')
  assert.run({'--lint', '--eval', ""})
  assert.run({'--generator', 'lua', '--eval', "print(_G.arg[1])", "hello"}, 'hello')
  assert.run({'--eval', ""})
  assert.run({'--cflags="-Wall"', '--eval',
    "## cflags '-w' linklib 'm' ldflags '--as-needed'"})
end)

it("error on parsing an invalid program" , function()
  assert.run_error('--aninvalidflag', 'unknown option')
  assert.run_error('--lint --eval invalid')
  assert.run_error('--lint invalid', 'invalid: No such file or directory')
  --assert.run_error({'--eval', "f()"}, 'undefined')
  assert.run_error({'--generator', 'lua', '--eval', "local a = 1_x"}, "literal suffix '_x' is undefined")
  assert.run_error(' --cc invgcc examples/helloworld.nelua', 'failed to retrieve compiler information')
end)

it("print correct generated AST" , function()
  assert.run('--print-ast examples/helloworld.nelua', [[Block {
  {
    Call {
      {
        String {
          "hello world",
          nil
        }
      },
      Id {
        "print"
      }
    }
  }
}]])
  assert.run('--print-analyzed-ast examples/helloworld.nelua', [[type = "stringview"]])
end)

it("print correct generated code", function()
  assert.run('--generator lua --print-code examples/helloworld.nelua', 'print("hello world")')
end)

it("define option", function()
  assert.run({
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
  assert.run_error('-D1 examples/helloworld.nelua', "failed parsing define '1'")
end)

it("configure module search paths", function()
  assert.run({'-L', './examples', '--eval',[[
    require 'helloworld'
  ]]}, 'hello world')
  assert.run_error({'--eval',[[
    require 'helloworld'
  ]]}, "module 'helloworld' not found")

  assert.run_error({'-L', './examples/invalid', '--analyze', '--eval',[[--nothing]]}, 'is not a valid directory')
  assert.run({'-L', './examples/?.lua', '--analyze', '--eval',[[
    ## assert(config.path:find('examples'))
  ]]})

  local defconfig = configer.get_default()
  local oldlibpath = defconfig.lib_path
  defconfig.lib_path = {'/tests'}
  assert.run({'-L', './examples', '--analyze', '--eval',[[
    ## assert(config.path:find('examples'))
    ## assert(config.path:find('tests'))
  ]]})
  defconfig.lib_path = oldlibpath

  assert.run({'--path', './examples', '--analyze', '--eval',[[
    ## assert(config.path:match('examples'))
  ]]})
end)

end)
