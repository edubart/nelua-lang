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
    assert_generate_cpp([[
      print('hello world')
    ]], [[
#include <iostream>
#include <string>

int main() {
    std::cout << std::string("hello world") << std::endl;
    return 0;
}
    ]])
  end)

  it("should return the correct values", function()
    assert_generate_cpp_and_run("", '', 0)
    assert_generate_cpp_and_run("return", '', 0)
    assert_generate_cpp_and_run("return 0", '', 0)
    assert_generate_cpp_and_run("return 1", '', 1)
    assert_generate_cpp_and_run("return 1+2", '', 3)
  end)

  it("should print the correct values", function()
    assert_generate_cpp_and_run("print('hello world')", 'hello world\n')
    assert_generate_cpp_and_run([[
      local b = true
      local i = 1234
      local h = 0x123
      local u = 1234_u64
      local f = 1234.56_f
      local d = 1234.56
      local s1 = 's1'
      local s2 = "s2"
      local c = 65_c
      print(b, i, h, u, f, d, s1, s2, c)
    ]], "true\t1234\t291\t1234\t1234.56\t1234.56\ts1\ts2\tA")

    assert_generate_cpp_and_run([[
      print('\\ \a\b\f\n\r\t\v\'\"??!\x1\x2\x3\x0')
    ]], '\\ \a\b\f\n\r\t\v\'\"??!\x01\x02\x03')
  end)

  describe("should compile and run example", function()
    it("example1", function() 
      assert_generate_cpp_and_run([[
        local a = 1
        if a == 1 then
          print('a=1')
        elseif a == 2 then
        else
        end
      ]], 'a=1')
    end)
  end)
end)
