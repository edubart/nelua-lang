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
  assert.generate_c("do local a = 1 end", "  int64_t a = 1;")
end)

it("global variable", function()
  assert.generate_c("global a = 1", "static int64_t mymod_a = 1;\n")
end)

it("number", function()
  assert.generate_c("do local a = 99 end", "99")
  assert.generate_c("do local a = 1.2 end", "1.2")
  assert.generate_c("do local a = 1e2 end", "100")
  assert.generate_c("do local a = 0x1f end", "0x1f")
  assert.generate_c("do local a = 0b10 end", "0x2")
  assert.generate_c("do local a = 1e129 end", "1e+129;")
end)

it("number literals", function()
  assert.generate_c("do local a = 1_integer end", "int64_t a = 1;")
  assert.generate_c("do local a = 1_number end", "double a = 1.0;")
  assert.generate_c("do local a = 1_byte end", "uint8_t a = 1U;")
  assert.generate_c("do local a = 1_isize end", "intptr_t a = 1;")
  assert.generate_c("do local a = 1_usize end", "uintptr_t a = 1U;")
  assert.generate_c("do local a = 1_cint end", "int a = 1;")
  assert.generate_c("do local a = 1_clong end", "long a = 1;")
  assert.generate_c("do local a = 1_clonglong end", "long long a = 1;")
end)

it("type assertion", function()
  assert.generate_c("do local b = 1_u64; local a = (@int16)(b) end", "int16_t a = (int16_t)b")
  assert.generate_c("do local b = 1_u8; local a = (@int64)(b) end", "int64_t a = (int64_t)b")
end)

it("string", function()
  assert.generate_c([[local a = "hello"]], [["hello"]])
  assert.generate_c([[local a = "\x01"]], [["\x01"]])
end)

it("boolean", function()
  assert.generate_c("do local a = true end", "bool a = true")
  assert.generate_c("do local a = false end", "bool a = false")
end)

it("call", function()
  assert.generate_c("f()", "mymod_f();")
  assert.generate_c("f(g())", "mymod_f(mymod_g())")
  assert.generate_c("f(a, b)", "mymod_f(mymod_a, mymod_b)")
  assert.generate_c("f(a)(b)", "mymod_f(mymod_a)(mymod_b)")
  assert.generate_c("a.f()", "mymod_a.f()")
  --assert.generate_c("a:f(a)", "mymod_a.f(mymod_a, mymod_a)")
  assert.generate_c("do f() end", "f();")
  assert.generate_c("do return f() end", "return nelua_any_to_nelua_cint(f());")
  assert.generate_c("do f(g()) end", "f(g())")
  assert.generate_c("do f(a, b) end", "f(a, b)")
  assert.generate_c("do f(a)(b) end", "f(a)(b)")
  assert.generate_c("do a.f() end", "a.f()")
  --assert.generate_c("do a:f() end", "a.f(a)")
end)

it("if", function()
  assert.generate_c("if nilptr then\nend","if(false) {\n")
  assert.generate_c("if nil then\nend","if(false) {\n")
  assert.generate_c("if 1 then\nend","if(true) {\n")
  assert.generate_c("if a then\nend","if(nelua_any_to_nelua_boolean(mymod_a)) {\n")
  assert.generate_c("if true then\nend","if(true) {\n  }")
  assert.generate_c("if true then\nelseif true then\nend", "if(true) {\n  } else if(true) {\n  }")
  assert.generate_c("if true then\nelse\nend", "if(true) {\n  } else {\n  }")
  assert.scoped_generate_c([[
    local a: boolean, b: boolean
    if a and b then end]],
    "if(a && b) {\n    }")
  assert.scoped_generate_c([[
    local a: boolean, b: boolean, c: boolean
    if a and b or c then end]],
    "if((a && b) || c) {\n    }")
  assert.scoped_generate_c([[
    local a: boolean, b: boolean
    if a and not b then end]],
    "if(a && (!b)) {\n    }")
end)

