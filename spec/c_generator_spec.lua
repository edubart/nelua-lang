require 'busted.runner'()

local assert = require 'spec.assert'
local euluna_parser = require 'euluna.parsers.euluna_std_default'.parser
local c_generator = require 'euluna.generators.c_generator'
local assertf = require 'euluna.utils'.assertf

local function assert_generate_c(euluna_code, c_code)
  local ast = assert.parse_ast(euluna_parser, euluna_code)
  local generated_code = assert(c_generator:generate(ast))
  if not c_code then c_code = euluna_code end
  assertf(generated_code:find(c_code or '', 1, true),
    "Expected C code to contains.\nPassed in:\n%s\nExpected:\n%s",
    generated_code, c_code)
end

describe("Euluna should parse and generate C", function()

it("empty file", function()
  assert_generate_c("", [[
int main() {
    return 0;
}]])
end)
it("return", function()
  assert_generate_c("return", [[
int main() {
    return 0;
}]])
  assert_generate_c("return 1", [[
int main() {
    return 1;
}]])
  assert_generate_c("return (1)")
end)
it("boolean", function()
  assert_generate_c("return true", "return true;")
end)
it("call", function()
  assert_generate_c("f()", "f();")
  assert_generate_c("return f()", "return f();")
  assert_generate_c("f(g())")
  assert_generate_c("f(a, 1)")
  assert_generate_c("f(a)(b)")
end)
it("if", function()
  assert_generate_c("if a then\nend","if(a) {\n    }")
  assert_generate_c("if a then\nelseif b then\nend", "if(a) {\n    } else if(b) {\n    }")
  assert_generate_c("if a then\nelse\nend", "if(a) {\n    } else {\n    }")
end)
it("do", function()
  assert_generate_c("do\n  return\nend", "{\n        return;\n    }")
end)
it("while", function()
  assert_generate_c("while a do\nend", "while(a) {\n    }")
end)
it("repeat", function()
  assert_generate_c("repeat\nuntil a", "do {\n    } while(!(a));")
end)
it("for", function()
  assert_generate_c("for i=1,10 do\nend", "for(i = 1; i <= 10; ++i) {\n    }")
  assert_generate_c("for i=1,10,2 do\nend", "for(i = 1; i <= 10; i += 2) {\n    }")
end)
it("break and continue", function()
  assert_generate_c("break")
  assert_generate_c("continue")
end)
it("goto", function()
  assert_generate_c("::mylabel::\ngoto mylabel", "mylabel:\n    goto mylabel;")
end)
it("variable declaration", function()
  assert_generate_c("local a: integer", "int64_t a;")
  assert_generate_c("local a: integer = 0", "int64_t a = 0;")
end)
it("function definition", function()
  assert_generate_c("local function f()\n end",
    "void f() {\n}")
  assert_generate_c(
    "local function f(): integer\n return 0 end",
    "int64_t f() {\n    return 0;\n")
  assert_generate_c(
    "local function f(a: integer): integer\n return a end",
    "int64_t f(int64_t a) {\n    return a;\n}")
end)

end)