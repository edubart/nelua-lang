local plutil = require 'pl.utils'

require 'busted.runner'()

describe("Euluna compiler #compiler", function()
  describe("should compile and run hello world", function()
    it("gcc", function()
      local ok, ret, stdout, stderr = plutil.executeex('./euluna.lua examples/helloworld.euluna')
      assert(ok and ret == 0 and stderr == '', stderr)
      assert(stdout:find('hello world'))
    end)

    it("clang", function()
      local ok, ret, stdout, stderr = plutil.executeex('./euluna.lua --cc=clang examples/helloworld.euluna')
      assert(ok and ret == 0 and stderr == '', stderr)
      assert(stdout:find('hello world'))
    end)
  end)
end)