it("switch", function()
  assert.generate_c("do switch a case 1 then f() case 2 then g() else h() end end",[[
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
  assert.generate_c("for i=a,b do end", {
    "for(nelua_any i = a, __end = b; i <= __end; i = i + 1) {"})
  assert.generate_c("for i=a,b do i=c end", {
    "for(nelua_any __it = a, __end = b; __it <= __end; __it = __it + 1) {",
    "nelua_any i = __it;"})
  assert.generate_c("for i=a,b,c do end",
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
  assert.generate_c("local a: integer", "int64_t mymod_a = 0;")
  assert.generate_c("local a: integer = 0", "int64_t mymod_a = 0;")
  assert.generate_c("local π = 3.14", "double mymod_uCF80 = 3.14;")
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
    local a <comptime>, b <comptime> = 1, 2
    local c <const> = (@int32)(a * b)
  ]], "static const int32_t mymod_c = 2;")

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
  assert.generate_c("do a = b end" ,"a = b")
end)

it("multiple assignment", function()
  assert.generate_c("do a, b = x, y end", {
    "__asgntmp1 = x;", "__asgntmp2 = y;",
    "a = __asgntmp1;", "b = __asgntmp2;" })
  assert.generate_c("do a.b, a[b] = x, y end", {
    "__asgntmp1 = x;", "__asgntmp2 = y;",
    "a.b = __asgntmp1;", "a[b] = __asgntmp2;" })
  assert.run_c([[
    local a, b = 1,2
    a, b = b, a
    assert(a == 2 and b == 1)
  ]])
end)

it("function definition", function()
  assert.generate_c("local function f() end",
    "void mymod_f() {\n}")
  assert.generate_c(
    "local function f(): integer return 0 end",
    "int64_t mymod_f() {\n  return 0;\n")
  assert.generate_c(
    "local function f(a: integer): integer return a end",
    "int64_t mymod_f(int64_t a) {\n  return a;\n}")
end)

it("global function definition", function()
  assert.generate_c("function f() end", "static void mymod_f();")
  assert.run_c([[
    ## strict = true
    global function f(x: integer) return x+1 end
    assert(f(1) == 2)
  ]])
end)

it("function return", function()
  assert.generate_c([[
    local function f(): integer return 0 end
  ]], "int64_t mymod_f() {\n  return 0;")
  assert.generate_c([[
    local function f(): any return end
  ]], "nelua_any mymod_f() {\n  return (nelua_any){0};")
  assert.generate_c([[
    local function f() return end
  ]], "return;")
end)

it("function multiple returns", function()
  assert.generate_c([[
    local function f(): (integer, boolean) return 1, true end
  ]], {
    "function_%w+_ret mymod_f",
    "return %(function_%w+_ret%){1, true};"
  }, true)
  assert.generate_c([[do
    local function f(): (integer, boolean) return 1, true end
    local a, b = f()
    local c = f()
  end]], {
    "int64_t a = __ret%d+%.r1;",
    "bool b = __ret%d+%.r2;",
    "int64_t c = f__%d+%(%)%.r1;"
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
  assert.scoped_generate_c("local x = not true", "x = false;")
  assert.scoped_generate_c("local x = not false", "x = true;")
  assert.scoped_generate_c("local x = not nil", "x = true;")
  assert.scoped_generate_c("local x = not nilptr", "x = true;")
  assert.scoped_generate_c("local x = not 'a'", "x = false;")
  assert.scoped_generate_c("local a = true; local x = not a", "x = !a;")
  --assert.scoped_generate_c("local a = nil; local x = not a", "x = true;")
  --assert.scoped_generate_c("local a = nilptr; local x = not a", "x = !a;")
end)

it("unary operator `ref`", function()
  assert.scoped_generate_c("local a = 1; local x = &a", "x = &a;")
end)

it("unary operator `unm`", function()
  assert.scoped_generate_c("local x = -a", "-a;")
end)

it("unary operator `deref`", function()
  assert.scoped_generate_c("local a: integer*; local x = $a", "x = *a;")
end)

it("unary operator `bnot`", function()
  assert.scoped_generate_c("local x = ~a", "~a;")
end)

it("unary operator `len`", function()
  assert.scoped_generate_c("local x = #@integer", "x = 8;")
  assert.scoped_generate_c("local x = #'asd'", "x = 3;")
  assert.scoped_generate_c("local x = #@integer[4]", "x = 32;")
  --assert.scoped_generate_c("a = 'asd'; local x = #a", "x = 3;")
end)

it("unary operator `lt`", function()
  assert.scoped_generate_c("local x = a < b", "a < b")
  assert.scoped_generate_c("local x = 1 < 1", "x = false;")
  assert.scoped_generate_c("local x = 1 < 2", "x = true;")
  assert.scoped_generate_c("local x = 2 < 1", "x = false;")
  assert.scoped_generate_c("local x = 'a' < 'a'", "x = false;")
  assert.scoped_generate_c("local x = 'a' < 'b'", "x = true;")
  assert.scoped_generate_c("local x = 'b' < 'a'", "x = false;")
end)

it("unary operator `le`", function()
  assert.scoped_generate_c("local x = a <= b", "a <= b")
  assert.scoped_generate_c("local x = 1 <= 1", "x = true;")
  assert.scoped_generate_c("local x = 1 <= 2", "x = true;")
  assert.scoped_generate_c("local x = 2 <= 1", "x = false;")
  assert.scoped_generate_c("local x = 'a' <= 'a'", "x = true;")
  assert.scoped_generate_c("local x = 'a' <= 'b'", "x = true;")
  assert.scoped_generate_c("local x = 'b' <= 'a'", "x = false;")
end)

it("unary operator `gt`", function()
  assert.scoped_generate_c("local x = a > b", "a > b")
  assert.scoped_generate_c("local x = 1 > 1", "x = false;")
  assert.scoped_generate_c("local x = 1 > 2", "x = false;")
  assert.scoped_generate_c("local x = 2 > 1", "x = true;")
  assert.scoped_generate_c("local x = 'a' > 'a'", "x = false;")
  assert.scoped_generate_c("local x = 'a' > 'b'", "x = false;")
  assert.scoped_generate_c("local x = 'b' > 'a'", "x = true;")
end)

it("unary operator `ge`", function()
  assert.scoped_generate_c("local x = a >= b", "a >= b")
  assert.scoped_generate_c("local x = 1 >= 1", "x = true;")
  assert.scoped_generate_c("local x = 1 >= 2", "x = false;")
  assert.scoped_generate_c("local x = 2 >= 1", "x = true;")
  assert.scoped_generate_c("local x = 'a' >= 'a'", "x = true;")
  assert.scoped_generate_c("local x = 'a' >= 'b'", "x = false;")
  assert.scoped_generate_c("local x = 'b' >= 'a'", "x = true;")
end)

it("binary operator `eq`", function()
  assert.scoped_generate_c("local x = a == b", "a == b")
  assert.scoped_generate_c("local x = 1 == 1", "x = true;")
  assert.scoped_generate_c("local x = 1 == 2", "x = false;")
  assert.scoped_generate_c("local x = 1 == '1'", "x = false;")
  assert.scoped_generate_c("local x = '1' == 1", "x = false;")
  assert.scoped_generate_c("local x = '1' == '1'", "x = true;")
  assert.scoped_generate_c("a,b = 1,2; local x = a == b", "x = a == b;")
end)

it("binary operator `ne`", function()
  assert.scoped_generate_c("local x = a ~= b", "a != b")
  assert.scoped_generate_c("local x = 1 ~= 1", "x = false;")
  assert.scoped_generate_c("local x = 1 ~= 2", "x = true;")
  assert.scoped_generate_c("local x = 1 ~= 's'", "x = true;")
  assert.scoped_generate_c("local x = 's' ~= 1", "x = true;")
  assert.scoped_generate_c("a,b = 1,2; local x = a ~= b", "x = a != b;")
end)

it("binary operator `add`", function()
  assert.scoped_generate_c("local x = a + b",       "a + b;")
  assert.scoped_generate_c("local x = 3 + 2",       "x = 5;")
  assert.scoped_generate_c("local x = 3.0 + 2.0",   "x = 5.0;")
end)

it("binary operator `sub`", function()
  assert.scoped_generate_c("local x = a - b",       "a - b")
  assert.scoped_generate_c("local x = 3 - 2",       "x = 1;")
  assert.scoped_generate_c("local x = 3.0 - 2.0",   "x = 1.0;")
end)

it("binary operator `mul`", function()
  assert.scoped_generate_c("local x = a * b",       "a * b")
  assert.scoped_generate_c("local x = 3 * 2",       "x = 6;")
  assert.scoped_generate_c("local x = 3.0 * 2.0",   "x = 6.0;")
end)

it("binary operator `div`", function()
  --assert.scoped_generate_c("local x = a / b")
  assert.scoped_generate_c("local x = 3 / 2",                   "x = 1.5;")
  assert.scoped_generate_c("local x = (@float64)(3 / 2)",       "x = 1.5;")
  assert.scoped_generate_c("local x = 3 / 2_int64",             "x = 1.5;")
  assert.scoped_generate_c("local x = 3.0 / 2",                 "x = 1.5;")
  assert.scoped_generate_c("local x = (@integer)(3_i / 2_i)",   "x = (int64_t)1.5;")
  assert.scoped_generate_c("local x = (@integer)(3 / 2_int64)", "x = (int64_t)1.5;")
  assert.scoped_generate_c("local x =  3 /  4",                 "x = 0.75;")
  assert.scoped_generate_c("local x = -3 /  4",                 "x = -0.75;")
  assert.scoped_generate_c("local x =  3 / -4",                 "x = -0.75;")
  assert.scoped_generate_c("local x = -3 / -4",                 "x = 0.75;")
  assert.scoped_generate_c("local a,b = 1,2; local x=a/b",      "x = a / (double)b;")
  assert.scoped_generate_c("local a,b = 1.0,2.0; local x=a/b",  "x = a / b;")
end)

it("binary operator `idiv`", function()
  --assert.scoped_generate_c("local x = a // b")
  assert.scoped_generate_c("local x = 3 // 2",      "x = 1;")
  assert.scoped_generate_c("local x = 3 // 2.0",    "x = 1.0;")
  assert.scoped_generate_c("local x = 3.0 // 2.0",  "x = 1.0;")
  assert.scoped_generate_c("local x = 3.0 // 2",    "x = 1.0;")
  assert.scoped_generate_c("local x =  7 //  3",    "x = 2;")
  assert.scoped_generate_c("local x = -7 //  3",    "x = -3;")
  assert.scoped_generate_c("local x =  7 // -3",    "x = -3;")
  assert.scoped_generate_c("local x = -7 // -3",    "x = 2;")
  assert.scoped_generate_c("local x =  7 //  3.0",  "x = 2.0;")
  assert.scoped_generate_c("local x = -7 //  3.0",  "x = -3.0;")
  assert.scoped_generate_c("local x =  7 // -3.0",  "x = -3.0;")
  assert.scoped_generate_c("local x = -7 // -3.0",  "x = 2.0;")
  assert.scoped_generate_c("local a,b = 1,2; local x=a//b",      "x = a / b;")
  assert.scoped_generate_c("local a,b = 1.0,2.0; local x=a//b",  "x = floor(a / b);")
end)

it("binary operator `mod`", function()
  --assert.scoped_generate_c("local x = a % b")
  assert.scoped_generate_c("local x = 3 % 2",       "x = 1;")
  assert.scoped_generate_c("local x = 3.0 % 2.0",   "x = 1.0;")
  assert.scoped_generate_c("local x = 3.0 % 2",     "x = 1.0;")
  assert.scoped_generate_c("local x = 3 % 2.0",     "x = 1.0;")
  assert.scoped_generate_c("local a, b = 3, 2;     local x = a % b", "x = a % b;")
  assert.scoped_generate_c("local a, b = 3.0, 2;   local x = a % b", "x = fmod(a, b);")
  assert.scoped_generate_c("local a, b = 3, 2.0;   local x = a % b", "x = fmod(a, b);")
  assert.scoped_generate_c("local a, b = 3.0, 2.0; local x = a % b", "x = fmod(a, b);")
end)

it("binary operator `pow`", function()
  --assert.scoped_generate_c("local x = a ^ b")
  assert.scoped_generate_c("local a,b = 2,2; local x = a ^ b", "x = pow(a, b);")
  assert.scoped_generate_c("local x = 2 ^ 2", "x = 4.0;")
  assert.scoped_generate_c("local x = 2_f32 ^ 2_f32", "x = 4.0f;")
  assert.scoped_generate_c("local a,b = 2_f32,2_f32; local x = a ^ b", "x = powf(a, b);")
end)

it("binary operator `band`", function()
  assert.scoped_generate_c("local x = 3 & 5",                   "x = 1;")
  assert.scoped_generate_c("local x = -0xfffffffd & 5",         "x = 1;")
  assert.scoped_generate_c("local x = -3 & -5",                 "x = -7;")
  assert.scoped_generate_c("local x = -3_i32 & 0xfffffffb_u32", "x = -7;")
end)

it("binary operator `bor`", function()
  assert.scoped_generate_c("local x = a | b", "a | b;")
  assert.scoped_generate_c("local x = 3 | 5", "x = 7;")
  assert.scoped_generate_c("local x = 3 | -5", "x = -5;")
  assert.scoped_generate_c("local x = -0xfffffffffffffffd | 5", "x = 7;")
  assert.scoped_generate_c("local x = -3 | -5", "x = -1;")
end)

it("binary operator `bxor`", function()
  assert.scoped_generate_c("local x = a ~ b", "a ^ b;")
  assert.scoped_generate_c("local x = 3 ~ 5", "x = 6;")
  assert.scoped_generate_c("local x = 3 ~ -5", "x = -8;")
  assert.scoped_generate_c("local x = -3 ~ -5", "x = 6;")
end)

it("binary operator `shl`", function()
  assert.scoped_generate_c("local x = a << b", "a << b;")
  assert.scoped_generate_c("local x = 6 << 1", "x = 12;")
  assert.scoped_generate_c("local x = 6 << 0", "x = 6;")
  assert.scoped_generate_c("local x = 6 << -1", "x = 3;")
end)

it("binary operator `shr`", function()
  assert.scoped_generate_c("local x = a >> b", "a >> b;")
  assert.scoped_generate_c("local x = 6 >> 1", "x = 3;")
  assert.scoped_generate_c("local x = 6 >> 0", "x = 6;")
  assert.scoped_generate_c("local x = 6 >> -1", "x = 12;")
end)

it("binary operator `concat`", function()
  assert.scoped_generate_c("local x = 'a' .. 'b'", [["ab"]])
end)

it("string comparisons", function()
  assert.generate_c("do local a,b = 'a','b'; local x = a == b end", "nelua_string_eq(a, b)")
  assert.generate_c("do local a,b = 'a','b'; local x = a ~= b end", "nelua_string_ne(a, b)")
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

it("binary conditional operators", function()
  assert.generate_c("do return a or b end",  [[({
      nelua_any t1_ = a; nelua_unused(t1_);
      nelua_any t2_ = {0}; nelua_unused(t2_);
      bool cond_ = nelua_any_to_nelua_boolean(t1_);
      if(cond_)
        t2_ = b;
      cond_ ? t1_ : t2_;
    })]])
  assert.generate_c("do return a and b end",  [[({
      nelua_any t1_ = a; nelua_unused(t1_);
      nelua_any t2_ = {0}; nelua_unused(t2_);
      bool cond_ = nelua_any_to_nelua_boolean(t1_);
      if(cond_) {
        t2_ = b;
        cond_ = nelua_any_to_nelua_boolean(t2_);
      }
      cond_ ? t2_ : (nelua_any){0};
    })]])
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
  ]])
end)

it("expressions with side effects", function()
  assert.generate_c([[do
    local function f() return 1 end
    local a = f() + 1
  end]],  "int64_t a = f__1() + 1")
  assert.generate_c([[do
    local function f() return 1 end
    local function g() return 1 end
    local a = f() + g()
  end]],  [[int64_t a = ({
      int64_t t1_ = f__1();
      int64_t t2_ = g__1();
      t1_ + t2_;
    });]])
  assert.run_c([[
    local function f() return 1 end
    local function g() return 2 end
    local a = f() + g()
    assert(a == 3)
  ]])
end)

it("c types", function()
  assert.generate_c("do local a: integer end", "int64_t a = 0;")
  assert.generate_c("do local a: number end", "double a = 0.0;")
  assert.generate_c("do local a: byte end", "uint8_t a = 0U;")
  assert.generate_c("do local a: float64 end", "double a = 0.0;")
  assert.generate_c("do local a: float32 end", "float a = 0.0f;")
  assert.generate_c("do local a: pointer end", "void* a = NULL;")
  assert.generate_c("do local a: int64 end", "int64_t a = 0;")
  assert.generate_c("do local a: int32 end", "int32_t a = 0;")
  assert.generate_c("do local a: int16 end", "int16_t a = 0;")
  assert.generate_c("do local a: int8 end", "int8_t a = 0;")
  assert.generate_c("do local a: isize end", "intptr_t a = 0;")
  assert.generate_c("do local a: uint64 end", "uint64_t a = 0U;")
  assert.generate_c("do local a: uint32 end", "uint32_t a = 0U;")
  assert.generate_c("do local a: uint16 end", "uint16_t a = 0U;")
  assert.generate_c("do local a: uint8 end", "uint8_t a = 0U;")
  assert.generate_c("do local a: usize end", "uintptr_t a = 0U;")
  assert.generate_c("do local a: boolean end", "bool a = false;")
end)

it("reserved names quoting", function()
  assert.generate_c("local default: integer", "int64_t mymod_default = 0;")
  assert.generate_c("local NULL: integer = 0", "int64_t mymod_NULL = 0;")
  assert.generate_c("do local default: integer end", "int64_t default_ = 0;")
  assert.generate_c("do local NULL: integer = 0 end", "int64_t NULL_ = 0;")
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
  ]])
