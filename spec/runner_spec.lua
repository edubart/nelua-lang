local assert = require 'utils.assert'

describe("Euluna runner should", function()

it("run simple programs", function()
  assert.run('examples/helloworld.euluna', 'hello world')
  assert.run('examples/helloworld.euluna', 'hello world') -- second time, use cache
  assert.run('--generator c examples/helloworld.euluna', 'hello world')
  assert.run({'--eval', "\n"}, '')
  assert.run({'--generator', 'c', '--eval', ""})
  assert.run({'--generator', 'c', '--no-cache', '--eval', "return 0"})
  assert.run({'--generator', 'c', '--eval', ""})
end)

it("throw error parsing an invalid program" , function()
  assert.run_error('--aninvalidflag', 'unknown option')
  assert.run_error('--lint --eval invalid')
  assert.run_error('--lint invalid', 'invalid: No such file or directory')
  assert.run_error({'--generator', 'c', '--eval', "f()"}, 'undefined reference')
end)

it("print correct generated AST" , function()
  assert.run('--print-ast examples/helloworld.euluna', [[AST('Block',
  { AST('Call',
      {},
      { AST('String',
          "hello world",
          nil
        )
      },
      AST('Id',
        "print"
      ),
      true
    )
  }
)]])
end)

it("print correct generated code", function()
  assert.run('--print-code examples/helloworld.euluna', 'print("hello world")')
end)

end)
