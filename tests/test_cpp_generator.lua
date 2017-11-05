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
    it("numeric fors", function()
      assert_generate_cpp_and_run([[
        local s = 0
        for i=1,10 do
          s = s + i
        end
        print(s)

        s=0
        for i=1,<10 do
          s = s + i
        end
        print(s)

        s=0
        for i=1,~=10 do
          s = s + i
        end
        print(s)

        s=0
        for i=10,>=0,-1 do
          s = s + i
        end
        print(s)
      ]], '55\n45\n45\n55')
    end)

    it("if statements", function()
      assert_generate_cpp_and_run([[
        for i=1,4 do
          if i == 1 then
            print('1')
          elseif i == 2 then
            print('2')
          elseif i == 3 then
            print('3')
          else
            print('else')
          end
        end
      ]], '1\n2\n3\nelse')
    end)

    it("switch statements", function()
      assert_generate_cpp_and_run([[
        for i=1,4 do
          switch i
          case 1 then
            print('1')
          case 2 then
            print('2')
          case 3 then
            print('3')
          else
            print('else')
          end
        end
      ]], '1\n2\n3\nelse')
    end)

    it("try and throw", function()
      assert_generate_cpp_and_run([[
        try
          print('try')
          throw 'err'
          print('never runned')
        catch
          print('catchall')
        finally
          print('finally')
        end
      ]], 'try\ncatchall\nfinally')
    end)

    it("do blocks", function()
      assert_generate_cpp_and_run([[
        do
          print('hello')
        end
      ]], 'hello')
    end)

    it("while loops", function()
      assert_generate_cpp_and_run([[
        local i = 0
        while i < 10 do
          i = i + 1
        end
        print(i)
      ]], '10')
    end)

    it("repeat loops", function()
      assert_generate_cpp_and_run([[
        local i = 0
        repeat
          i = i + 1
        until i==10
        print(i)
      ]], '10')
    end)

    it("goto", function()
      assert_generate_cpp_and_run([[
        for i=0,<3 do
          for j=0,<3 do
            print(i .. j)
            if i+j >= 3 then
              goto endloop
            end
          end
        end
        ::endloop::
      ]], '00\n01\n02\n10\n11\n12')
    end)

    it("breaking and continuing loops", function()
      assert_generate_cpp_and_run([[
        for i=1,10 do
          if i > 5 then break end
          print(i)
        end
        for i=1,10 do
          if i <= 5 then continue end
          print(i)
        end
      ]], '1\n2\n3\n4\n5\n6\n7\n8\n9\n10')
    end)

    it("defer", function()
      assert_generate_cpp_and_run([[
        defer
          print('world')
        end
        print('hello')
      ]], 'hello\nworld')
    end)

    it("binary operators", function()
      assert_generate_cpp_and_run([[
        local s = 1 .. 2 .. 3
        local slen = #s
        local d = 2 ^ 2
        print(s, slen, d)
      ]], "123\t3\t4")
    end)

    it("functions", function()
      assert_generate_cpp_and_run([[
        function sum(a, b)
          return a+b
        end
        print(sum(1,2))
      ]], "3")
    end)

    it("example1", function()
      assert_generate_cpp_and_run([[
        for i=1,10 do
          if i % 3 == 0 then
            print(3)
          elseif i % 2 == 0 then
            print(2)
          else
            print(1)
          end
        end
      ]], "1\n2\n3\n2\n1\n3\n1\n2\n3\n2")
    end)
  end)
end)