end)

it("any type", function()
  assert.generate_c(
    "do local a: any end",
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
  ]], "true\nfalse")
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
    local b: string = a
  ]], "type check fail")
end)

it("cstring and string conversions", function()
  assert.run_c([[
    local a = 'hello'
    print(a)
    local b: cstring = a
    print(b)
    local c: string = (@string)(b)
    print(c)
  ]], "hello\nhello\nhello")
end)

it("array tables", function()
  assert.generate_c(
    "do local t: arraytable(boolean) end",
    "nelua_boolean_arrtab t = {0};")
  assert.generate_c(
    "do local t: arraytable(boolean); local a = #t end",
    "int64_t a = nelua_boolean_arrtab_length(&t);")
  assert.run_c([[
    local t: arraytable(boolean)
    print(t[0], #t)
    t[1] = true
    print(t[1], #t)
  ]], "false\t0\ntrue\t1")
  assert.run_c([[
    local t: arraytable(integer) = {}
    print(t[0],#t)
  ]], "0\t0")
  assert.run_c([[
    local t: arraytable(integer) = {1, 2}
    print(t[0], t[1], t[2], #t)
  ]], "0\t1\t2\t2")
end)

it("spans", function()
  assert.run_c([[
    local buff: array(integer, 10)
    local s: span(integer) = {&buff[0], 10}
    assert(s.size == 10)
    assert(s.data == &buff[0])
    assert(s[0] == 0)
    s[0] = 0xf
    assert(s[0] == 0xf)
  ]])
end)

it("ranges", function()
  assert.run_c([[
    local a: range(integer)
    assert(a.low == 0 and a.high == 0)
    a = 2:3
    assert(a.low == 2 and a.high == 3)
    a = -1:0
    assert(a.low == -1 and a.high == 0)

    local buff: array(integer, 10)
    local span1 = buff[0:9]
    local span2 = span1[0:9]
    assert(span2[0] == 0)
    span2[0] = 2
    span2[9] = 3
    assert(buff[0] == 2 and buff[9] == 3)

    local arr = (@integer[4]){1,2,3,4}
    local s = arr[1:2]
    assert(s[0] == 2 and s[1] == 3)
  ]])
end)

it("arrays", function()
  assert.generate_c(
    "local a: array(boolean, 10)",
    "bool data[10];")
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
    print(b[0], b[1], b[2], b[3], #b)
  ]], "1\t2\t3\t4\t4")
end)

it("records", function()
  assert.generate_c(
    "local t: record{}",
    "typedef struct record_%w+ record_%w+;", true)
  assert.generate_c(
    "local t: record{a: boolean}",
    [[typedef struct record_%w+ {
  bool a;
} record_%w+]], true)
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
    do
      local Point = @record {x: integer, y: integer}
      local p = Point{x=1, y=2}
      assert(p.x == 1 and p.y == 2)
    end
    do
      local Point = @record {x: integer, y: integer}
      local p: Point = {x=1, y=2}
      assert(p.x == 1 and p.y == 2)
    end
  ]])
  assert.run_c([[
    local r: record {x: array(integer, 1)} =  {x={1}}
    assert(r.x[0] == 1)
  ]])
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

