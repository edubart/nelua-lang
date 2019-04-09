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
  assert.generate_c("return 1_integer", "return ((int64_t)1")
  assert.generate_c("return 1_number", "return ((double)1")
  assert.generate_c("return 1_byte", "return ((uint8_t)1")
  assert.generate_c("return 1_char", "return ((char)1")
  assert.generate_c("return 1_int", "return ((intptr_t)1")
  assert.generate_c("return 1_uint", "return ((uintptr_t)1")
  assert.generate_c("return 1_pointer", "return ((void*)1")
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
  assert.generate_c("if a then\nend","if(a) {\n    }")
  assert.generate_c("if a then\nelseif b then\nend", "if(a) {\n    } else if(b) {\n    }")
  assert.generate_c("if a then\nelse\nend", "if(a) {\n    } else {\n    }")
  assert.generate_c("if a and b then\nend","if(a && b) {\n    }")
  assert.generate_c("if a and b or c then\nend","if((a && b) || c) {\n    }")
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
  assert.generate_c("do\n  return\nend", "{\n        return;\n    }")
end)
it("while", function()
  assert.generate_c("while a do\nend", "while(a) {\n    }")
end)
it("repeat", function()
  assert.generate_c("repeat\nuntil a", "do {\n    } while(!(a));")
end)
it("for", function()
  assert.generate_c("for i=a,b do\nend", "for(euluna_any_t i = a; i <= b; i += 1) {\n    }")
  assert.generate_c("for i=a,b,c do\nend", "for(euluna_any_t i = a; i <= b; i += c) {\n    }")
end)
it("break and continue", function()
  assert.generate_c("break")
  assert.generate_c("continue")
end)
it("goto", function()
  assert.generate_c("::mylabel::\ngoto mylabel", "mylabel:\n    goto mylabel;")
end)
it("variable declaration", function()
  assert.generate_c("local a: integer", "int64_t a = {0};")
  assert.generate_c("local a: integer = 0", "int64_t a = 0;")
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
    "int64_t f() {\n    return 0;\n")
  assert.generate_c(
    "local function f(a: integer): integer\n return a end",
    "int64_t f(int64_t a) {\n    return a;\n}")
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
  assert.generate_c("return 3.0 // 2.0",  "return ((int64_t)(3.0 / 2.0));")
  assert.generate_c("return 2 ^ 2",       "return pow(2, 2);")
  assert.generate_c("return 2_f32 ^ 2_f32",
                    "return powf(((float)2), ((float)2));")
end)
it("binary conditional operators", function()
  assert.generate_c("return a or b",  "return a ? a : b;")
  assert.generate_c("return a and b",  "return (a && b) ? b : 0;")
  assert.generate_c("return not (a or b)",  "return !(a || b)")
  assert.generate_c("return not (a and b)",  "return !(a && b)")
end)

it("c types", function()
  assert.generate_c("local a: integer", "int64_t a = {0};")
  assert.generate_c("local a: number", "double a = {0};")
  assert.generate_c("local a: byte", "uint8_t a = {0};")
  assert.generate_c("local a: char", "char a = {0};")
  assert.generate_c("local a: float64", "double a = {0};")
  assert.generate_c("local a: float32", "float a = {0};")
  assert.generate_c("local a: pointer", "void* a = {0};")
  assert.generate_c("local a: int64", "int64_t a = {0};")
  assert.generate_c("local a: int32", "int32_t a = {0};")
  assert.generate_c("local a: int16", "int16_t a = {0};")
  assert.generate_c("local a: int8", "int8_t a = {0};")
  assert.generate_c("local a: int", "intptr_t a = {0};")
  assert.generate_c("local a: uint64", "uint64_t a = {0};")
  assert.generate_c("local a: uint32", "uint32_t a = {0};")
  assert.generate_c("local a: uint16", "uint16_t a = {0};")
  assert.generate_c("local a: uint8", "uint8_t a = {0};")
  assert.generate_c("local a: uint", "uintptr_t a = {0};")
  assert.generate_c("local a: boolean", "bool a = {0};")
  assert.generate_c("local a: bool", "bool a = {0};")
end)

it("any type", function()
  assert.generate_c(
    "local a: any",
    "euluna_any_t a = (euluna_any_t){&euluna_type_nil, {0}};")
  assert.generate_c(
    "local a: any; local b: any = a",
    "euluna_any_t b = a;")
  assert.generate_c(
    "local a: any = 1",
    "euluna_any_t a = (euluna_any_t){&euluna_type_int64, {1}};")
  assert.generate_c(
    "local a: any = 1; local b: integer = a",
    "int64_t b = euluna_cast_any_int64(a);")
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
    local b: bool = a
    print(b)
  ]], "type check fail")
end)

it("array tables", function()
  assert.generate_c(
    "local t: table<bool>",
    "euluna_arrtab_boolean_t t = {0};")
  assert.generate_c(
    "local t: table<bool>; local a = #t",
    "int64_t a = euluna_arrtab_boolean_length(&t);")
  assert.run_c([[
    local t: table<bool>
    print(t[0], #t)
    t[1] = true
    print(t[1], #t)
  ]], "false\t0\ntrue\t1")
end)

it("print", function()
  assert.run({'-g', 'c', '-e', "print(1,0.2,1e2,0xf,0b01)"},
    '1\t0.200000\t100\t15\t1')
end)

end)
