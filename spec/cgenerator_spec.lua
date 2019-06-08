require 'busted.runner'()

local assert = require 'spec.assert'

describe("Euluna should parse and generate C", function()

it("empty file", function()
  assert.generate_c("", [[
int euluna_main() {
  return 0;
}]])
end)

it("return", function()
  assert.generate_c("return", [[
int euluna_main() {
  return 0;
}]])
  assert.generate_c("return 1", [[
int euluna_main() {
  return 1;
}]])
  assert.generate_c("return (1)")
end)

it("number", function()
  assert.generate_c("do local a = 99 end", "99")
  assert.generate_c("do local a = 1.2 end", "1.2")
  assert.generate_c("do local a = 1e2 end", "100")
  assert.generate_c("do local a = 0x1f end", "0x1f")
  assert.generate_c("do local a = 0b10 end", "0x2")
  assert.generate_c("do local a = 1e127 end", "1e127;")
end)

it("number literals", function()
  assert.generate_c("do local a = 1_integer end", "int64_t a = 1")
  assert.generate_c("do local a = 1_number end", "double a = 1.0")
  assert.generate_c("do local a = 1_byte end", "uint8_t a = 1")
  assert.generate_c("do local a = 1_isize end", "intptr_t a = 1")
  assert.generate_c("do local a = 1_usize end", "uintptr_t a = 1")
  assert.generate_c("do local a = 1_pointer end", "void* a = 1")
  assert.generate_c("do local a = 1_cint end", "int a = 1")
  assert.generate_c("do local a = 1_clong end", "long a = 1")
  assert.generate_c("do local a = 1_clonglong end", "long long a = 1")
end)

it("type assertion", function()
  assert.generate_c("do local a = @int16(1_u64) end", "int16_t a = (int16_t)((uint64_t)1U)")
  assert.generate_c("do local a = @int64(1_u8) end", "int64_t a = (int64_t)((uint8_t)1U)")
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
  assert.generate_c("a:f(a)", "mymod_a.f(mymod_a, mymod_a)")
  assert.generate_c("do f() end", "f();")
  assert.generate_c("do return f() end", "return euluna_cint_any_cast(f());")
  assert.generate_c("do f(g()) end", "f(g())")
  assert.generate_c("do f(a, b) end", "f(a, b)")
  assert.generate_c("do f(a)(b) end", "f(a)(b)")
  assert.generate_c("do a.f() end", "a.f()")
  assert.generate_c("do a:f() end", "a.f(a)")
end)

it("if", function()
  assert.generate_c("if nilptr then\nend","if(false) {\n")
  assert.generate_c("if nil then\nend","if(false) {\n")
  assert.generate_c("if 1 then\nend","if(true) {\n")
  assert.generate_c("if a then\nend","if(euluna_any_to_boolean(mymod_a)) {\n")
  assert.generate_c("if true then\nend","if(true) {\n  }")
  assert.generate_c("if true then\nelseif true then\nend", "if(true) {\n  } else if(true) {\n  }")
  assert.generate_c("if true then\nelse\nend", "if(true) {\n  } else {\n  }")
  assert.generate_c("if true and true then\nend","if(true && true) {\n  }")
  assert.generate_c("if true and true or true then\nend","if((true && true) || true) {\n  }")
end)

it("switch", function()
  assert.generate_c("do switch a case b then f() case c then g() else h() end end",[[
    switch(a) {
      case b: {
        f();
        break;
      }
      case c: {
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
    if(true) break;
  }]])
  assert.generate_c([[
    repeat
      local a = true
    until a
  ]], [[
  while(true) {
    bool a = true;
    if(a) break;
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
    "for(euluna_any i = a, __end = b; i <= __end; i = i + 1) {"})
  assert.generate_c("for i=a,b do i=c end", {
    "for(euluna_any __it = a, __end = b; __it <= __end; __it = __it + 1) {",
    "euluna_any i = __it;"})
  assert.generate_c("for i=a,b,c do end",
    "for(euluna_any i = a, __end = b, __step = c; " ..
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

it("const", function()
  assert.generate_c("local const a: integer = 0", "static const int64_t mymod_a = 0;")
  assert.generate_c("local const a = 1", "static const int64_t mymod_a = 1;")
  assert.generate_c(
    "local const N = 3773; local a: array<integer, N>",
    {"static const int64_t mymod_N = 3773",
     "int64_t data[3773];"})
  assert.generate_c("local const a, b = 1, 2; local const c = a * b",
    "static const int64_t mymod_c = mymod_a * mymod_b;")
  assert.generate_c("local const a, b = 1, 2; local const c = @int32(a * b)",
    "static const int32_t mymod_c = (int32_t)(mymod_a * mymod_b);")
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

it("function return", function()
  assert.generate_c([[
    local function f(): integer return 0 end
  ]], "int64_t mymod_f() {\n  return 0;")
  assert.generate_c([[
    local function f(): any return end
  ]], "euluna_any mymod_f() {\n  return (euluna_any){0};")
  assert.generate_c([[
    local function f() return end
  ]], "return;")
end)

it("function multiple returns", function()
  assert.generate_c([[
    local function f(): integer, boolean return 1, true end
  ]], {
    "function_%w+_ret mymod_f",
    "return %(function_%w+_ret%){1, true};"
  }, true)
  assert.generate_c([[do
    local function f(): integer, boolean return 1, true end
    local a, b = f()
    local c = f()
  end]], {
    "int64_t a = __ret%d+%.r1;",
    "bool b = __ret%d+%.r2;",
    "int64_t c = f%(%)%.r1;"
  }, true)
  assert.run_c([[
    local function f(): integer, boolean return 1, true end
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

    local function t(): boolean, integer return false, 1 end
    local function u(): boolean, number return t() end
    local a, b, c = 2, u()
    assert(a == 2 and b == false and c == 1)
  ]])
end)

it("call with multiple args", function()
  assert.generate_c([[do
    local function f(): integer, boolean return 1, true end
    local function g(a: int32, b: integer, c: boolean) end
    g(1, f())
  end]], {
    "function_%w+_ret __tmp%d+ = f%(%)",
    "g%(1, __tmp%d+.r1, __tmp%d+.r2%);"
  }, true)
  assert.run_c([[do
    local function f(): integer, integer return 1, 2 end
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

it("unary operators", function()
  assert.generate_c("do local x = not a end", "!a")
  assert.generate_c("do local x = -a end", "-a")
  assert.generate_c("do local x = ~a end", "~a")
  assert.generate_c("do local x = &a end", "&a")
  assert.generate_c("do local x = $a end", "*a")
end)

it("binary operators", function()
  assert.generate_c("do local x = a ~= b end",      "a != b")
  assert.generate_c("do local x = a == b end",      "a == b")
  assert.generate_c("do local x = a <= b end",      "a <= b")
  assert.generate_c("do local x = a >= b end",      "a >= b")
  assert.generate_c("do local x = a < b end",       "a < b")
  assert.generate_c("do local x = a > b end",       "a > b")
  assert.generate_c("do local x = a | b end",       "a | b")
  assert.generate_c("do local x = a ~ b end",       "a ^ b")
  assert.generate_c("do local x = a & b end",       "a & b")
  assert.generate_c("do local x = a << b end",      "a << b")
  assert.generate_c("do local x = a >> b end",      "a >> b")
  assert.generate_c("do local x = a + b end",       "a + b")
  assert.generate_c("do local x = a - b end",       "a - b")
  assert.generate_c("do local x = a * b end",       "a * b")
  -- div
  --assert.generate_c("return a / b")
  assert.generate_c("return 3 / 2",       "return 3 / (double)2")
  assert.generate_c(
    "return @float64(3 / 2)",
    "return 3.0 / 2.0")
  assert.generate_c(
    "return 3 / 2_int64",
    "return 3 / (double)(int64_t)2")
  assert.generate_c(
    "return 3.0 / 2",
    "return 3.0 / 2")
  assert.generate_c(
    "return @integer(3_i / 2_i)",
    "return (int64_t)((int64_t)3 / (double)(int64_t)2)")
  assert.generate_c(
    "return @integer(3 / 2_int64)",
    "return (int64_t)(3 / (double)(int64_t)2)")
  -- idiv
  --assert.generate_c("return a // b")
  assert.generate_c("return 3 // 2",      "return 3 / 2")
  assert.generate_c("return 3 // 2.0",    "return floor(3.0 / 2.0)")
  assert.generate_c("return 3.0 // 2.0",  "return floor(3.0 / 2.0)")
  assert.generate_c("return 3.0 // 2",    "return floor(3.0 / 2)")
  -- mod
  --assert.generate_c("return a % b",       "return a % b;")
  assert.generate_c("return 3 % 2",       "return 3 % 2")
  assert.generate_c("return 3.0 % 2",     "return fmod(3.0, 2)")
  assert.generate_c("return 3 % 2.0",     "return fmod(3.0, 2.0)")
  assert.generate_c("return 3.0 % 2.0",   "return fmod(3.0, 2.0)")
  -- pow
  --assert.generate_c("return a ^ b")
  assert.generate_c("return 2 ^ 2",       "return pow(2, 2);")
  assert.generate_c("return 2_f32 ^ 2_f32",
                    "return powf(2.0f, 2.0f);")
  assert.run_c([[
    assert(1 / 2 == 0.5)
    assert(1.0 / 2.0 == 0.5)
    assert(3 % 2 == 1)
    assert(3.0 % 2.0 == 1)
    assert(3 // 2 == 1)
    assert(3.0 // 2.0 == 1)
    assert(2 ^ 2 == 4)
  ]])
end)

it("binary conditional operators", function()
  assert.generate_c("do return a or b end",  [[({
      euluna_any t1_ = a; EULUNA_UNUSED(t1_);
      euluna_any t2_ = {0}; EULUNA_UNUSED(t2_);
      bool cond_ = euluna_any_to_boolean(t1_);
      if(cond_)
        t2_ = b;
      cond_ ? t1_ : t2_;
    })]])
  assert.generate_c("do return a and b end",  [[({
      euluna_any t1_ = a; EULUNA_UNUSED(t1_);
      euluna_any t2_ = {0}; EULUNA_UNUSED(t2_);
      bool cond_ = euluna_any_to_boolean(t1_);
      if(cond_) {
        t2_ = b;
        cond_ = euluna_any_to_boolean(t2_);
      }
      cond_ ? t2_ : (euluna_any){0};
    })]])
  --[[
  assert.generate_c("do return a and b end",  "return (a && b) ? b : (euluna_any){0};")
  assert.generate_c("do return a and b or c end",  "return (a && b) ? a : b;")
  assert.generate_c("do return not (a or b) end",  "return !(a || b)")
  assert.generate_c("do return not (a and b) end",  "return !(a && b)")
  ]]
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

    local t1, t2 = false, false
    if (2 or 1) == 2 then t1 = true end
    if (2 and 0) == 0 then t2 = true end
    assert(t1)
    assert(t2)
  ]])
end)

it("expressions with side effects", function()
  assert.generate_c([[do
    local function f() return 1 end
    local a = f() + 1
  end]],  "int64_t a = f() + 1")
  assert.generate_c([[do
    local function f() return 1 end
    local function g() return 1 end
    local a = f() + g()
  end]],  [[int64_t a = ({
      int64_t t1_ = f();
      int64_t t2_ = g();
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
    local function struct(static: integer)
      local default: integer
      default = 1
      return default + static
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
  ]])
end)

it("any type", function()
  assert.generate_c(
    "do local a: any end",
    "euluna_any a = {0};")
  assert.generate_c(
    "do local a: any; local b: any = a end",
    "euluna_any b = a;")
  assert.generate_c(
    "do local a: any = 1 end",
    "euluna_any a = (euluna_any){&euluna_int64_type, {1}};")
  assert.generate_c(
    "do local a: any = 1; local b: integer = a end",
    "int64_t b = euluna_int64_any_cast(a);")
  assert.run_c([[
    local a: any = 1
    local b: integer = a
    print(a, b)
  ]], "1\t1")
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

it("array tables", function()
  assert.generate_c(
    "do local t: arraytable<boolean> end",
    "euluna_boolean_arrtab t = {0};")
  assert.generate_c(
    "do local t: arraytable<boolean>; local a = #t end",
    "int64_t a = euluna_boolean_arrtab_length(&t);")
  assert.run_c([[
    local t: arraytable<boolean>
    print(t[0], #t)
    t[1] = true
    print(t[1], #t)
  ]], "false\t0\ntrue\t1")
  assert.run_c([[
    local t: arraytable<integer> = {}
    print(t[0],#t)
  ]], "0\t0")
  assert.run_c([[
    local t: arraytable<integer> = {1, 2}
    print(t[0], t[1], t[2], #t)
  ]], "0\t1\t2\t2")
end)

it("arrays", function()
  assert.generate_c(
    "local a: array<boolean, 10>",
    "bool data[10];")
  assert.run_c([[
    local a: array<boolean, 1>
    assert(a[0] == false)
    assert(#a == 1)
    a[0] = true
    assert(a[0] == true)
    a = {}
    assert(a[0] == false)
  ]])
  assert.run_c([[
    local a: array<integer, 4> = {1,2,3,4}
    local b: array<integer, 4> = a
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
    assert(#p == 16)
  ]])
  assert.run_c([[
    local Point = @record {x: integer, y: integer}
    local p: Point
    p.x = 1
    assert(p.x == 1 and p.y == 0)
    p = Point{}
    assert(p.x == 0 and p.y == 0)
    assert(Point({1,2}).x == 1)
    assert(Point({1,2}).y == 2)
    assert(Point({x=1,2}).y == 2)
    assert(Point({1,y=2}).x == 1)
  ]])
  assert.run_c([[
    local Point = @record {x: integer, y: integer}
    local p = Point{x=1, y=2}
    print(p.x, p.y)
  ]], "1\t2")
  assert.run_c([[
    local Point = @record {x: integer, y: integer}
    local p: Point = {x=1, y=2}
    print(p.x, p.y)
  ]], "1\t2")
  assert.run_c([[
    local r: record {x: array<integer, 1>} =  {x={1}}
    assert(r.x[0] == 1)
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
  ]])
end)

it("pointers", function()
  assert.generate_c("local p: pointer<float32>", "float*")
  assert.generate_c("do local p: pointer end", "void* p")
  assert.generate_c("local p: pointer<record{x:integer}>; p.x = 0", "->x = ")
  assert.run_c([[
    local function f(a: pointer): pointer return a end
    local i: integer = 1
    local p: pointer<integer> = &i
    print($p)
    p = @pointer<int64>(f(p))
    i = 2
    print($p)
    $p = 3
    print(i)
  ]], "1\n2\n3")
end)

it("automatic reference", function()
  assert.run_c([[
    local p: integer*
    local a: integer = 1
    p = a
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
  assert.run_c([[
    local function malloc(size: usize): pointer !cimport('malloc','<stdlib.h>') end
    local function memset(s: pointer, c: int32, n: usize): pointer !cimport('memset','<stdlib.h>') end
    local function free(ptr: pointer) !cimport('free','<stdlib.h>') end
    local a = @pointer<array<int64, 10>>(malloc(10 * 8))
    memset(a, 0, 10*8)
    assert(a[0] == 0)
    a[0] = 1
    assert(a[0] == 1)
    free(a)
  ]])
end)

it("pragmas", function()
  assert.generate_c("!!cinclude '<myheader.h>'", "#include <myheader.h>")
  assert.generate_c("!!cemit '#define SOMETHING'", "#define SOMETHING")
  assert.generate_c("!!cdefine 'SOMETHING'", "#define SOMETHING")
  assert.generate_c("local huge: number !cimport('HUGE_VAL', '<math.h>')", "include <math.h>")
  assert.generate_c("local a: int64 !volatile !codename'a'", "volatile int64_t mymod_a")
  assert.generate_c("local a: int64 !register", "register int64_t mymod_a")
  assert.generate_c("local a: int64 !restrict", "restrict int64_t mymod_a")
  assert.generate_c("local a: int64 !nodecl", "")
  assert.generate_c("local R !aligned(16) = @record{x: integer}; local r: R", "} __attribute__((aligned(16))) ")
  assert.generate_c("local function f() !inline end", "inline void")
  assert.generate_c("local function f() !noreturn end", "EULUNA_NORETURN void")
  assert.generate_c("local function f() !noinline end", "EULUNA_NOINLINE void")
  assert.generate_c("local function f() !volatile end", "volatile void")
  assert.generate_c("local function f() !nodecl end", "")
  assert.generate_c(
    "local function puts(s: cstring): int32 !cimport('puts', true) end",
    "int32_t puts(char* s);")
  assert.generate_c(
    "local function cos(x: number): number !cimport('myfunc','<myheader.h>') end",
    "#include <myheader.h>")
  assert.run_c([[
    local function exit(x: int32) !cimport('exit', '<stdlib.h>') end
    local function puts(s: cstring): int32 !cimport('puts', '<stdio.h>') end
    local function perror(s: cstring): void !cimport end
    local function f() !noinline !noreturn
      local i: int32 !register !volatile !codename'i' = 0
      exit(i)
    end
    puts('msg stdout\n')
    perror('msg stderr\n')
    f()
  ]], "msg stdout", "msg stderr")
end)

it("print", function()
  assert.run({'-g', 'c', '-e', "print(1,0.2,1e2,0xf,0b01)"},
    '1\t0.200000\t100\t15\t1')
end)

it("assert", function()
  assert.generate_c(
    "assert(true)",
    "euluna_assert(true)")
  assert.generate_c(
    "assert(true, 'assertion')",
    'euluna_assert_message(true, ')
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

end)