it("record globals", function()
  assert.generate_c([[
    ## nohashcodenames = true
    local Math = @record{}
    global Math.PI: number <const> = 3.14
    global Math.E <const> = 2.7

    global Math.Number = @number
    local MathNumber = Math.Number
    local a: MathNumber = 1
    assert(a == 1)
  ]], "double mymod_Math_PI = 3.14")
  assert.run_c([[
    local Math = @record{}
    global Math.PI = 3.14
    assert(Math.PI == 3.14)
    Math.PI = 3
    assert(Math.PI == 3)
  ]])
end)

it("enums", function()
  assert.generate_c(
    "local e: enum{A=0}",
    [[enum {]])
  assert.run_c([[
    local Enum = @enum{A=0,B=1,C}
    local e: Enum; assert(e == 0)
    e = Enum.B; assert(e == 1)
    e = Enum.C; assert(e == 2)
    assert(Enum.B | Enum.C == 3)
  ]])
end)

it("pointers", function()
  assert.generate_c("local p: pointer(float32)", "float*")
  assert.generate_c("do local p: pointer end", "void* p")
  assert.generate_c("local p: pointer(record{x:integer}); p.x = 0", "->x = ")
  assert.run_c([[
    local function f(a: pointer): pointer return a end
    local i: integer = 1
    local p: pointer(integer) = &i
    print($p)
    p = (@pointer(int64))(f(p))
    i = 2
    print($p)
    $p = 3
    print(i)
  ]], "1\n2\n3")
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
    local p: integer*, q: integer*
    local a: integer = 1
    p = a
    q = &a
    assert(p == q)
    assert($p == 1)
    local function f(p: integer*) return $p end
    assert(f(a) == 1)
    local function g(): integer* return a end
    assert($g() == 1)
  ]])
