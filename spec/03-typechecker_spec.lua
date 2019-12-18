require 'busted.runner'()

local assert = require 'spec.tools.assert'
local n = require 'nelua.syntaxdefs'().astbuilder.aster
local bn = require 'nelua.utils.bn'

describe("Nelua should check types for", function()

it("analyzed ast transform", function()
  assert.analyze_ast("local a = 1; f(a)",
    n.Block{{
      n.VarDecl{'local',
        { n.IdDecl{
          assign=true,
          attr = {codename='a', name='a', type='int64', lvalue=true},
          'a' }},
        { n.Number{
          attr = {compconst=true, initializer=true, integral=true, base='dec', type='int64', value=bn.fromdec('1')},
          'dec', '1'
        }}
      },
      n.Call{
        attr = {calleetype = 'any', sideeffect = true, type='varanys'},
        {n.Id{ attr = {codename='a', name='a', type='int64', lvalue=true}, "a"}},
        n.Id{ attr = {codename='f', name='f', type='any', lvalue=true}, "f"},
        true
      }
  }})
end)

it("local variable", function()
  assert.analyze_ast([[local a: byte = 1.0]])
  assert.ast_type_equals("local a = 1", "local a: integer = 1")
  assert.analyze_error("local a: integer = 'string'", "no viable type conversion")
  assert.analyze_error("local a: byte = 1.1", "is fractional")
  assert.analyze_error("local a: byte = {1.0}", "cannot be initialized using a table literal")
  assert.analyze_error("local a, b = 1,2,3", "too many expressions in declaration")
  assert.analyze_error("local a: void", "variable declaration cannot be of the type")
end)

it("global variable", function()
  assert.ast_type_equals("global a = 1", "global a: integer = 1")
  assert.analyze_error("do global a = 1 end", "global variables can only be declared in top scope")
end)

it("name collision", function()
  assert.ast_type_equals("local a = 1; local a = 2", "local a: integer = 1; local a: integer = 2")
  assert.ast_type_equals([[
    local a, b
    do
      b = 1
      local a = 2
    end
    a = 1
  ]], [[
    local a: integer, b: integer
    do
      b = 1
      local a: integer = 2
    end
    a = 1
  ]])
end)

it("compconst variable" , function()
  assert.analyze_ast([[local N <compconst> = 255; local a: byte = N]])
  assert.analyze_ast([[local N: number <compconst> = 255; local a: byte = N]])
  assert.analyze_ast([[local N <compconst> = -1; local a: integer = N]])
  assert.analyze_ast([[local N <compconst> = -1 + -1; local a: integer = N]])
  assert.analyze_ast([[local a: integer <compconst> = 1]])
  assert.ast_type_equals(
    [[local a <compconst> = 1; local function f() return a end]],
    [[local a: integer <compconst> = 1; local function f() return a end]])
  assert.analyze_ast([[local a <compconst> = 1 * 2]])
  assert.analyze_ast([[local a <compconst> = 1 * 2 + 3]])
  assert.analyze_ast([[local a <compconst> = 1; local b <compconst> = a]])
  assert.analyze_ast([[global a <compconst> = 1]])
  assert.analyze_error("local a: integer <compconst>", "const variables must have an initial value")
  assert.analyze_error("local a: integer <compconst> = true", "no viable type conversion")
  assert.analyze_error("local a <compconst> = 1; a = 2", "cannot assign a constant variable")
  assert.analyze_error("local a = 1; local c <compconst> = a", "can only assign to constant expressions")
  assert.analyze_error("local b = 1; local c <compconst> = 1 * 2 + b", "can only assign to constant expressions")
end)

it("const variable" , function()
  assert.analyze_ast([[local a: integer <const> = 1]])
  assert.analyze_ast([[local function f(x: integer <const>) end]])
  assert.analyze_ast([[local b = 1; local a: integer <const> = b]])
  assert.analyze_error([[local a: integer <const> = 1; a = 2]], "cannot assign a constant variable")
  assert.analyze_error("local a: integer <const>", "const variables must have an initial value")
  assert.analyze_error("local function f(x: integer <const>) x = 2 end", "cannot assign a constant variable")
end)

it("numeric types coercion", function()
  assert.analyze_ast([[
    local u:usize, u8:uint8, u16:uint16, u32:uint32, u64:uint64 = 1,1,1,1,1
    local i:isize, i8:int8, i16:int16, i32:int32, i64:int64 = 1,1,1,1,1
    local f32: float32, f64: float64 = 1,1
  ]])
  assert.analyze_ast([[
    local a: uint16 = 1 + 1_u16
    local b: uint16 = 1 + 1
    local b: int16 = -1
  ]])
  assert.ast_type_equals("local a = 1 + 1_u16", "local a: uint16 = 1 + 1_u16")
  assert.ast_type_equals("local a = 1_u16 + 1", "local a: uint16 = 1_u16 + 1")
  assert.ast_type_equals("local a = 1 + 2.0_f32", "local a: float32 = 1 + 2.0_f32")
end)

it("narrow casting", function()
  assert.analyze_ast([[
    local u   = (@usize)  (0xffffffffffffffff)
    local u8  = (@uint8)  (0xffffffffffffffff)
    local u16 = (@uint16) (0xffffffffffffffff)
    local u32 = (@uint32) (0xffffffffffffffff)
    local u64 = (@uint64) (0xffffffffffffffff)
    local i   = (@isize) (-0x8000000000000000)
    local i8  = (@int8)  (-0x8000000000000000)
    local i16 = (@int16) (-0x8000000000000000)
    local i32 = (@int32) (-0x8000000000000000)
    local i64 = (@int64) (-0x8000000000000000)
  ]])
end)

it("numeric ranges", function()
  assert.analyze_ast([[
    local u:usize, u8:uint8, u16:uint16, u32:uint32, u64:uint64 = 0,0,0,0,0
  ]])
  assert.analyze_ast([[
    local u:usize = 18446744073709551615_us
    local u8:uint8, u16:uint16, u32:uint32, u64:uint64 = 255,65535,4294967295,18446744073709551615
  ]])
  assert.analyze_error([[local u: uinteger = -1_u]],   "is out of range")
  assert.analyze_error([[local u: uint8 = -1_u8]],  "is out of range")
  assert.analyze_error([[local u: uint16 = -1_u16]], "is out of range")
  assert.analyze_error([[local u: uint32 = -1_u32]], "is out of range")
  assert.analyze_error([[local u: uint64 = -1_u64]], "is out of range")
  assert.analyze_error([[local u: uinteger = 18446744073709551616_u]], 'is out of range')
  assert.analyze_error([[local u: uint8 = 256_u8]], 'is out of range')
  assert.analyze_error([[local u: uint16 = 65536_u16]], 'is out of range')
  assert.analyze_error([[local u: uint32 = 4294967296_u32]], 'is out of range')
  assert.analyze_error([[local u: uint64 = 18446744073709551616_u64]], 'is out of range')

  assert.analyze_ast([[
    local i:isize = -9223372036854775808_is
    local i8:int8, i16:int16, i32:int32, i64:int64 = -128,-32768,-2147483648,-9223372036854775808
  ]])
  assert.analyze_ast([[
    local i:isize = 9223372036854775807_is
    local i8:int8, i16:int16, i32:int32, i64:int64 = 127,32767,2147483647,9223372036854775807
  ]])
  --assert.analyze_ast([[local i: integer = -9223372036854775809]])
  assert.analyze_error([[local i = -9223372036854775809_i]], 'is out of range')
  assert.analyze_error([[local i: int8 = -129_i8]], 'is out of range')
  assert.analyze_error([[local i: int16 = -32769_i16]], 'is out of range')
  assert.analyze_error([[local i: int32 = -2147483649_i32]], 'is out of range')
  assert.analyze_error([[local i: int64 = -9223372036854775809_i64]], 'is out of range')
  assert.analyze_error([[local i: integer = 9223372036854775808_i]], 'is out of range')
  assert.analyze_error([[local i: int8 = 128_i8]], 'is out of range')
  assert.analyze_error([[local i: int16 = 32768_i16]], 'is out of range')
  assert.analyze_error([[local i: int32 = 2147483648_i32]], 'is out of range')
  assert.analyze_error([[local i: int64 = 9223372036854775808_i64]], 'is out of range')
end)

it("typed var initialization", function()
  assert.lua_gencode_equals("local a: integer", "local a: integer = 0")
  assert.lua_gencode_equals("local a: boolean", "local a: boolean = false")
  assert.lua_gencode_equals("local a: arraytable(integer)", "local a: arraytable(integer) = {}")
end)

it("loop variables", function()
  assert.ast_type_equals("for i=1,10 do end", "for i:integer=1,10 do end")
  assert.ast_type_equals("for i=1,10,2 do end", "for i:integer=1,10,2 do end")
  assert.ast_type_equals("for i=0_is,1_is-1 do end", "for i:isize=0_is,1_is-1 do end")
  assert.analyze_error("for i:byte=1.0,256 do end", "no viable type conversion")
  assert.analyze_error("for i:byte=1_byte,256 do end", "no viable type conversion")
  assert.analyze_error("for i:byte=1_byte,10_byte,2.1 do end", "no viable type conversion")
  assert.analyze_error("for i='s','b' do end", "must be a number")
  assert.analyze_error("for i=1,2,'s' do end", "no viable type conversion")
  assert.analyze_error("for i=1,2,0 do end", "step cannot be zero")
end)

it("variable assignments", function()
  assert.ast_type_equals("local a; a = 1", "local a: integer; a = 1")
  assert.analyze_error("local a: integer; a = 's'", "no viable type conversion")
  assert.analyze_error("local a, b; a, b = 1,2,3", "too many expressions in assign")
end)

it("unary operators", function()
  assert.ast_type_equals("local a = not b", "local a: boolean = not b")
  assert.ast_type_equals("local a = -1", "local a: integer = -1")
  assert.ast_type_equals("local a = -1.0", "local a: number = -1.0")
  assert.analyze_error("local x = &1", "cannot reference compile time value")
end)

it("binary operator shift", function()
  assert.ast_type_equals("local a = 1_u32 << 1", "local a: uint32 = 1_u32 << 1")
  assert.ast_type_equals("local a = 1_u16 >> 1_u32", "local a: uint16 = 1_u16 >> 1_u32")
end)

it("binary operator add", function()
  assert.ast_type_equals("local a = 1 + 2", "local a: integer = 1 + 2")
  assert.ast_type_equals("local a = 1 + 2.0", "local a: number = 1 + 2.0")
  assert.ast_type_equals("local a = 1_f32 + 2_f32", "local a: float32 = 1_f32 + 2_f32")
  assert.ast_type_equals("local a = 1_f32 + 2_f64", "local a: float64 = 1_f32 + 2_f64")
  assert.ast_type_equals("local a = 1_i8 + 2_u8",   "local a: int16 = 1_i8 + 2_u8")
  assert.ast_type_equals("local a = 1_i8 + 2_u16",  "local a: int32 = 1_i8 + 2_u16")
  assert.ast_type_equals("local a = 1_i8 + 2_u32",  "local a: int64 = 1_i8 + 2_u32")
  assert.ast_type_equals("local a = 1_i8 + 2_u64",  "local a: int64 = 1_i8 + 2_u64")
  assert.ast_type_equals("local a = 1_i8 + 2_f32",  "local a: float32 = 1_i8 + 2_f32")
  assert.ast_type_equals("local a = 1_i8 + 2_f64",  "local a: float64 = 1_i8 + 2_f64")
  assert.ast_type_equals("local a = 1_i16 + 2_u8",  "local a: int16 = 1_i16 + 2_u8")
  assert.ast_type_equals("local a = 1_i16 + 2_u16", "local a: int32 = 1_i16 + 2_u16")
  assert.ast_type_equals("local a = 1_i16 + 2_u32", "local a: int64 = 1_i16 + 2_u32")
  assert.ast_type_equals("local a = 1_i16 + 2_u64", "local a: int64 = 1_i16 + 2_u64")
  assert.ast_type_equals("local a = 1_i16 + 2_f32", "local a: float32 = 1_i16 + 2_f32")
  assert.ast_type_equals("local a = 1_i16 + 2_f64", "local a: float64 = 1_i16 + 2_f64")
  assert.ast_type_equals("local a = 1_i32 + 2_u8",  "local a: int32 = 1_i32 + 2_u8")
  assert.ast_type_equals("local a = 1_i32 + 2_u16", "local a: int32 = 1_i32 + 2_u16")
  assert.ast_type_equals("local a = 1_i32 + 2_u32", "local a: int64 = 1_i32 + 2_u32")
  assert.ast_type_equals("local a = 1_i32 + 2_u64", "local a: int64 = 1_i32 + 2_u64")
  assert.ast_type_equals("local a = 1_i32 + 2_f32", "local a: float32 = 1_i32 + 2_f32")
  assert.ast_type_equals("local a = 1_i32 + 2_f64", "local a: float64 = 1_i32 + 2_f64")
  assert.ast_type_equals("local a = 1_i64 + 2_u8",  "local a: int64 = 1_i64 + 2_u8")
  assert.ast_type_equals("local a = 1_i64 + 2_u16", "local a: int64 = 1_i64 + 2_u16")
  assert.ast_type_equals("local a = 1_i64 + 2_u32", "local a: int64 = 1_i64 + 2_u32")
  assert.ast_type_equals("local a = 1_i64 + 2_u64", "local a: int64 = 1_i64 + 2_u64")
  assert.ast_type_equals("local a = 1_i64 + 2_f32", "local a: float32 = 1_i64 + 2_f32")
  assert.ast_type_equals("local a = 1_i64 + 2_f64", "local a: float64 = 1_i64 + 2_f64")
  assert.analyze_error("local a = 1 + 's'", "is not defined between types")
  assert.analyze_error("local a = 1.0 + 's'", "is not defined between types")
end)

it("binary operator pow", function()
  assert.ast_type_equals("local a = 2 ^ 2", "local a: number = 2 ^ 2")
  assert.ast_type_equals("local a = 2_i32 ^ 2_i32", "local a: float32 = 2_i32 ^ 2_i32")
end)

it("binary operator idiv", function()
  assert.ast_type_equals("local a = 2 // 2", "local a: integer = 2 // 2")
  assert.analyze_error("local a = 1 // 0", "division by zero")
end)

it("binary operator div", function()
  assert.ast_type_equals("local a = 2 / 2", "local a: number = 2 / 2")
  assert.ast_type_equals("local a = 2_i32 / 2_i32", "local a: float32 = 2_i32 / 2_i32")
  assert.ast_type_equals(
    "local x = 1; local a = x / 2_f32",
    "local x = 1; local a: float32 = x / 2_f32")
  assert.analyze_error("local a = 1 / 0", "division by zero")
  assert.analyze_error("local a = 1 / -0", "division by zero")
  assert.ast_type_equals(
    "local a, b = 1, 2; a = b / 1",
    "local a: number, b: integer = 1, 2; a = b / 1")
end)

it("binary operator mod", function()
  assert.ast_type_equals("local a = 2_u32 % 2_u32", "local a: uint32 = 2_u32 % 2_u32")
  assert.analyze_error("local a = 1 % 0", "division by zero")
end)

it("binary operator eq", function()
  assert.ast_type_equals("local a = 1 == 2", "local a: boolean = 1 == 2")
  assert.ast_type_equals("local a = 1 == 'a'", "local a: boolean = 1 == 'a'")
end)

it("binary operator ne", function()
  assert.ast_type_equals("local a = 1 ~= 2", "local a: boolean = 1 ~= 2")
  assert.ast_type_equals("local a = 1 ~= 'a'", "local a: boolean = 1 ~= 'a'")
end)

it("binary operator bor", function()
  assert.ast_type_equals("local a = 1 | 2", "local a: integer = 1 | 2")
  assert.analyze_error("local a = 1 | 's'", "is not defined between types")
end)

it("binary operator band", function()
  assert.ast_type_equals("local a = 1 & 2", "local a: integer = 1 & 2")
  assert.analyze_error("local a = 1 & 's'", "is not defined between types")
end)

it("binary operator bxor", function()
  assert.ast_type_equals("local a = 1 ~ 2", "local a: integer = 1 ~ 2")
  assert.analyze_error("local a = 1 ~ 's'", "is not defined between types")
end)

it("binary operator shl", function()
  assert.ast_type_equals("local a = 1 << 2", "local a: integer = 1 << 2")
  assert.analyze_error("local a = 1 << 's'", "is not defined between types")
end)

it("binary operator shr", function()
  assert.ast_type_equals("local a = 1 >> 2", "local a: integer = 1 >> 2")
  assert.analyze_error("local a = 1 >> 's'", "is not defined between types")
end)

it("binary conditional and", function()
  assert.ast_type_equals("local a = 1 and 2", "local a: integer = 1 and 2")
  assert.ast_type_equals("local a = 1_i8 and 2_u8", "local a: int16 = 1_i8 and 2_u8")
  assert.ast_type_equals("local a = 1 and true", "local a: any = 1 and true")
  assert.ast_type_equals("local a = 1 and 2 or 3", "local a: integer = 1 and 2 or 3")
  assert.ast_type_equals("local a = 1 and '2'", "local a: any = 1 and '2'")
  assert.ast_type_equals("local a = 1.0 and '2'", "local a: any = 1.0 and '2'")
  assert.ast_type_equals("local a = 1.0 and 2.0_f32", "local a: float32 = 1.0 and 2.0_f32")
  assert.ast_type_equals("local a = 1.0_f32 and 2.0", "local a: float32 = 1.0_f32 and 2.0")
  assert.ast_type_equals("local a = 1.0_f32 and 2.0_f64", "local a: float64 = 1.0_f32 and 2.0_f64")
  assert.ast_type_equals("local a = 1.0_f64 and 2.0_f32", "local a: float64 = 1.0_f64 and 2.0_f32")
end)

it("binary conditional or", function()
  assert.ast_type_equals("local a = 1 or true", "local a: any = 1 or true")
  assert.ast_type_equals("local a = nilptr and false or 1", "local a: any = nilptr and false or 1")
end)

it("operation with parenthesis", function()
  assert.ast_type_equals("local a = -(1)", "local a: integer = -(1)")
end)

it("recursive late deduction", function()
  assert.ast_type_equals([[
    local a, b, c
    a = 1
    b = 2
    c = a + b
  ]],[[
    local a:integer, b:integer, c:integer
    a = 1
    b = 2
    c = a + b
  ]])
  assert.ast_type_equals([[
    local a = 1_integer
    local b = a + 1
  ]],[[
    local a: integer = 1_integer
    local b: integer = a + 1
  ]])
  assert.ast_type_equals([[
    local limit = 1_integer
    for i=1,limit do end
  ]],[[
    local limit = 1_integer
    for i:integer=1,limit do end
  ]])
end)

it("function definition", function()
  assert.analyze_ast([[
    local f
    function f() end
  ]])
  assert.analyze_ast([[
    global function f(a: integer) end
    local function f(a: integer) end
    function f(a: integer) end
  ]])
  assert.analyze_ast([[
    local f: function(integer): string
    function f(a: integer): string return '' end
  ]])
  assert.analyze_error([[
    do
      global function f() end
    end
  ]], "can only be declared in top scope")
  assert.analyze_error([[
    local f: isize
    function f(a: integer) return 0 end
  ]], "no viable type conversion")
  assert.analyze_error([[
    local function f(a: integer) end
    function f(a: integer, b:integer) end
  ]], "no viable type conversion")
  assert.analyze_error([[
    local function f(a: integer) end
    function f(a: string) end
  ]], "no viable type conversion")
  assert.analyze_error([[
    local function f(): (integer, string) return 1, '' end
    function f(): integer end
  ]], "no viable type conversion")
  assert.analyze_error([[
    local f: function():(integer, string)
    function f(): integer end
  ]], "no viable type conversion")
end)

it("function multiple argument types", function()
  assert.analyze_ast([[
    local function f(x: integer | boolean): void end
    local function g(x: integer | boolean) end
    f(1)
    g(1)
  ]])
end)

it("function return", function()
  assert.ast_type_equals(
    "local function f() return 0 end",
    "local function f(): integer return 0 end"
  )
  assert.ast_type_equals([[
    local function f()
      local a, b, c
      a = 1; b = 2; c = a + b
      return c
    end
    ]],[[
    local function f(): integer
      local a: integer, b: integer, c: integer
      a = 1; b = 2; c = a + b
      return c
    end
  ]])
  assert.ast_type_equals([[
    local f
    local x = f()
  ]],[[
    local f: any
    local x: any = f()
  ]])
  assert.analyze_ast([[
    local function f(): integer return 1 end
    local function f(): integer if true then return 1 else return 2 end end
    local function f(): integer do return 1 end end
    local function f(): integer switch a case 1 then return 1 else return 2 end end
  ]])
  assert.analyze_error([[
    local function f() end
    local a: integer = f()
  ]], "cannot assign to expressions of type void")
  assert.analyze_error([[
    local function f() end
    local a: any
    a = f()
  ]], "cannot assign to expressions of type void")
  assert.analyze_error([[
    local function f(): (integer, string) return 1 end
  ]], "missing return expression at index")
  assert.analyze_error([[
    local function f(): integer end
  ]], "return statement is missing")
  assert.analyze_error([[
    local function f(): integer if a then return 1 end end
  ]], "return statement is missing")
  assert.analyze_error([[
    local function f(x: boolean): integer
      if x then assert(true) else return 1 end
    end
  ]], "return statement is missing")
  assert.analyze_error([[
    local function f(): integer return 1, 2 end
  ]], "invalid return expression at index")
  assert.analyze_error([[
    local function f(): string return 0 end
  ]], "no viable type conversion")
end)

it("function multiple return", function()
  assert.analyze_ast([[
    local function f(): (integer, string) return 1,'s'  end
    local function g(a: boolean, b: integer, c: string) end
    g(false, f())
    local a: integer, b: string = f()
    local a: integer = f()
  ]])
  assert.analyze_ast([[
    local function f(): (integer, boolean) return 1,false  end
    local a, b, c = f()
  ]])
  assert.analyze_ast([[
    local function f(): varanys end
    local a, b, c
    a, b, c  = f()
    local x = f()
  ]])
  assert.analyze_ast([[
    local function f(): (boolean,integer) return true,1 end
    local function g(): (boolean,integer) return f() end
    local a: boolean, b: integer = g()
  ]])
  assert.analyze_ast([[
    local R = @record{x: integer}
    function R.foo(self: R*): (boolean, integer) return true, self.x end
    function R:boo(): (boolean, integer) return true, self.x end
    local r = R{}
    local function foo(): (boolean, integer) return R.foo(r) end
    local function boo(): (boolean, integer) return r:boo() end
  ]])
  assert.ast_type_equals([[
    local function f() return true,1 end
    local function g() return f() end
    local a, b = g()
  ]],[[
    local function f() return true,1 end
    local function g(): (boolean,integer) return f() end
    local a: boolean, b: integer = g()
  ]])
  assert.ast_type_equals([[
    local function f() return true,1 end
    local function g() return 's', f() end
    local a, b = g()
  ]],[[
    local function f() return true,1 end
    local function g(): (string,boolean,integer) return 's', f() end
    local a: string, b: boolean = g()
  ]])
  assert.analyze_error([[
    local function f(): (integer, boolean) return 1,false  end
    local a, b, c
    a, b, c = f()
  ]], 'is assigning to nothing in this expression')
  assert.analyze_error([[
    local function f() return 1,false  end
    local a, b, c
    a, b, c = f()
  ]], 'is assigning to nothing in this expression')
  assert.analyze_error([[
    local function f(): (integer, boolean) return 1,false  end
    local function g(a: boolean, b: integer, c: string) end
    g(false, f())
  ]], 'no viable type conversion')
  assert.analyze_error([[
    local function f(): (integer, boolean) return 1,false  end
    local a: integer, b: number = f()
  ]], 'no viable type conversion')
  assert.analyze_error([[
    local function f(): (integer, boolean) return 1,false  end
    local a: integer, b: number;
    a, b = f()
  ]], 'no viable type conversion')
  assert.analyze_error([[
    local function f(): (integer, number) return 1,'s'  end
  ]], 'no viable type conversion')
end)

it("function call", function()
  assert.ast_type_equals([[
    local function f() return 0 end
    local a = f()
  ]],[[
    local function f(): integer return 0 end
    local a: integer = f()
  ]])
  assert.analyze_ast([[local function f(a: integer) end; f(1_u32)]])
  assert.analyze_ast([[local function f(a) end; f() f(1)]])
  assert.analyze_error([[local a: integer = 1; a()]], "attempt to call a non callable variable")
  assert.analyze_error([[local function f(a: integer) end; f('a')]], "no viable type conversion")
  assert.analyze_error([[local function f(a: integer) end; f(1,1)]], "expected at most 1 arguments but got 2")
  assert.analyze_error([[local function f(a: integer) end; f()]], "expected an argument at index 1")
end)

it("for in", function()
  assert.analyze_ast([[for a in a,b,c do end]])
  assert.analyze_ast([[in a,b,c do end]])
  assert.analyze_error(
    [[local a = 1; for i in a do end]],
    "first argument of `in` expression must be a function")
  assert.analyze_error(
    [[for i in a,b,c,d do end]],
    "`in` expression can have at most")
  --[=[
  assert.ast_type_equals([[
  local function iter() return 1 end
  for i in iter do end
  ]],[[
  local function iter():integer return 1 end
  for i:integer in iter do end
  ]])
  ]=]
end)

it("array tables", function()
  assert.analyze_ast([[local a: arraytable(boolean); local len = #a]])
  assert.analyze_ast([[
    local a: arraytable(boolean)
    local b: arraytable(boolean)
    b = a
  ]])
  assert.analyze_ast([[
    local a: arraytable(boolean)
    local len = #a
  ]])
  assert.analyze_ast([[
    local a: arraytable(boolean) = {}
    local b: arraytable(boolean) = {false, true}
    local c = (@arraytable(boolean)){false, true}
    local d: arraytable(boolean); d = {false, true}
    local function f(a: arraytable(boolean)) end
    f({false, true})
  ]])
  assert.ast_type_equals([[
    local a: arraytable(boolean)
    local b = a[0]
  ]],[[
    local a: arraytable(boolean)
    local b: boolean = a[0]
  ]])
  assert.analyze_error([[
    local a: arraytable(integer)
    local b: arraytable(boolean)
    b = a
  ]], "no viable type conversion")
  assert.analyze_error([[
    local a: arraytable(integer) = {false}
  ]], "no viable type conversion")
  assert.analyze_error([[
    local a: arraytable(integer) = {a = 1}
  ]], "fields are not allowed")
  assert.analyze_error([[
    local a: arraytable(boolean)
    local b: arraytable(integer)
    b = a
  ]], "no viable type conversion")
end)

it("spans", function()
  assert.analyze_ast([[
    local a: span(boolean)
    local dataptr = a.data
    local size = a.size
    a.data = nilptr
    a.size = 0
    local b: boolean = a[0]
    a[0] = b
  ]])
  assert.analyze_ast([[
    local a: span(boolean)
    local b: span(boolean)
    b = a
  ]])
  assert.analyze_error([[
    local a: span(float64)
    local b: span(int64)
    b = a
  ]], 'no viable type conversion')
  assert.analyze_error([[local a: span(void) ]], 'spans cannot be of')
end)

it("ranges", function()
  assert.analyze_ast([[
    local a: range(integer)
    local low, high = a.low, a.high
    local b = 1:2
    low, high = b.low, b.high
  ]])
  assert.ast_type_equals([[
    local a = 1_u8:2_u16
  ]],[[
    local a: range(uint16) = 1_u8:2_u16
  ]])
  assert.analyze_error([[local a: range(string) ]], 'is not an integral type')
end)

it("arrays", function()
  --assert.analyze_ast([[local a: array(integer, (2 << 1)) ]])
  assert.analyze_ast([[local N <compconst> = 10; local a: array(integer, N) ]])
  assert.analyze_ast([[local a: array(integer, 10); a[0] = 1]])
  assert.analyze_ast([[local a: array(integer, 2) = {1,2}]])
  assert.analyze_ast([[local a: array(integer, 2); a[0] = 1; a[1] = 2]])
  assert.analyze_ast([[local a: array(integer, 2); a = {1,2}]])
  assert.analyze_ast([[local a: array(integer, 2); a = {}]])
  assert.analyze_ast([[local a: array(integer, 10), b: array(integer, 10); b = a]])
  assert.analyze_ast([[local a: array(integer, 2) <compconst> = {1,2}]])
  assert.analyze_error([[local a: array(integer, 2) = {1}]], 'expected 2 values but got 1')
  assert.analyze_error([[local a: array(integer, 2) = {1,2,3}]], 'expected 2 values but got 3')
  assert.analyze_error([[local a: array(integer, 2) = {1.1,2.3}]], 'no viable type conversion')
  assert.analyze_error([[local a: array(integer, 2) = {a=0,2}]], 'fields are not allowed')
  assert.analyze_error([[local a: array(integer, 10), b: array(integer, 11); b = a]], "no viable type conversion")
  assert.analyze_error([[local a: array(integer, 10); a[0] = 1.1]], "no viable type conversion")
  assert.analyze_error([[local a: array(integer, 1.0) ]], "expected a valid decimal integral")
  assert.analyze_error([[local Array = @array(integer, 1); local a = Array.l]], "cannot index fields")
  assert.analyze_error([[local a: array(integer, 2) = {1}]], 'expected 2 values but got 1')
  assert.analyze_error([[local a: array(integer, 2); a[-1] = 1]], 'trying to index negative value')
  assert.analyze_error([[local a: array(integer, 2); a[2] = 1]], 'is out of bounds')
  assert.analyze_error([[local a: array(integer, 2); a['s'] = 1]], 'trying to index with value of type')
  assert.analyze_error([[local a: array(integer, 2) <compconst> = {1,b}]], 'can only assign to constant expressions')
end)

it("indexing", function()
  assert.analyze_error([[local a = 1; a[1] = 2]], 'cannot index variable of type')
  assert.analyze_error([[local a = 1; a.b = 2]], 'cannot index field')
end)

it("range indexing", function()
  assert.ast_type_equals([[
    local a: integer[8]
    local s = a[0:3]
    local s2 = s[0:1]
  ]],[[
    local a: array(integer,8)
    local s: span(integer) = a[0:3]
    local s2: span(integer) = s[0:1]
  ]])
end)

it("records", function()
  assert.analyze_ast([[local a: record {x: boolean}; a.x = true]])
  assert.analyze_ast([[local a: record {x: boolean} = {}]])
  assert.analyze_ast([[local a: record {x: boolean} = {x = true}]])
  assert.analyze_ast([[local a: record {x: boolean}; a = {}]])
  assert.analyze_ast([[local a: record {x: boolean}; a = {x = true}]])
  assert.analyze_error([[local a: record {x: integer}; a.x = true]], "no viable type conversion")
  assert.analyze_error([[local a: record {x: boolean}; local b = a.y]], "does not have field named")
  assert.analyze_error([[local a: record {x: integer} = {x = true}]], "no viable type conversion")
  assert.analyze_error([[local a: record {x: boolean} = {y = 1}]], "is not present in record")
  assert.analyze_error([[local a: record {x: boolean} = {[x] = 1}]], "only string literals are allowed")
  assert.analyze_error([[local a: record {x: boolean} = {false,false}]], "field at index 2 is not valid")
  assert.analyze_ast([[
    local Record: type = @record{x: boolean}
    local a: Record, b: Record
    b = a
  ]])
  assert.analyze_ast([[
    local Record: type = @record{x: boolean}
    local a
    a = Record{x = true}
    a = Record{}
    a = Record{false}
  ]])
  assert.analyze_ast([[
    local Record: type = @record{x: integer, y: integer}
    local a
    a = Record{x=1, 2}
    a = Record{1, y=2}
  ]])
  assert.analyze_ast([[
    local Record = @record{x: boolean}
    local a <compconst> = Record{}
    local b <compconst> = Record{x=true}
  ]])
  assert.analyze_error([[
    local Record: type = @record{x: integer, y: integer}
    local a
    a = Record{y = 1, 2}
  ]], "field at index 3 is not valid")
  assert.analyze_error([[
    local a: record {x: boolean}, b: record {x: boolean}
    b = a
  ]], "no viable type conversion")
  assert.analyze_error([[
    local A, B = @record {x: boolean}, @record {x: boolean}
    local a: A, b: B
    b = a
  ]], "no viable type conversion")
  assert.analyze_error([[
    local b = false
    local Record = @record{x: boolean}
    local a <compconst> = Record{x = b}
  ]], "can only assign to constant expressions")
  assert.ast_type_equals(
    "local a: record {x: boolean}; local b = a.x",
    "local a: record {x: boolean}; local b: boolean = a.x")
  assert.ast_type_equals(
    "local a: record {x: boolean}; local b; b = a.x",
    "local a: record {x: boolean}; local b: boolean; b = a.x")
end)

it("dependent functions resolution", function()
  assert.ast_type_equals([[
    local A = @record{x:number}
    function A:foo() return self.x end
    local a = A{}
    function A:boo() return a:foo() end
    function A.boo2() return a:foo() end
    local b = a:boo()
    --local b2 = A.boo2()
  ]], [[
    local A = @record{x:number}
    function A:foo():number return self.x end
    local a = A{}
    function A:boo():number return a:foo() end
    function A.boo2():number return a:foo() end
    local b:number = a:boo()
    --local b2:number = A.boo2()
  ]])
end)

it("record methods", function()
  assert.analyze_ast([[
    local vec2 = @record{x: integer, y: integer}
    function vec2.create(x: integer, y: integer) return vec2{x,y} end
    function vec2:length() return self.x + self.y end
    local v: vec2 = vec2.create(1,2)
    local l: integer = v:length()

    local vec2pointer = @vec2*
    function vec2pointer:len() return self.x + self.y end
    l = v:len()
  ]])
  assert.analyze_error([[
    local vec2 = @record{x: integer, y: integer}
    local v: vec2 = vec2.create(1,2)
  ]], "cannot index record meta field")
  assert.analyze_error([[
    local vec2 = @record{x: integer, y: integer}
    function vec2.create(x: integer, y: integer) return vec2{x,y} end
    function vec2.create(x: integer, y: integer) return vec2{x,y+1} end
  ]], "cannot redefine meta type function")
end)

it("record globals", function()
  assert.analyze_ast([[
    local Math = @record{}
    global Math.PI = 3.14
    local a = Math.PI
  ]])
  assert.analyze_ast([[
    local Math = @record{}
    global Math.mathnumber = @number
    local mathnumber = Math.mathnumber
    local a: mathnumber = 1
  ]])
  assert.analyze_error([[
    local Math = @record{}
    global Math.PI: integer = 3
    Math.PI = 3.14
  ]], "no viable type conversion")
end)

it("type neasting", function()
  assert.analyze_ast([[
    local a: record{x: record{y: integer}}
    a.x.y = 1
    local b = a.x.y
  ]])
  assert.analyze_ast([[
    local a: record{x: record{y: integer}} = {x={y=1}}
  ]])
  assert.analyze_ast([[
    local a: record{a: array(integer, 2)}
    a.a = (@array(integer,2)){1,2}
    local b = a.a
  ]])
  assert.analyze_ast([[
    local a: record{a: array(integer, 2)} = {a={1,2}}
  ]])
end)

it("enums", function()
  assert.analyze_ast([[
    local a: enum{A=0}
    local b: enum(integer){A=0,B}
    local b: enum(byte){A=0,B,C}
    local b: enum(integer){A=0,B=1 + 2}
  ]])
  assert.analyze_ast([[
    local c <compconst> = 2
    local Enum = @enum{A=0,B=1,C=c}
    local e: Enum = Enum.A
    local i: number = e
  ]])
  assert.analyze_ast([[
    local Enum = @enum(byte){A=255}
  ]])
  assert.analyze_error([[
    local Enum = @enum(byte){A=256}
  ]], "no viable type conversion")
  assert.analyze_error([[
    local Enum = @enum(byte){A=255,B}
  ]], "is not in range of type")
  assert.analyze_error([[
    local Enum = @enum(byte){A=256_integer}
  ]], "no viable type conversion")
  assert.analyze_error([[
    local Enum = @enum{A=0,B=3}
    local e: Enum = Enum.A
    local i: string = e
  ]], "no viable type conversion")
  assert.analyze_error([[
    local Enum = @enum{A=0,B}
    local e: Enum = Enum.C
  ]], "does not have field named")
  assert.analyze_error([[
    local Enum = @enum{A,B=3}
  ]], "first field requires a initial value")
  assert.analyze_error([[
    local C: integer
    local Enum = @enum{A=C}
  ]], "enum fields can only be assigned to")
  assert.analyze_error([[
    local Enum = @enum{A=1.0}
  ]], "only integral numbers are allowed in enums")
  assert.analyze_error([[
    local Enum = @enum{A=1}
    local e: Enum
    print(e.A)
  ]], "cannot index field")
end)

it("pointers", function()
  assert.analyze_ast([[
    local a: pointer(integer) = nilptr
    local b: pointer = nilptr
    b = nilptr
    a = nilptr
  ]])
  assert.analyze_ast([[
    local a: pointer(integer)
    local b: pointer(void)
    b = a
  ]])
  assert.analyze_ast([[
    local a: pointer(integer)
    local b: pointer(integer)
    b = a
  ]])
  assert.analyze_ast([[
    local a: cstring
    local b: pointer(cchar)
    b = a
  ]])
  assert.analyze_error([[
    local a: pointer(integer)
    local b: pointer(boolean)
    b = a
  ]], "no viable type conversion")
  assert.analyze_error([[
    local a: pointer(integer)
    local b: pointer
    a = b
  ]], "no viable type conversion")
  assert.analyze_error([[local a: integer*, b: number*; b = a]], "no viable type conversion")
end)

it("automatic referencing", function()
  assert.analyze_ast([[local p: pointer(integer); local i = 1; p = &i]])
  assert.analyze_ast([[local p: pointer(integer); local i = $p]])
  assert.analyze_ast([[local p: pointer(integer); local a: integer; p = a]])
  assert.analyze_ast([[local a: integer; local function f(a: integer*) end; f(p)]])
  assert.analyze_ast([[
    local p: pointer(integer)
    local r: record{x: integer}
    p = r.x
  ]])
  assert.analyze_ast([[
    local p: pointer(integer)
    local a: integer
    local function f(): integer* return a end
    p = f()
  ]])
  assert.analyze_error([[
    local p: pointer(integer)
    p = 1
  ]], 'cannot automatic reference rvalue')
  assert.analyze_error([[
    local p: pointer(integer)
    local function f(): integer return 1 end
    p = f()
  ]], 'cannot automatic reference rvalue')
  assert.analyze_error([[
    local p: pointer(integer)
    local Record = @record{x: integer}
    p = (Record{x=1}).x
  ]], 'cannot automatic reference rvalue')
end)

it("automatic dereferencing", function()
  assert.analyze_ast([[
    local p: pointer(integer)
    local a: integer = p
  ]])
  assert.analyze_ast([[
    local p: pointer(integer)
    local a: integer
    local function f(x: integer): integer return p end
    f(p)
  ]])
  assert.analyze_error([[
    local p: pointer(integer)
    local a: number = 1
    p = a
  ]], 'no viable type conversion')
  assert.analyze_error([[
    local p: pointer
    local a: number = 1
    p = a
  ]], 'no viable type conversion')
  assert.analyze_error([[
    local function f(x: number): number return x end
    local p: pointer(integer)
    local r: record{x: integer*}
    f(r.x)
  ]], 'no viable type conversion')
end)

it("pointers to complex types", function()
  assert.analyze_ast([=[local p: pointer(record{x:isize}); p.x = 0]=])
  assert.analyze_ast([=[local p: pointer(array(isize, 10)); p[0] = 0]=])
  assert.analyze_error([=[local p: pointer(record{x:isize}); p.y = 0]=], "does not have field")
  assert.analyze_error([=[local p: pointer(array(isize, 10)); p[-1] = 0]=], "trying to index negative value")
end)

it("type construction", function()
  assert.analyze_ast("local a = (@integer)(0)")
  assert.analyze_ast("local a = (@boolean)(false)")
  assert.analyze_ast("local a = (@string)('')")
  assert.analyze_ast("local a = (@any)(nil)")
  assert.analyze_error("local a = (@integer)()", "expected one argument")
  assert.analyze_error("local a = (@integer)(1,2)", "expected one argument")
  assert.analyze_error("local a = (@integer)(false)", "no viable type conversion")
  assert.analyze_error("local a = (@integer)(nil)", "no viable type conversion")
end)

it("attributes", function()
  assert.analyze_ast("local r: record{x: integer} <aligned(8)>")
  assert.analyze_ast("local Record <aligned(8)> = @record{x: integer}")
  assert.analyze_error(
    "local function f() <cimport,nodecl> return 0 end",
    "body of an import function must be empty")
  assert.analyze_error("local a <cimport,nodecl> = 2", "cannot assign imported variables")
  assert.analyze_error([[
    local function main1() <entrypoint> end
    local function main2() <entrypoint> end
  ]], "cannot have more than one function entrypoint")
end)

it("builtins", function()
  assert.ast_type_equals("local a = type(x)", "local a: string = type(x)")
  assert.ast_type_equals("local a = #@integer", "local a: integer = #@integer")
  assert.ast_type_equals("local a = likely(a)", "local a: boolean = likely(a)")
  assert.ast_type_equals("local a = unlikely(a)", "local a: boolean = unlikely(a)")
  assert.analyze_ast("error 'an error'")
  assert.analyze_ast("warn 'an warn'")
end)

it("require builtin", function()
  assert.analyze_ast("require 'examples.helloworld'")
  assert.analyze_ast("require 'somelualib'")
  assert.analyze_ast("local a = 'dynamiclib'; require(a)")
end)

it("strict mode", function()
  assert.analyze_ast([[
    ## strict = true
    local a = 1
    local function f() return 3 end
    global b = 2
    global function g() return 4 end
    assert(a == 1 and b == 2 and f() == 3 and g() == 4)
  ]])
  assert.analyze_error("[##[ strict = true ]##] function f() return 0 end", "undeclared symbol")
  assert.analyze_error("[##[ strict = true ]##] a = 1", "undeclared symbol")
  assert.analyze_error("[##[ strict = true ]##] local a; local a", "shadows pre declared symbol")
end)

end)
