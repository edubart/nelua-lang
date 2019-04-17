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
  assert.generate_c("return 1")
  assert.generate_c("return 1.2")
  assert.generate_c("return 1e2")
  assert.generate_c("return 0x1f")
  assert.generate_c("return 0b10", "return 0x2")
end)
it("number literals", function()
  assert.generate_c("return 1_integer", "return ((euluna_int64)1")
  assert.generate_c("return 1_number", "return ((euluna_float64)1")
  assert.generate_c("return 1_byte", "return ((euluna_uint8)1")
  assert.generate_c("return 1_char", "return ((euluna_char)1")
  assert.generate_c("return 1_int", "return ((euluna_int)1")
  assert.generate_c("return 1_uint", "return ((euluna_uint)1")
  assert.generate_c("return 1_pointer", "return ((euluna_pointer)1")
end)
it("string", function()
  assert.generate_c([[local a = "hello"]], [["hello"]])
  assert.generate_c([[local a = "\x01"]], [["\x01"]])
end)
it("boolean", function()
  assert.generate_c("return true", "return true;")
end)
it("call", function()
  assert.generate_c("f()", "f();")
  assert.generate_c("return f()", "return f();")
  assert.generate_c("f(g())")
  assert.generate_c("f(a, b)")
  assert.generate_c("f(a)(b)")
  assert.generate_c("a.f()")
  assert.generate_c("a:f()", "a.f(a)")
end)
it("if", function()
  assert.generate_c("if a then\nend","if(a) {\n  }")
  assert.generate_c("if a then\nelseif b then\nend", "if(a) {\n  } else if(b) {\n  }")
  assert.generate_c("if a then\nelse\nend", "if(a) {\n  } else {\n  }")
  assert.generate_c("if a and b then\nend","if(a && b) {\n  }")
  assert.generate_c("if a and b or c then\nend","if((a && b) || c) {\n  }")
end)
it("switch", function()
  assert.generate_c("switch a case b then f() case c then g() else h() end",[[
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
  assert.generate_c("do\n  return\nend", "{\n    return;\n  }")
end)
it("while", function()
  assert.generate_c("while a do\nend", "while(a) {\n  }")
end)
it("repeat", function()
  assert.generate_c("repeat\nuntil a", "do {\n  } while(!(a));")
end)
it("for", function()
  assert.generate_c("for i=a,b do\nend", "for(euluna_any i = a; i <= b; i += 1) {\n  }")
  assert.generate_c("for i=a,b,c do\nend", "for(euluna_any i = a; i <= b; i += c) {\n  }")
end)
it("break and continue", function()
  assert.generate_c("break")
  assert.generate_c("continue")
end)
it("goto", function()
  assert.generate_c("::mylabel::\ngoto mylabel", "mylabel:\n  goto mylabel;")
end)
it("variable declaration", function()
  assert.generate_c("local a: integer", "euluna_int64 a = {0};")
  assert.generate_c("local a: integer = 0", "euluna_int64 a = 0;")
end)
it("assignment", function()
  assert.generate_c("a = b")
  assert.generate_c("a, b = x, y", "a = x; b = y;")
  assert.generate_c("a.b, a[b] = x, y", "a.b = x; a[b] = y;")
end)
it("function definition", function()
  assert.generate_c("local function f()\n end",
    "void f() {\n}")
  assert.generate_c(
    "local function f(): integer\n return 0 end",
    "euluna_int64 f() {\n  return 0;\n")
  assert.generate_c(
    "local function f(a: integer): integer\n return a end",
    "euluna_int64 f(euluna_int64 a) {\n  return a;\n}")
end)
it("unary operators", function()
  assert.generate_c("return not a", "return !a;")
  assert.generate_c("return -a")
  assert.generate_c("return ~a")
  assert.generate_c("return &a")
  assert.generate_c("return *a")
end)
it("binary operators", function()
  assert.generate_c("return a ~= b",      "return a != b;")
  assert.generate_c("return a == b",      "return a == b;")
  assert.generate_c("return a <= b",      "return a <= b;")
  assert.generate_c("return a >= b",      "return a >= b;")
  assert.generate_c("return a < b",       "return a < b;")
  assert.generate_c("return a > b",       "return a > b;")
  assert.generate_c("return a | b",       "return a | b;")
  assert.generate_c("return a ~ b",       "return a ^ b;")
  assert.generate_c("return a & b",       "return a & b;")
  assert.generate_c("return a << b",      "return a << b;")
  assert.generate_c("return a >> b",      "return a >> b;")
  assert.generate_c("return a + b",       "return a + b;")
  assert.generate_c("return a - b",       "return a - b;")
  assert.generate_c("return a * b",       "return a * b;")
  assert.generate_c("return a / b",       "return a / b;")
  assert.generate_c("return a % b",       "return a % b;")
  assert.generate_c("return 3 // 2",      "return 3 / 2")
  assert.generate_c("return 3.0 // 2.0",  "return ((euluna_int64)(3.0 / 2.0));")
  assert.generate_c("return 2 ^ 2",       "return pow(2, 2);")
  assert.generate_c("return 2_f32 ^ 2_f32",
                    "return powf(((euluna_float32)2), ((euluna_float32)2));")
end)
it("binary conditional operators", function()
  assert.generate_c("return a or b",  "return a ? a : b;")
  assert.generate_c("return a and b",  "return (a && b) ? b : 0;")
  assert.generate_c("return not (a or b)",  "return !(a || b)")
  assert.generate_c("return not (a and b)",  "return !(a && b)")
end)

it("c types", function()
  assert.generate_c("local a: integer", "euluna_int64 a = {0};")
  assert.generate_c("local a: number", "euluna_float64 a = {0};")
  assert.generate_c("local a: byte", "euluna_uint8 a = {0};")
  assert.generate_c("local a: char", "euluna_char a = {0};")
  assert.generate_c("local a: float64", "euluna_float64 a = {0};")
  assert.generate_c("local a: float32", "euluna_float32 a = {0};")
  assert.generate_c("local a: pointer", "euluna_pointer a = {0};")
  assert.generate_c("local a: int64", "euluna_int64 a = {0};")
  assert.generate_c("local a: int32", "euluna_int32 a = {0};")
  assert.generate_c("local a: int16", "euluna_int16 a = {0};")
  assert.generate_c("local a: int8", "euluna_int8 a = {0};")
  assert.generate_c("local a: int", "euluna_int a = {0};")
  assert.generate_c("local a: uint64", "euluna_uint64 a = {0};")
  assert.generate_c("local a: uint32", "euluna_uint32 a = {0};")
  assert.generate_c("local a: uint16", "euluna_uint16 a = {0};")
  assert.generate_c("local a: uint8", "euluna_uint8 a = {0};")
  assert.generate_c("local a: uint", "euluna_uint a = {0};")
  assert.generate_c("local a: boolean", "euluna_boolean a = {0};")
end)

it("any type", function()
  assert.generate_c(
    "local a: any",
    "euluna_any a = (euluna_any){&euluna_nil_type, {0}};")
  assert.generate_c(
    "local a: any; local b: any = a",
    "euluna_any b = a;")
  assert.generate_c(
    "local a: any = 1",
    "euluna_any a = (euluna_any){&euluna_int64_type, {1}};")
  assert.generate_c(
    "local a: any = 1; local b: integer = a",
    "euluna_int64 b = euluna_int64_any_cast(a);")
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
    local b: boolean = a
    print(b)
  ]], "type check fail")
end)

it("array tables", function()
  assert.generate_c(
    "local t: table<boolean>",
    "euluna_boolean_arrtab t = {0};")
  assert.generate_c(
    "local t: table<boolean>; local a = #t",
    "euluna_int64 a = euluna_boolean_arrtab_length(&t);")
  assert.run_c([[
    local t: table<boolean>
    print(t[0], #t)
    t[1] = true
    print(t[1], #t)
  ]], "false\t0\ntrue\t1")
end)

it("records", function()
  assert.generate_c(
    "local t: record{a: boolean}",
[[typedef struct {
  euluna_boolean a;
} record_]])
  assert.run_c([[
    local p: record{
      x: integer,
      y: integer
    }
    print(p.x, p.y)
    p.x, p.y = 1, 2
    print(p.x, p.y)
  ]], "0\t0\n1\t2")
  assert.run_c([[
    local Point = @record {x: integer, y: integer}
    local p: Point
    p.x = 1
    print(p.x, p.y)
  ]], "1\t0")
  assert.run_c([[
    local Point = @record {x: integer, y: integer}
    local p = Point{x=1, y=2}
    print(p.x, p.y)
  ]], "1\t2")
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
