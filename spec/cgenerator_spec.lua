local lester = require 'nelua.thirdparty.lester'
local describe, it = lester.describe, lester.it

local ccompiler = require 'nelua.ccompiler'
local config = require 'nelua.configer'.get()
local expect = require 'spec.tools.expect'

describe("C generator", function()

lester.before(function()
  -- must disable dead code elimination to do these tests
  config.pragmas.nodce = true
end)

lester.after(function()
  -- must disable dead code elimination to do these tests
  config.pragmas.nodce = nil
end)

it("empty file", function()
  expect.generate_c("", [[
int main(int argc, char** argv) {
  return 0;
}]])
end)

it("return", function()
  expect.generate_c("return", [[
int nelua_main(int nelua_argc, char** nelua_argv) {
  return 0;
}]])
  expect.generate_c("return 1", [[
int nelua_main(int nelua_argc, char** nelua_argv) {
  return 1;
}]])
  expect.generate_c("return 1")
  expect.generate_c("if false then return end", [[
int nelua_main(int nelua_argc, char** nelua_argv) {
  if(false) {
    return 0;
  }
  return 0;
}
]])
  expect.run_error_c([[
    return 1, 2
  ]], "multiple returns in main is not supported")
end)

it("local variable", function()
  expect.generate_c("local a = 1", "int64_t a = 1;")
end)

it("global variable", function()
  expect.generate_c("global a = 1", "static int64_t a = 1;\n")
end)

it("number", function()
  expect.generate_c("local a = 99", "99")
  expect.generate_c("local a = 1.5", "1.5")
  expect.generate_c("local a = 1e2", "100")
  expect.generate_c("local a = 2.5e-16", "2.5e-16")
  expect.generate_c("local a = 0x1f", "0x1f")
  expect.generate_c("local a = 0b10", "0x2")
  expect.generate_c("local a = 1e129", "1e+129;")
  expect.generate_c("local a = #[aster.Number{99}]#", "99;")
end)

it("number literals", function()
  expect.generate_c("local a = 1_integer", "int64_t a = 1;")
  expect.generate_c("local a = 1_uinteger", "uint64_t a = 1U;")
  expect.generate_c("local a = 1_number", "double a = 1.0;")
  expect.generate_c("local a = 1_byte", "uint8_t a = 1U;")
  expect.generate_c("local a = 1_isize", "intptr_t a = 1;")
  expect.generate_c("local a = 1_int8", "int8_t a = 1;")
  expect.generate_c("local a = 1_int16", "int16_t a = 1;")
  expect.generate_c("local a = 1_int32", "int32_t a = 1;")
  expect.generate_c("local a = 1_int64", "int64_t a = 1;")
  expect.generate_c("local a = 1_int128", "__int128 a = 1;")
  expect.generate_c("local a = 1_usize", "uintptr_t a = 1U;")
  expect.generate_c("local a = 1_uint8", "uint8_t a = 1U;")
  expect.generate_c("local a = 1_uint16", "uint16_t a = 1U;")
  expect.generate_c("local a = 1_uint32", "uint32_t a = 1U;")
  expect.generate_c("local a = 1_uint64", "uint64_t a = 1U;")
  expect.generate_c("local a = 1_uint128", "unsigned __int128 a = 1U;")
  expect.generate_c("local a = 1_float32", "float a = 1.0f;")
  expect.generate_c("local a = 1_float64", "double a = 1.0;")
  expect.generate_c("local a = 1_float128", "__float128 a = 1.0q;")

  expect.generate_c("local a = 1_cchar", "char a = 1;")
  expect.generate_c("local a = 1_cschar", "signed char a = 1;")
  expect.generate_c("local a = 1_cshort", "short a = 1;")
  expect.generate_c("local a = 1_cint", "int a = 1;")
  expect.generate_c("local a = 1_cshort", "short a = 1;")
  expect.generate_c("local a = 1_clong", "long a = 1;")
  expect.generate_c("local a = 1_clonglong", "long long a = 1;")
  expect.generate_c("local a = 1_cptrdiff", "ptrdiff_t a = 1;")
  expect.generate_c("local a = 1_cuchar", "unsigned char a = 1U;")
  expect.generate_c("local a = 1_cushort", "unsigned short a = 1U;")
  expect.generate_c("local a = 1_cuint", "unsigned int a = 1U;")
  expect.generate_c("local a = 1_cushort", "unsigned short a = 1U;")
  expect.generate_c("local a = 1_culong", "unsigned long a = 1U;")
  expect.generate_c("local a = 1_culonglong", "unsigned long long a = 1U;")
  expect.generate_c("local a = 1_csize", "size_t a = 1U;")
  expect.generate_c("local a = 1_clongdouble", "long double a = 1.0l;")

  expect.generate_c("local a = ' '_byte", "uint8_t a = 32U;")
  expect.generate_c("local a = ' '_int8", "int8_t a = 32;")
  expect.generate_c("local a = ' '_uint8", "uint8_t a = 32U;")
  expect.generate_c("local a = ' '_cchar", "char a = ' ';")
  expect.generate_c("local a = ' '_cschar", "signed char a = 32;")
  expect.generate_c("local a = ' '_cuchar", "unsigned char a = 32U;")
  expect.generate_c("local a = 'str'_cstring", 'char* a = "str"')
end)

it("type cast", function()
  expect.generate_c("do local b = 1_u64; local a = (@int16)(b) end", "int16_t a = (int16_t)b")
  expect.generate_c("do local b = 1_u8; local a = (@int64)(b) end", "int64_t a = (int64_t)b")
  expect.generate_c([[
    local a: usize
    local b: number
    local x = (@usize)((a + 1) / b)
  ]], "x = (uintptr_t)((a + 1) / b);")

  expect.generate_c([[
    local R = @record{x: integer}
    local a = (@[4]integer)()
    local i = (@integer)()
    local u = (@uinteger)()
    local b = (@boolean)()
    local p = (@pointer)()
    local n = (@number)()
    local f = (@float32)()
    local r = (@R)()
  ]],[[a = (nlint64_arr4){0};
  i = 0;
  u = 0U;
  b = false;
  p = NULL;
  n = 0.0;
  f = 0.0f;
  r = (R){0};]])

  expect.generate_c([[
    local recA = @record{a: integer}
    local recB = @record{b: integer}
    local x: recA
    local y = ((@*recB)(&x).b)
  ]], "y = ((recB_ptr)(&x))->b;")
end)

it("string", function()
  expect.generate_c([[local a = "hello"]], [["hello"]])
  expect.generate_c([[local a = "\001"]], [["\001"]])
  expect.generate_c([[local a = #[string.rep('\0', 256)]# ]], [[0x00,0x00,0x00]])
  expect.generate_c([==[
    local function f(s: cstring)
      print(s)
    end
    local STR: cstring <comptime> = "\z
      AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\z
      AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\z
    "
    f(STR)
    f(STR)
  ]==], [[static char nelua_strlit_1[161] = "AAAA]])

  expect.run_c([[
    local Foo = @record{text: *[4]cchar}
    local foo = Foo{text = 'asd'}
    assert(foo.text == 'asd')

    local texts: string = 'asd'
    local textcs: *[4]cchar = texts
    assert(textcs == 'asd')

    local text: *[4]cchar = 'asd'
    assert(text == 'asd')
    print(text)
  ]], [[asd]])
end)

it("boolean", function()
  expect.generate_c("local a = true", "bool a = true")
  expect.generate_c("local a = false", "bool a = false")

  expect.generate_c([[
    local function f() return nil end
    local b1: boolean = f()
    local b2: boolean = not f()
  ]], {
    "b1 = (f(), false);",
    "b2 = (!(f(), false));",
  })

end)

it("nil", function()
  expect.generate_c("local a: niltype", "nlniltype a;")
  expect.generate_c("local a: niltype = nil", "nlniltype a = NELUA_NIL;")
  expect.generate_c("local function f(a: niltype) end f(nil)", "f(NELUA_NIL);")
  expect.generate_c("local function f() <nosideeffect> return nil end assert(f() == f())",
    "(f(), f(), true)")
  expect.generate_c("local function f() <nosideeffect> return nil end assert(f() ~= f())",
    "(f(), f(), false)")
end)

it("call", function()
  expect.generate_c("local f: function(); f()", "f();")
  expect.generate_c("local f: function(integer), g: function(): integer; f(g())", "f(g())")
  expect.generate_c("local f: function(integer,integer), a:integer, b:integer; f(a, b)", "f(a, b)")
  expect.generate_c("local f: function(integer): function(integer), a:integer, b:integer; f(a)(b)", "f(a)(b)")
  expect.generate_c("local a: record{f: function()}; a.f()", "a.f()")
  expect.generate_c("local A=@record{f: function(*A)}; local a: A; a:f()", "(&a)->f((&a))")
  expect.generate_c("local f: function(); do f() end", "f();")
  expect.generate_c("local f: function(function()), g:function():function(); do f(g()) end", "f(g())")
  expect.generate_c("local f: function(integer,integer), a:integer, b:integer; do f(a, b) end", "f(a, b)")
  expect.generate_c("local f: function(integer): function(integer), a:integer, b:integer; do f(a)(b) end", "f(a)(b)")
  expect.generate_c("local a: record{f: function()}; do a.f() end", "a.f()")
  expect.generate_c("local A=@record{f: function(*A)}; do local a: A; a:f() end", "(&a)->f((&a))")
end)

it("callbacks", function()
  expect.generate_c("local f: function(x: integer): integer",
    "typedef int64_t %(%*function_%w+%)%(int64_t%);", true)
  expect.run_c([[
    local function call_callback(callback: function(integer, integer): integer): integer
      return callback(1, 2)
    end

    local function mycallback(x: integer, y: integer): integer
      assert(x == 1 and y == 2)
      return x + y
    end

    local mycallback_proxy = mycallback
    assert(mycallback(1, 2) == 3)
    assert(mycallback_proxy(1 ,2) == 3)
    assert(call_callback(mycallback) == 3)

    local callback_type = @function(x: integer, y: integer): integer
    local mycallback_proxy2: callback_type
    assert(not mycallback_proxy2)
    assert(mycallback_proxy2 == nilptr)
    mycallback_proxy2 = mycallback
    assert(mycallback_proxy2)
    assert(mycallback_proxy2 ~= nilptr)
    assert(mycallback_proxy2(1, 2) == 3)

    local function f(x: integer) return x + 1 end
    local r: record{f: function(x: integer):integer} = {f=f}
    assert(r.f(1) == 2)
]])
end)

it("if", function()
  expect.generate_c("if nilptr then\nend","if(false) {\n")
  expect.generate_c("if nil then\nend","if(false) {\n")
  expect.generate_c("if 1 then\nend","if((1, true)) {\n")
  expect.generate_c("local a: boolean; if a then\nend","if(a) {\n")
  expect.generate_c("if true then\nend","if(true) {\n  }")
  expect.generate_c("if true then\nelseif true then\nend", "if(true) {\n  } else if(true) {\n  }")
  expect.generate_c("if true then\nelse\nend", "if(true) {\n  } else {\n  }")
  expect.generate_c([[
  local a: boolean, b: boolean
  if a and b then end]],
  "if((a && b)) {\n")
  expect.generate_c([[
  local a: boolean, b: boolean, c: boolean
  if a and b or c then end]],
  "if(((a && b) || c)) {\n")
  expect.generate_c([[
  local a: boolean, b: boolean
  if a and not b then end]],
  "if((a && (!b))) {\n")
end)

it("switch", function()
  expect.generate_c([[local a: integer, f: function(), g: function(), h: function()
    switch a
      case 1 then
        f()
      case 2, 3, 4 then
        g()
    else
      h()
    end
  ]],[[
  switch(a) {
    case 1: {
      f();
      break;
    }
    case 2:
    case 3:
    case 4: {
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
  expect.generate_c("do\n  return\nend", "return 0;\n")
end)

it("defer", function()
  expect.generate_c("do local x: int64 = 1 defer x = 2 end x = 3 end", [[{
    int64_t x = 1;
    x = 3;
    { /* defer */
      x = 2;
    }
  }]])
  expect.run_c([[
    local function g(x: integer): integer
      print(x)
      return x
    end
    local function f(): integer
      defer g(4) end
      return g(5)
    end
    f()

    local function f(): (integer, integer)
      defer g(1) end
      return g(3), g(2)
    end
    f()

    defer g(-1) end
    return g(0)
  ]], '5\n4\n3\n2\n1\n0\n-1')
end)

it("close", function()
  expect.run_c([[
    local R = @record{x: integer}
    function R:__close() print(self.x) end
    do
      local a: R <close> = {1}
      local b: R <close> = {2}
    end
    do
      local a: R <close>, b: R <close> = {3}, {4}
    end
    print('end')
  ]], '2\n1\n4\n3\nend')
end)

it("while", function()
  expect.generate_c("while true do\nend", "while(true) {")
end)

it("repeat", function()
  expect.generate_c("repeat until true", [[
  while(1) {
    if(true) {
      break;
    }
  }]])
  expect.generate_c([[
    repeat
      local a = true
    until a
  ]], [[
  while(1) {
    bool a = true;
    if(a) {
      break;
    }
  }]])
  expect.run_c([[
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
  expect.generate_c("local a: integer, b: integer; for i=a,b do end", {
    "for(int64_t i = a, _end = b; i <= _end; i = i + 1) {"})
  expect.generate_c("local a: integer, b: integer, c: integer; for i=a,b do i=c end", {
    "for(int64_t _it = a, _end = b; _it <= _end; _it = _it + 1) {",
    "int64_t i = _it;"})
  expect.generate_c("local a: integer, b: integer, c: integer; for i=a,b,c do end",
    "for(int64_t i = a, _end = b, _step = c; " ..
    "_step >= 0 ? i <= _end : i >= _end; i = i + _step) {")
  expect.generate_c(
    "for i=1,<2 do end",
    "for(int64_t i = 1; i < 2; i = i + 1)")
  expect.generate_c(
    "for i=2,1,-1 do end",
    "for(int64_t i = 2; i >= 1; i = i + -1)")
  expect.generate_c([[
  local last <const> = -1
  for i=5,0,last do end
  ]], "for(int64_t i = 5, _end = 0, _step = last; _step >= 0 ? i <= _end : i >= _end; i = i + _step)")
  expect.run_c([[
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
  expect.generate_c("while true do break end", "break;")
  expect.generate_c("while true do continue end", "continue;")

  expect.run_c([[
    local a = 0
    for i=1,10 do
      switch i
      case 1 then a = 1 continue
      case 2 then break
      else a = 2
      end
      a = 3
    end
    assert(a == 1)

    a = 0
    while true do
      switch 1
      case 1 then a = 1 break
      end
      a = 2
      break
    end
    assert(a == 1)

    a = 0
    repeat
      switch 1
      case 1 then a = 1 break
      end
      a = 2
    until false
    assert(a == 1)
  ]])
end)

it("goto", function()
  expect.generate_c("::mylabel::\ngoto mylabel", "mylabel:;\n  goto mylabel;")
end)

it("variable declaration", function()
  expect.generate_c("local a: integer", "int64_t a;")
  expect.generate_c("local a: integer = 0", "int64_t a = 0;")
  -- expect.generate_c("local π = 3.14", "double uCF80 = 3.14;")
end)

it("operation on comptime variables", function()
  expect.generate_c([[
    local a <comptime> = false
    local b <comptime> = not a
    local c = b
  ]], "c = true;")
  expect.generate_c([[
    local a <comptime> = 2
    local b <comptime> = -a
    local c = b
  ]], "c = -2;")
  expect.generate_c([[
    local a = @integer == @integer
    local b = @integer ~= @number
  ]], {"a = true;", "b = true;"})
  expect.generate_c([[
    local a <comptime>, b <comptime> = 1, 2
    local c <const> = (@int32)(a * b)
  ]], "static const int32_t c = 2;")
  expect.generate_c([[
    local a <comptime> = 0xffffffffffffffff_u
    local c <const> = a + a
  ]], "static const uint64_t c = 18446744073709551614ULL;")
  expect.generate_c([[
    local a <comptime> = 0x7fffffffffffffff
    local c <const> = a + a
  ]], "static const int64_t c = -2;")
  expect.generate_c([[
    local huge1: float64 = #[math.huge]#
    local huge2: float64 = #[-math.huge]#
    local nan: float64 = #[0.0/0.0]#
    local huge1f: float32 = #[math.huge]#
    local huge2f: float32 = #[-math.huge]#
    local nanf: float32 = #[0.0/0.0]#
  ]], {
    "huge1 = NELUA_INF",
    "huge2 = -NELUA_INF",
    "nan = NELUA_NAN",
    "huge1f = NELUA_INFF",
    "huge2f = -NELUA_INFF",
    "nanf = NELUA_NANF",
  })
  expect.generate_c([[
    local s <comptime> = 'hello\n'_cstring
    local function printf(format: cstring, ...: cvarargs): cint <cimport,nodecl,cinclude'<stdio.h>'> end
    printf(s)
  ]], [[printf("hello\n");]])
  expect.generate_c([[
    local ADDR: *uinteger <comptime> = (@*uinteger)(0xfffffffff)
    local a = ADDR
  ]], "a = ((nluint64_ptr)0xfffffffff)")
  expect.run_c([[
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
  expect.generate_c("local a,b = 1,2; a = b" ,"a = b;")
end)

it("multiple assignment", function()
  expect.generate_c("local a,b,x,y=1,2,3,4; a, b = x, y", {
    "_asgntmp_1 = x;", "_asgntmp_2 = y;",
    "a = _asgntmp_1;", "b = _asgntmp_2;" })
  --expect.generate_c("local a: table, x:integer, y:integer; a.b, a[b] = x, y", {
  --  "_asgntmp_1 = x;", "_asgntmp_2 = y;",
  --  "a.b = _asgntmp_1;", "a[b] = _asgntmp_2;" })
  expect.run_c([[
    local a, b = 1,2
    a, b = b, a
    assert(a == 2 and b == 1)
  ]])
end)

it("function definition", function()
  expect.generate_c("local function f() end",
    "void f(void) {\n}")
  expect.generate_c(
    "local function f(): integer return 0 end",
    "int64_t f(void) {\n  return 0;\n")
  expect.generate_c(
    "local function f(a: integer): integer return a end",
    "int64_t f(int64_t a) {\n  return a;\n}")
end)

it("anonymous functions", function()
  expect.generate_c([[
    local R = @record{f: function(integer): R, x: integer}
    local function newR(r: R) return r end
    local a = newR{f = function(x: integer) return newR{x=x} end}
  ]], {
    "return newR((R){.x = x});",
    "a = newR((R){.f = anonfunc});",
  })
  expect.run_c([[
    local function call1(f: function()) f() end
    local function call2(f: function(x: integer): integer) return f(1) end

    call1(function() print 'hello' end)
    assert(call2(function(x: integer) <nosideeffect> return x+1 end) == 2)

    do -- issue #114
      local function f(a: string) end
      local A = function() f('hello world') end
      A()
    end
  ]], "hello")
end)

it("poly functions", function()
  expect.run_c([[
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
      ## elseif x.type.is_boolean then
        print('f', x)
      ## else
        print('unknown')
      ## end
      return x
    end
    assert(printtype(1) == 1)
    assert(printtype(3.14) == 3.14)
    assert(printtype(true) == true)
    assert(printtype(false) == false)
    assert(printtype(f) == f)
    printtype()

    do
      local function f() <polymorphic>
        ## assert(false)
      end
      local function g() <polymorphic>
        return 1
      end
      assert(g() == 1)
    end
  ]])
end)

it("poly function aliases", function()
  expect.run_c([[
    local function f(x: auto) return x + 1 end
    local g = f
    assert(g(1) == 2)
    assert(g(1.0) == 2.0)

    local Foo = @record{}
    function Foo.foo(x: auto) return x + 1 end
    local Boo = @record{}
    global Boo.boo = Foo.foo
    assert(Boo.boo(1) == 2)
    assert(Boo.boo(1.0) == 2.0)
  ]])
end)

it("poly function for records", function()
  expect.run_c([[
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

it("poly functions with comptime arguments", function()
  expect.run_c([[
    local function cast(T: type, value: auto)
      return (@T)(value)
    end

    local a = cast(@boolean, 1)
    assert(a == true)

    local b = cast(@number, 1)
    assert(b == 1.0)

    local c = cast(@number, 2)
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

  expect.run_c([[
    local function f(a: string <comptime>)
       ## if a.value == 'test' then
          return 1
       ## else
          return 2
       ## end
    end

    local function g(a: integer <comptime>)
       ## if a.value == 1 then
          return 1
       ## elseif a.value == 2 then
          return 2
       ## else
          return 0
       ## end
    end

    local function h(a: auto <comptime>)
      ## if a.type.is_niltype then
        return 0
      ## else
        return a
      ## end
    end

    assert(f('test') == 1) assert(f('test') == 1)
    assert(f('else') == 2) assert(f('else') == 2)
    assert(g(1) == 1) assert(g(1) == 1)
    assert(g(2) == 2) assert(g(2) == 2)
    assert(g(3) == 0) assert(g(3) == 0)
    assert(g(4) == 0) assert(g(4) == 0)
    assert(h(1) == 1) assert(h(1) == 1)
    assert(h(2) == 2) assert(h(2) == 2)
    assert(h() == 0) assert(h() == 0)

    local function f(x: function(): integer <comptime>)
      return x()
    end
    local function g1() return 1 end
    local function g2() return 2 end
    assert(f(g1) == 1)
    assert(f(g2) == 2)
    assert(f(function(): integer return 1 end) == 1)
    assert(f(function(): integer return 2 end) == 2)
  ]])
end)

it("recursive functions", function()
  expect.run_c([[
    local function decrement(n: integer): integer
      if n == 0 then
        return 0
      else
        return decrement(n - 1)
      end
    end
    local a: integer = decrement(5)
    assert(a == 0)

    local function fi(x: integer): integer
      if x == 0 then return 0 end
      return fi(x-1)
    end
    fi(3)

    local function fa(x: auto): integer
      if x == 0 then return 0 end
      return fa(x-1)
    end
    fa(3)
  ]])
end)

it("global function definition", function()
  expect.generate_c("local function f() end", "static void f(void);")
  expect.run_c([[
    global function f(x: integer) return x+1 end
    assert(f(1) == 2)
  ]])
end)

it("function return", function()
  expect.generate_c([[
    local function f(): integer return 0 end
  ]], "int64_t f(void) {\n  return 0;")
  expect.generate_c([[
    local function f(): niltype return end
  ]], "return NELUA_NIL;")
  expect.generate_c([[
    local function f(): string return (@string){} end
  ]], "nlstring f(void) {\n  return (nlstring){0};")
  expect.generate_c([[
    local function f() return end
  ]], "return;")
end)

it("function multiple returns", function()
  expect.generate_c([[
    local function f(): (integer, boolean) return 1, true end
  ]], {
    "nlmulret_[%w_]+ f",
    "return %(nlmulret_[%w_]+%){1, true};"
  }, true)
  expect.generate_c([[do
    local function f(): (integer, boolean) return 1, true end
    local a, b = f()
    local c = f()
  end]], {
    "int64_t a = _asgnret_%d+%.r1;",
    "bool b = _asgnret_%d+%.r2;",
    "int64_t c = f%(%)%.r1",
  }, true)
  expect.run_c([[
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
    function R.foo(self: *R): (boolean, integer) return true, self.x end
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
  expect.run_c([[
    local function getf()
      local function f(): (integer, integer)
        return 1, 2
      end
      return f
    end
    local f = getf()
    local a,b = f()
    assert(a == 1 and b == 2)

    do
      local function f() return (@[0]int64){}, 1 end
      local a, b = f()
      assert(b == 1)
    end
  ]])
  expect.run_c([[
    local function f(): integer return 1 end
    local function g(): (integer, integer) return 1,2 end
    local function h(): (integer, integer, integer) return 1,2,3 end
    local function sum(...: varargs): integer
      local n: integer = 0
      ## for i=1,select('#', ...) do
        n = n + #[select(i, ...)]#
      ## end
      return n
    end
    assert(sum(f()) == 1)
    assert(sum(g()) == 3)
    assert(sum(h()) == 6)
    assert(sum((f())) == 1)
    assert(sum((g())) == 1)
    assert(sum((h())) == 1)
  ]])
end)

it("call with multiple args", function()
  expect.generate_c([[do
    local function f(): (integer, boolean) return 1, true end
    local function g(a: int32, b: integer, c: boolean) end
    g(1, f())
  end]], {
    "nlmulret_[%w_]+ _tmp%d+ = f%(%)",
    "g%(1, _tmp%d+.r1, _tmp%d+.r2%);"
  }, true)
  expect.run_c([[do
    local function f(): (integer, integer) return 1, 2 end
    local function g(a: integer, b: integer, c: integer) return a + b + c end
    assert(g(3, f()) == 6)
    assert(g(3, f(), 0) == 4)
    assert(g(3, 0, f()) == 4)
  end]])
end)

it("call with side effects", function()
  expect.run_c([[do
    local function f(x: integer) print(x) return x end
    local function g(a: integer, b: integer, c: integer) return a+b+c end
    assert(f(1) + f(2) + f(3) == 6)
    assert(g(f(4), f(5), f(6)) == 15)
  end]],"1\n2\n3\n4\n5\n6")

  expect.run_c([[
    local R = @record{x: integer, y: integer, z: integer}
    local function f(x: integer): integer
      print(x)
      return x
    end
    local a: R = {f(1), f(2)}
  ]], "1\n2")
end)

it("unary operator `not`", function()
  expect.generate_c("local x = not true", "x = false;")
  expect.generate_c("local x = not false", "x = true;")
  expect.generate_c("local x = not nil", "x = (!false);")
  expect.generate_c("local x = not nilptr", "x = (!false);")
  expect.generate_c("local x = not 'a'", "x = false;")
  expect.generate_c("local a = true; local x = not a", "x = (!a);")
  --expect.generate_c("local a = nil; local x = not a", "x = true;")
  --expect.generate_c("local a = nilptr; local x = not a", "x = !a;")
end)

it("unary operator `ref`", function()
  expect.generate_c("local a = 1; local x = &a", "x = (&a);")
end)

it("unary operator `unm`", function()
  expect.generate_c("local a = 1; local x = -a", "(-a);")
end)

it("unary operator `deref`", function()
  expect.generate_c("local a: *integer; local x = $a", "x = (*(int64_t*)nelua_assert_deref(a));")
  config.pragmas.nochecks = true
  expect.generate_c("local a: *integer; local x = $a", "x = (*a);")
  expect.generate_c([[
    local UnchekedByteArray = @[0]byte
    local x: UnchekedByteArray = $(@*UnchekedByteArray)(''_cstring)
    local y = &x
  ]], 'static nluint8_arr0 x;')
  expect.generate_c([[
    local R = @record{}
    local r = R()
    local x = &r
    local function f(a: R): void end
    f(x)
  ]], {"R r;", "x = (&r)", "f((*x))"})
  expect.generate_c([[
    local R = @record{}
    function R:foo(alloc: auto) end
    local r = R()
    r:foo()
  ]], {"r = (R){", "((&r), NELUA_NIL)"})
  expect.generate_c([[
    local a: *[0]integer
    local function f(x: [0]integer) end
    f($a)
  ]], {"f((*(nlint64_arr0*)a));"})
  config.pragmas.nochecks = nil
end)

it("unary operator `bnot`", function()
  expect.generate_c("local a = 1; local x = ~a", "x = (~a);")
  expect.generate_c("local x = ~1", "x = -2;")
  expect.generate_c("local x = ~-2", "x = 1;")
  expect.generate_c("local x = ~0x2_u8", "x = 253U;")
end)

it("unary operator `len`", function()
  expect.generate_c("local x = #@integer", "x = 8;")
  expect.generate_c("local x = #'asd'", "x = 3;")
  expect.generate_c("local x = #@[4]integer", "x = 32;")
  --expect.generate_c("a = 'asd'; local x = #a", "x = 3;")
end)

it("unary operator `lt`", function()
  expect.generate_c("local a, b = 1, 2; local x = a < b", "a < b")
  expect.generate_c("local x = 1 < 1", "x = false;")
  expect.generate_c("local x = 1 < 2", "x = true;")
  expect.generate_c("local x = 2 < 1", "x = false;")
  expect.generate_c("local x = 'a' < 'a'", "x = false;")
  expect.generate_c("local x = 'a' < 'b'", "x = true;")
  expect.generate_c("local x = 'b' < 'a'", "x = false;")
end)

it("unary operator `le`", function()
  expect.generate_c("local a, b = 1, 2; local x = a <= b", "a <= b")
  expect.generate_c("local x = 1 <= 1", "x = true;")
  expect.generate_c("local x = 1 <= 2", "x = true;")
  expect.generate_c("local x = 2 <= 1", "x = false;")
  expect.generate_c("local x = 'a' <= 'a'", "x = true;")
  expect.generate_c("local x = 'a' <= 'b'", "x = true;")
  expect.generate_c("local x = 'b' <= 'a'", "x = false;")
end)

it("unary operator `gt`", function()
  expect.generate_c("local a, b = 1, 2; local x = a > b", "a > b")
  expect.generate_c("local x = 1 > 1", "x = false;")
  expect.generate_c("local x = 1 > 2", "x = false;")
  expect.generate_c("local x = 2 > 1", "x = true;")
  expect.generate_c("local x = 'a' > 'a'", "x = false;")
  expect.generate_c("local x = 'a' > 'b'", "x = false;")
  expect.generate_c("local x = 'b' > 'a'", "x = true;")
end)

it("unary operator `ge`", function()
  expect.generate_c("local a, b = 1, 2; local x = a >= b", "a >= b")
  expect.generate_c("local x = 1 >= 1", "x = true;")
  expect.generate_c("local x = 1 >= 2", "x = false;")
  expect.generate_c("local x = 2 >= 1", "x = true;")
  expect.generate_c("local x = 'a' >= 'a'", "x = true;")
  expect.generate_c("local x = 'a' >= 'b'", "x = false;")
  expect.generate_c("local x = 'b' >= 'a'", "x = true;")
end)

it("binary operator `eq`", function()
  expect.generate_c("local a, b = 1, 2; local x = a == b", "a == b")
  expect.generate_c("local x = 1 == 1", "x = true;")
  expect.generate_c("local x = 1 == 2", "x = false;")
  expect.generate_c("local x = 1 == '1'", "x = false;")
  expect.generate_c("local x = '1' == 1", "x = false;")
  expect.generate_c("local x = '1' == '1'", "x = true;")
  expect.generate_c("local a,b = 1,2; local x = a == b", "x = (a == b);")
  expect.generate_c("local a: pointer, b: *boolean; local x = a == b", "x = (a == (void*)b);")
  expect.generate_c("local x = 0e12 == 0", "x = true;")
end)

it("binary operator `ne`", function()
  expect.generate_c("local a, b = 1, 2; local x = a ~= b", "a != b")
  expect.generate_c("local x = 1 ~= 1", "x = false;")
  expect.generate_c("local x = 1 ~= 2", "x = true;")
  expect.generate_c("local x = 1 ~= 's'", "x = true;")
  expect.generate_c("local x = 's' ~= 1", "x = true;")
  expect.generate_c("local a,b = 1,2; local x = a ~= b", "x = (a != b);")
end)

it("binary operator `add`", function()
  expect.generate_c("local a, b = 1, 2; local x = a + b",       "a + b")
  expect.generate_c("local x = 3 + 2",       "x = 5;")
  expect.generate_c("local x = 3.0 + 2.0",   "x = 5.0;")
end)

it("binary operator `sub`", function()
  expect.generate_c("local a, b = 1, 2; local x = a - b",       "a - b")
  expect.generate_c("local x = 3 - 2",       "x = 1;")
  expect.generate_c("local x = 3.0 - 2.0",   "x = 1.0;")
end)

it("binary operator `mul`", function()
  expect.generate_c("local a, b = 1, 2; local x = a * b",       "a * b")
  expect.generate_c("local x = 3 * 2",       "x = 6;")
  expect.generate_c("local x = 3.0 * 2.0",   "x = 6.0;")
end)

it("binary operator `div`", function()
  expect.generate_c("local x = 3 / 2",                   "x = 1.5;")
  expect.generate_c("local x = (@float64)(3 / 2)",       "x = 1.5;")
  expect.generate_c("local x = 3 / 2_int64",             "x = 1.5;")
  expect.generate_c("local x = 3.0 / 2",                 "x = 1.5;")
  expect.generate_c("local x = (@integer)(3_i / 2_i)",   "x = (int64_t)1.5;")
  expect.generate_c("local x = (@integer)(3 / 2_int64)", "x = (int64_t)1.5;")
  expect.generate_c("local x =  3 /  4",                 "x = 0.75;")
  expect.generate_c("local x = -3 /  4",                 "x = -0.75;")
  expect.generate_c("local x =  3 / -4",                 "x = -0.75;")
  expect.generate_c("local x = -3 / -4",                 "x = 0.75;")
  expect.generate_c("local a,b = 1,2; local x=a/b",      "x = (a / (double)b);")
  expect.generate_c("local a,b = 1.0,2.0; local x=a/b",  "x = (a / b);")
end)

it("binary operator `idiv`", function()
  expect.generate_c("local x = 3 // 2",      "x = 1;")
  expect.generate_c("local x = 3 // 2.0",    "x = 1.0;")
  expect.generate_c("local x = 3.0 // 2.0",  "x = 1.0;")
  expect.generate_c("local x = 3.0 // 2",    "x = 1.0;")
  expect.generate_c("local x =  7 //  3",    "x = 2;")
  expect.generate_c("local x = -7 //  3",    "x = -3;")
  expect.generate_c("local x =  7 // -3",    "x = -3;")
  expect.generate_c("local x = -7 // -3",    "x = 2;")
  expect.generate_c("local x =  7 //  3.0",  "x = 2.0;")
  expect.generate_c("local x = -7 //  3.0",  "x = -3.0;")
  expect.generate_c("local x =  7 // -3.0",  "x = -3.0;")
  expect.generate_c("local x = -7 // -3.0",  "x = 2.0;")
  expect.generate_c("local a,b = 1_u,2_u; local x=a//b",      "x = (a / b);")
  expect.generate_c("local a,b = 1,2; local x=a//b",      "x = nelua_assert_idiv_nlint64(a, b);")
  expect.generate_c("local a,b = 1.0,2.0; local x=a//b",  "x = floor(a / b);")
  expect.run_c([[
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
    do
      local a: int64, b: int64 = (@int64)(0x8000000000000000), -1
      assert(a // b == a)
      assert(a % b == 0)
    end
  ]])
  config.pragmas.nochecks = true
  expect.generate_c("local a,b = 1,2; local x=a//b",      "x = nelua_idiv_nlint64(a, b);")
  config.pragmas.nochecks = nil
end)

it("binary operator `tdiv`", function()
  expect.generate_c("local x = 3 /// 2",      "x = 1;")
  expect.generate_c("local x = 3 /// 2.0",    "x = 1.0;")
  expect.generate_c("local x = 3.0 /// 2.0",  "x = 1.0;")
  expect.generate_c("local x = 3.0 /// 2",    "x = 1.0;")
  expect.generate_c("local x =  7 ///  3",    "x = 2;")
  expect.generate_c("local x = -7 ///  3",    "x = -2;")
  expect.generate_c("local x =  7 /// -3",    "x = -2;")
  expect.generate_c("local x = -7 /// -3",    "x = 2;")
  expect.generate_c("local x =  7 ///  3.0",  "x = 2.0;")
  expect.generate_c("local x = -7 ///  3.0",  "x = -2.0;")
  expect.generate_c("local x =  7 /// -3.0",  "x = -2.0;")
  expect.generate_c("local x = -7 /// -3.0",  "x = 2.0;")
  expect.generate_c("local x =  7.0 ///  3.0",  "x = 2.0;")
  expect.generate_c("local x = -7.0 ///  3.0",  "x = -2.0;")
  expect.generate_c("local x =  7.0 /// -3.0",  "x = -2.0;")
  expect.generate_c("local x = -7.0 /// -3.0",  "x = 2.0;")
  expect.generate_c("local a,b = 1,2; local x=a///b",      "x = (a / b);")
  expect.generate_c("local a,b = 1.0,2.0; local x=a///b",  "x = trunc(a / b);")
  expect.run_c([[
    do
      local a, b = 7, 3
      assert(a /// b == 2)
      assert(-a /// b == -2)
      assert(a /// -b == -2)
      assert(-a /// -b == 2)
      assert(a /// a == 1)
    end
    do
      local a, b = 7.0, 3.0
      assert(a /// b == 2.0)
      assert(-a /// b == -2.0)
      assert(a /// -b == -2.0)
      assert(-a /// -b == 2.0)
      assert(a /// a == 1.0)
    end
  ]])
end)

it("binary operator `mod`", function()
  --expect.generate_c("local x = a % b")
  expect.generate_c("local x = 3 % 2",       "x = 1;")
  expect.generate_c("local x = 3.0 % 2.0",   "x = 1.0;")
  expect.generate_c("local x = 3.0 % 2",     "x = 1.0;")
  expect.generate_c("local x = 3 % 2.0",     "x = 1.0;")
  expect.generate_c("local x =  7 %  3",     "x = 1;")
  expect.generate_c("local x = -7 %  3",     "x = 2;")
  expect.generate_c("local x =  7 % -3",     "x = -2;")
  expect.generate_c("local x = -7 % -3",     "x = -1;")
  expect.generate_c("local x =  7 %  3.0",   "x = 1.0;")
  expect.generate_c("local x = -7 %  3.0",   "x = 2.0;")
  expect.generate_c("local x =  7 % -3.0",   "x = -2.0;")
  expect.generate_c("local x = -7 % -3.0",   "x = -1.0;")
  expect.generate_c("local x = -7.0 % 3.0",  "x = 2.0;")
  expect.generate_c("local a, b = 3, 2;     local x = a % b", "x = nelua_assert_imod_nlint64(a, b);")
  expect.generate_c("local a, b = 3_u, 2_u; local x = a % b", "x = (a % b);")
  expect.generate_c("local a, b = 3.0, 2;   local x = a % b", "x = nelua_fmod(a, b);")
  expect.generate_c("local a, b = 3, 2.0;   local x = a % b", "x = nelua_fmod(a, b);")
  expect.generate_c("local a, b = 3.0, 2.0; local x = a % b", "x = nelua_fmod(a, b);")
  expect.run_c([[
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
  config.pragmas.nochecks = true
  expect.generate_c("local a, b = 3, 2;     local x = a % b", "x = nelua_imod_nlint64(a, b);")
  config.pragmas.nochecks = nil
end)

it("binary operator `tmod`", function()
  expect.generate_c("local x = 3 %%% 2",       "x = 1;")
  expect.generate_c("local x = 3.0 %%% 2.0",   "x = 1.0;")
  expect.generate_c("local x = 3.0 %%% 2",     "x = 1.0;")
  expect.generate_c("local x = 3 %%% 2.0",     "x = 1.0;")
  expect.generate_c("local x =  7 %%%  3",     "x = 1;")
  expect.generate_c("local x = -7 %%%  3",     "x = -1;")
  expect.generate_c("local x =  7 %%% -3",     "x = 1;")
  expect.generate_c("local x = -7 %%% -3",     "x = -1;")
  expect.generate_c("local x =  7 %%%  3.0",   "x = 1.0;")
  expect.generate_c("local x = -7 %%%  3.0",   "x = -1.0;")
  expect.generate_c("local x =  7 %%% -3.0",   "x = 1.0;")
  expect.generate_c("local x = -7 %%% -3.0",   "x = -1.0;")
  expect.generate_c("local x = -7.0 %%% 3.0",  "x = -1.0;")
  expect.generate_c("local a, b = 3, 2;     local x = a %%% b", "x = (a % b);")
  expect.generate_c("local a, b = 3_u, 2_u; local x = a %%% b", "x = (a % b);")
  expect.generate_c("local a, b = 3.0, 2;   local x = a %%% b", "x = fmod(a, b);")
  expect.generate_c("local a, b = 3, 2.0;   local x = a %%% b", "x = fmod(a, b);")
  expect.generate_c("local a, b = 3.0, 2.0; local x = a %%% b", "x = fmod(a, b);")
  expect.run_c([[
    do
      local a, b = 7, 3
      assert(a %%% b == 1)
      assert(-a %%% b == -1)
      assert(a %%% -b == 1)
      assert(-a %%% -b == -1)
      assert(a %%% a == 0)
    end
    do
      local a, b = 7.0, 3.0
      assert(a %%% b == 1.0)
      assert(-a %%% b == -1.0)
      assert(a %%% -b == 1.0)
      assert(-a %%% -b == -1.0)
      assert(a %%% a == 0.0)
    end
  ]])
end)


it("binary operator `pow`", function()
  --expect.generate_c("local x = a ^ b")
  expect.generate_c("local a,b = 2,2; local x = a ^ b", "x = pow(a, b);")
  expect.generate_c("local x = 2 ^ 2", "x = 4.0;")
  expect.generate_c("local x = 2_f32 ^ 2_f32", "x = 4.0f;")
  expect.generate_c("local a,b = 2_f32,2_f32; local x = a ^ b", "x = powf(a, b);")
  expect.generate_c("local a,b = 2_f64,2_f64; local x = a ^ b", "x = pow(a, b);")
  expect.generate_c("local a,b = 2_cld,2_cld; local x = a ^ b", "x = powl(a, b);")
end)

it("binary operator `band`", function()
  expect.generate_c("local x = 3 & 5",                   "x = 1;")
  expect.generate_c("local x = -0xfffffffd & 5",         "x = 1;")
  expect.generate_c("local x = -3 & -5",                 "x = -7;")
  expect.generate_c("local x = -3_i32 & 0xfffffffb_u32", "x = -7;")
end)

it("binary operator `bor`", function()
  expect.generate_c("local a,b = 1,2; local x = a | b", "(a | b);")
  expect.generate_c("local x = 3 | 5", "x = 7;")
  expect.generate_c("local x = 3 | -5", "x = -5;")
  expect.generate_c("local x = -0xfffffffffffffffd | 5", "x = 7;")
  expect.generate_c("local x = -3 | -5", "x = -1;")
end)

it("binary operator `bxor`", function()
  expect.generate_c("local a,b = 1,2; local x = a ~ b", "(a ^ b);")
  expect.generate_c("local x = 3 ~ 5", "x = 6;")
  expect.generate_c("local x = 3 ~ -5", "x = -8;")
  expect.generate_c("local x = -3 ~ -5", "x = 6;")
end)

it("binary operator `shl`", function()
  expect.generate_c("local a,b = 1,2; local x = a << b", "nelua_shl_nlint64(a, b)")
  expect.generate_c("local x = 6 << 1", "x = 12;")
  expect.generate_c("local x = 6 << 0", "x = 6;")
  expect.generate_c("local x = 6 << -1", "x = 3;")
end)

it("binary operator `shr`", function()
  expect.generate_c("local a,b = 1,2; local x = a >> b", "nelua_shr_nlint64(a, b)")
  expect.generate_c("local x = 6 >> 1", "x = 3;")
  expect.generate_c("local x = 6 >> 0", "x = 6;")
  expect.generate_c("local x = 6 >> -1", "x = 12;")
end)

it("binary operator `asr`", function()
  expect.generate_c("local a,b = 1,2; local x = a >>> b", "nelua_asr_nlint64(a, b)")
  expect.generate_c("local x = 6 >>> 1", "x = 3;")
  expect.generate_c("local x = 6 >>> 0", "x = 6;")
  expect.generate_c("local x = 6 >>> -1", "x = 12;")
  expect.generate_c("local x = -5 >>> 1", "x = -3;")
end)

it("binary shifting", function()
  expect.run_c([[
    local a: int64 = 6
    assert((a << 64) == 0)
    assert((a >> 64) == 0)
    assert((a << -64) == 0)
    assert((a >> -64) == 0)
    assert((a >> 1) == 3)
    assert((a >> 63) == 0)
    assert((a << 63) == 0)
    assert((a << 62) == -9223372036854775807-1)
    assert((a >> -1) == 12)
    assert((a << 1) == 12)
    assert((a << -1) == 3)

    do
      local a: int64, b: int64 = -8, 32
      assert((a >> b) == 0xffffffff)
      assert((a >> 32) == 0xffffffff)
      assert((-8 >> 32) == 0xffffffff)
      assert((-8 >> b) == 0xffffffff)
    end

    do
      local a: int64, b: int64 = 0x4000000000000000, 1
      assert((a << b) == (@int64)(0x8000000000000000))
      assert((a << 1) == (@int64)(0x8000000000000000))
      assert((0x4000000000000000 << b) == (@int64)(0x8000000000000000))
      assert((0x4000000000000000 << 1) == (@int64)(0x8000000000000000))
    end

    do
      local a = -0x4d
      local i: [10]integer = {0,1,2,3,4,5,6,7,8,65}

      assert(-0x4d >>> 0 == -77)
      assert(-0x4d >>> 1 == -39)
      assert(-0x4d >>> 2 == -20)
      assert(-0x4d >>> 3 == -10)
      assert(-0x4d >>> 4 == -5)
      assert(-0x4d >>> 5 == -3)
      assert(-0x4d >>> 6 == -2)
      assert(-0x4d >>> 7 == -1)
      assert(-0x4d >>> 8 == -1)
      assert(-0x4d >>> 65 == -1)

      assert(a >>> i[0] == -77) assert(-0x4d >>> i[0] == -77) assert(a >>> 0 == -77)
      assert(a >>> i[1] == -39) assert(-0x4d >>> i[1] == -39) assert(a >>> 1 == -39)
      assert(a >>> i[2] == -20) assert(-0x4d >>> i[2] == -20) assert(a >>> 2 == -20)
      assert(a >>> i[3] == -10) assert(-0x4d >>> i[3] == -10) assert(a >>> 3 == -10)
      assert(a >>> i[4] == -5) assert(-0x4d >>> i[4] == -5) assert(a >>> 4 == -5)
      assert(a >>> i[5] == -3) assert(-0x4d >>> i[5] == -3) assert(a >>> 5 == -3)
      assert(a >>> i[6] == -2) assert(-0x4d >>> i[6] == -2) assert(a >>> 6 == -2)
      assert(a >>> i[7] == -1) assert(-0x4d >>> i[7] == -1) assert(a >>> 7 == -1)
      assert(a >>> i[8] == -1) assert(-0x4d >>> i[8] == -1) assert(a >>> 8 == -1)
      assert(a >>> i[9] == -1) assert(-0x4d >>> i[9] == -1) assert(a >>> 65 == -1)
    end
  ]])
end)

it("binary operator `concat`", function()
  expect.generate_c("local x = 'a' .. 'b'", [["ab"]])
end)

it("string comparisons", function()
  expect.generate_c("local a,b = 'a','b'; local x = a == b", "nelua_eq_string(a, b)")
  expect.generate_c("local a,b = 'a','b'; local x = a ~= b", "!nelua_eq_string(a, b)")
  expect.run_c([[
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
  expect.run_c([[
    local A = @[4]integer
    local a: A = {1,2,3,4}
    local b: A = {1,2,3,4}
    local c: A = {1,2,3,5}
    assert(a == a)
    assert(a == (@[4]integer){1,2,3,4})
    assert(a ~= (@[4]integer){1,2,3,5})
    assert(a == b)
    assert(not (a ~= b))
    assert(not (a == c))
    assert(a ~= c)
]])
end)

it("number comparisons", function()
  expect.run_c([[
    local a: int32 = -1
    local b: uint32 = 0xffffffff
    assert(not (@uint32)(a) ~= b)
    assert((@uint32)(a) == b)
    assert((@uint32)(a) <= b)
    assert((@uint32)(a) >= b)
    assert(not ((@uint32)(a) < b))
    assert(not (b > (@uint32)(a)))
    assert(not (a == b)) assert(not (b == a))
    assert(a ~= b) assert(b ~= a)
    assert(a <= b) assert(b >= a)
    assert(a < b) assert(b > a)

    do
      local a: usize, b: isize, c: isize
      local d = a - b
      assert(a - b >= c)
    end

    do
      local a: integer = 2
      local b: number = 2.1
      local c: number = 2.0
      assert(a ~= b)
      assert(a == c)
    end

    do
      local i: int8 = -1
      assert(i < '0'_byte)
    end

    do
      local a: uinteger = 2
      assert(not (a < -1))
      assert(not (a <= -1))
      assert(not (a == -1))
    end
]])
end)

it("record comparisons", function()
  expect.run_c([[
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


    local Q = @record{x: [2]integer}
    local a: Q = {{1,2}}
    local b: Q = {{1,2}}
    local c: Q = {{1,3}}
    assert(a == a)
    assert(a == b)
    assert(not (a ~= b))
    assert(not (a == c))
    assert(a ~= c)

    local r: record{}
    assert(r == r)

    local pq: *Q = &a
    assert(($pq == 0) == false)
    assert(($pq ~= 0) == true)
]])
end)

it("binary conditional operators", function()
  expect.generate_c("local a: pointer, b: pointer; do return a or b end",  [[({
      void* t1_ = a;
      void* t2_ = NULL;
      bool cond_ = (t1_ != NULL);
      if(!cond_) {
        t2_ = b;
      }
      cond_ ? t1_ : t2_;
    })]])
  expect.generate_c("local a: pointer, b: pointer; return a and b",  [[({
    void* t1_ = a;
    void* t2_ = NULL;
    bool cond_ = (t1_ != NULL);
    if(cond_) {
      t2_ = b;
      cond_ = (t2_ != NULL);
    }
    cond_ ? t2_ : NULL;
  })]])
  expect.generate_c([[
    local a: boolean, b: integer, c: number
    local x = a and b or c
  ]], "x = (a ? (double)b : c);")
  expect.generate_c([[
    local p: pointer
    local i: integer = 1
    local b: boolean = i == 0 or p
    local b2 = (@boolean)(i == 0 or p)
  ]], {
    "b = ((i == 0) || (p != NULL));",
    "b2 = ((i == 0) || (p != NULL));"
  })
  expect.generate_c([[
    local p: *integer
    local a: pointer, b: pointer
    if p and a == b then end
    while p and a == b do end
  ]], {
    "if(((p != NULL) && (a == b)))",
    "while(((p != NULL) && (a == b)))"
  })
  expect.run_c([[
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
    -- assert((true and 1 and 2 or 3) == 2)
    -- assert((false and 1 and 2 or 3) == 3)
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
      assert(a < b == true)   assert(a < a == false)
      assert(b < a == false)  assert(b < b == false)
      assert(a <= b == true)  assert(a <= a == true)
      assert(b <= a == false) assert(b <= b == true)
      assert(a > b == false)  assert(a > a == false)
      assert(b > a == true)   assert(b > b == false)
      assert(a >= b == false) assert(a >= a == true)
      assert(b >= a == true)  assert(b >= b == true)
      assert(a == b == false) assert(a == a == true)
      assert(b == a == false) assert(b == b == true)
    end

    do
      local p: pointer
      local b: boolean = true
      assert(not (p or b) == false)
      assert(not (b and p) == true)
    end

    do
      assert(not (true == 1))
      assert(not (false == 1))
      assert(true ~= 1)
      assert(false ~= 1)
    end

    do
      local btrue: boolean = true
      local bfalse: boolean = false
      local one: integer = 1
      assert(not (btrue == one))
      assert(not (bfalse == one))
      assert(btrue ~= one)
      assert(bfalse ~= one)
    end
  ]])
end)

it("expressions with side effects", function()
  expect.generate_c([[do
    local function f() return 1 end
    local a = f() + 1
  end]],  "int64_t a = (f() + 1)")
  expect.generate_c([[do
    local function f() return 1 end
    local function g() return 1 end
    local a = f() + g()
  end]],  [[int64_t a = (f() + g());]])
  expect.run_c([[
    local function f() return 1 end
    local function g() return 2 end
    local a = f() + g()
    assert(a == 3)
  ]])
end)

it("statement expressions", function()
  expect.run_c([[
    do
      local x = 1
      local a = (do in x end)
      assert(a == 1)
      assert((do in (1+4)*2 end) == 10)

      local function f(cond1: boolean, cond2: boolean)
        return (do
          if cond1 and cond2 then
            in 12
          elseif cond1 then
            in 1
          elseif cond2 then
            in 2
          else
            in 0
          end
        end)
      end

      assert(f(true, true) == 12)
      assert(f(true, false) == 1)
      assert(f(false, true) == 2)
      assert(f(false, false) == 0)
    end

    do
      ## local f = expr_macro(function(x, a, b)
        local r = (#[x]# << #[a]#) >> #[b]#
        r = r + 4
        in r
      ## end)

      local x = 0xff
      local y = #[f(x, 2, 3)]#
      assert(y == 131)
    end

    do
      local x = (do
        if true then
          in 10
        else
          in 20
        end
        in 30
      end)
      assert(x == 10)
    end
  ]])
end)

it("replacement macros" ,function()
  expect.run_c([[
    do -- statements
      ## local function statmul(res, a, b)
        #[res]# = #[a]# * #[b]#
      ## end

      local a, b = 2, 3
      local res
      #[statmul]#(res, a, b)
      assert(res == 6)
    end

    do -- expressions
      ## local mul = expr_macro(function(a, b)
        in #[a]# * #[b]#
      ## end)
      local a, b = 2, 3
      assert(#[mul]#(a, b) == 6)
      #[mul]#(a, b)
    end
  ]])
end)

it("c types", function()
  expect.generate_c("local a: integer", "int64_t a;")
  expect.generate_c("local a: number", "double a;")
  expect.generate_c("local a: byte", "uint8_t a;")
  expect.generate_c("local a: float128", "__float128 a;")
  expect.generate_c("local a: float64", "double a;")
  expect.generate_c("local a: float32", "float a;")
  expect.generate_c("local a: pointer", "void* a;")
  expect.generate_c("local a: int128", "__int128 a;")
  expect.generate_c("local a: int64", "int64_t a;")
  expect.generate_c("local a: int32", "int32_t a;")
  expect.generate_c("local a: int16", "int16_t a;")
  expect.generate_c("local a: int8", "int8_t a;")
  expect.generate_c("local a: isize", "intptr_t a;")
  expect.generate_c("local a: uint128", "unsigned __int128 a;")
  expect.generate_c("local a: uint64", "uint64_t a;")
  expect.generate_c("local a: uint32", "uint32_t a;")
  expect.generate_c("local a: uint16", "uint16_t a;")
  expect.generate_c("local a: uint8", "uint8_t a;")
  expect.generate_c("local a: usize", "uintptr_t a;")
  expect.generate_c("local a: boolean", "bool a;")

  expect.generate_c("local a: clongdouble", "long double a;")
  expect.generate_c("local a: cdouble", "double a;")
  expect.generate_c("local a: cfloat", "float a;")
  expect.generate_c("local a: cschar", "signed char a;")
  expect.generate_c("local a: cchar", "char a;")
  expect.generate_c("local a: cshort", "short a;")
  expect.generate_c("local a: cint", "int a;")
  expect.generate_c("local a: clong", "long a;")
  expect.generate_c("local a: clonglong", "long long a;")
  expect.generate_c("local a: cptrdiff", "ptrdiff_t a;")
  expect.generate_c("local a: cuchar", "unsigned char a;")
  expect.generate_c("local a: cushort", "unsigned short a;")
  expect.generate_c("local a: cuint", "unsigned int a;")
  expect.generate_c("local a: culong", "unsigned long a;")
  expect.generate_c("local a: culonglong", "unsigned long long a;")
  expect.generate_c("local a: csize", "size_t a;")

  expect.generate_c("do local a: float128 end", "__float128 a = 0.0q;")
  expect.generate_c("do local a: float64 end", "double a = 0.0;")
  expect.generate_c("do local a: float32 end", "float a = 0.0f;")
  expect.generate_c("do local a: clongdouble end", "long double a = 0.0l;")
  expect.generate_c("do local a: cdouble end", "double a = 0.0;")
  expect.generate_c("do local a: cfloat end", "float a = 0.0f;")
end)

it("reserved names quoting", function()
  expect.config.srcname = 'mymod'
  expect.generate_c("local default: integer", "int64_t mymod_default;")
  expect.generate_c("local NULL: integer = 0", "int64_t mymod_NULL = 0;")
  expect.generate_c("do local default: integer end", "int64_t default_ = 0;")
  expect.generate_c("do local NULL: integer = 0 end", "int64_t NULL_ = 0;")
  expect.config.srcname = nil
  expect.run_c([[
    local function struct(double: integer)
      local default: integer
      default = 1
      return default + double
    end
    print(struct(1))
  ]], "2")
end)

it("variable shadowing", function()
  expect.run_c([[
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

    local function exit(code: cint) <cimport> end
    local function exit(code: cint) <cimport> end
    exit(0)
  ]])
end)

it("any type", function()
  expect.run_error_c([[
    local row_pix: integer = (true and 1) * 2
  ]], "not supported yet")
  expect.run_error_c([[
    local row_pix: integer = -(true and 1)
  ]], "not supported yet")
  expect.run_error_c("local a: any", "not supported yet")
  expect.run_error_c([[
    local function f(...) return ... end
  ]], "not supported yet")
  expect.run_error_c([[
    local function f(...) return 1 end
  ]], "not supported yet")
end)

it("table type", function()
  expect.run_error_c("local a = {}", "not supported yet")
end)

it("cstring and string", function()
  expect.run_c([[
    local a = 'hello'
    print(a)
    local b: cstring = a
    print(b)

    do
      local c: cstring = 'hello'
      local s: string = (@string)(c)
      assert(#s == 5)
      assert(#c == 5)
    end

    do
      local s: string = 'hello'
      local c: cstring = (@cstring)(s)
      assert(#s == 5)
      assert(#c == 5)
    end

    do
      local s: [4]byte = {'a'_byte,'b'_byte,0}
      local c: cstring = &s
      assert(#c == 2)
      assert(c == 'ab')
    end
    assert(#(@cstring)('hello') == 5)
  ]], "hello\nhello")
end)

it("arrays", function()
  expect.generate_c(
    "local a: array(boolean, 10)",
    {"v[10];} nlboolean_arr10"})
  expect.generate_c([[
    local Range = @record{ptr: pointer, size: usize}
    local ImageData = @record{subimage: [8][4]Range}
    local ImageDesc = @record{data: ImageData}
    local imgdesc: ImageDesc
    imgdesc.data.subimage[0][0] = {ptr=nilptr, size = 0}
  ]], {
    [[Range subimage[8][4];]],
    [[imgdesc.data.subimage[0][0] = ]],
  })
  expect.run_c([[
    do
      local a: array(boolean, 1)
      assert(a[0] == false)
      assert(#a == 1)
      a[0] = true
      assert(a[0] == true)
      a = {}
      assert(a[0] == false)
    end

    do
      local a: []integer = {1,2,3,4}
      local b: array(integer, 4) = a
      local c: auto = (@[]integer){1,2,3,4}

      assert(b[0] == 1 and b[1] == 2 and b[2] == 3 and b[3] == 4)
      assert(#b == 4)
      assert(#c == 4)
    end

    do
      local words: [2]cstring = {
        "hello",
        "world",
      }
      assert(words[0] == "hello")
      local i: usize = 1
      assert(words[i] == "world")
      assert(#words == 2)
    end

    do
      local cs: cstring = 'a'
      local a: [4]string = {cs, 'b'_cstring, 'c'}
      assert(a[0] == 'a' and a[1] == 'b' and a[2] == 'c' and a[3] == '')
    end

    do
      local message: [4]string = {'hello'_cstring}
      assert(message[0] == 'hello')
    end
  ]])
  expect.run_c([[
    local INT4: [4]integer <comptime> = {1,2,3,4}
    local a: [4]integer = INT4
    assert(a[0] == 1)

    local R: [3]byte <comptime> = {0xff,0x00,0x00}
    local G: [3]byte <comptime> = {0x00,0xff,0x00}
    local B: [3]byte <comptime> = {0x00,0x00,0xff}
    local Colors: [3][3]byte = {R,G,B}
    assert(Colors[0] == R)
    assert(Colors[1] == G)
    assert(Colors[2] == B)


    do
      local a: [4]integer = INT4
      assert(a[0] == 1)
      local colors: [3][3]byte = {R,G,B}
      assert(colors[0] == R)
      assert(colors[1] == G)
      assert(colors[2] == B)
    end
    do
      local function gR() return (@[3]byte){0xff,0x00,0x00} end
      local function gG() return (@[3]byte){0x00,0xff,0x00} end
      local function gB() return (@[3]byte){0x00,0x00,0xff} end
      local colors: [3][3]byte = {gR(),gG(),gB()}
      assert(colors[0] == R)
      assert(colors[1] == G)
      assert(colors[2] == B)
    end
  ]])
end)

it("array bounds checking", function()
  expect.run_error_c([[
    local a: [4]integer
    local i = 4
    print(a[i])
  ]], "array index: position out of bounds")
  expect.run_error_c([[
    local a: [4]integer
    local i = -1
    print(a[i])
  ]], "array index: position out of bounds")
end)

it("arrays inside records", function()
  expect.run_c([[
    local R = @record{v: [4]integer}
    local a: R
    a.v[0]=1 a.v[1]=2 a.v[2]=3 a.v[3]=4
    assert(a.v[0]==1 and a.v[1]==2 and a.v[2]==3 and a.v[3]==4)
    a.v = {5,6,7,8}
    assert(a.v[0]==5 and a.v[1]==6 and a.v[2]==7 and a.v[3]==8)

    local b: R = {v = {1,2,3,4}}
    assert(b.v[0]==1 and b.v[1]==2 and b.v[2]==3 and b.v[3]==4)

    local function f(): [2][2]integer
      local a: [2][2]integer
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

    local function g(): [2][2]integer
      return (@[2][2]integer){{1,2},{3,4}}
    end
    assert(g()[0][0] == 1)
    assert(g()[0][1] == 2)
    assert(g()[1][0] == 3)
    assert(g()[1][1] == 4)

    local R = @record{v: [4]integer}
    local v = (@[4]integer){1,2,3,4}
    local a: R = {v=v}
    assert(a.v[0] == 1 and a.v[1] == 2 and a.v[2] == 3 and a.v[3] == 4)
  ]])
end)

it("multi dimensional arrays", function()
  expect.run_c([[
    local function f(): [2][2]integer
      local a: [2][2]integer
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

    local function g(): [2][2]integer
      return (@[2][2]integer){{1,2},{3,4}}
    end
    print(g()[0][0])
    print(g()[0][1])
    print(g()[1][0])
    print(g()[1][1])

    do
      local Object = @record{
        values: *[0]*[0]integer
      }
      local b: [4]integer = {1,2,3,4}
      local a: [4]*[0]integer = {&b, &b, &b, &b}
      local o: Object
      o.values = &a
      assert(o.values[0][0] == 1)
      assert(o.values[0][1] == 2)
      assert(o.values[2][2] == 3)
      assert(o.values[3][3] == 4)
    end

    do
      local Map = @[0][0]integer
      local a: Map
      local b: Map
      a = $(&b)
    end
  ]])
end)

it("records", function()
  expect.generate_c(
    "local t: record{}",
    "typedef struct record_%w+ record_%w+;", true)
  expect.generate_c(
    "local t: record{a: boolean}",
    [[struct record_%w+ {
  bool a;
};]], true)
  expect.run_c([[
    local p: record{
      x: integer,
      y: integer
    }
    assert(p.x == 0 and p.y == 0)
    p.x, p.y = 1, 2
    assert(p.x == 1 and p.y == 2)
  ]])
  expect.run_c([[
    local Point = @record{x: integer, y: integer}
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
    local x, y = 1, 2
    assert(Point({=x,=y}).y == 2)
  ]])
  expect.run_c([[
    local Point = @record{x: integer, y: integer}
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
  expect.run_c([[
    local P = @record{x: byte, y: byte}
    local p <const> = P{x=1,y=2}
    assert(p.x == 1 and p.y == 2)

    local r: record {x: array(integer, 1)} =  {x={1}}
    assert(r.x[0] == 1)
  ]])
end)

it("records size", function()
  expect.run_c([=[
    require 'span'
    do
      local R = @record{ a: usize, b: span(integer) }
      local r: R, s: integer ##[[cemit('s = sizeof(r);')]]
      assert(#R == s)
    end

    do
      local R = @record{ a: cint, b: cchar }
      local r: R, s: integer ##[[cemit('s = sizeof(r);')]]
      assert(#R == s)
    end

    do
      local R = @record{ a: cint, b: float64, c: cchar }
      local r: R, s: integer ##[[cemit('s = sizeof(r);')]]
      assert(#R == s)
    end

    do
      local R = @record{ a: [64][64]float64, c: cchar }
      local r: R, s: integer ##[[cemit('s = sizeof(r);')]]
      assert(#R == s)
    end

    do
      local R1 = @record{ a: int32 }
      local R2 = @record{ a: number, b: number }
      local R = @record{ s: R1, a: R2 }
      local r: R, s: integer ##[[cemit('s = sizeof(r);')]]
      assert(#R == s)
    end

    do
      local R = @record{a: int32, b: boolean, c: pointer, d: pointer}
      local r: R, s: integer ##[[cemit('s = sizeof(r);')]]
      assert(#R == s)
    end
  ]=])
end)

it("record methods", function()
  expect.run_c([[
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

    function vec2.length4(self: *vec2) return self:length() end
    assert(v:length4() == 3)
    assert(vec2.length4(v) == 3)

    function vec2:lenmul(a: integer, b: integer) return (self.x + self.y)*a*b end
    assert(v:lenmul(2,3) == 18)

    local vec2pointer = @*vec2
    function vec2pointer:len() return self.x + self.y end
    assert(v:len() == 3)

    local Math = @record{}
    function Math.abs(x: number): number <cimport'fabs',cinclude'<math.h>'> end
    assert(Math.abs(-1) == 1)

    local Foo = @record{x: integer, f: function(*Foo): integer}
    local foo: Foo = {1}
    foo.f = function(foo: *Foo): integer return foo.x end
    assert(foo:f() == 1)

    local R = @record{f: function(*R, x: integer): integer}
    local r = R{}
    function r:f(x: integer) return x end
    assert(r:f(1) == 1)
  ]])

  expect.run_c([[
    local Foo = @record{x: integer, g: function(*Foo): integer}
    local foo: Foo
    function foo:g() return self.x end
    local function f() foo.x = foo.x + 1 return &foo end

    assert(foo.x == 0)
    f():g()
    assert(foo.x == 1)
  ]])
end)

it("record metametods", function()
  expect.run_c([[
    local intarray = @record{
      data: [100]integer
    }
    function intarray:__atindex(i: usize): *integer <inline>
      return &self.data[i]
    end
    function intarray:__len(): isize <inline>
      return #self.data
    end
    ## intarray.value.is_contiguous = true
    ## assert(intarray.value:is_contiguous_of(symbols.integer.value))
    ## assert(not intarray.value:is_contiguous_of(symbols.number.value))
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

    local R = @record{
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

    local R = @record{
      x: [2]integer
    }
    local R_convertible_concept = #[concept(function(x)
      return true
    end, function()
      return types.ArrayType(primtypes.integer, 2)
    end
    )]#
    function R.__convert(x: R_convertible_concept): R
      local self: R
      self.x = x
      return self
    end
    local r: R = {1,2}
    assert(r.x[0] == 1 and r.x[1] == 2)
  ]])

  expect.run_c([[
    local R = @record{x: integer, diff: boolean}
    function R.__eq(a: R, b: R): boolean
      if a.diff or b.diff then return false end
      return a.x == b.x
    end
    function R.__lt(a: R, b: R): boolean
      return a.x < b.x
    end
    function R.__le(a: R, b: R): boolean
      return a.x <= b.x
    end

    local a: R, b: R = {1}, {2}
    assert(not (a == b)) assert(a ~= b)
    assert(a <= b) assert(a < b)
    assert(b >= a) assert(b > a)
    assert(not (a >= b)) assert(not (a > b))

    assert(a == a) assert(not (a ~= a))
    assert(a <= a) assert(not (a < a))
    assert(a >= a) assert(not (a > a))

    a.diff = true
    assert(not (a == a)) assert(a ~= a)
  ]])
end)

it("record operator overloading", function()
  expect.run_c([[
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
    function R:__tdiv(r: R): R return R{16} end
    function R:__idiv(r: R): R return R{10} end
    function R:__div(r: R): R return R{11} end
    function R:__pow(r: R): R return R{12} end
    function R:__mod(r: R): R return R{13} end
    function R:__tmod(r: R): R return R{17} end
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
    assert((r /// r).x == 16)
    assert((r // r).x == 10)
    assert((r / r).x == 11)
    assert((r ^ r).x == 12)
    assert((r % r).x == 13)
    assert((r %%% r).x == 17)
    assert((#r).x == 14)
    assert((-r).x == 15)

    local vec2 = @record{x: number, y: number}
    local is_vec2_or_scalar = #[concept(function(b)
      return b.type.nickname == 'vec2' or b.type.is_scalar
    end)]#
    function vec2.__mul(a: is_vec2_or_scalar, b: is_vec2_or_scalar): vec2
      ## if b.type.is_scalar then
        return vec2{a.x * b, a.y * b}
      ## elseif a.type.is_scalar then
        return vec2{a * b.x, a * b.y}
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
  expect.generate_c([[
    local Math = @record{}
    global Math.PI: number <const> = 3.14
    global Math.E <const> = 2.7

    global Math.Number = @number
    local MathNumber = Math.Number
    local a: MathNumber = 1
    assert(a == 1)
  ]], "double Math_PI = 3.14")
  expect.run_c([[
    local Math = @record{}
    global Math.PI = 3.14
    assert(Math.PI == 3.14)
    Math.PI = 3
    assert(Math.PI == 3)

    local R = @record{x: integer}
    global R.values: [4]integer = {1,2,3,4}
    assert(R.values[0] == 1)
    assert(R.values[1] == 2)
    assert(R.values[2] == 3)
    assert(R.values[3] == 4)
  ]])
end)

it("records referencing itself", function()
  expect.run_c([[
    local NodeA = @record{next: *NodeA}
    local ap: *NodeA
    local a: NodeA
    assert(ap == nilptr and a.next == nilptr)

    local NodeB = @record{next: *NodeB}
    local b: NodeB
    local bp: *NodeB
    assert(bp == nilptr and b.next == nilptr)
  ]])
end)

it("enums", function()
  expect.generate_c(
    "local e: enum{A=0}",
    [[typedef int64_t enum_]])
  expect.generate_c([[
    local E = @enum{A=1, B=2}
    local i: E = 1
    local E = @enum{A=1, B=2}
    local i: E = 1
  ]], {"typedef int64_t E", "typedef int64_t E_1"})
  expect.run_c([[
    local Enum = @enum{A=0,B=1,C}
    local e: Enum; assert(e == 0)
    e = Enum.B; assert(e == 1)
    e = Enum.C; assert(e == 2)
    assert(Enum.B | Enum.C == 3)
    print(Enum.C)
  ]], "2")
end)

it("pointers", function()
  expect.generate_c("local p: pointer(float32)", "float*")
  expect.generate_c("do local p: pointer end", "void* p")
  expect.generate_c("local p: pointer(record{x:integer}); p.x = 0", "->x = ")
  expect.run_c([[
    local function f(a: pointer): pointer return a end
    local i: integer = 1
    local p: pointer(integer) = &i
    assert($p == 1)
    p = (@pointer(int64))(f(p))
    i = 2
    assert($p == 2)
    $p = 3
    assert(i == 3)
    $&i = 4
    assert(i == 4)

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
  expect.run_c([[
    local function f() return 1 end
    assert((&f)() == 1)
    assert(f() == 1)
    local g = &f
    assert(g() == 1)
    local pg = &g
    assert(($pg)() == 1)
  ]])
end)

it("automatic reference", function()
  expect.run_c([[
    local R = @record{x: integer}
    local r: R = R{1}
    local function f(x: *R) assert(x == &r) return $x end
    assert(f(r).x == 1)

    local A = @[4]integer
    local a: A = A{1}
    local function f(x: *A) assert(x == &a) return $x end
    assert(f(a)[0] == 1)

    local vec2 = @record{x: number, y: number}
    function vec2:add(a: vec2): vec2
      return vec2{self.x + a.x, self.y + a.y}
    end
    local a, b = vec2{1,2}, vec2{3,4}
    assert(a:add(b) == vec2{4,6})

    local u: union{x: integer, y: number} = {y=1.0}
    local pu = &u
    assert(pu.x == u.x)
    assert(pu.y == u.y)

    do
      local R = @record{x: integer}
      local function foo(r: *R)
        print(r.x)
      end
      local r = R()
      foo(r)
    end
  ]])
end)

it("automatic dereference", function()
  expect.run_c([[
    local R = @record{x: integer}
    local r: R = R{1}
    local pr: *R = &r
    local function f(x: R) assert(x == r) return x end
    assert(f(pr).x == 1)

    local A = @[4]integer
    local a: A = A{1}
    local pa: *A = &a
    local function f(x: A) assert(x == a) return x end
    assert(f(pa)[0] == 1)

    local vec2 = @record{x: number, y: number}
    function vec2.add(self: vec2, a: vec2): vec2
      return vec2{self.x + a.x, self.y + a.y}
    end
    local a, b = vec2{1,2}, vec2{3,4}
    assert((&a):add(&b) == vec2{4,6})
  ]])
end)

it("automatic casting", function()
  expect.generate_c([[
    local a = (@uint8)(-1)
    local b: uint8 = (@uint8)(-1)
  ]], {"a = 0xffU", "b = 0xffU"})
  expect.run_c([[
    do
      local i8: int8
      local u8: uint8 = 255
      i8 = (@int8)(u8)
      assert(i8 == -1)
    end
    do
      local i8: int8 = -1
      local u8: uint8
      u8 = (@uint8)(i8)
      assert(u8 == 255)
    end

    local function f(x: uint8)
      return x
    end
    local function g(x: int8)
      return x
    end

    local i: int8 = -1
    local u: uint8 = 255
    assert(f((@uint8)(i)) == 255)
    assert(g((@int8)(u)) == -1)
  ]])
end)

it("narrow casting", function()
  expect.run_c([[
    do
      local a: float64 = -15
      local b: int64 = a
      assert(b == -15)
    end
    do
      local a: int64 = 0xffff
      local b: int32 = a
      assert(b == 0xffff)
    end
    do
      local a: uint32 = 0xffff
      local b: int32 = a
      assert(b == 0xffff)
    end
    do
      local a: int32 = 0xffff
      local b: uint32 = a
      assert(b == 0xffff)
    end
    do
      local a: int64 = 0xffff
      local b: uint32 = a
      assert(b == 0xffff)
    end
    do
      local a: number = 3.0
      local b: uint32 = a
      assert(b == 3)
    end
  ]])
  expect.run_error_c([[
    local a: float64 = 1.5
    local b: int64 = a
  ]], "narrow casting")
  expect.run_error_c([[
    local a: int64 = 0xffffffff
    local b: int32 = a
  ]], "narrow casting")
  expect.run_error_c([[
    local a: uint32 = 0xffffffff
    local b: int32 = a
  ]], "narrow casting")
  expect.run_error_c([[
    local a: int32 = -10
    local b: uint32 = a
  ]], "narrow casting")
end)

it("implicit casting for unbounded arrays", function()
  expect.run_c([[
    local i: integer = 1
    local p: *integer = &i
    local a4: [4]integer
    local a: *[0]integer
    a = p
    p = a
    assert(i == 1)
    assert(a[0] == 1)
    assert($p == 1)
    a = &a4
    assert(a == &a4)
  ]])
end)

it("nilptr", function()
  expect.generate_c("local p: pointer = nilptr", "void* p;")
  expect.generate_c("do local p: pointer = nilptr end", "void* p = (void*)NULL;")
  expect.run_c([[
    local p: pointer = nilptr
    assert(p == nilptr)
  ]])
end)

it("manual memory managment", function()
  expect.run_c([=[
    local function malloc(size: usize): pointer <cimport'malloc',cinclude'<stdlib.h>',nodecl> end
    local function memset(s: pointer, c: int32, n: usize): pointer <cimport'memset',cinclude'<string.h>',nodecl> end
    local function free(ptr: pointer) <cimport'free',cinclude'<stdlib.h>',nodecl> end
    local p = malloc(10 * 8)
    if p then
      local a = (@pointer(array(int64, 10)))(p)
      memset(a, 0, 10*8)
      assert(a[0] == 0)
      a[0] = 1
      assert(a[0] == 1)
      free(a)
    end
  ]=])
end)

it("C varargs", function()
  expect.generate_c(
    "local function scanf(format: cstring <const>, ...: cvarargs): cint <cimport> end scanf('')",
    "int scanf(const char* format, ...);")

  expect.generate_c(
    [[local function printf(format: cstring, ...: cvarargs): cint <cimport> end printf('hello')]],
    [[printf("hello");]])

  expect.generate_c(
    [[local F = @function(cint, cvarargs); local f: F]],
    [[typedef void (*F)(int, ...);]])

  expect.run_c([=[
    local function snprintf(str: cstring, size: csize, format: cstring, ...: cvarargs): cint
      <cimport,nodecl,cinclude'<stdio.h>'>
    end

    local buf: [1024]cchar
    snprintf(&buf[0], #buf, "%s %d %.2f", 'hi'_cstring, 2, 3.14)
    assert(&buf[0] == 'hi 2 3.14')
    snprintf(&buf[0], #buf, "%d %.2f %s", 2, 3.14, 'hi'_cstring)
    assert(&buf[0] == '2 3.14 hi')

    snprintf(&buf[0], #buf, "%s %s", 'hello', 'world')
    assert(&buf[0] == 'hello world')

    local a = 'hello'
    local i = 1
    snprintf(&buf[0], #buf, '%s %d', a, (@cint)(i))
    assert(&buf[0] == 'hello 1')
  ]=])
end)

it("call pragmas", function()
  expect.generate_c([[## cinclude '<myheader.h>']], [[#include <myheader.h>]])
  expect.generate_c([[## cinclude '"myheader.h"']], [[#include "myheader.h"]])
  expect.generate_c([[## cinclude 'myfile.h'; cfile 'myfile.h']], [[#include <myfile.h>]])
  expect.generate_c([[## cinclude 'myfile.h'; cincdir '.']], [[#include <myfile.h>]])
  expect.generate_c([[## linklib 'mylib'; linkdir '.']], 'main')
  expect.generate_c("## cemit '#define SOMETHING'", "#define SOMETHING")
  expect.generate_c("## cemitdecl('#define SOMETHING')", "#define SOMETHING")
  expect.generate_c("## cemitdefn('#define SOMETHING')", "#define SOMETHING")
  expect.generate_c("## cdefine 'SOMETHING'", "#define SOMETHING")
  expect.generate_c([==[
    do ##[[cemit(function(e) e:add_ln('#define SOMETHING') end)]] end
  ]==], "#define SOMETHING")
  expect.generate_c([==[
    do ##[[cemitdecl(function(e) e:add_ln('#define SOMETHING') end)]] end
  ]==], "#define SOMETHING")
  expect.generate_c([==[
    do ##[[cemitdefn(function(e) e:add_ln('#define SOMETHING') end)]] end
  ]==], "#define SOMETHING")
end)

it("annotations", function()
  expect.generate_c("local huge: number <cimport'HUGE_VAL',cinclude'<math.h>',nodecl>", "include <math.h>")
  expect.generate_c("local a: int64 <volatile, codename 'a'>", "volatile int64_t a")
  expect.generate_c("local R <nickname 'RR'> = @record{x:integer} local r: R", "struct RR {")
  expect.generate_c("do local a: int64 <register> end",
    (ccompiler.get_cc_info().is_cpp and "" or "NELUA_REGISTER ").."int64_t a")
  expect.generate_c("local a: pointer <restrict>", "void* __restrict a")
  expect.generate_c("local a: int64 <atomic>", "NELUA_ATOMIC(int64_t) a")
  expect.generate_c("local a: int64 <threadlocal>", "NELUA_THREAD_LOCAL int64_t a")
  expect.generate_c("local a: int64 <nodecl>", "")
  expect.generate_c("local a: cint <cimport>", "NELUA_CIMPORT int a;")
  expect.generate_c("local a: int64 <noinit>; a = 2", {"a;", "a = 2;"})
  expect.generate_c("local a: int64 <cexport>", "NELUA_CEXPORT int64_t a;")
  expect.generate_c("do local a <static> = 1 end", "static int64_t a = 1;", true)
  expect.generate_c("local a: int64 <cattribute 'vector_size(16)'>", "int64_t __attribute__((vector_size(16))) a")
  expect.generate_c("local a: number <cqualifier 'in'> = 1", "in double a = 1.0;")
  expect.generate_c("local R <aligned(16)> = @record{x: integer}; local r: R",
    {"struct NELUA_ALIGNED(16) R", "sizeof(R) == 16"})
  expect.generate_c("local R <packed> = @record{x: integer, y: byte}; local r: R",
    {"struct NELUA_PACKED R", "sizeof(R) == 9"})
  expect.generate_c("local a: int64 <aligned(16)>",
    "NELUA_ALIGNAS(16) static int64_t a")
  expect.generate_c("local function f() <inline> end", "NELUA_INLINE void")
  expect.generate_c("local function f() <noreturn> end", "NELUA_NORETURN void")
  expect.generate_c("local function f() <noinline> end", "NELUA_NOINLINE void")
  expect.generate_c("local function f() <volatile> end", "volatile void")
  expect.generate_c("local function f() <nodecl> end", "")
  expect.generate_c("local function f() <nosideeffect> end", "")
  expect.generate_c("local function f() <cqualifier 'volatile'> end", "volatile void")
  expect.generate_c("local function f() <cattribute 'noinline'> end", "void __attribute__((noinline))")
  expect.generate_c(
    "local function puts(s: cstring): int32 <cimport'puts'> end puts('')",
    "int32_t puts(char* s);")
  expect.generate_c(
    "local SIG_DFL: function(cint) <const,cimport,cinclude'<signal.h>',nodecl> SIG_DFL(0)",
    "SIG_DFL(0);")
  expect.generate_c([[
    global timespec: type <cimport,cinclude'<time.h>',nodecl,ctypedef> = @record{tv_sec: clong, tv_nsec: clong}
    local t: timespec
  ]], "typedef struct timespec timespec;")
  expect.generate_c([[
    global sigval: type <cimport,cinclude'<signal.h>',nodecl,ctypedef> = @union{sival_int: cint, sival_ptr: pointer}
    local s: sigval
  ]], "typedef union sigval sigval;")
  expect.generate_c([[
    ## cemitdecl "enum MyEnum {MyEnumA, MyEnumB};"
    global MyEnum: type <cimport,nodecl,ctypedef,using> = @enum(cint){MyEnumA=0,MyEnumB=1}
    local e: MyEnum = MyEnumB
  ]], "typedef enum MyEnum MyEnum;")
  expect.generate_c(
    "local function cos(x: number): number <cimport'myfunc',cinclude'<myheader.h>',nodecl> end cos(0)",
    "#include <myheader.h>")
  expect.run_c([[
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
  expect.run_c([[
    ## cinclude '<stdlib.h>'
    local div_t <cimport,nodecl> = @record{quot: cint, rem: cint}
    local function div(numer: cint, denom: cint): div_t <cimport,nodecl> end
    local r = div(38,5)
    assert(r.quot == 7 and r.rem == 3)

    local function f() return 1, 2 end
    local a <noinit>, b <noinit>
    a, b = f()
    assert(a == 1 and b == 2)
  ]])
end)

it("type codenames", function()
  expect.generate_c([[
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
  expect.run_c([[
    print 'hello'
    local function main(): cint <entrypoint>
      print 'world'
      return 0
    end
    print 'wonderful'
  ]], "hello\nwonderful\nworld")
end)

it("hook main", function()
  expect.run_c([[
    local function nelua_main(argc: cint, nelua_argv: *cstring): cint <cimport,nodecl> end
    local function main(argc: cint, argv: *cstring): cint <entrypoint>
      print 'before'
      local ret = nelua_main(argc, argv)
      print 'after'
      return ret
    end
    print 'inside'
  ]], "before\ninside\nafter")
end)

it("print builtin", function()
  expect.run_c([[
    print(0, 1, 0.0, 1.0, 1_uinteger)
    print(1,0.2,1e2,0xf,0b01,nilptr)
    local i: integer, s: string, n: niltype, p: pointer
    print(i, s, n, p)
    local function f()
      return 'a', 1
    end
    print(f())
    local g: function()
    print(g)

    local Person = @record{name: string}
    function Person:__tostring(): string
      return self.name
    end
    local p: Person = {name='John'}
    print(p)
  ]],
    '0\t1\t0.0\t1.0\t1\n'..
    '1\t0.2\t100.0\t15\t1\t(null)\n' ..
    '0\t\tnil\t(null)\n'..
    'a\t1\n'..
    'function: (null)\n'..
    'John\n')

  expect.run_error_c([[local r: record{x: integer} print(r)]], "you could implement `__tostring`")
end)

it("sizeof builtin", function()
  expect.run_c([[
    assert(#@int8 == 1)
    assert(#@int16 == 2)
    assert(#@int32 == 4)
    assert(#@int64 == 8)
    assert(#@[4]int32 == 16)

    local A = @record{
      s: int16,   -- 2
                  -- 2 pad
      i: int32,   -- 4
      c: boolean, -- 1
                  -- 3 pad
    }
    assert(#A == 12)
    assert(#@[8]A == 96)

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
      i: int32,   -- 4
      c: cchar,   -- 1
    }
    assert(#D == 8)
  ]])
end)

it("assert builtin", function()
  local abort = config.pragmas.abort
  config.pragmas.abort = nil
  expect.generate_c(
    "assert(true)",
    "nelua_assert_line_1(true)")
  expect.generate_c(
    "assert(true, 'assertion')",
    'nelua_assert_line_1(true, ')
  expect.run_c([[
    assert(true)
    assert(true, 'assertion')
    assert(1)
    assert(0)
    assert(assert(true) == true)
    assert(assert(1) == 1)

    local function f()
      return true, 'assertion!'
    end
    assert(f())

    local f
    local function g()
      assert(f())
    end
    function f()
      return true, 'asd'
    end
    g()
  ]])
  config.pragmas.abort = 'trap'
  expect.generate_c(
    "assert(true)",
    "__builtin_trap")
  config.pragmas.abort = abort
  expect.run_error_c([[
    assert()
  ]], "assertion failed!")
  expect.run_error_c([[
    assert(false)
  ]], "assertion failed!")
  expect.run_error_c([[
    assert(false, 'assertion!')
  ]], "assertion!")
  expect.run_error_c([[
    local function f()
      return false, 'assertion!'
    end
    assert(f())
  ]], "assertion!")
end)

it("check builtin", function()
  expect.run_c([[
    local count = 0
    local function f(): boolean
      count = count + 1
      return true
    end
    check(f(), 'check1')
    ## pragmapush{nochecks=true}
    check(false, 'check2')
    ## pragmapop()
    check(f(), 'check3')
    assert(count == 2)
  ]])
  expect.run_error_c([[
    check(false, "check failed!")
  ]], "check failed!")
end)


it("error builtin", function()
  expect.run_error_c([[
    error 'got an error!'
  ]], 'got an error!')
  expect.run_error_c([[
    panic 'got an panic!'
  ]], 'got an panic!')
end)

it("warn builtin", function()
  expect.run_error_c([[
    warn 'got an warn!'
    return -1
  ]], 'got an warn!')
end)

it("likely builtin", function()
  expect.generate_c([[do
    local a = likely(true)
    local b = unlikely(false)
  end]], {
    "bool a = NELUA_LIKELY(true)",
    "b = NELUA_UNLIKELY(false)"
  })
  expect.run_c([[
    assert(likely(true))
    assert(not unlikely(false))
  ]])
end)

it("context pragmas", function()
  expect.generate_c([[
    do
      ## pragmapush{noinit = true}
      local a: integer
      ## pragmapop()
      local b: integer
    end
  ]], {
    "int64_t a;\n",
    "int64_t b = 0;\n"
  })

  expect.generate_c([[
    ## pragmapush{nocstatic = true}
    local a: integer
    local function f() end
    ## pragmapop()
    local b: integer
    local function g() end
  ]], {
    "\nint64_t a;\n",
    "\nstatic int64_t b;\n",
    "\nvoid f(void)",
    "\nstatic void g(void)",
  })

  config.pragmas.nocfloatsuffix = true
  expect.generate_c([[
    local a: float32 = 0
  ]], {
    "a = 0.0;",
  })
  config.pragmas.nocfloatsuffix = nil

  expect.generate_c([[
    ## context.pragmas.unitname = 'mylib'
    local function foo() <cexport>
    end
  ]], "NELUA_CEXPORT void mylib_foo(void);")
end)

it("require builtin", function()
  expect.generate_c([[
    require '~examples.helloworld'
  ]], "hello world")
  expect.generate_c([[
    require 'examples.helloworld'
  ]], "hello world")
  expect.generate_c([[
    require 'examples/helloworld'
  ]], "hello world")
  expect.run_c([[
    require 'examples.helloworld'
  ]], "hello world")
  expect.c_gencode_equals([[
    require 'examples.helloworld'
  ]], [[
    require 'examples.helloworld'
    require 'examples/helloworld'
  ]])
  expect.run_error_c([[
    local a = 'mylib'
    require(a)
  ]], "runtime require unsupported")
  expect.run_error_c([[
    require 'invalid_file'
  ]], "module 'invalid_file' not found")
end)

it("name collision", function()
  expect.run_c([[
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
  expect.run_c([[
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
  expect.run_c([[
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
  expect.config.srcname = 'mymod'
  expect.generate_c("local a = 1", "int64_t mymod_a = 1;")
  expect.generate_c("global a = 1", "static int64_t mymod_a = 1;\n")
  expect.generate_c("global a = 1", "static int64_t mymod_a = 1;\n")
  expect.generate_c("local function f() end", "void mymod_f(void) {\n}")
  expect.config.srcname = nil
end)

it("GC requirements", function()
  expect.generate_c([=[
    global gp: pointer
    global gr: record{x: pointer}
    global ga: [4]*integer
    global gs: string
    local p: pointer
    local r: record{x: pointer}
    local a: [4]*integer
    local s: string

    local function markp(what: pointer)
    end

    local function mark()
      ## emit_mark_static = hygienize(function(sym)
        markp(&#[sym]#)
      ## end)

      ##[[
      after_analyze(function()
        local function search_scope(scope)
          for i=1,#scope.symbols do
            local sym = scope.symbols[i]
            local symtype = sym.type or primtypes.any
            if sym:is_on_static_storage() and symtype:has_pointer() then
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

    mark()
  ]=], [[void mark(void) {
  markp((void*)(&gp));
  markp((void*)(&gr));
  markp((void*)(&ga));
  markp((void*)(&gs));
  markp((void*)(&p));
  markp((void*)(&r));
  markp((void*)(&a));
  markp((void*)(&s));
}]])
end)

it("concepts", function()
  expect.run_c([=[
    local an_array = #[concept(function(attr)
      if attr.type and attr.type.is_array then
        return true
      end
    end)]#
    local an_scalar = #[concept(function(attr)
      if attr.type.is_scalar then
        return true
      end
    end)]#
    local function f(a: an_array, x: an_scalar, len: integer)
      ## print(a.type)
      assert(a[0] == x)
    end
    local a: [4]integer = {1,2,3,4}
    local b: [3]number = {5,6,7}
    f(a, a[0], #a)
    f(b, b[0], #b)

    local R = @record{
      x: integer
    }
    function R:__convert(x: an_scalar)
      self.x = x
    end
    local r: R
    R.__convert(&r, 1)
    assert(r.x == 1)
    r:__convert(2)
    assert(r.x == 2)
  ]=])
  expect.run_c([=[
    local is_optional_integer = #[concept(function(x)
      if x.type.is_niltype then return true end
      return primtypes.integer
    end)]#
    local function g(a: integer, b: is_optional_integer): integer
      ## if b.type.is_niltype then
      return a
      ## else
      return a*a
      ## end
    end
    local function f(a: integer): integer
      return a
    end
    local R = @record{
      x: integer
    }
    assert(g(f(2)) == 2)
    assert(g(f(2), 10) == 4)
  ]=])
  expect.run_c([=[
    local R = @record{x: integer}
    function R.__convert(x: integer): R
      return R{x=x}
    end
    local is_optional_R = #[concept(function(x)
      if x.type.is_niltype then return true end
      return R
    end)]#
    local function f(x: is_optional_R): integer
      ## if x.type.is_niltype then
      return a
      ## else
      return x.x
      ## end
    end
    print(f(R{x=1}))
  ]=])
  expect.run_c([=[
    -- Concept to check whether a type is indexable.
    local indexable_concept = #[concept(function(symbol)
      local type = symbol.type
      if type.is_pointer then
        type = type.subtype
      end
      if type.is_array then
        return true
      end
      if not type.is_record then
        return false, 'the container is not a record'
      end
      if not type.metafields.__index then
        return false, 'the container must have the __index metamethod'
      end
      if not type.metafields.__len then
        return false, 'the container must have the __len metamethod'
      end
      return true
    end)]#

    local function sum_container(container: indexable_concept)
      local v: integer = 0
      for i=0,<#container do
        v = v + container[i]
      end
      return v
    end

    local MyArray = @record{data: [10]integer}

    function MyArray:__index(i: integer)
      return self.data[i]
    end

    function MyArray:__len()
      return #self.data
    end

    local a: [10]integer = {1,2,3,4,5,6,7,8,9,10}
    local b: MyArray = {data = a}

    assert(sum_container(&a) == 55)
    assert(sum_container(&b) == 55)
  ]=])
  expect.run_c([=[
    local Foo = @record{x: integer}
    function Foo.f(self: auto)
      return self.x
    end
    function Foo.g(self: #[concept(function(x) return true end)]#)
      return self.x
    end
    local foo = Foo{1}
    assert(Foo.f(foo) == 1)
    assert(Foo.g(foo) == 1)
    assert(foo:f() == 1)
    assert(foo:g() == 1)
  ]=])
end)

it("generics", function()
  expect.run_c([=[
    local arrayproxy = #[generalize(function(T, size)
      return types.ArrayType(T, size)
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

it("deprecated", function()
  expect.run_error_c([=[
    local function f() <deprecated> end
    f()

    local a: integer <deprecated>
    a = 1

    local Rec = @record{}
    function Rec:m() <deprecated> end
    local r: Rec
    r:m()

    Rec.m(r)
  ]=], {
    "use of deprecated symbol 'f'",
    "use of deprecated symbol 'a'",
    "use of deprecated method 'm'",
    "use of deprecated metafield 'm'"
  }, 0)
end)

it("forward type declaration", function()
  expect.run_c([=[
    local Level <forwarddecl> = @record{}
    local Entity = @record{level: *Level}
    Level = @record{n: integer}
    local level: Level = {n=1}
    local entity: Entity = {level = &level}
    assert(entity.level.n == 1)
    level.n = 2
    assert(entity.level.n == 2)

    local Union <forwarddecl> = @union{}
    local Union = @union{i: integer, n: number}
  ]=])
  expect.run_c([=[
    local function f(x: integer): integer <forwarddecl> end
    assert(f(1) == 1)
    function f(x: integer): integer return x end

    local Foo = @record{x: integer}
    function Foo.f(x: integer): integer <forwarddecl> end
    function Foo:g(x: integer): integer <forwarddecl> end
    assert(Foo.f(1) == 1)
    local foo: Foo = {1}
    assert(foo:g(1) == 2)
    function Foo.f(x: integer): integer return x end
    function Foo:g(x: integer): integer return self.x + x end

    local S <forwarddecl> = @record{}
    local F = @function(integer): S
    S = @record{ x: integer, f: F }
    local s: S
    s.f = function(x: integer): S
      return {x=x}
    end
    local s2 = s.f(1)
    assert(s2.x == 1)
  ]=])
  expect.run_error_c([=[
    local function f(x: integer): integer <forwarddecl> end
    assert(f(1) == 1)
  ]=], "marked as forward declaration but was never defined")
end)

it("function assignment", function()
  expect.run_c([=[
    local f
    local function g(x: integer)
      return f(x)
    end
    function f(x: integer): integer
      return x+1
    end
    assert(f(1) == 2)
    assert(g(1) == 2)

    local r: record{
      f: function(x: integer): integer
    }
    function r.f(x: integer): integer
      return x+1
    end
    assert(r.f(1) == 2)

    do
      local function f() return 1 end
      assert(f() == 1)
      function f() return 2 end
      assert(f() == 2)
    end
  ]=])
end)

it("importing type of uknown sizes", function()
  expect.run_c([=[
    local FILE <cimport,nodecl,cinclude'<stdio.h>',cincomplete> = @record{}
    local f: FILE
    assert(#FILE > 0)
    local FileRec = @record{f: FILE}
    assert(#FileRec == #FILE)
    local FileUn = @union{f: FILE, b: byte}
    assert(#FileUn == #FILE)

    local FILE <cimport,nodecl,cinclude'<stdio.h>',cincomplete,forwarddecl> = @record{}
    FILE = @record{
      x: byte
    }
    assert(#FILE ~= 1 and #FILE > 0)
  ]=])
end)

it("importing type declaration", function()
  expect.run_c([=[
    local Level <forwarddecl> = @record{}
    local Entity = @record{level: *Level}
    Level = @record{n: integer}
    local level: Level = {n=1}
    local entity: Entity = {level = &level}
    assert(entity.level.n == 1)
    level.n = 2
    assert(entity.level.n == 2)

    local Union <forwarddecl> = @union{}
    local Union = @union{i: integer, n: number}
  ]=])
end)

it("unions", function()
  expect.run_c([=[
    local Union = @union{
      b: boolean,
      i: int64,
      s: cstring
    }
    local u: Union
    assert(u.b == false and u.i == 0 and u.s == nilptr)
    u.b = true
    assert(u.b == true and u.i ~= 0 and u.s ~= nilptr)
    u.i = 15
    assert(u.i == 15 and u.s ~= nilptr)
    local s: cstring = 'hello'_cstring
    u.s = s
    assert(u.i == (@int64)(s) and u.s == s)
    local v = u
    assert(v.i == u.i and v.s == u.s)
    assert(v == u)

    do
      local U2 = @union{x: integer, a: [4]integer}
      local u: U2 = {}
      local u: U2 = {x = 1}
      local u: U2 = {a = {1,2,3,4}}
      local x = 1
      local a: [4]integer = {1,2,3,4}
      local u: U2 = {x = x} assert(u.x == x)
      u.x = 2 assert(u.x == 2)
      u = {x=3} assert(u.x == 3)
      local x2 = 4.0
      u = {x=x2} assert(u.x == 4)
      local u: U2 = {a = a} assert(u.a[2] == 3)
      u.a = (@[4]integer){2,3,4,5} assert(u.a[2] == 4)
      u = {a = {3,4,5,6}} assert(u.a[2] == 5)
    end
  ]=])
end)

it("facultative", function()
  expect.run_c([=[
    do
      local X = @record{y: integer}
      function X:A(a: facultative(string) <comptime>)
        print(a)
      end
      local z: X = {0}
      X.A(z)
      X.A(z, 'hello world')
      z:A('hello world')
    end
    do
      local function f(x: facultative(cstring)) return x end
      local function g(x: facultative(string)) return x end
      assert(#f('abc') == #'abc'_cstring)
      assert(g('abc'_cstring) == 'abc')
    end
  ]=])
end)

it("record as namespaces", function()
  expect.run_c([=[
    global Namespace = @record{}
    global Namespace.Point = @record{x: integer, y: integer}
    function Namespace.Point:mlen()
      return self.x + self.y
    end

    local function f(p: Namespace.Point): Namespace.Point
      return p
    end
    local p: Namespace.Point = {1,2}
    local p2 = f(p)
    assert(p:mlen() == 3)
    assert(p2:mlen() == 3)
  ]=])
end)

it("record initialize evaluation order", function()
  expect.generate_c([[
    local Boo = @record{x: integer}
    local Foo = @record{a: [2]Boo}
    local y = 0
    local function f(x: integer) y = x return x end
    local p: Foo = {a={{x=f(1)}, {x=f(2)}}}
  ]], [[_tmp.v[0] = (Boo){.x = f(1)};]])
  expect.generate_c([[
    local Piece = @record{
      layout: [2][3]byte,
      color: integer,
    }
    local RED = 1
    local GREEN = 2
    local PIECES: [2]Piece = {
      { layout={
          {0,0,0},
          {1,1,1},
        },
        color=RED,
      },
      { layout={
          {0,0,0},
          {1,1,1},
        },
        color=GREEN,
      },
    }
  ]], [[PIECES = (Piece_arr2){{(Piece){.layout = {{0U, 0U, 0U}, {1U, 1U, 1U}}, .color = RED}]])
  expect.run_c([=[
    local Point = @record{x: integer, y: integer}
    local function f(x: integer): integer
      print(x)
      return 1
    end
    local a: Point = {
      y=f(2),
      x=f(1),
    }
    local b: Point = {
      x=1+f(2),
      y=f(1),
    }
  ]=], "2\n1\n2\n1")
end)

it("polymorphic variable arguments", function()
  expect.generate_c([[
    local vec2 = @record{x: integer, y: integer}
    function vec2:sum(...: varargs)
      return self.x + self.y
    end
    local v: vec2 = {1,2}
    v:sum()
  ]],[[int64_t vec2_sum_1(vec2_ptr self) {
  return (self->x + self->y);
}]])

  expect.run_c([=[
    -- functions
    local function f(...: varargs)
      print(...)
      print('unpack', ...)
    end
    f()
    f('a')
    f('b', 0)
    f('c', 1, false)

    -- nesting
    local function g(...: varargs)
      f(...)
    end
    g()
    g('d')
    f('e', true)

    -- methods
    local R = @record{x: integer}
    function R:f(...: varargs)
      print(self.x, ...)
    end
    local r: R = {2}
    r:f('hello', 'world', 3)

    -- returns
    local function f(...: varargs)
      return ...
    end
    local a, b = f(1,2)
    assert(a == 1 and b == 2)

    -- assignments
    local function f(...: varargs)
      local a, b = ...
      a, b = ...
      return a + b
    end
    assert(f(1,2) == 3)

    -- operations
    local function f(...: varargs)
      local a = ... * 2
      local b = (...) * 3
      return a, b
    end
    local a, b = f(1)
    assert(a == 2 and b == 3)

    -- select
    local function f(...: varargs)
      ## for i=1,select('#', ...) do
        print(#[select(i, ...)]#)
      ## end
      print(...)
    end
    f(1,2,3)

    -- forwarding
    local function g(x: auto, ...: varargs)
      return x + ...
    end
    local function f(...: varargs)
      return g(1, ...)
    end
    assert(f(2) == 3)
  ]=], (([[
unpack
a
unpack a
b 0
unpack b 0
c 1 false
unpack c 1 false

unpack
d
unpack d
e true
unpack e true
2 hello world 3
1
2
3
1 2 3]]):gsub(' ', '\t')))

  expect.run_c([[
    local function push(...: varargs): void
      print(...)
    end

    local function resume(...: varargs): (boolean, string)
      push(...)
      return true, (@string){}
    end

    resume()
    resume(1)
    resume(1, 'test')

    local function f(...: varargs)
      local a: []integer = {...}
      return #a
    end

    assert(f() == 0)
    assert(f(1) == 1)
    assert(f(1, 2) == 2)
  ]], "1\ttest")
end)

it("record field aliases", function()
  expect.run_c([=[
    local vec3 = @record{x: number, y: number, z: number}

    ##[[
    local vec3fields = vec3.value.fields
    vec3fields.r = vec3fields.x
    vec3fields.g = vec3fields.y
    vec3fields.b = vec3fields.z
    ]]

    local col: vec3 = (@vec3){r=1.0,g=0.0,b=0.5}
    assert(col.x == 1.0 and col.y == 0.0 and col.z == 0.5)
    assert(col.r == 1.0 and col.g == 0.0 and col.b == 0.5)
    col.r = 0.0
    assert(col.r == 0.0 and col.x == 0.0)
  ]=])
end)

it("issue with multiple returns and dead code elimination", function()
  expect.run_c([=[
    local n = 0
    local function f()
      n = n + 1
      return 1, 2
    end

    local a, b = f()
    assert(b == 2)
    assert(n == 1)
  ]=])
end)

end)
