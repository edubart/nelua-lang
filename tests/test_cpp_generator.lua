require 'tests/testcommon'
require 'busted.runner'()

describe("Euluna C++ code generator", function()
  it("should generate empty code", function()
    assert_generate_cpp({}, [[
int main() {
    return 0;
}
    ]])
  end)

  it("should generate simple codes", function()
    assert_generate_cpp(assert_parse([[
print('hello world')
]]), [[
#include <iostream>

int main() {
    std::cout << "hello world" << std::endl;
    return 0;
}
    ]])
  end)

  --[[
  it("should return the correct values", function()
    assert_generate_cpp_and_run(assert_parse(""), '', 0)
    assert_generate_cpp_and_run(assert_parse("return"), '', 0)
    assert_generate_cpp_and_run(assert_parse("return 0"), '', 0)
    assert_generate_cpp_and_run(assert_parse("return 1"), '', 1)
    assert_generate_cpp_and_run(assert_parse("return 1+2"), '', 3)
  end)

  it("should print the correct values", function()
    assert_generate_cpp_and_run(assert_parse("print('hello world')"), 'hello world')
  end)
  ]]
end)
