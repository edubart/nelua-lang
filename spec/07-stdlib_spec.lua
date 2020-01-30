require 'busted.runner'()

local assert = require 'spec.tools.assert'

describe("Nelua stdlib", function()

it("libc", function()
  assert.run_c_from_file('tests/libc_test.nelua')
end)
it("math", function()
  assert.run_c_from_file('tests/math_test.nelua')
end)
it("os", function()
  assert.run_c_from_file('tests/os_test.nelua')
end)
it("memory", function()
  assert.run_c_from_file('tests/memory_test.nelua')
end)

end)
