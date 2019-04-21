require 'busted.runner'()

local assert = require 'spec.assert'

describe("Euluna runner should", function()

it("compile simple programs" , function()
  assert.run('--no-cache --compile examples/helloworld.euluna')
  assert.run('--generator c --no-cache --compile examples/helloworld.euluna')
  assert.run('--compile-binary examples/helloworld.euluna')
  assert.run('--generator c --compile-binary examples/helloworld.euluna')
end)

it("run simple programs", function()
  assert.run({'--generator', 'c', '--no-cache', '--eval', "return 0"})
  assert.run('examples/helloworld.euluna', 'hello world')
  assert.run('--generator c examples/helloworld.euluna', 'hello world')
  assert.run({'--eval', ""}, '')
  assert.run({'--lint', '--eval', ""})
  assert.run({'--eval', "print(arg[1])", "hello"}, 'hello')
  assert.run({'--generator', 'c', '--eval', ""})
end)

it("error on parsing an invalid program" , function()
  assert.run_error('--aninvalidflag', 'unknown option')
  assert.run_error('--lint --eval invalid')
  assert.run_error('--lint invalid', 'invalid: No such file or directory')
  --assert.run_error({'--generator', 'c', '--eval', "f()"}, 'undefined')
  assert.run_error({'--generator', 'lua', '--eval', "local a = 1_x"}, 'literal suffix "_x" is not defined')
  assert.run_error('--generator c --cc invgcc examples/helloworld.euluna', 'failed to retrive compiler information')
end)

it("print correct generated AST" , function()
  assert.run('--print-ast examples/helloworld.euluna', [[Block {
  { Call {
      { String {
          "hello world",
          nil
        }
      },
      Id {
        "print"
      },
      true
    }
  }
}]])
  assert.run('--print-analyzed-ast examples/helloworld.euluna', [[Block {
  { Call {
      callee_type = "any",
      type = "any",
      { String {
          type = "string",
          value = "hello world",
          "hello world",
          nil
        }
      },
      Id {
        codename = "print",
        type = "any",
        "print"
      },
      true
    }
  }
}]])
end)

it("print correct generated code", function()
  assert.run('--print-code examples/helloworld.euluna', 'print("hello world")')
end)

end)
