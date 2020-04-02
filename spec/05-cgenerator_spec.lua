require 'busted.runner'()

local assert = require 'spec.tools.assert'

describe("Nelua should parse and generate C", function()

it("empty file", function()
  assert.generate_c("", [[
int nelua_main() {
  return 0;
}]])
end)

it("return", function()
  assert.generate_c("return", [[
int nelua_main() {
  return 0;
}]])
  assert.generate_c("return 1", [[
int nelua_main() {
  return 1;
}]])
  assert.generate_c("return 1")
end)

it("local variable", function()
  assert.generate_c("local a = 1", "int64_t a = 1;")
end)

it("global variable", function()
  assert.generate_c("global a = 1", "static int64_t a = 1;\n")
end)

it("number", function()
  assert.generate_c("local a = 99", "99")
  assert.generate_c("local a = 1.2", "1.2")
  assert.generate_c("local a = 1e2", "100")
  assert.generate_c("local a = 0x1f", "0x1f")
  assert.generate_c("local a = 0b10", "0x2")
  assert.generate_c("local a = 1e129", "1e+129;")
end)

it("number literals", function()
  assert.generate_c("local a = 1_integer", "int64_t a = 1;")
  assert.generate_c("local a = 1_number", "double a = 1.0;")
  assert.generate_c("local a = 1_byte", "uint8_t a = 1U;")
  assert.generate_c("local a = 1_isize", "intptr_t a = 1;")
  assert.generate_c("local a = 1_usize", "uintptr_t a = 1U;")
  assert.generate_c("local a = 1_cint", "int a = 1;")
  assert.generate_c("local a = 1_clong", "long a = 1;")
  assert.generate_c("local a = 1_clonglong", "long long a = 1;")
end)

it("type assertion", function()
  assert.generate_c("do local b = 1_u64; local a = (@int16)(b) end", "int16_t a = (int16_t)b")
  assert.generate_c("do local b = 1_u8; local a = (@int64)(b) end", "int64_t a = (int64_t)b")
  assert.generate_c([[
    local a: usize
    local b: number
    local x = (@usize)((a + 1) / b)
  ]], "x = (uintptr_t)((a + 1) / b);")

  assert.generate_c([[
    local R = @record{x: integer}
    local a = (@integer[4])()
    local i = (@integer)()
    local u = (@uinteger)()
    local b = (@boolean)()
    local p = (@pointer)()
    local n = (@number)()
    local f = (@float32)()
    local r = (@R)()
  ]],[[a = (nelua_int64_arr4){0};
  i = 0;
  u = 0U;
  b = false;
  p = NULL;
  n = 0.0;
  f = 0.0f;
  r = (R){0};]])
end)

it("string", function()
  assert.generate_c([[local a = "hello"]], [["hello"]])
  assert.generate_c([[local a = "\001"]], [["\001"]])
end)

it("boolean", function()
  assert.generate_c("local a = true", "bool a = true")
  assert.generate_c("local a = false", "bool a = false")
end)

it("nil", function()
  assert.generate_c("local a: nilable", "nelua_nilable a = NULL;")
  assert.generate_c("local a: nilable = nil", "nelua_nilable a = NULL;")
  assert.generate_c("local a = nil", "nelua_any a = {0};")
  assert.generate_c("local function f(a: nilable) end f(nil)", "f(NULL);")
end)

it("call", function()
  assert.generate_c("local f; f()", "f();")
  assert.generate_c("local f,g; f(g())", "f(g())")
  assert.generate_c("local f,a,b; f(a, b)", "f(a, b)")
  assert.generate_c("local f,a,b; f(a)(b)", "f(a)(b)")
  assert.generate_c("local a; a.f()", "a.f()")
  --assert.generate_c("a:f(a)", "a.f(a, a)")
  assert.generate_c("local f; do f() end", "f();")
  assert.generate_c("local f; do return f() end", "return nelua_any_to_nelua_cint(f());")
  assert.generate_c("local f,g; do f(g()) end", "f(g())")
  assert.generate_c("local f,a,b; do f(a, b) end", "f(a, b)")
  assert.generate_c("local f,a,b; do f(a)(b) end", "f(a)(b)")
  assert.generate_c("local a; do a.f() end", "a.f()")
  --assert.generate_c("do a:f() end", "a.f(a)")
end)

it("callbacks", function()
  assert.run_c([[
local function call_callback(callback: function(integer, integer): integer): integer
  return callback(1, 2)
end

local function mycallback(x: integer, y: integer): integer
  assert(x == 1 and y == 2)
  return x + y
end

assert(call_callback(mycallback) == 3)
]])
end)

it("if", function()
  assert.generate_c("if nilptr then\nend","if(false) {\n")
  assert.generate_c("if nil then\nend","if(false) {\n")
  assert.generate_c("if 1 then\nend","if(true) {\n")
  assert.generate_c("local a; if a then\nend","if(nelua_any_to_nelua_boolean(a)) {\n")
  assert.generate_c("if true then\nend","if(true) {\n  }")
  assert.generate_c("if true then\nelseif true then\nend", "if(true) {\n  } else if(true) {\n  }")
  assert.generate_c("if true then\nelse\nend", "if(true) {\n  } else {\n  }")
  assert.generate_c([[
  local a: boolean, b: boolean
  if a and b then end]],
  "if(a && b) {\n")
  assert.generate_c([[
  local a: boolean, b: boolean, c: boolean
  if a and b or c then end]],
  "if((a && b) || c) {\n")
  assert.generate_c([[
  local a: boolean, b: boolean
  if a and not b then end]],
  "if(a && (!b)) {\n")
end)

it("switch", function()
  assert.generate_c("local a,f,g,h; do switch a case 1 then f() case 2 then g() else h() end end",[[
    switch(a) {
      case 1: {
        f();
        break;
      }
      case 2: {
        g();
        break;
      }
      default: {
        h();
        break;
      }
    }]])
end)

it("do", function()
  assert.generate_c("do\n  return\nend", "return 0;\n")
end)

it("while", function()
  assert.generate_c("while true do\nend", "while(true) {")
end)

it("repeat", function()
  assert.generate_c("repeat until true", [[
  while(true) {
    if(true) {
      break;
    }
  }]])
  assert.generate_c([[
    repeat
      local a = true
    until a
  ]], [[
  while(true) {
    bool a = true;
    if(a) {
      break;
    }
  }]])
  assert.run_c([[
    local x = 0
    repeat
      x = x + 1
      local a = (x == 4)
    until a
    print(x)
    assert(x == 4)
  ]])
end)

it("for", function()
  assert.generate_c("local a,b; for i=a,b do end", {
    "for(nelua_any i = a, __end = b; i <= __end; i = i + 1) {"})
  assert.generate_c("local a,b,c; for i=a,b do i=c end", {
    "for(nelua_any __it = a, __end = b; __it <= __end; __it = __it + 1) {",
    "nelua_any i = __it;"})
  assert.generate_c("local a,b,c; for i=a,b,c do end",
    "for(nelua_any i = a, __end = b, __step = c; " ..
    "__step >= 0 ? i <= __end : i >= __end; i = i + __step) {")
  assert.generate_c(
    "for i=1,<2 do end",
    "for(int64_t i = 1; i < 2; i = i + 1)")
  assert.generate_c(
    "for i=2,1,-1 do end",
    "for(int64_t i = 2; i >= 1; i = i + -1)")
  assert.run_c([[
    local x = 0
    for i=1,10 do x = x + 1 end
    assert(x == 10)
    x = 0
    for i=1,<10 do x = x + 1 end
    assert(x == 9)
    x = 0
    for i=1,10,2 do x = x + 1 end
    assert(x == 5)
    x = 0
    for i=10,1,-1 do x = x + 1 end
    assert(x == 10)
    local step = -2
    x = 0
    for i=10,1,step do x = x + 1 end
    assert(x == 5)
    local s: usize = 0
    for i=10_usize,>0_usize,-1 do
      s = s + i
    end
    assert(s == 55)
  ]])
end)

it("break and continue", function()
  assert.generate_c("break")
  assert.generate_c("continue")
end)
it("goto", function()
  assert.generate_c("::mylabel::\ngoto mylabel", "mylabel:\n  goto mylabel;")
end)

it("variable declaration", function()
  assert.generate_c("local a: integer", "int64_t a = 0;")
  assert.generate_c("local a: integer = 0", "int64_t a = 0;")
  assert.generate_c("local π = 3.14", "double uCF80 = 3.14;")
end)

it("operation on comptime variables", function()
  assert.generate_c([[
    local a <comptime> = false
    local b <comptime> = not a
    local c = b
  ]], "c = true;")
  assert.generate_c([[
    local a <comptime> = 2
    local b <comptime> = -a
    local c = b
  ]], "c = -2;")
  assert.generate_c([[
    local a = @integer == @integer
    local b = @integer ~= @number
  ]], {"a = true;", "b = true;"})
  assert.generate_c([[
    local a <comptime>, b <comptime> = 1, 2
    local c <const> = (@int32)(a * b)
  ]], "static int32_t c = 2;")

  assert.run_c([[
    -- sum/sub/mul
    assert(3 + 4 == 7)
    assert(3 - 4 == -1)
    assert(3 * 4 == 12)

    -- bor
    assert(3 | 5 == 7)
    --assert(-0xfffffffffffffffd_u64 & 5 == 7)
    --assert(-3 & -5 == -1)
    --assert(-3_i32 & 0xfffffffb_u32 == -7)
  ]])
end)

it("assignment", function()
  assert.generate_c("local a,b = 1,2; a = b" ,"a = b;")
end)

it("multiple assignment", function()
  assert.generate_c("local a,b,x,y=1,2,3,4; a, b = x, y", {
    "__asgntmp1 = x;", "__asgntmp2 = y;",
    "a = __asgntmp1;", "b = __asgntmp2;" })
  --assert.generate_c("local a: table, x:integer, y:integer; a.b, a[b] = x, y", {
  --  "__asgntmp1 = x;", "__asgntmp2 = y;",
  --  "a.b = __asgntmp1;", "a[b] = __asgntmp2;" })
  assert.run_c([[
    local a, b = 1,2
    a, b = b, a
    assert(a == 2 and b == 1)
  ]])
end)

it("function definition", function()
  assert.generate_c("local function f() end",
    "void f() {\n}")
  assert.generate_c(
    "local function f(): integer return 0 end",
    "int64_t f() {\n  return 0;\n")
  assert.generate_c(
    "local function f(a: integer): integer return a end",
    "int64_t f(int64_t a) {\n  return a;\n}")
end)

it("lazy functions", function()
  assert.run_c([[
    local function f(x: auto, y: auto)
      return x
    end
    f()
    assert(f(1) == 1)
    assert(f(true,2) == true)

    global function get(x: auto)
      return x, x+1
    end
    local i: number, f: number
    i, f = get(1)
    assert(f == 2)

    local function printtype(x: auto)
      ## if x.type.is_float then
        print('float', x)
      ## elseif x.type.is_integral then
        print('integral', x)
      ## elseif x.type.is_boolean then
        print('boolean', x)
      ## else
        print('unknown')
      ## end
      return x
    end
    assert(printtype(1) == 1)
    assert(printtype(3.14) == 3.14)
    assert(printtype(true) == true)
    assert(printtype(false) == false)
    printtype()
  ]])
end)

it("lazy function for records", function()
  assert.run_c([[
    local R = @record{}
    function R.f(x: auto)
      return x
    end
    assert(R.f(1) == 1)
    assert(R.f(2) == 2)
    assert(R.f(true) == true)
    assert(R.f(false) == false)
    local i: integer, b: boolean
    assert(R.f(i) == 0 and R.f(b) == false)

    local R = @record{v: integer}
    function R:f(x: auto)
      return x
    end
    function R:setget(v: auto)
      self.v = v
      return v
    end
    local r: R
    local x = r:setget(1)
    assert(r:f(1) == 1)
    assert(r:f('x') == 'x')
    assert(x == 1)
    assert(r.v == 1)
    assert(r:setget(2) == 2)
    assert(r.v == 2)
  ]])
end)

it("lazy functions with comptime arguments", function()
  assert.run_c([[
    local function cast(T: type, value: auto)
      return (@T)(value)
    end

    local a = cast(@boolean, 1)
    assert(type(a) == 'boolean')
    assert(a == true)

    local b = cast(@number, 1)
    assert(type(b) == 'number')
    assert(b == 1.0)

    local c = cast(@number, 2)
    assert(type(c) == 'number')
    assert(c == 2.0)

    local function iszero(x: auto)
      if x == 0 then
        return true
      else
        return false
      end
    end

    assert(iszero(0) == true)
    assert(iszero(1) == false)
    assert(iszero(2) == false)
  ]])
end)

it("global function definition", function()
  assert.generate_c("local function f() end", "static void f();")
  assert.run_c([[
    global function f(x: integer) return x+1 end
    assert(f(1) == 2)
  ]])
end)

it("function return", function()
  assert.generate_c([[
    local function f(): integer return 0 end
  ]], "int64_t f() {\n  return 0;")
  assert.generate_c([[
    local function f(): any return end
  ]], "nelua_any f() {\n  return (nelua_any){0};")
  assert.generate_c([[
    local function f() return end
  ]], "return;")
end)

it("function multiple returns", function()
  assert.generate_c([[
    local function f(): (integer, boolean) return 1, true end
  ]], {
    "function_%w+_ret f",
    "return %(function_%w+_ret%){1, true};"
  }, true)
  assert.generate_c([[do
    local function f(): (integer, boolean) return 1, true end
    local a, b = f()
    local c = f()
  end]], {
    "int64_t a = __ret%d+%.r1;",
    "bool b = __ret%d+%.r2;",
    "int64_t c = %({%s+function_%w+_ret __ret%d = f.*__ret%d.r1;%s+}%)",
  }, true)
  assert.run_c([[
    local function f(): (integer, boolean) return 1, true end
    local function g() return 2, true end
    local a, b = f()
    local c = g()
    assert(a == 1)
    assert(b == true)
    assert(c == 2)
    a, b = f()
    c = g()
    assert(a == 1)
    assert(b == true)
    assert(c == 2)

    local function t(): (boolean, integer) return false, 1 end
    local function u(): (boolean, number) return t() end
    local a, b, c = 2, u()
    assert(a == 2 and b == false and c == 1)

    local R = @record{x: integer}
    function R.foo(self: R*): (boolean, integer) return true, self.x end
    function R:boo(): (boolean, integer) return true, self.x end
    local r = R{1}
    local function foo(): (boolean, integer) return R.foo(r) end
    local function boo(): (boolean, integer) return r:boo() end
    local a,b = foo()
    assert(a == true and b == 1)
    a,b = boo()
    assert(a == true and b == 1)

    local function f1(): integer
      return 1
    end
    local function f2(): (integer, integer)
      return 1, 2
    end
    local function g1(x: integer)
      assert(x == 1)
    end
    local function g2(x: integer, y: integer)
      assert(x == 1)
      assert(y == 2)
    end
    local function h1(): integer
      return f1()
    end
    local function h2(): (integer, integer)
      return f2()
    end
    local function hh2(): (integer, integer)
      return f2(), 2
    end
    g1(f1())
    g1(f2())
    g2(f1(), 2)
    g2(f2())
    g1(h1())
    g2(h2())
    local a: integer = f1()
    g2(hh2())
    local a: integer = f1()
    assert(a == 1)
    local a: integer = f2()
    assert(a == 1)
    local a: integer, b: integer = f2()
    assert(a == 1 and b == 2)
    a, b = f2()
    assert(a == 1 and b == 2)
    local a: integer, b: integer = f2(), 3
    assert(a == 1 and b == 3)
    assert(f1() == 1)
  ]])
end)

it("call with multiple args", function()
  assert.generate_c([[do
    local function f(): (integer, boolean) return 1, true end
    local function g(a: int32, b: integer, c: boolean) end
    g(1, f())
  end]], {
    "function_%w+_ret __tmp%d+ = f__%d+%(%)",
    "g__%d+%(1, __tmp%d+.r1, __tmp%d+.r2%);"
  }, true)
  assert.run_c([[do
    local function f(): (integer, integer) return 1, 2 end
    local function g(a: integer, b: integer, c: integer) return a + b + c end
    assert(g(3, f()) == 6)
    assert(g(3, f(), 0) == 4)
    assert(g(3, 0, f()) == 4)
  end]])
end)

it("call with side effects", function()
  assert.run_c([[do
    local function f(x: integer) print(x) return x end
    local function g(a: integer, b: integer, c: integer) return a+b+c end
    assert(f(1) + f(2) + f(3) == 6)
    assert(g(f(4), f(5), f(6)) == 15)
  end]],"1\n2\n3\n4\n5\n6")
end)

it("unary operator `not`", function()
  assert.generate_c("local x = not true", "x = false;")
  assert.generate_c("local x = not false", "x = true;")
  assert.generate_c("local x = not nil", "x = true;")
  assert.generate_c("local x = not nilptr", "x = true;")
  assert.generate_c("local x = not 'a'", "x = false;")
  assert.generate_c("local a = true; local x = not a", "x = (!a);")
  --assert.generate_c("local a = nil; local x = not a", "x = true;")
  --assert.generate_c("local a = nilptr; local x = not a", "x = !a;")
end)

it("unary operator `ref`", function()
  assert.generate_c("local a = 1; local x = &a", "x = (&a);")
end)

it("unary operator `unm`", function()
  assert.generate_c("local a = 1; local x = -a", "(-a);")
end)

it("unary operator `deref`", function()
  assert.generate_c("local a: integer*; local x = $a", "x = (*a);")
end)

it("unary operator `bnot`", function()
  assert.generate_c("local a = 1; local x = ~a", "(~a);")
  assert.generate_c("local a = 2; local x=~a",      "x = (~a);")
  assert.generate_c("local x = ~1", "x = -2;")
  assert.generate_c("local x = ~-2", "x = 1;")
  assert.generate_c("local x = ~0x2_u8", "x = 253U;")
end)

it("unary operator `len`", function()
  assert.generate_c("local x = #@integer", "x = 8;")
  assert.generate_c("local x = #'asd'", "x = 3;")
  assert.generate_c("local x = #@integer[4]", "x = 32;")
  --assert.generate_c("a = 'asd'; local x = #a", "x = 3;")
end)

it("unary operator `lt`", function()
  assert.generate_c("local a, b = 1, 2; local x = a < b", "a < b")
  assert.generate_c("local x = 1 < 1", "x = false;")
  assert.generate_c("local x = 1 < 2", "x = true;")
  assert.generate_c("local x = 2 < 1", "x = false;")
  assert.generate_c("local x = 'a' < 'a'", "x = false;")
  assert.generate_c("local x = 'a' < 'b'", "x = true;")
  assert.generate_c("local x = 'b' < 'a'", "x = false;")
end)

it("unary operator `le`", function()
  assert.generate_c("local a, b = 1, 2; local x = a <= b", "a <= b")
  assert.generate_c("local x = 1 <= 1", "x = true;")
  assert.generate_c("local x = 1 <= 2", "x = true;")
  assert.generate_c("local x = 2 <= 1", "x = false;")
  assert.generate_c("local x = 'a' <= 'a'", "x = true;")
  assert.generate_c("local x = 'a' <= 'b'", "x = true;")
  assert.generate_c("local x = 'b' <= 'a'", "x = false;")
end)

it("unary operator `gt`", function()
  assert.generate_c("local a, b = 1, 2; local x = a > b", "a > b")
  assert.generate_c("local x = 1 > 1", "x = false;")
  assert.generate_c("local x = 1 > 2", "x = false;")
  assert.generate_c("local x = 2 > 1", "x = true;")
  assert.generate_c("local x = 'a' > 'a'", "x = false;")
  assert.generate_c("local x = 'a' > 'b'", "x = false;")
  assert.generate_c("local x = 'b' > 'a'", "x = true;")
end)

it("unary operator `ge`", function()
  assert.generate_c("local a, b = 1, 2; local x = a >= b", "a >= b")
  assert.generate_c("local x = 1 >= 1", "x = true;")
  assert.generate_c("local x = 1 >= 2", "x = false;")
  assert.generate_c("local x = 2 >= 1", "x = true;")
  assert.generate_c("local x = 'a' >= 'a'", "x = true;")
  assert.generate_c("local x = 'a' >= 'b'", "x = false;")
  assert.generate_c("local x = 'b' >= 'a'", "x = true;")
end)

it("binary operator `eq`", function()
  assert.generate_c("local a, b = 1, 2; local x = a == b", "a == b")
  assert.generate_c("local x = 1 == 1", "x = true;")
  assert.generate_c("local x = 1 == 2", "x = false;")
  assert.generate_c("local x = 1 == '1'", "x = false;")
  assert.generate_c("local x = '1' == 1", "x = false;")
  assert.generate_c("local x = '1' == '1'", "x = true;")
  assert.generate_c("local a,b = 1,2; local x = a == b", "x = (a == b);")
end)

it("binary operator `ne`", function()
  assert.generate_c("local a, b = 1, 2; local x = a ~= b", "a != b")
  assert.generate_c("local x = 1 ~= 1", "x = false;")
  assert.generate_c("local x = 1 ~= 2", "x = true;")
  assert.generate_c("local x = 1 ~= 's'", "x = true;")
  assert.generate_c("local x = 's' ~= 1", "x = true;")
  assert.generate_c("local a,b = 1,2; local x = a ~= b", "x = (a != b);")
end)

it("binary operator `add`", function()
  assert.generate_c("local a, b = 1, 2; local x = a + b",       "a + b")
  assert.generate_c("local x = 3 + 2",       "x = 5;")
  assert.generate_c("local x = 3.0 + 2.0",   "x = 5.0;")
end)

it("binary operator `sub`", function()
  assert.generate_c("local a, b = 1, 2; local x = a - b",       "a - b")
  assert.generate_c("local x = 3 - 2",       "x = 1;")
  assert.generate_c("local x = 3.0 - 2.0",   "x = 1.0;")
end)

it("binary operator `mul`", function()
  assert.generate_c("local a, b = 1, 2; local x = a * b",       "a * b")
  assert.generate_c("local x = 3 * 2",       "x = 6;")
  assert.generate_c("local x = 3.0 * 2.0",   "x = 6.0;")
end)

it("binary operator `div`", function()
  assert.generate_c("local x = 3 / 2",                   "x = 1.5;")
  assert.generate_c("local x = (@float64)(3 / 2)",       "x = 1.5;")
  assert.generate_c("local x = 3 / 2_int64",             "x = 1.5;")
  assert.generate_c("local x = 3.0 / 2",                 "x = 1.5;")
  assert.generate_c("local x = (@integer)(3_i / 2_i)",   "x = (int64_t)1.5;")
  assert.generate_c("local x = (@integer)(3 / 2_int64)", "x = (int64_t)1.5;")
  assert.generate_c("local x =  3 /  4",                 "x = 0.75;")
  assert.generate_c("local x = -3 /  4",                 "x = -0.75;")
  assert.generate_c("local x =  3 / -4",                 "x = -0.75;")
  assert.generate_c("local x = -3 / -4",                 "x = 0.75;")
  assert.generate_c("local a,b = 1,2; local x=a/b",      "x = (a / (double)b);")
  assert.generate_c("local a,b = 1.0,2.0; local x=a/b",  "x = (a / b);")
end)

it("binary operator `idiv`", function()
  assert.generate_c("local x = 3 // 2",      "x = 1;")
  assert.generate_c("local x = 3 // 2.0",    "x = 1.0;")
  assert.generate_c("local x = 3.0 // 2.0",  "x = 1.0;")
  assert.generate_c("local x = 3.0 // 2",    "x = 1.0;")
  assert.generate_c("local x =  7 //  3",    "x = 2;")
  assert.generate_c("local x = -7 //  3",    "x = -3;")
  assert.generate_c("local x =  7 // -3",    "x = -3;")
  assert.generate_c("local x = -7 // -3",    "x = 2;")
  assert.generate_c("local x =  7 //  3.0",  "x = 2.0;")
  assert.generate_c("local x = -7 //  3.0",  "x = -3.0;")
  assert.generate_c("local x =  7 // -3.0",  "x = -3.0;")
  assert.generate_c("local x = -7 // -3.0",  "x = 2.0;")
  assert.generate_c("local a,b = 1_u,2_u; local x=a//b",      "x = (a / b);")
  assert.generate_c("local a,b = 1,2; local x=a//b",      "x = (nelua_idiv_i64(a, b));")
  assert.generate_c("local a,b = 1.0,2.0; local x=a//b",  "x = (floor(a / b));")
  assert.run_c([[
    do
      local a, b = 7, 3
      assert(a // b == 2)
      assert(-a // b == -3)
      assert(a // -b == -3)
      assert(-a // -b == 2)
      assert(a // a == 1)
    end
    do
      local a, b = 7.0, 3.0
      assert(a // b == 2.0)
      assert(-a // b == -3.0)
      assert(a // -b == -3.0)
      assert(-a // -b == 2.0)
      assert(a // a == 1.0)
    end
  ]])
end)

it("binary operator `mod`", function()
  --assert.generate_c("local x = a % b")
  assert.generate_c("local x = 3 % 2",       "x = 1;")
  assert.generate_c("local x = 3.0 % 2.0",   "x = 1.0;")
  assert.generate_c("local x = 3.0 % 2",     "x = 1.0;")
  assert.generate_c("local x = 3 % 2.0",     "x = 1.0;")
  assert.generate_c("local x =  7 %  3",     "x = 1;")
  assert.generate_c("local x = -7 %  3",     "x = 2;")
  assert.generate_c("local x =  7 % -3",     "x = -2;")
  assert.generate_c("local x = -7 % -3",     "x = -1;")
  assert.generate_c("local x =  7 %  3.0",   "x = 1.0;")
  assert.generate_c("local x = -7 %  3.0",   "x = 2.0;")
  assert.generate_c("local x =  7 % -3.0",   "x = -2.0;")
  assert.generate_c("local x = -7 % -3.0",   "x = -1.0;")
  assert.generate_c("local x = -7.0 % 3.0",  "x = 2.0;")
  assert.generate_c("local a, b = 3, 2;     local x = a % b", "x = (nelua_imod_i64(a, b));")
  assert.generate_c("local a, b = 3_u, 2_u; local x = a % b", "x = (a % b);")
  assert.generate_c("local a, b = 3.0, 2;   local x = a % b", "x = (nelua_fmod(a, b));")
  assert.generate_c("local a, b = 3, 2.0;   local x = a % b", "x = (nelua_fmod(a, b));")
  assert.generate_c("local a, b = 3.0, 2.0; local x = a % b", "x = (nelua_fmod(a, b));")
  assert.run_c([[
    do
      local a, b = 7, 3
      assert(a % b == 1)
      assert(-a % b == 2)
      assert(a % -b == -2)
      assert(-a % -b == -1)
      assert(a % a == 0)
    end
    do
      local a, b = 7.0, 3.0
      assert(a % b == 1.0)
      assert(-a % b == 2.0)
      assert(a % -b == -2.0)
      assert(-a % -b == -1.0)
      assert(a % a == 0.0)
    end
  ]])
end)

it("binary operator `pow`", function()
  --assert.generate_c("local x = a ^ b")
  assert.generate_c("local a,b = 2,2; local x = a ^ b", "x = (pow(a, b));")
  assert.generate_c("local x = 2 ^ 2", "x = 4.0;")
  assert.generate_c("local x = 2_f32 ^ 2_f32", "x = 4.0f;")
  assert.generate_c("local a,b = 2_f32,2_f32; local x = a ^ b", "x = (powf(a, b));")
end)

it("binary operator `band`", function()
  assert.generate_c("local x = 3 & 5",                   "x = 1;")
  assert.generate_c("local x = -0xfffffffd & 5",         "x = 1;")
  assert.generate_c("local x = -3 & -5",                 "x = -7;")
  assert.generate_c("local x = -3_i32 & 0xfffffffb_u32", "x = -7;")
end)

it("binary operator `bor`", function()
  assert.generate_c("local a,b = 1,2; local x = a | b", "(a | b);")
  assert.generate_c("local x = 3 | 5", "x = 7;")
  assert.generate_c("local x = 3 | -5", "x = -5;")
  assert.generate_c("local x = -0xfffffffffffffffd | 5", "x = 7;")
  assert.generate_c("local x = -3 | -5", "x = -1;")
end)

it("binary operator `bxor`", function()
  assert.generate_c("local a,b = 1,2; local x = a ~ b", "(a ^ b);")
  assert.generate_c("local x = 3 ~ 5", "x = 6;")
  assert.generate_c("local x = 3 ~ -5", "x = -8;")
  assert.generate_c("local x = -3 ~ -5", "x = 6;")
end)

it("binary operator `shl`", function()
  assert.generate_c("local a,b = 1,2; local x = a << b", "(a << b);")
  assert.generate_c("local x = 6 << 1", "x = 12;")
  assert.generate_c("local x = 6 << 0", "x = 6;")
  assert.generate_c("local x = 6 << -1", "x = 3;")
end)

it("binary operator `shr`", function()
  assert.generate_c("local a,b = 1,2; local x = a >> b", "(a >> b);")
  assert.generate_c("local x = 6 >> 1", "x = 3;")
  assert.generate_c("local x = 6 >> 0", "x = 6;")
  assert.generate_c("local x = 6 >> -1", "x = 12;")
end)

it("binary operator `concat`", function()
  assert.generate_c("local x = 'a' .. 'b'", [["ab"]])
end)

it("string comparisons", function()
  assert.generate_c("local a,b = 'a','b'; local x = a == b", "nelua_stringview_eq(a, b)")
  assert.generate_c("local a,b = 'a','b'; local x = a ~= b", "nelua_stringview_ne(a, b)")
  assert.run_c([[
    assert('a' == 'a')
    assert(not ('a' ~= 'a'))
    assert('a' ~= 'b')
    assert(not ('a' == 'b'))
    local a = 'a'
    local b = 'b'
    assert(a == a)
    assert(not (a ~= a))
    assert(a ~= b)
    assert(not (a == b))
  ]])
end)

it("array comparisons", function()
  assert.run_c([[
    local A = @integer[4]
    local a: A = {1,2,3,4}
    local b: A = {1,2,3,4}
    local c: A = {1,2,3,5}
    assert(a == a)
    assert(a == (@integer[4]){1,2,3,4})
    assert(a == b)
    assert(not (a ~= b))
    assert(not (a == c))
    assert(a ~= c)
]])
end)

it("record comparisons", function()
  assert.run_c([[
    local R = @record{x: integer, y: integer}
    local a: R = {1,1}
    local b: R = {1,1}
    local c: R = {2,2}

    assert(a == a)
    assert(a == R{1,1})
    assert(a == b)
    assert(not (a ~= b))
    assert(not (a == c))
    assert(a ~= c)


    local P = @record{x: R}
    local a: P = {{1}}
    local b: P = {{1}}
    local c: P = {{2}}
    assert(a == a)
    assert(a == b)
    assert(not (a ~= b))
    assert(not (a == c))
    assert(a ~= c)


    local Q = @record{x: integer[2]}
    local a: Q = {{1,2}}
    local b: Q = {{1,2}}
    local c: Q = {{1,3}}
    assert(a == a)
    assert(a == b)
    assert(not (a ~= b))
    assert(not (a == c))
    assert(a ~= c)
]])
end)

it("binary conditional operators", function()
  assert.generate_c("local a, b; do return a or b end",  [[({
      nelua_any t1_ = a;
      nelua_any t2_ = {0};
      bool cond_ = nelua_any_to_nelua_boolean(t1_);
      if(!cond_) {
        t2_ = b;
      }
      cond_ ? t1_ : t2_;
    })]])
  assert.generate_c("local a, b; return a and b",  [[({
    nelua_any t1_ = a;
    nelua_any t2_ = {0};
    bool cond_ = nelua_any_to_nelua_boolean(t1_);
    if(cond_) {
      t2_ = b;
      cond_ = nelua_any_to_nelua_boolean(t2_);
    }
    cond_ ? t2_ : (nelua_any){0};
  })]])
  assert.generate_c([[
    local p: pointer
    local i: integer = 1
    local b: boolean = i == 0 or p
    local b2 = (@boolean)(i == 0 or p)
  ]], {
    "b = ((i == 0) || p);",
    "b2 = ((i == 0) || p);"
  })
  assert.generate_c([[
    local p: integer*
    local a: pointer, b: pointer
    if p and a == b then end
    while p and a == b do end
  ]], {
    "if(p && (a == b))",
    "while(p && (a == b))"
  })
  assert.run_c([[
    local a = 2 or 3
    assert(a == 2)
    assert((2 and 3) == 3)
    assert((0 or 1) == 0)
    --assert(nilptr or 1)
    --assert(1 or 's')

    assert((false or false) == false)
    assert((false or true) == true)
    assert((true or false) == true)
    assert((false and false) == false)
    assert((false and true) == false)
    assert((true and false) == false)

    assert((true and true or true) == true)
    assert((true and true or false) == true)
    assert((true and false or true) == true)
    assert((true and false or false) == false)
    assert((false and true or true) == true)
    assert((false and true or false) == false)
    assert((false and false or true) == true)
    assert((false and false or false) == false)

    assert((false and 1 or 2) == 2)
    assert((true and 1 or 2) == 1)
    assert((true and 1 and 2 or 3) == 2)
    assert((false and 1 and 2 or 3) == 3)
    assert((false and 0xff_uint8 or 0xffff_uint16) == 0xffff)

    local p: pointer = nilptr
    local pa: pointer = &a
    assert((p and p or pa) == pa)
    assert((pa and pa or p) == pa)

    local t1, t2 = false, false
    if (2 or 1) == 2 then t1 = true end
    if (2 and 0) == 0 then t2 = true end
    assert(t1)
    assert(t2)

    do
      local a: auto = -1_i16
      local b: auto = 1_u32
      assert(a < b == true)
      assert(b < a == false)
      assert(a <= b == true)  assert(a <= a == true)
      assert(b <= a == false) assert(b <= b == true)
      assert(a > b == false)
      assert(b > a == true)
      assert(a >= b == false) assert(a >= a == true)
      assert(b >= a == true)  assert(b >= b == true)
    end

    do
      local p: pointer
      local b: boolean = true
      assert(not (p or b) == false)
      assert(not (b and p) == true)
    end
  ]])
end)

it("expressions with side effects", function()
  assert.generate_c([[do
    local function f() return 1 end
    local a = f() + 1
  end]],  "int64_t a = (f__1() + 1)")
  assert.generate_c([[do
    local function f() return 1 end
    local function g() return 1 end
    local a = f() + g()
  end]],  [[int64_t a = (({
      int64_t t1_ = f__1();
      int64_t t2_ = g__1();
      t1_ + t2_;
    }));]])
  assert.run_c([[
    local function f() return 1 end
    local function g() return 2 end
    local a = f() + g()
    assert(a == 3)
  ]])
end)

it("c types", function()
  assert.generate_c("local a: integer", "int64_t a = 0;")
  assert.generate_c("local a: number", "double a = 0.0;")
  assert.generate_c("local a: byte", "uint8_t a = 0U;")
  assert.generate_c("local a: float64", "double a = 0.0;")
  assert.generate_c("local a: float32", "float a = 0.0f;")
  assert.generate_c("local a: pointer", "void* a = NULL;")
  assert.generate_c("local a: int64", "int64_t a = 0;")
  assert.generate_c("local a: int32", "int32_t a = 0;")
  assert.generate_c("local a: int16", "int16_t a = 0;")
  assert.generate_c("local a: int8", "int8_t a = 0;")
  assert.generate_c("local a: isize", "intptr_t a = 0;")
  assert.generate_c("local a: uint64", "uint64_t a = 0U;")
  assert.generate_c("local a: uint32", "uint32_t a = 0U;")
  assert.generate_c("local a: uint16", "uint16_t a = 0U;")
  assert.generate_c("local a: uint8", "uint8_t a = 0U;")
  assert.generate_c("local a: usize", "uintptr_t a = 0U;")
  assert.generate_c("local a: boolean", "bool a = false;")
end)

it("reserved names quoting", function()
  assert.config.srcname = 'mymod'
  assert.generate_c("local default: integer", "int64_t mymod_default = 0;")
  assert.generate_c("local NULL: integer = 0", "int64_t mymod_NULL = 0;")
  assert.generate_c("do local default: integer end", "int64_t default_ = 0;")
  assert.generate_c("do local NULL: integer = 0 end", "int64_t NULL_ = 0;")
  assert.config.srcname = nil
  assert.run_c([[
    local function struct(double: integer)
      local default: integer
      default = 1
      return default + double
    end
    print(struct(1))
  ]], "2")
end)

it("variable shadowing", function()
  assert.run_c([[
    local a = 1
    assert(a == 1)
    local a = 2
    assert(a == 2)
    local a = 3
    assert(a == 3)

    local function f() return 1 end
    assert(f() == 1)
    local function f() return 2 end
    assert(f() == 2)

    local a2 = 4
    assert(a2 == 4)

    local x, y = 1, 2
    local x = x + y
    assert(x == 3)
  ]])
end)

it("any type", function()
  assert.generate_c(
    "local a: any",
    "nelua_any a = {0};")
  assert.generate_c(
    "do local a: any; local b: any = a end",
    "nelua_any b = a;")
  assert.generate_c(
    "do local a: any = 1; local b: integer = a end",
    "int64_t b = nelua_any_to_nelua_int64(a);")
  assert.run_c([[
    local a: any = 1
    local b: integer = a
    print(a, b)
  ]], "1\t1")
  assert.run_c([[
    local a: any = 1
    local b: boolean = a
    print(b)
    local p: pointer
    a = p
    b = a
    print(b)
    local n: any
    print(n)
  ]], "true\nfalse\nnil")
  assert.run_c([[
    local a: any = 1
    a = true
    print(a)
  ]], "true")
  assert.run_c([[
    local function f(a: integer) return a + 1 end
    local a: any = 1
    local r = f(a)
    print(r)
  ]], "2")
  assert.run_c([[
    local a: any, b: any = 1,2
    for i:integer=a,b do print(i) end
  ]], "1\n2")
  assert.run_error_c([[
    local a: any = 1
    local b: stringview = a
  ]], "type check fail")
end)

it("cstring and string conversions", function()
  assert.run_c([[
    local a = 'hello'
    print(a)
    local b: cstring = a
    print(b)

    do
      local c: cstring = 'hello'
      local s: stringview = (@stringview)(c)
      --assert(s.data == c)
    end

    do
      local s: stringview = 'hello'
      local c: cstring = (@cstring)(s)
      --assert(s.data == c)
    end
  ]], "hello\nhello")
end)

it("ranges", function()
  assert.run_c([[
    local a: range(integer)
    assert(a.low == 0 and a.high == 0)
    a = (2:3)
    assert(a.low == 2 and a.high == 3)
    a = (-1:0)
    assert(a.low == -1 and a.high == 0)
  ]])
end)

it("arrays", function()
  assert.generate_c(
    "local a: array(boolean, 10)",
    {"data[10];} nelua_boolean_arr10"})
  assert.run_c([[
    local a: array(boolean, 1)
    assert(a[0] == false)
    assert(#a == 1)
    a[0] = true
    assert(a[0] == true)
    a = {}
    assert(a[0] == false)
  ]])
  assert.run_c([[
    local a: array(integer, 4) = {1,2,3,4}
    local b: array(integer, 4) = a

    assert(b[0] == 1 and b[1] == 2 and b[2] == 3 and b[3] == 4)
    assert(#b == 4)
  ]])
end)

it("arrays inside records", function()
  assert.run_c([[
    local R = @record{v: integer[4]}
    local a: R
    a.v[0]=1 a.v[1]=2 a.v[2]=3 a.v[3]=4
    assert(a.v[0]==1 and a.v[1]==2 and a.v[2]==3 and a.v[3]==4)
    a.v = {5,6,7,8}
    assert(a.v[0]==5 and a.v[1]==6 and a.v[2]==7 and a.v[3]==8)

    local b: R = {v = {1,2,3,4}}
    assert(b.v[0]==1 and b.v[1]==2 and b.v[2]==3 and b.v[3]==4)

    local function f(): integer[2][2]
      local a: integer[2][2]
      a[0][0] = 1
      a[0][1] = 2
      a[1][0] = 3
      a[1][1] = 4
      return a
    end
    assert(f()[0][0] == 1)
    assert(f()[0][1] == 2)
    assert(f()[1][0] == 3)
    assert(f()[1][1] == 4)

    local function g(): integer[2][2]
      return (@integer[2][2]){{1,2},{3,4}}
    end
    assert(g()[0][0] == 1)
    assert(g()[0][1] == 2)
    assert(g()[1][0] == 3)
    assert(g()[1][1] == 4)

    local R = @record{v: integer[4]}
    local v = (@integer[4]){1,2,3,4}
    local a: R = {v=v}
    assert(a.v[0] == 1 and a.v[1] == 2 and a.v[2] == 3 and a.v[3] == 4)
  ]])
end)

it("multi dimensional arrays", function()
  assert.run_c([[
    local function f(): integer[2][2]
      local a: integer[2][2]
      a[0][0] = 1
      a[0][1] = 2
      a[1][0] = 3
      a[1][1] = 4
      return a
    end
    assert(f()[0][0] == 1)
    assert(f()[0][1] == 2)
    assert(f()[1][0] == 3)
    assert(f()[1][1] == 4)

    local function g(): integer[2][2]
      return (@integer[2][2]){{1,2},{3,4}}
    end
    print(g()[0][0])
    print(g()[0][1])
    print(g()[1][0])
    print(g()[1][1])
  ]])
end)

it("records", function()
  assert.generate_c(
    "local t: record{}",
    "typedef struct record_%w+ record_%w+;", true)
  assert.generate_c(
    "local t: record{a: boolean}",
    [[struct record_%w+ {
  bool a;
};]], true)
  assert.run_c([[
    local p: record{
      x: integer,
      y: integer
    }
    assert(p.x == 0 and p.y == 0)
    p.x, p.y = 1, 2
    assert(p.x == 1 and p.y == 2)
  ]])
  assert.run_c([[
    local Point = @record {x: integer, y: integer}
    local p: Point
    local pptr = &p
    p.x = 1
    assert(p.x == 1 and p.y == 0)
    assert(pptr.x == 1 and pptr.y == 0)
    pptr.x = 2
    assert(p.x == 2 and p.y == 0)
    assert(pptr.x == 2 and pptr.y == 0)
    p = Point{}
    assert(p.x == 0 and p.y == 0)
    assert(Point({1,2}).x == 1)
    assert(Point({1,2}).y == 2)
    assert(Point({x=1,2}).y == 2)
    assert(Point({1,y=2}).x == 1)
  ]])
  assert.run_c([[
    local Point = @record {x: integer, y: integer}
    do
      local p = Point{x=1, y=2}
      assert(p.x == 1 and p.y == 2)
    end
    do
      local p: Point = {x=1, y=2}
      assert(p.x == 1 and p.y == 2)
    end
    do
      local V <comptime> = 2
      local p: Point = {V, V}
      assert(p.x == 2 and p.y == 2)
    end
  ]])
  assert.run_c([[
    local P = @record{x: byte, y: byte}
    local p <const> = P{x=1,y=2}
    assert(p.x == 1 and p.y == 2)

    local r: record {x: array(integer, 1)} =  {x={1}}
    assert(r.x[0] == 1)
  ]])
end)

it("records size", function()
  assert.run_c([=[
    require 'span'
    do
      local R = @record { a: usize, b: span(integer) }
      local r: R, s: integer ##[[cemit('s = sizeof(r);')]]
      assert(#R == s)
    end

    do
      local R = @record { a: cint, b: cchar }
      local r: R, s: integer ##[[cemit('s = sizeof(r);')]]
      assert(#R == s)
    end

    do
      local R = @record { a: cint, b: float64, c: cchar }
      local r: R, s: integer ##[[cemit('s = sizeof(r);')]]
      assert(#R == s)
    end

    do
      local R = @record { a: float64[64][64], c: cchar }
      local r: R, s: integer ##[[cemit('s = sizeof(r);')]]
      assert(#R == s)
    end

    do
      local R1 = @record { a: int32 }
      local R2 = @record { a: number, b: number }
      local R = @record { s: R1, a: R2 }
      local r: R, s: integer ##[[cemit('s = sizeof(r);')]]
      assert(#R == s)
    end
  ]=])
end)

it("record methods", function()
  assert.run_c([[
    local vec2 = @record{x: integer, y: integer}
    function vec2.create(x: integer, y: integer) return vec2{x,y} end
    local v = vec2.create(1,2)
    assert(v.x == 1 and v.y == 2)

    function vec2:length() return self.x + self.y end
    assert(v:length() == 3)
    assert(vec2.length(v) == 3)
    local vp = &v
    assert(vp:length() == 3)
    assert(vec2.length(vp) == 3)

    function vec2.length2(self: vec2) return self:length() end
    assert(v:length2() == 3)
    assert(vec2.length2(v) == 3)

    function vec2:length3() return self:length() end
    assert(v:length3() == 3)

    function vec2.length4(self: vec2*) return self:length() end
    assert(v:length4() == 3)
    assert(vec2.length4(v) == 3)

    function vec2:lenmul(a: integer, b: integer) return (self.x + self.y)*a*b end
    assert(v:lenmul(2,3) == 18)

    local vec2pointer = @vec2*
    function vec2pointer:len() return self.x + self.y end
    assert(v:len() == 3)

    local Math = @record{}
    function Math.abs(x: number): number <cimport'fabs',cinclude'<math.h>'> end
    assert(Math.abs(-1) == 1)
  ]])
end)

it("record metametods", function()
  assert.run_c([[
    local intarray = @record {
      data: integer[100]
    }
    function intarray:__atindex(i: usize <autocast>): integer* <inline>
      return &self.data[i]
    end
    function intarray:__len(): isize <inline>
      return #self.data
    end
    local a: intarray
    assert(a[0] == 0 and a[1] == 0)
    a[0] = 1 a[1] = 2
    assert(a:__atindex(0) == &a.data[0])
    assert(a[0] == 1 and a[1] == 2)
    assert(#a == 100)
    assert(a:__len() == 100)
    local pa = &a
    assert(#$pa == 100)
    assert(#pa == 100)

    local R = @record {
      x: integer
    }
    function R.__convert(x: integer): R
      local self: R
      self.x = x
      return self
    end
    local r: R = 1
    assert(r.x == 1)
    r = R.__convert(2)
    assert(r.x == 2)
    r = 3
    assert(r.x == 3)
    local function f()
      local r: R = 1
      assert(r.x == 1)
      r = R.__convert(2)
      assert(r.x == 2)
      r = 3
      assert(r.x == 3)
    end
    f()
    local function g(r: R)
      return r.x
    end
    assert(g(r) == 3)
    assert(g(4) == 4)

    local R = @record {
      x: integer[2]
    }
    ## R.value.choose_braces_type = function() return types.ArrayType(nil, primtypes.integer, 2) end
    function R.__convert(x: auto): R
      local self: R
      self.x = x
      return self
    end
    local r: R = {1,2}
    assert(r.x[0] == 1 and r.x[1] == 2)
  ]])
end)

it("record string conversions", function()
  assert.run_c([[
    local R = @record{x: integer}
    function R:__tocstring(): cstring return (@cstring)('R') end
    function R:__tostringview(): stringview return 'R' end
    local r: R
    local s: stringview = r
    assert(s == 'R')
    local cs: cstring = r
    assert((@stringview){size=1,data=cs} == 'R')
  ]])
end)

it("record operator overloading", function()
  assert.run_c([[
    local R = @record{x: integer}
    function R:__eq(r: R): boolean return false end
    function R:__lt(r: R): boolean return true end
    function R:__le(r: R): boolean return false end
    function R:__bor(r: R): R return R{1} end
    function R:__bxor(r: R): R return R{2} end
    function R:__band(r: R): R return R{3} end
    function R:__shl(r: R): R return R{4} end
    function R:__shr(r: R): R return R{5} end
    function R:__concat(r: R): R return R{6} end
    function R:__add(r: R): R return R{7} end
    function R:__sub(r: R): R return R{8} end
    function R:__mul(r: R): R return R{9} end
    function R:__idiv(r: R): R return R{10} end
    function R:__div(r: R): R return R{11} end
    function R:__pow(r: R): R return R{12} end
    function R:__mod(r: R): R return R{13} end
    function R:__len(): R return R{14} end
    function R:__unm(): R return R{15} end
    local r: R
    assert((r == r) == false)
    assert((r <= r) == false)
    assert((r < r) == true)
    assert((r | r).x == 1)
    assert((r ~ r).x == 2)
    assert((r & r).x == 3)
    assert((r << r).x == 4)
    assert((r >> r).x == 5)
    assert((r .. r).x == 6)
    assert((r + r).x == 7)
    assert((r - r).x == 8)
    assert((r * r).x == 9)
    assert((r // r).x == 10)
    assert((r / r).x == 11)
    assert((r ^ r).x == 12)
    assert((r % r).x == 13)
    assert((#r).x == 14)
    assert((-r).x == 15)

    local vec2 = @record{x: number, y: number}
    ## vec2.value.is_vec2 = true
    function vec2.__mul(a: vec2, b: #[concept(function(b)
        return b.type.is_vec2 or b.type.is_arithmetic
      end)]#): vec2
      ## if b.type.is_arithmetic then
        return vec2{a.x * b, a.y * b}
      ## else
        return vec2{a.x * b.x, a.y * b.y}
      ## end
    end
    function vec2.__eq(a: vec2, b: vec2): boolean
      return a.x == b.x and a.y == b.y
    end
    local v: vec2 = {1,2}
    assert((v*2) == vec2{2,4})
    assert((2*v) == vec2{2,4})
    assert((v*v) == vec2{1,4})
    assert((v*v) == vec2{1,4})
  ]])
end)

it("record globals", function()
  assert.generate_c([[
    local Math = @record{}
    global Math.PI: number <const> = 3.14
    global Math.E <const> = 2.7

    global Math.Number = @number
    local MathNumber = Math.Number
    local a: MathNumber = 1
    assert(a == 1)
  ]], "double Math_PI = 3.14")
  assert.run_c([[
    local Math = @record{}
    global Math.PI = 3.14
    assert(Math.PI == 3.14)
    Math.PI = 3
    assert(Math.PI == 3)
  ]])
end)

it("records referencing itself", function()
  assert.run_c([[
    local NodeA = @record{next: NodeA*}
    local ap: NodeA*
    local a: NodeA
    assert(ap == nilptr and a.next == nilptr)

    local NodeB = @record{next: NodeB*}
    local b: NodeB
    local bp: NodeB*
    assert(bp == nilptr and b.next == nilptr)
  ]])
end)

it("enums", function()
  assert.generate_c(
    "local e: enum{A=0}",
    [[typedef int64_t enum_]])
  assert.generate_c([[
    local E = @enum{A=1, B=2}
    local i: E = 1
    local E = @enum{A=1, B=2}
    local i: E = 1
  ]], {"typedef int64_t E", "typedef int64_t E__1"})
  assert.run_c([[
    local Enum = @enum{A=0,B=1,C}
    local e: Enum; assert(e == 0)
    e = Enum.B; assert(e == 1)
    e = Enum.C; assert(e == 2)
    assert(Enum.B | Enum.C == 3)
    print(Enum.C)
  ]], "2")
end)

it("pointers", function()
  assert.generate_c("local p: pointer(float32)", "float*")
  assert.generate_c("do local p: pointer end", "void* p")
  assert.generate_c("local p: pointer(record{x:integer}); p.x = 0", "->x = ")
  assert.run_c([[
    local function f(a: pointer): pointer return a end
    local i: integer = 1
    local p: pointer(integer) = &i
    assert($p == 1)
    p = (@pointer(int64))(f(p))
    i = 2
    assert($p == 2)
    $p = 3
    assert(i == 3)

    do
      local x: usize = 0xffffffff
      local p: pointer = (@pointer)(x)
      x = (@usize)(p)
      assert(x == 0xffffffff)
    end

    do
      local x: isize = -1
      local p: pointer = (@pointer)(x)
      x = (@isize)(p)
      assert(x == -1)
    end
  ]])
end)

it("function pointers", function()
  assert.run_c([[
    local function f() return 1 end
    assert((&f)() == 1)
    assert(f() == 1)
  ]])
end)

it("automatic reference", function()
  assert.run_c([[
    local R = @record{x: integer}
    local p: R*, q: R*
    local a: R = R{1}
    p = a
    q = &a
    assert(p.x == q.x)
    assert(($p).x == 1)
    local function f(p: R*) return $p end
    assert(f(a).x == 1)
    local function g(): (integer, R*) return 1, a end
    local function h(): (integer, R) return 1, p end
    local _, r: R = g()
    assert(r.x == 1)
  ]])
end)

it("automatic dereference", function()
  assert.run_c([[
    local A = @integer[1]
    local a: A = {1}
    local p: A* = &a
    local b: A
    b = p
    assert(b[0] == 1)
    local function f(x: A) return x end
    local function g(): A return p end
    a[0] = 2
    assert(f(p)[0] == 2)
    assert(g()[0] == 2)

    local vec2 = @record {x: number, y: number}
    function vec2:add(a: vec2): vec2
      return vec2{self.x + a.x, self.y + a.y}
    end

    local a = vec2{1,2}
    local b = vec2{1,2}
    local c = vec2{0,0}
    local pa = &a
    local pb = &b
    local pc = &c
    $pc = pb:add(pc)
  ]])
end)

it("automatic casting", function()
  assert.generate_c([[
    local a = (@uint8)(-1)
    local b: uint8 <autocast> = -1
  ]], {"a = 255U", "b = 255U"})
  assert.run_c([[
    do
      local i8: int8 <autocast>
      local u8: uint8 = 255
      i8 = u8
      assert(i8 == -1)
    end
    do
      local i8: int8 = -1
      local u8: uint8 <autocast>
      u8 = i8
      assert(u8 == 255)
    end

    local function f(x: uint8 <autocast>)
      return x
    end
    local function g(x: int8 <autocast>)
      return x
    end

    local i: int8 = -1
    local u: uint8 = 255
    assert(f(i) == 255)
    assert(g(u) == -1)
  ]])
end)

it("nilptr", function()
  assert.generate_c("local p: pointer = nilptr", "void* p = NULL")
  assert.run_c([[
    local p: pointer = nilptr
    assert(p == nilptr)
  ]])
end)

it("manual memory managment", function()
  assert.run_c([=[
    local function malloc(size: usize): pointer <cimport'malloc',cinclude'<stdlib.h>',nodecl> end
    local function memset(s: pointer, c: int32, n: usize): pointer <cimport'memset',cinclude'<string.h>',nodecl> end
    local function free(ptr: pointer) <cimport'free',cinclude'<stdlib.h>',nodecl> end
    local a = (@pointer(array(int64, 10)))(malloc(10 * 8))
    memset(a, 0, 10*8)
    assert(a[0] == 0)
    a[0] = 1
    assert(a[0] == 1)
    free(a)
  ]=])
end)

it("C varargs", function()
  assert.generate_c(
    "local function scanf(format: cstring, ...): cint <cimport'scanf'> end",
    "int scanf(char* format, ...);")
end)

it("call pragmas", function()
  assert.generate_c("## cinclude '<myheader.h>'", "#include <myheader.h>")
  assert.generate_c("## cemit '#define SOMETHING'", "#define SOMETHING")
  assert.generate_c("## cemit('#define SOMETHING', 'declaration')", "#define SOMETHING")
  assert.generate_c("## cemit('#define SOMETHING', 'definition')", "#define SOMETHING")
  assert.generate_c("## cdefine 'SOMETHING'", "#define SOMETHING")
end)

it("annotations", function()
  assert.generate_c("local huge: number <cimport'HUGE_VAL',cinclude'<math.h>',nodecl>", "include <math.h>")
  assert.generate_c("local a: int64 <volatile, codename 'a'>", "volatile int64_t a")
  assert.generate_c("local a: int64 <register>", "register int64_t a")
  assert.generate_c("local a: int64 <restrict>", "restrict int64_t a")
  assert.generate_c("local a: int64 <nodecl>", "")
  assert.generate_c("local a: int64 <noinit>", "a;")
  assert.generate_c("local a: int64 <cexport>", "extern int64_t a;")
  assert.generate_c("do local a <static> = 1 end", "static int64_t a = 1;", true)
  assert.generate_c("local a: int64 <cattribute 'vector_size(16)'>", "int64_t a __attribute__((vector_size(16)))")
  assert.generate_c("local a: number <cqualifier 'in'> = 1", "in double a = 1.0;")
  assert.generate_c("local R <aligned(16)> = @record{x: integer}; local r: R", "__attribute__((aligned(16)));")
  assert.generate_c("local function f() <inline> end", "inline void")
  assert.generate_c("local function f() <noreturn> end", "nelua_noreturn void")
  assert.generate_c("local function f() <noinline> end", "nelua_noinline void")
  assert.generate_c("local function f() <volatile> end", "volatile void")
  assert.generate_c("local function f() <nodecl> end", "")
  assert.generate_c("local function f() <nosideeffect> end", "")
  assert.generate_c("local function f() <cqualifier 'volatile'> end", "volatile void")
  assert.generate_c("local function f() <cattribute 'noinline'> end", "__attribute__((noinline)) void")
  assert.generate_c(
    "local function puts(s: cstring): int32 <cimport'puts'> end",
    "int32_t puts(char* s);")
  assert.generate_c(
    "local function cos(x: number): number <cimport'myfunc',cinclude'<myheader.h>',nodecl> end",
    "#include <myheader.h>")
  assert.generate_c([[
    do
      ## cemit(function(e) e:add_ln('#define SOMETHING') end)
    end
  ]], "#define SOMETHING")
  assert.run_c([[
    local function exit(x: int32) <cimport'exit',cinclude'<stdlib.h>',nodecl> end
    local function puts(s: cstring): int32 <cimport'puts',cinclude'<stdio.h>',nodecl> end
    local function perror(s: cstring): void <cimport,nodecl> end
    local function f() <noinline, noreturn>
      local i: int32 <register, volatile, codename 'i'> = 0
      exit(i)
    end
    puts('msg stdout\n')
    perror('msg stderr\n')
    f()
  ]], "msg stdout", "msg stderr")
  assert.run_c([[
    ## cinclude '<stdlib.h>'
    local div_t <cimport,nodecl> = @record{quot: cint, rem: cint}
    local function div(numer: cint, denom: cint): div_t <cimport,nodecl> end
    local r = div(38,5)
    assert(r.quot == 7 and r.rem == 3)
  ]])
end)

it("type codenames", function()
  assert.generate_c([[
    local myrecord <codename 'myrecord'> = @record{x: integer}
    function myrecord:foo() return self.x end
    local r = myrecord{}
    return r:foo()
  ]], {
    "typedef struct myrecord myrecord;",
    "struct myrecord {\n  int64_t x;\n};",
    "static int64_t myrecord_foo(myrecord_ptr self);"
  })
end)

it("entrypoint", function()
  assert.run_c([[
    print 'hello'
    local function main(): cint <entrypoint>
      print 'world'
      return 0
    end
    print 'wonderful'
  ]], "hello\nwonderful\nworld")
end)

it("hook main", function()
  assert.run_c([[
    local function nelua_main(): cint <cimport,nodecl> end
    local function main(argc: cint, argv: cchar**): cint <entrypoint>
      print 'before'
      local ret = nelua_main()
      print('after')
      return ret
    end
    print 'inside'
  ]], "before\ninside\nafter")
end)

it("print builtin", function()
  assert.run_c([[
    print(1,0.2,1e2,0xf,0b01)
    local i: integer, s: stringview, n: nilable
    print(i, s, n)
  ]],
    '1\t0.200000\t100.000000\t15\t1\n' ..
    '0\t\tnil')
end)

it("sizeof builtin", function()
  assert.run_c([[
    assert(#@int8 == 1)
    assert(#@int16 == 2)
    assert(#@int32 == 4)
    assert(#@int64 == 8)
    assert(#@int32[4] == 16)

    local A = @record{
      s: int16,   -- 2
                  -- 2 pad
      i: int32,   -- 4
      c: boolean, -- 1
                  -- 3 pad
    }
    assert(#A == 12)
    assert(#@A[8] == 96)

    local B = @record{
      i: int32,   -- 4
      c: cchar,   -- 1
                  -- 1 pad
      s: int16,   -- 2
    }
    assert(#B == 8)

    local C = @record{
      i: int32,   -- 4
      c: cchar,   -- 1
    }
    assert(#C == 8)

    local D = @record{
      i: int64,   -- 8
      c: cchar,   -- 1
    }
    assert(#D == 16)
  ]])
end)

it("assert builtin", function()
  assert.generate_c(
    "assert(true)",
    "nelua_assert(true)")
  assert.generate_c(
    "assert(true, 'assertion')",
    'nelua_assert_stringview(true, ')
  assert.run_c([[
    assert(true)
    assert(true, 'assertion')
  ]])
  assert.run_error_c([[
    assert()
  ]], "invalid assert call")
  assert.run_error_c([[
    assert(false, 'assertion')
  ]], "assertion")
  assert.run_error_c([[
    assert(false)
  ]], "assertion failed!")
end)

it("error builtin", function()
  assert.run_error_c([[
    error 'got an error!'
  ]], 'got an error!')
  assert.run_error_c([[
    panic 'got an panic!'
  ]], 'got an panic!')
end)

it("warn builtin", function()
  assert.run_error_c([[
    warn 'got an warn!'
    return -1
  ]], 'got an warn!')
end)

it("likely builtin", function()
  assert.generate_c([[do
    local a = likely(true)
    local b = unlikely(false)
  end]], {
    "bool a = nelua_likely(true)",
    "b = nelua_unlikely(false)"
  })
  assert.run_c([[
    assert(likely(true))
    assert(not unlikely(false))
  ]])
end)

it("type builtin", function()
  assert.run_c([[
    local function f() end
    local R = @record{x:integer}
    local r: R
    assert(r.x == 0)
    assert(type('a') == 'string')
    assert(type(1) == 'number')
    assert(type(false) == 'boolean')
    assert(type(f) == 'function')
    assert(type(R) == 'type')
    assert(type(r) == 'record')
    assert(type(&r) == 'pointer')
    assert(type(nilptr) == 'pointer')
    assert(type(nil) == 'nilable')
  ]])
end)

it("context pragmas", function()
  assert.generate_c([[
    ## context.pragmas.noinit = true
    local a: integer
    ## context.pragmas.noinit = false
    local b: integer
  ]], {
    "\nstatic int64_t a;\n",
    "\nstatic int64_t b = 0;\n"
  })

  assert.generate_c([[
    ## context.pragmas.nostatic = true
    local a: integer
    local function f() end
    ## context.pragmas.nostatic = false
    local b: integer
    local function g() end
  ]], {
    "\nint64_t a = 0;\n",
    "\nstatic int64_t b = 0;\n",
    "\nvoid f()",
    "\nstatic void g()",
  })

  assert.generate_c([[
    ## context.pragmas.nofloatsuffix = true
    local a: float32 = 0
  ]], {
    "a = 0.0;",
  })

  assert.generate_c([[
    ## context.pragmas.nostatic = true
    local a: integer
    ## context.pragmas.nostatic = false
    local b: integer
  ]], {
    "\nint64_t a = 0;\n",
    "\nstatic int64_t b = 0;\n"
  })

  assert.generate_c([[
    ## context.pragmas.unitname = 'mylib'
    local function foo() <cexport>
    end
  ]], "extern void mylib_foo();")
end)

it("require builtin", function()
  assert.generate_c([[
    require 'examples.helloworld'
  ]], "hello world")
  assert.generate_c([[
    require 'examples/helloworld'
  ]], "hello world")
  assert.run_c([[
    require 'examples.helloworld'
  ]], "hello world")
  assert.c_gencode_equals([[
    require 'examples.helloworld'
  ]], [[
    require 'examples.helloworld'
    require 'examples/helloworld'
  ]])
  assert.run_error_c([[
    local a = 'mylib'
    require(a)
  ]], "runtime require unsupported")
  assert.run_error_c([[
    require 'invalid_file'
  ]], "module 'invalid_file' not found")
  assert.run_c_from_file('tests/memory_test.nelua')
end)

it("name collision", function()
  assert.run_c([[
    local function hello() print 'a' end
    hello()
    local function hello() print 'b' end
    hello()
    do
      hello()
      local function hello() print 'c' end
      hello()
      local function hello() print 'd' end
      hello()
    end
    hello()
    do
      hello()
      local function hello() print 'e' end
      hello()
      local function hello() print 'f' end
      hello()
    end
    hello()
  ]], "a\nb\nb\nc\nd\nb\nb\ne\nf\nb\n")
  assert.run_c([[
    local s = 'a'
    print(s)
    local s = 'b'
    print(s)
    do
      print(s)
      local s = 'c'
      print(s)
      local s = 'd'
      print(s)
    end
    print(s)
    do
      print(s)
      local s = 'e'
      print(s)
      local s = 'f'
      print(s)
    end
    print(s)
  ]], "a\nb\nb\nc\nd\nb\nb\ne\nf\nb\n")
  assert.run_c([[
    do
      local function foo() print 'a' end
      foo()
    end
    do
      local function foo() print 'b' end
      foo()
    end
    local function foo() print 'c' end
    foo()
  ]], "a\nb\nc\n")
end)

it("top scope variables prefix", function()
  assert.config.srcname = 'mymod'
  assert.generate_c("local a = 1", "int64_t mymod_a = 1;")
  assert.generate_c("global a = 1", "static int64_t mymod_a = 1;\n")
  assert.generate_c("global a = 1", "static int64_t mymod_a = 1;\n")
  assert.generate_c("local function f() end", "void mymod_f() {\n}")
  assert.config.srcname = nil
end)

it("GC requirements", function()
  assert.generate_c([=[
    global gp: pointer
    global gr: record{x: pointer}
    global ga: integer*[4]
    global g
    local p: pointer
    local r: record{x: pointer}
    local a: integer*[4]
    local l

    local function markp(what: pointer)
    end

    local function mark()
      ## emit_mark_static = hygienize(function(sym)
        markp(&#[sym]#)
      ## end)

      ##[[
      afteranalyze(function()
        local function search_scope(scope)
          for i=1,#scope.symbols do
            local sym = scope.symbols[i]
            local symtype = sym.type or primtypes.any
            if sym:is_static_vardecl() and symtype:has_pointer() then
              emit_mark_static(sym, symtype)
            end
          end
        end
        search_scope(context.rootscope)
        for _,childscope in ipairs(context.rootscope.children) do
          search_scope(childscope)
        end
      end)
      ]]
    end
  ]=], [[void mark() {
  markp((void*)(&gp));
  markp((void*)(&gr));
  markp((void*)(&ga));
  markp((void*)(&g));
  markp((void*)(&p));
  markp((void*)(&r));
  markp((void*)(&a));
  markp((void*)(&l));
}]])
end)

it("concepts", function()
  assert.run_c([=[
    local an_array = #[concept(function(attr)
      if attr.type and attr.type.is_array then
        return true
      end
    end)]#
    local an_arithmetic = #[concept(function(attr)
      if attr.type.is_arithmetic then
        return true
      end
    end)]#
    local function f(a: an_array, x: an_arithmetic, len: integer)
      ## print(a.type)
      assert(a[0] == x)
    end
    local a: integer[4] = {1,2,3,4}
    local b: number[3] = {5,6,7}
    f(a, a[0], #a)
    f(b, b[0], #b)

    local R = @record {
      x: integer
    }
    function R:__convert(x: an_arithmetic)
      self.x = x
    end
    local r: R
    R.__convert(&r, 1)
    assert(r.x == 1)
    r:__convert(2)
    assert(r.x == 2)
  ]=])
end)

it("generics", function()
  assert.run_c([=[
    local arrayproxy = #[generalize(function(T, size)
      return types.ArrayType(nil, T, size)
    end)]#

    local intarray = @arrayproxy(integer, 4)
    local j: arrayproxy(integer, 4) = {1,2,3,4}
    assert(j[0] == 1)
    local i = (@arrayproxy(integer, 4)){1,2,3,4}
    assert(i[0] == 1)

    local function f(x: arrayproxy(integer, 4))
      assert(x[0] == 1)
    end

    f(i)
    f(j)
  ]=])
end)

end)