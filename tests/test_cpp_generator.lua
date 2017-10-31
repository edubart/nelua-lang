require 'tests/testcommon'
require 'busted.runner'()

describe("Euluna C++ code generator", function()
  describe("should generate empty program", function()
    assert_generate_cpp({}, [[
int main() {
  return 0;
}
    ]])

    assert_generate_cpp_and_run(assert_parse("return 0"), '', 0)
  end)
end)