end)

it("automatic dereference", function()
  assert.run_c([[
    local a: integer = 1
    local p: integer* = &a
    local b: integer
    b = p
    assert(b == 1)
    local function f(x: integer) return x end
    local function g(): integer return p end
    a = 2
    assert(f(p) == 2)
    assert(g() == 2)
  ]])
end)

it("nilptr", function()
  assert.generate_c("do local p: pointer = nilptr end", "void* p = NULL")
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

it("attributes", function()
  assert.generate_c("## cinclude '<myheader.h>'", "#include <myheader.h>")
  assert.generate_c("## cemit '#define SOMETHING'", "#define SOMETHING")
  assert.generate_c("## cemit('#define SOMETHING', 'declaration')", "#define SOMETHING")
  assert.generate_c("## cemit('#define SOMETHING', 'definition')", "#define SOMETHING")
  assert.generate_c("## cdefine 'SOMETHING'", "#define SOMETHING")
  assert.generate_c("local huge: number <cimport'HUGE_VAL',cinclude'<math.h>',nodecl>", "include <math.h>")
  assert.generate_c("local a: int64 <volatile, codename 'a'>", "volatile int64_t mymod_a")
  assert.generate_c("local a: int64 <register>", "register int64_t mymod_a")
  assert.generate_c("local a: int64 <restrict>", "restrict int64_t mymod_a")
  assert.generate_c("local a: int64 <nodecl>", "")
  assert.generate_c("local a: int64 <noinit>", "mymod_a;")
  assert.generate_c("local a: int64 <cexport>", "extern int64_t mymod_a;")
  assert.generate_c("do local a <static> = 1 end", "static int64_t a = 1;", true)
  assert.generate_c("local a: int64 <cattribute 'vector_size(16)'>", "int64_t mymod_a __attribute__((vector_size(16)))")
  assert.generate_c("local a: number <cqualifier 'in'> = 1", "in double mymod_a = 1.0;")
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
  assert.run_c([[
    local function exit(x: int32) <cimport'exit',cinclude'<stdlib.h>',nodecl> end
    function puts(s: cstring): int32 <cimport'puts',cinclude'<stdio.h>',nodecl> end
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
    "typedef struct myrecord {\n  int64_t x;\n} myrecord;",
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

it("print builtin", function()
  assert.run({'-g', 'c', '-e', "print(1,0.2,1e2,0xf,0b01)"},
    '1\t0.200000\t100.000000\t15\t1')
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
    'nelua_assert_string(true, ')
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
    assert(type(nil) == 'nil')
  ]])
end)

it("context states", function()
  assert.generate_c([[
    ## noinit = true
    local a: integer
    ## noinit = false
    local b: integer
  ]], {
    "\nstatic int64_t mymod_a;\n",
    "\nstatic int64_t mymod_b = 0;\n"
  })

  assert.generate_c([[
    ## nostatic = true
    local a: integer
    ## nostatic = false
    local b: integer
  ]], {
    "\nint64_t mymod_a = 0;\n",
    "\nstatic int64_t mymod_b = 0;\n"
  })

  assert.generate_c([[
    ## nofloatsuffix = true
    local a: float32 = 0
  ]], {
    "a = 0.0;",
  })

  assert.generate_c([[
    ## nostatic = true
    local a: integer
    ## nostatic = false
    local b: integer
  ]], {
    "\nint64_t mymod_a = 0;\n",
    "\nstatic int64_t mymod_b = 0;\n"
  })

  assert.generate_c([[
    ## modname = 'mylib'
    local function foo() <cexport>
    end
  ]], "extern void mylib_foo();")
end)

it("require builtin", function()
  assert.generate_c([[
    require 'examples.helloworld'
  ]], "hello world")

  assert.run_c([[
    require 'examples.helloworld'
  ]], "hello world")

  assert.run_error_c([[
    local a = 'mylib'
    require(a)
  ]], "runtime require is not supported in C")

  assert.run_error_c([[
    require 'invalid_file'
  ]], "compile time module 'invalid_file' not found")
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

end)
