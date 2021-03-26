local lester = require 'nelua.thirdparty.lester'
local describe, it = lester.describe, lester.it

local expect = require 'spec.tools.expect'
local n = require 'nelua.syntaxdefs'().astbuilder.aster
local bn = require 'nelua.utils.bn'
local config = require 'nelua.configer'.get()

describe("type checker", function()

it("analyzed ast transform", function()
  expect.analyze_ast("local a = 1;",
    n.Block{{
      n.VarDecl{'local',
        { n.IdDecl{
          assign=true,
          attr = {
            codename='a',
            name='a',
            staticstorage=true,
            type='int64',
            vardecl=true,
            lvalue=true
          },
          'a' }},
        { n.Number{
          attr = {
            comptime=true,
            initializer=true,
            literal=true,
            base='dec',
            type='int64',
            untyped=true,
            value=bn.fromdec('1')
          },'dec', '1'
        }}
      }
  }})
end)

it("local variable", function()
  expect.analyze_ast([[local a: byte = 1]])
  expect.analyze_ast([[local a: byte = 'a'_byte]])
  expect.ast_type_equals("local a = 1", "local a: integer = 1")
  expect.analyze_error("local a: integer = 'string'", "no viable type conversion")
  expect.analyze_error("local a: byte = 1.1", "is fractional")
  expect.analyze_error("local a: byte = {1}", "cannot be initialized using a table literal")
  expect.analyze_error("local a, b = 1,2,3", "extra expressions in declaration")
  expect.analyze_error("local a: void", "variable declaration cannot be of the empty type")
  expect.analyze_error("local a: varanys", "variable declaration cannot be of the type")
  expect.analyze_error("local a: integer = 'string'_s", "literal suffix '_s' is undefined for strings")
  expect.analyze_error("local a: byte = 'aa'_byte", "literal suffix '%s' expects a string of length 1")
end)

it("global variable", function()
  expect.ast_type_equals("global a = 1", "global a: integer = 1")
  expect.analyze_error("do global a = 1 end", "global variables can only be declared in top scope")
end)

it("name collision", function()
  expect.ast_type_equals("local a = 1; local a = 2", "local a: integer = 1; local a: integer = 2")
  expect.ast_type_equals([[
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

it("comptime variable" , function()
  expect.analyze_ast([[local N <comptime> = 255; local a: byte = N]])
  expect.analyze_ast([[local N: number <comptime> = 255; local a: byte = N]])
  expect.analyze_ast([[local N <comptime> = -1; local a: integer = N]])
  expect.analyze_ast([[local N <comptime> = -1 + -1; local a: integer = N]])
  expect.analyze_ast([[local a: integer <comptime> = 1]])
  expect.ast_type_equals(
    [[local a <comptime> = 1; local function f() return a end]],
    [[local a: integer <comptime> = 1; local function f() return a end]])
  expect.analyze_ast([[local a <comptime> = 1 * 2]])
  expect.analyze_ast([[local a <comptime> = 1 * 2 + 3]])
  expect.analyze_ast([[local a <comptime> = 1; local b <comptime> = a]])
  expect.analyze_ast([[global a <comptime> = 1]])
  expect.analyze_error("local a: integer <comptime>", "const variables must have an initial value")
  expect.analyze_error("local a: integer <comptime> = true", "no viable type conversion")
  expect.analyze_error("local a <comptime> = 1; a = 2", "cannot assign a constant variable")
  expect.analyze_error("local a = 1; local c <comptime> = a", "can only assign to compile time expressions")
  expect.analyze_error("local b = 1; local c <comptime> = 1 * 2 + b", "can only assign to compile time expressions")
  expect.analyze_ast("local function f(a: integer <comptime>) end f(1)")
  expect.analyze_error(
    "local function f(a: integer <comptime>) end local a = 1 f(a)",
    "expected a compile time argument")
end)

it("const variable" , function()
  expect.analyze_ast([[local a: integer <const> = 1]])
  expect.analyze_ast([[local function f(x: integer <const>) end]])
  expect.analyze_ast([[local b = 1; local a: integer <const> = b]])
  expect.analyze_error([[local a: integer <const> = 1; a = 2]], "cannot assign a constant variable")
  expect.analyze_error("local a: integer <const>", "const variables must have an initial value")
  expect.analyze_error("local function f(x: integer <const>) x = 2 end", "cannot assign a constant variable")
  expect.analyze_error([[
    local v: record{x: integer} <const> = {x=1}
    v.x = 1
  ]], "cannot assign a constant variable")
  expect.analyze_error([[
    local v: [4]integer <const> = {1,2,3,4}
    v[1] = 1
  ]], "cannot assign a constant variable")
end)

it("auto type" , function()
  expect.ast_type_equals("local a: auto = 1", "local a: integer = 1")
  expect.ast_type_equals("local a: auto <comptime> = 1", "local a: integer <comptime> = 1")
  expect.ast_type_equals("local a: auto = 's'", "local a: string = 's'")
  expect.ast_type_equals("local a: auto = @integer", "local a: type = @integer")
  expect.analyze_error("local b; local a: auto = b", "must be assigned to expressions where type is known ahead")
  expect.analyze_error("local a: auto = nilptr", "auto variables cannot be assigned to expressions of type")
end)

it("any type", function()
  expect.analyze_ast([[local i: integer; local a: any; i = a; a = i]])
end)

it("nil type" , function()
  expect.ast_type_equals("local a = nil", "local a: any = nil")
end)

it("nilptr type" , function()
  expect.ast_type_equals("local a = nilptr", "local a: pointer = nilptr")
end)

it("numeric types coercion", function()
  expect.analyze_ast([[
    local u:usize, u8:uint8, u16:uint16, u32:uint32, u64:uint64 = 1,1,1,1,1
    local i:isize, i8:int8, i16:int16, i32:int32, i64:int64 = 1,1,1,1,1
    local f32: float32, f64: float64 = 1,1
  ]])
  expect.analyze_ast([[
    local a: uint16 = 1 + 1_u16
    local b: uint16 = 1 + 1
    local b: int16 = -1
  ]])
  expect.ast_type_equals("local a = 1 + 1_u16", "local a: uint16 = 1 + 1_u16")
  expect.ast_type_equals("local a = 1_u16 + 1", "local a: uint16 = 1_u16 + 1")
  expect.ast_type_equals("local a = 1 + 2.0_f32", "local a: float32 = 1 + 2.0_f32")
end)

it("narrow casting", function()
  expect.analyze_ast([[
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

  expect.analyze_ast([[
    local i: integer
    local n: number
    local u: uinteger
    i = u u = i
    i = n n = i
    n = u n = u
  ]])

  expect.analyze_ast([[
    local function f(u: uinteger)
      return u
    end
    local i: integer
    f(i)
  ]])
end)

it("numeric ranges", function()
  expect.analyze_ast([[
    local u:usize, u8:uint8, u16:uint16, u32:uint32, u64:uint64 = 0,0,0,0,0
  ]])

  expect.analyze_ast([[
    local u:usize = 65535_us
    local u8:uint8, u16:uint16, u32:uint32, u64:uint64 = 255,65535,4294967295,18446744073709551615
  ]])
  expect.analyze_error([[local u: uinteger = -1_u]],   "is out of range")
  expect.analyze_error([[local u: uint8 = -1_u8]],  "is out of range")
  expect.analyze_error([[local u: uint16 = -1_u16]], "is out of range")
  expect.analyze_error([[local u: uint32 = -1_u32]], "is out of range")
  expect.analyze_error([[local u: uint64 = -1_u64]], "is out of range")
  expect.analyze_error([[local u: uinteger = 18446744073709551616_u]], 'is out of range')
  expect.analyze_error([[local u: uint8 = 256_u8]], 'is out of range')
  expect.analyze_error([[local u: uint16 = 65536_u16]], 'is out of range')
  expect.analyze_error([[local u: uint32 = 4294967296_u32]], 'is out of range')
  expect.analyze_error([[local u: uint64 = 18446744073709551616_u64]], 'is out of range')

  expect.analyze_ast([[
    local i:isize = 32767_is
    local i8:int8, i16:int16, i32:int32, i64:int64 = 127,32767,2147483647,9223372036854775807
  ]])
  expect.analyze_error([[local i: integer = -9223372036854775808_i]])
  expect.analyze_error([[local i: int8 = -128_i8]], 'is out of range')
  expect.analyze_error([[local i: int16 = -32768_i16]], 'is out of range')
  expect.analyze_error([[local i: int32 = -2147483648_i32]], 'is out of range')
  expect.analyze_error([[local i: int64 = -9223372036854775808_i64]], 'is out of range')
  expect.analyze_error([[local i: integer = 9223372036854775808_i]], 'is out of range')
  expect.analyze_error([[local i: int8 = 128_i8]], 'is out of range')
  expect.analyze_error([[local i: int16 = 32768_i16]], 'is out of range')
  expect.analyze_error([[local i: int32 = 2147483648_i32]], 'is out of range')
  expect.analyze_error([[local i: int64 = 9223372036854775808_i64]], 'is out of range')
  expect.ast_type_equals("local a = -9223372036854775809", "local a: number = -9223372036854775809")
  expect.ast_type_equals(
    "local a = 9223372036854775807 + 9223372036854775807",
    "local a: integer = 9223372036854775807 + 9223372036854775807")
  expect.ast_type_equals(
    "local a = 9223372036854775807_u64 + 9223372036854775807",
    "local a: uinteger = 9223372036854775807_u64 + 9223372036854775807")
  expect.ast_type_equals("local a = 9223372036854775807", "local a: integer = 9223372036854775807")
  expect.ast_type_equals("local a = -9223372036854775807-1", "local a: integer = -9223372036854775807-1")
  expect.ast_type_equals("local a = -9223372036854775808-1", "local a: number = -9223372036854775808-1")
  expect.ast_type_equals("local a = -9223372036854775809", "local a: number = -9223372036854775809")
  expect.ast_type_equals("local a = 9223372036854775807", "local a: integer = 9223372036854775807")
  expect.ast_type_equals("local a = 9223372036854775808", "local a: number = 9223372036854775808")
end)

it("type declaration", function()
  expect.ast_type_equals(
    "local int = @integer; local a: int",
    "local int = @integer; local a: integer")
  expect.analyze_error("local int = 1; local a: int = 2", "invalid type")
  expect.analyze_error("local a: invalid = 2", "undeclared symbol")
end)

it("for loop variables", function()
  expect.ast_type_equals("for i=1,10 do end", "for i:integer=1,10 do end")
  expect.ast_type_equals("for i=1,10,2 do end", "for i:integer=1,10,2 do end")
  expect.ast_type_equals("for i=0_is,1_is-1 do end", "for i:isize=0_is,1_is-1 do end")
  expect.analyze_error("for i:byte=1.0,256 do end", "is fractional")
  expect.analyze_error("for i:byte=1_byte,256 do end", "is out of range")
  expect.analyze_error("for i:byte=256,1,-1 do end", "is out of range")
  expect.analyze_error("for i:byte=1_byte,10_byte,2.1 do end", "fractional step")
  expect.analyze_error("for i='s','b' do end", "must be a number")
  expect.analyze_error("for i=1,2,'s' do end", "invalid operation")
  expect.analyze_error("for i=1,2,0 do end", "step cannot be zero")
  expect.analyze_error("for i=integer,2 do end", "begin: cannot be of")
  expect.analyze_error("for i=1,integer do end", "end: cannot be of")
  expect.analyze_error("for i=1,2,integer do end", "step: cannot be of")
end)

it("variable assignments", function()
  expect.ast_type_equals("local a; a = 1", "local a: integer; a = 1")
  expect.analyze_error("local a: integer; a = 's'", "no viable type conversion")
  expect.analyze_error("local a, b; a, b = 1,2,3", "extra expressions in assign")
end)

it("unary operators", function()
  expect.ast_type_equals("local a = not 1", "local a: boolean = not 1")
  expect.ast_type_equals("local a = -1", "local a: integer = -1")
  expect.ast_type_equals("local a = -1.0", "local a: number = -1.0")
  expect.analyze_error("local x = &1", "cannot reference compile time value")
  expect.analyze_error([[
    local function f(): integer return 1 end
    local a = &f()
  ]], "cannot reference rvalues")
  expect.analyze_error([[
    local i = 1
    local a = &(-i)
  ]], "cannot reference rvalues")
  expect.analyze_error("local x: niltype; local b = &x", "cannot reference not addressable type")
  expect.analyze_error("local a = -'s'", "invalid operation")
  expect.ast_type_equals([[
    local x = 1_usize * #@integer
  ]],[[
    local x: usize = 1_usize * #@integer
  ]])
end)

it("unary operator not", function()
  expect.ast_type_equals("local a = ~1", "local a: integer = ~1")
  expect.ast_type_equals("local a = ~1_u32", "local a: uint32 = ~1_u32")
  expect.analyze_error("local a = ~1.0", "invalid operation")
end)

it("binary operator shift", function()
  expect.ast_type_equals("local a = 1_u32 << 1", "local a: uint32 = 1_u32 << 1")
  expect.ast_type_equals("local a = 1_u16 >> 1_u32", "local a: uint16 = 1_u16 >> 1_u32")
  expect.ast_type_equals("local a = 1_u16 >>> 1_u32", "local a: uint16 = 1_u16 >>> 1_u32")
end)

it("binary operator add", function()
  expect.ast_type_equals("local b,c; local a = b + c", "local b: any, c:any; local a: any = b + c")
  expect.ast_type_equals("local a = 1 + 2", "local a: integer = 1 + 2")
  expect.ast_type_equals("local a = 1 + 2.0", "local a: number = 1 + 2.0")
  expect.ast_type_equals("local a = 1_f32 + 2_f32", "local a: float32 = 1_f32 + 2_f32")
  expect.ast_type_equals("local a = 1_f32 + 2_f64", "local a: float64 = 1_f32 + 2_f64")
  expect.ast_type_equals("local a = 1_i8 + 2_u8",   "local a: int8 = 1_i8 + 2_u8")
  expect.ast_type_equals("local a = 1_i8 + 2_u16",  "local a: int16 = 1_i8 + 2_u16")
  expect.ast_type_equals("local a = 1_i8 + 2_u32",  "local a: int32 = 1_i8 + 2_u32")
  expect.ast_type_equals("local a = 1_i8 + 2_u64",  "local a: int64 = 1_i8 + 2_u64")
  expect.ast_type_equals("local a = 1_i8 + 2_f32",  "local a: float32 = 1_i8 + 2_f32")
  expect.ast_type_equals("local a = 1_i8 + 2_f64",  "local a: float64 = 1_i8 + 2_f64")
  expect.ast_type_equals("local a = 1_i16 + 2_u8",  "local a: int16 = 1_i16 + 2_u8")
  expect.ast_type_equals("local a = 1_i16 + 2_u16", "local a: int16 = 1_i16 + 2_u16")
  expect.ast_type_equals("local a = 1_i16 + 2_u32", "local a: int32 = 1_i16 + 2_u32")
  expect.ast_type_equals("local a = 1_i16 + 2_u64", "local a: int64 = 1_i16 + 2_u64")
  expect.ast_type_equals("local a = 1_i16 + 2_f32", "local a: float32 = 1_i16 + 2_f32")
  expect.ast_type_equals("local a = 1_i16 + 2_f64", "local a: float64 = 1_i16 + 2_f64")
  expect.ast_type_equals("local a = 1_i32 + 2_u8",  "local a: int32 = 1_i32 + 2_u8")
  expect.ast_type_equals("local a = 1_i32 + 2_u16", "local a: int32 = 1_i32 + 2_u16")
  expect.ast_type_equals("local a = 1_i32 + 2_u32", "local a: int32 = 1_i32 + 2_u32")
  expect.ast_type_equals("local a = 1_i32 + 2_u64", "local a: int64 = 1_i32 + 2_u64")
  expect.ast_type_equals("local a = 1_i32 + 2_f32", "local a: float32 = 1_i32 + 2_f32")
  expect.ast_type_equals("local a = 1_i32 + 2_f64", "local a: float64 = 1_i32 + 2_f64")
  expect.ast_type_equals("local a = 1_i64 + 2_u8",  "local a: int64 = 1_i64 + 2_u8")
  expect.ast_type_equals("local a = 1_i64 + 2_u16", "local a: int64 = 1_i64 + 2_u16")
  expect.ast_type_equals("local a = 1_i64 + 2_u32", "local a: int64 = 1_i64 + 2_u32")
  expect.ast_type_equals("local a = 1_i64 + 2_u64", "local a: int64 = 1_i64 + 2_u64")
  expect.ast_type_equals("local a = 1_i64 + 2_f32", "local a: float32 = 1_i64 + 2_f32")
  expect.ast_type_equals("local a = 1_i64 + 2_f64", "local a: float64 = 1_i64 + 2_f64")
  expect.ast_type_equals("local a = 1_i32 + 2    ", "local a: int32 = 1_i32 + 2")
  expect.ast_type_equals("local a = 1     + 2_i32", "local a: int32 = 1     + 2_i32")
  expect.ast_type_equals("local a = 1_i64 + 2.1", "local a: number = 1_i64 + 2.1")
  expect.analyze_error("local a = 1 + 's'", "invalid operation")
  expect.analyze_error("local a = 1.0 + 's'", "invalid operation")
end)

it("binary operator mul", function()
  expect.ast_type_equals("local a = 1 * 2", "local a: integer = 1 * 2")
  expect.ast_type_equals("local a = 1_f32; local b = 2.0*a",
                         "local a: float32 = 1_f32; local b: float32 = 2.0*a")
  expect.ast_type_equals("local a = 1_f32; local b = a*2.0",
                         "local a: float32 = 1_f32; local b: float32 = a*2.0")
end)

it("binary operator div", function()
  expect.ast_type_equals("local a = 2 / 2", "local a: number = 2 / 2")
  expect.ast_type_equals("local a = 2.0_f64 / 2_i64", "local a: number = 2.0_f64 / 2_i64")
  expect.ast_type_equals("local b = 1; local a = 2.0 / b", "local b = 1; local a: number = 2.0 / b")
  expect.ast_type_equals("local a = 2_i32 / 2_i32", "local a: number = 2_i32 / 2_i32")
  expect.ast_type_equals(
    "local x = 1; local a = x / 2_f32",
    "local x = 1; local a: float32 = x / 2_f32")
  expect.analyze_ast("local a = 1 / 0")
  expect.analyze_ast("local a = 1 / -0")
  expect.analyze_ast("local a = 1.0 / 0")
  expect.analyze_ast("local a = 1 / 0.0")
  expect.ast_type_equals(
    "local a, b = 1.0, 2; a = b / 1",
    "local a: number, b: integer = 1.0, 2; a = b / 1")
end)

it("binary operator idiv", function()
  expect.ast_type_equals("local a = 2 // 2", "local a: integer = 2 // 2")
  expect.analyze_error("local a = 1 // 0", "divide by zero")
  expect.analyze_ast("local a = 1.0 // 0")
  expect.analyze_ast("local a = 1 // 0.0")
end)

it("binary operator tdiv", function()
  expect.ast_type_equals("local a = 2 /// 2", "local a: integer = 2 /// 2")
  expect.analyze_error("local a = 1 /// 0", "divide by zero")
  expect.analyze_error("local a = (-9223372036854775807-1) /// -1", "divide overflow")
  expect.analyze_ast("local a = 1.0 /// 0")
  expect.analyze_ast("local a = 1 /// 0.0")
end)

it("binary operator mod", function()
  expect.ast_type_equals("local a = 2_u32 % 2_u32", "local a: uint32 = 2_u32 % 2_u32")
  expect.analyze_error("local a = 1 % 0", "divide by zero")
  expect.analyze_ast("local a = 1.0 % 0")
  expect.analyze_ast("local a = 1 % 0.0")
end)

it("binary operator tmod", function()
  expect.ast_type_equals("local a = 2_u32 %%% 2_u32", "local a: uint32 = 2_u32 %%% 2_u32")
  expect.analyze_error("local a = (-9223372036854775807-1) %%% -1", "divide overflow")
  expect.analyze_error("local a = 1 %%% 0", "divide by zero")
  expect.analyze_ast("local a = 1.0 %%% 0")
  expect.analyze_ast("local a = 1 %%% 0.0")
end)

it("binary operator pow", function()
  expect.ast_type_equals("local a = 2 ^ 2", "local a: number = 2 ^ 2")
  expect.ast_type_equals("local a = 2_i32 ^ 2_i32", "local a: number = 2_i32 ^ 2_i32")
end)

it("binary operator eq", function()
  expect.ast_type_equals("local a = 1 == 2", "local a: boolean = 1 == 2")
  expect.ast_type_equals("local a = 1 == 'a'", "local a: boolean = 1 == 'a'")
end)

it("binary operator ne", function()
  expect.ast_type_equals("local a = 1 ~= 2", "local a: boolean = 1 ~= 2")
  expect.ast_type_equals("local a = 1 ~= 'a'", "local a: boolean = 1 ~= 'a'")
end)

it("binary operator bor", function()
  expect.ast_type_equals("local a = 1 | 2", "local a: integer = 1 | 2")
  expect.analyze_error("local a = 1 | 's'", "attempt to perform a bitwise operation")
end)

it("binary operator band", function()
  expect.ast_type_equals("local a = 1 & 2", "local a: integer = 1 & 2")
  expect.ast_type_equals("local a = 1_i32 & 1", "local a: int32 = 1_i32 & 1")
  expect.analyze_error("local a = 1 & 's'", "attempt to perform a bitwise operation")
end)

it("binary operator bxor", function()
  expect.ast_type_equals("local a = 1 ~ 2", "local a: integer = 1 ~ 2")
  expect.analyze_error("local a = 1 ~ 's'", "attempt to perform a bitwise operation")
end)

it("binary operator shl", function()
  expect.ast_type_equals("local a = 1 << 2", "local a: integer = 1 << 2")
  expect.analyze_error("local a = 1 << 's'", "attempt to perform a bitwise operation")
end)

it("binary operator shr", function()
  expect.ast_type_equals("local a = 1 >> 2", "local a: integer = 1 >> 2")
  expect.analyze_error("local a = 1 >> 's'", "attempt to perform a bitwise operation")
end)

it("binary operator asr", function()
  expect.ast_type_equals("local a = 1 >>> 2", "local a: integer = 1 >>> 2")
  expect.analyze_error("local a = 1 >>> 's'", "attempt to perform a bitwise operation")
end)

it("binary conditional and", function()
  expect.ast_type_equals("local a = 1 and 2", "local a: integer = 1 and 2")
  expect.ast_type_equals("local a = 1_i8 and 2_u8", "local a: int8 = 1_i8 and 2_u8")
  expect.ast_type_equals("local a = 1 and true", "local a: any = 1 and true")
  expect.ast_type_equals("local a = 1 and 2 or 3", "local a: integer = 1 and 2 or 3")
  expect.ast_type_equals("local a = 1 and '2'", "local a: any = 1 and '2'")
  expect.ast_type_equals("local a = 1.0 and '2'", "local a: any = 1.0 and '2'")
  expect.ast_type_equals("local a = 1.0 and 2.0_f32", "local a: float32 = 1.0 and 2.0_f32")
  expect.ast_type_equals("local a = 1.0_f32 and 2.0", "local a: float32 = 1.0_f32 and 2.0")
  expect.ast_type_equals("local a = 1.0_f32 and 2.0_f64", "local a: float64 = 1.0_f32 and 2.0_f64")
  expect.ast_type_equals("local a = 1.0_f64 and 2.0_f32", "local a: float64 = 1.0_f64 and 2.0_f32")
end)

it("binary conditional or", function()
  expect.ast_type_equals("local a = 1 or true", "local a: any = 1 or true")
  expect.ast_type_equals("local a = nilptr and false or 1", "local a: any = nilptr and false or 1")
end)

it("binary operator concat", function()
  expect.analyze_ast("local a = 'a'..'b'")
  expect.analyze_error("local a = 'a' local ab = a..'b'", "invalid operation between types")
end)

it("operation with parenthesis", function()
  expect.ast_type_equals("local a = -(1)", "local a: integer = -(1)")
end)

it("late deduction", function()
  expect.ast_type_equals([[
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
  expect.ast_type_equals([[
    local a = 1
    a = true
  ]],[[
    local a: any = 1
    a = true
  ]])
  expect.ast_type_equals([[
    local a = 1_integer
    local b = a + 1
  ]],[[
    local a: integer = 1_integer
    local b: integer = a + 1
  ]])
  expect.ast_type_equals([[
    local limit = 1_integer
    for i=1,limit do end
  ]],[[
    local limit = 1_integer
    for i:integer=1,limit do end
  ]])
  expect.ast_type_equals([[
    local a
    a = a + 1
    local x = a
  ]], [[
    local a
    a = a + 1
    local x: any = a
  ]])
  expect.ast_type_equals([[
    local a
    a = a + 1
    local x = a
    local a = 2
  ]], [[
    local a: any
    a = a + 1
    local x: any = a
    local a: integer = 2
  ]])
  expect.ast_type_equals([[
    local x: integer, y: integer = 1, 2
    local x = x + y
  ]], [[
    local x: integer, y: integer = 1, 2
    local x: integer = x + y
  ]])
  expect.ast_type_equals([[
    local a = false
    local b = 2
    do
       local c = b == 1
       a = c
    end
  ]],[[
    local a: boolean = false
    local b: integer = 2
    do
       local c: boolean = b == 1
       a = c
    end
  ]])
  expect.ast_type_equals([[
    local ONE: integer <comptime> = 1
    local z = ONE
    for y=1,z do
      for x=0,y do
        local a = x
      end
    end
    z = 2.0
  ]],[[
    local ONE: integer <comptime> = 1
    local z:number = ONE
    for y:number=1,z do
      for x:number=0,y do
        local a:number = x
      end
    end
    z = 2.0
  ]])
  expect.ast_type_equals([[
    local R = @record{x: integer}
    function R:f() return (@pointer)(self) end
    local r = (@R)()
    do
      local p = r:f()
      p = nilptr
    end
  ]],[[
    local R = @record{x: integer}
    function R:f(): pointer return (@pointer)(self) end
    local r: R = (@R)()
    do
      local p: pointer = r:f()
      p = nilptr
    end
  ]])
  expect.ast_type_equals([[
    local i: integer
    local a: auto = nilptr or &i
    local b: auto = &i and nilptr

  ]],[[
    local i: integer
    local a: *integer = nilptr or &i
    local b: *integer = &i and nilptr
  ]])
  expect.ast_type_equals([[
    local a = 1_integer
    local b = 1_number
    b = b + 1_integer
    a = b
  ]],[[
    local a: number = 1_integer
    local b: number = 1_number
    b = b + 1_integer
    a = b
  ]])
  expect.ast_type_equals([[
    local a, b = 0, 0
    do
      local c = a*b
      b = c + c
    end
  ]],[[
    local a: integer, b: integer = 0, 0
    do
      local c: integer = a*b
      b = c + c
    end
  ]])
end)

it("anonymous functions", function()
  expect.analyze_ast([[
    local function foo(f: function(integer)) end
    foo(function(x: integer) end)
  ]])
  expect.analyze_error([[
    local function foo(f: function(x: integer)) end
    foo(function(x: auto) end)
  ]], "anonymous functions cannot be polymorphic")
  expect.analyze_error([[
    local function foo(f: function(x: integer): integer) end
    foo(function(x: integer): integer end)
  ]], "a return statement is missing")
end)

it("function definition", function()
  expect.analyze_ast([[
    local f
    function f() end
  ]])
  expect.analyze_ast([[
    local function f(...) end
    local function f(...: cvarargs) end
    local function f(...: varanys) end
  ]])
  expect.analyze_ast([[
    global function f(a: integer) end
    local function f(a: integer) end
    function f(a: integer) end
  ]])
  expect.analyze_ast([[
    local f: function(integer): string
    function f(a: integer): string return '' end
  ]])
  expect.analyze_error([[
    do
      global function f() end
    end
  ]], "can only be declared in top scope")
  expect.analyze_error([[
    local f: isize
    function f(a: integer) return 0 end
  ]], "no viable type conversion")
  expect.analyze_error([[
    local function f(a: integer) end
    function f(a: integer, b:integer) end
  ]], "no viable type conversion")
  expect.analyze_error([[
    local function f(a: integer) end
    function f(a: string) end
  ]], "no viable type conversion")
  expect.analyze_error([[
    local function f(): (integer, string) return 1, '' end
    function f(): integer return 1 end
  ]], "no viable type conversion")
  expect.analyze_error([[
    local f: function():(integer, string)
    function f(): integer return 1 end
  ]], "no viable type conversion")
  expect.analyze_error([[
    local f: function(): type
  ]], "return #1 cannot be of")
  expect.analyze_error([[
    local function f(): type end
  ]], "return #1 cannot be of")
end)

it("closures", function()
  expect.analyze_ast([[
    local x: integer = 1
    do
      local y: integer <comptime> = 1
      local function foo()
        print(x, y)
      end
    end
  ]])
  expect.analyze_error([[
    do
      local x: integer = 1
      local function foo()
        print(x)
      end
    end
  ]], "attempt to access upvalue")
end)

it("poly function definition", function()
  expect.analyze_ast([[
    local function f(x: auto) end
    f(1)
    f('s')
  ]])
  expect.analyze_ast([[
    local function f(x: auto) return x end
    local a = f(1)
    local b = f('s')
  ]])
  expect.analyze_ast([[
    local function f(x: auto, y: auto) return x, y end
    local a = f(1, 's')
    local b = f('s', 1)
  ]])
  expect.analyze_ast([[
    local function f(x: auto) return x end
    local a = 1
    f(a)
  ]])
  expect.analyze_ast([[
    local function f(T: type): integer
      return 1
    end
    f(@number)
  ]])
  expect.analyze_ast([[
    local function cast(T: type, value: auto)
      return (@T)(value)
    end
    local a = cast(@number, 1)
  ]])
  expect.analyze_ast([[
    local R = @record{}
    function R.foo(x: auto)
      return 1
    end
    local x = R.foo(2)
  ]])
  expect.analyze_ast([[
    local function f(x: auto): #[x.type]#
      return x
    end
    local z: integer = f(1)
  ]])
  expect.analyze_error([[
    local function f(x: auto): #[x.type]#
      return false
    end
    f(1)
  ]], "no viable type conversion from")
end)

it("function return", function()
  expect.ast_type_equals(
    "local function f() return 0 end",
    "local function f(): integer return 0 end"
  )
  expect.ast_type_equals([[
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
  expect.ast_type_equals([[
    local f
    local x = f()
  ]],[[
    local f: any
    local x: any = f()
  ]])
  expect.analyze_ast([[
    local function f(): integer return 1 end
    local function f(): integer if true then return 1 else return 2 end end
    local function f(): integer do return 1 end end
    local function f(): integer switch 1 case 1 then return 1 else return 2 end end
    local function f(): integer switch 1 case 1, 2 then return 1 else return 2 end end
    local function f(): integer error('error!') end
    local function f(): integer panic('panic!') end
    local function g() <noreturn> error'error!' end
    local function f(): integer g() end
  ]])
  expect.analyze_error([[
    local function f() end
    local a: integer = f()
  ]], "cannot assign to expressions of type 'void'")
  expect.analyze_error([[
    local function f() end
    local a: any
    a = f()
  ]], "cannot assign to expressions of type 'void'")
  expect.analyze_error([[
    local function f(): (integer, string) return 1 end
  ]], "missing return expression at index")
  expect.analyze_error([[
    local function f(): integer end
  ]], "return statement is missing")
  expect.analyze_error([[
    local function f(): integer if false then return 1 end end
  ]], "return statement is missing")
  expect.analyze_error([[
    local function f(x: boolean): integer
      if x then assert(true) else return 1 end
    end
  ]], "return statement is missing")
  expect.analyze_error([[
    local function f(): integer return 1, 2 end
  ]], "invalid return expression at index")
  expect.analyze_error([[
    local function f(): string return 0 end
  ]], "no viable type conversion")
end)

it("function multiple return", function()
  expect.analyze_ast([[
    local function f(): (integer, string) return 1,'s'  end
    local function g(a: boolean, b: integer, c: string) end
    g(false, f())
    local a: integer, b: string = f()
    local a: integer = f()
  ]])
  expect.analyze_ast([[
    local function f(): (integer, boolean) return 1,false  end
    local a, b, c = f()
  ]])
  expect.analyze_ast([[
    local function f(): varanys end
    local a, b, c
    a, b, c  = f()
    local x = f()
  ]])
  expect.analyze_ast([[
    local function f(): (boolean,integer) return true,1 end
    local function g(): (boolean,integer) return f() end
    local a: boolean, b: integer = g()
  ]])
  expect.analyze_ast([[
    local f: any
    local a, b = f()
  ]])
  expect.analyze_ast([[
    local R = @record{x: integer}
    function R.foo(self: *R): (boolean, integer) return true, self.x end
    function R:boo(): (boolean, integer) return true, self.x end
    local r = R{}
    local function foo(): (boolean, integer) return R.foo(r) end
    local function boo(): (boolean, integer) return r:boo() end
  ]])
  expect.ast_type_equals([[
    local function f() return true,1 end
    local function g() return f() end
    local a, b = g()
  ]],[[
    local function f() return true,1 end
    local function g(): (boolean,integer) return f() end
    local a: boolean, b: integer = g()
  ]])
  expect.ast_type_equals([[
    local function f() return true,1 end
    local function g() return 's', f() end
    local a, b = g()
  ]],[[
    local function f() return true,1 end
    local function g(): (string,boolean,integer) return 's', f() end
    local a: string, b: boolean = g()
  ]])
  expect.analyze_error([[
    local function f(): (integer, boolean) return 1,false  end
    local a, b, c
    a, b, c = f()
  ]], 'is assigning to nothing in the expression')
  expect.analyze_error([[
    local function f() return 1,false  end
    local a, b, c
    a, b, c = f()
  ]], 'is assigning to nothing in the expression')
  expect.analyze_error([[
    local function f(): (integer, boolean) return 1,false  end
    local function g(a: boolean, b: integer, c: string) end
    g(false, f())
  ]], 'no viable type conversion')
  expect.analyze_error([[
    local function f(): (integer, boolean) return 1,false  end
    local a: integer, b: number = f()
  ]], 'no viable type conversion')
  expect.analyze_error([[
    local function f(): (integer, boolean) return 1,false  end
    local a: integer, b: number;
    a, b = f()
  ]], 'no viable type conversion')
  expect.analyze_error([[
    local function f(): (integer, number) return 1,'s'  end
  ]], 'no viable type conversion')
end)

it("switch", function()
  expect.analyze_ast([[
    local B <comptime> = 2
    local a = 2
    switch a case 1 then case B then else end
  ]])
  expect.analyze_error(
    "switch 's' case 1 then end",
    'must be convertible to an integral')
  expect.analyze_error(
    "local a; switch a case 1 then case 1.1 then else end",
    'must evaluate to a compile time integral value')
end)

it("function call", function()
  expect.ast_type_equals([[
    local function f() return 0 end
    local a = f()
  ]],[[
    local function f(): integer return 0 end
    local a: integer = f()
  ]])
  expect.analyze_ast([[local function f(a: integer) end; f(1_u32)]])
  expect.analyze_ast([[local function f(a) end; f() f(1)]])
  expect.analyze_ast([[local function f(...: cvarargs) end; f('')]])
  expect.analyze_error([[local a: integer = 1; a()]], "cannot call type")
  expect.analyze_error([[local function f(a: integer) end; f('a')]], "no viable type conversion")
  expect.analyze_error([[local function f(a: integer) end; f(1,1)]], "expected at most 1 arguments but got 2")
  expect.analyze_error([[local function f(a: integer) end; f()]], "expected an argument at index 1")
  expect.analyze_error([[local function f(...: cvarargs) end; local r:record{} f(r)]], "invalid type")
end)

it("callbacks", function()
  expect.analyze_ast([[
    local callback_type = @function(x: integer, string): (number, boolean)
    local callback: callback_type = nilptr
  ]])
  expect.analyze_ast([[
    local callback_type = @function(*integer, [4]integer, record{x:integer}): ([4]integer, boolean)
    local callback: callback_type = nilptr
  ]])
  expect.analyze_ast([[
    local Callback = @function(*void)
    local g: function(*integer)
    local f: Callback = (@Callback)(g)
    local f: Callback = (@Callback)(nilptr)
    local p: pointer
    local f: Callback = (@Callback)(p)
    p = (@pointer)(f)
  ]])
  expect.ast_type_equals([[
    local f: function()
  ]],[[
    local f: function(): void
  ]])
  expect.analyze_error([[local r: record{f: function(x: integer)} r.f(true)]], "no viable type conversion")
end)

it("for in", function()
  expect.analyze_ast([[local a,b,c; for i in a,b,c do end]])
  expect.analyze_error(
    [[local a = 1; for i in a do end]],
    "cannot call type")
  expect.analyze_error(
    [[for i in a,b,c,d do end]],
    "`in` statement can have at most")

  --[=[
  expect.ast_type_equals([[
  local function iter() return 1 end
  for i in iter do end
  ]],[[
  local function iter():integer return 1 end
  for i:integer in iter do end
  ]])
  ]=]
end)

it("break", function()
  expect.analyze_ast("for i=1,10 do break end")
  expect.analyze_ast("while true do break end")
  expect.analyze_ast("repeat break until true")
  expect.analyze_error("break", "is not inside a loop")
  expect.analyze_error("do break end", "is not inside a loop")
  expect.analyze_error("if true then break end", "is not inside a loop")
end)

it("continue", function()
  expect.analyze_ast("for i=1,10 do continue end")
  expect.analyze_ast("while true do continue end")
  expect.analyze_ast("repeat continue until true")
  expect.analyze_error("continue", "is not inside a loop")
  expect.analyze_error("do continue end", "is not inside a loop")
  expect.analyze_error("if true then continue end", "is not inside a loop")
end)

it("goto", function()
  expect.analyze_ast("goto label ::label::")
  expect.analyze_ast("::label:: goto label")
  expect.analyze_ast("do goto label end ::label::")
  expect.analyze_ast("::label:: do goto label end")
  expect.analyze_ast("local function f() ::label:: do goto label end end")
  expect.analyze_ast("local function f() do goto label end ::label:: end")
  expect.analyze_error("::label:: ::label::", "label 'label' already defined")
  expect.analyze_error("goto label", "no visible label")
  expect.analyze_error("local function f() goto label end ::label::", "no visible label")
  expect.analyze_error("::label:: local function f() goto label end", "no visible label")
  expect.analyze_error([[defer end goto finish ::finish::]], 'cannot mix `goto` and `defer` statements')
  expect.analyze_error([[do defer end goto finish end ::finish::]], 'cannot mix `goto` and `defer` statements')
end)

it("spans", function()
  expect.analyze_ast([[
    require 'span'
    local a: span(boolean)
    local dataptr = a.data
    local size = a.size
    a.data = nilptr
    a.size = 0
    local b: boolean = a[0]
    a[0] = b
    local len = #a
  ]])
  expect.analyze_ast([[
    require 'span'
    local a: span(boolean)
    local b: span(boolean)
    b = a
  ]])
  expect.analyze_error([[
    require 'span'
    local a: span(float64)
    local b: span(int64)
    b = a
  ]], 'no viable conversion')
  expect.analyze_error([[
    require 'span'
    local v1: span(integer)
    local v2: span(*integer)
    v1 = v2
  ]], "no viable conversion from 'span(pointer(int64))' to 'span(int64)'")
  expect.analyze_error([[require 'span' local a: span(void) ]], 'spans cannot be of')
end)

it("arrays", function()
  --expect.analyze_ast([[local a: array(integer, (2 << 1)) ]])
  expect.analyze_ast([[local N <comptime> = 10; local a: array(integer, N) ]])
  expect.analyze_ast([[local a: array(integer, 10); a[0] = 1]])
  expect.analyze_ast([[local a: array(integer, 2) = {1,2}]])
  expect.analyze_ast([[local a: array(integer, 2); a[0] = 1; a[1] = 2]])
  expect.analyze_ast([[local a: array(integer, 2); a = {1,2}]])
  expect.analyze_ast([[local a: array(integer, 2); a = {}]])
  expect.analyze_ast([[local a: array(integer, 10), b: array(integer, 10); b = a]])
  expect.analyze_ast([[local a: array(integer, 2) <comptime> = {1,2}]])
  expect.analyze_ast([[local a: array(integer) = {1,2}]])
  expect.analyze_ast([[local a: array(integer, 2) = {1}]])
  expect.analyze_error([[local X = 2; local a: array(integer, X);]], "unknown comptime value for expression")
  expect.analyze_error([[local a: array(type, 4)]], 'subtype cannot be of compile-time type')
  expect.analyze_error([[local a: array(integer, 2) = {1,2,3}]], 'expected at most 2 values in array literal but got 3')
  expect.analyze_error([[local a: array(integer, 2) = {1.1,2.3}]], 'is fractional')
  expect.analyze_error([[local a: array(integer, 2) = {a=0,2}]], 'fields are disallowed')
  expect.analyze_error([[local a: array(integer, 10), b: array(integer, 11); b = a]], "no viable type conversion")
  expect.analyze_error([[local a: array(integer, 10); a[0] = 1.1]], "is fractional")
  expect.analyze_error([[local a: array(integer, 1.0) ]], "cannot have non integral type")
  expect.analyze_error([[local N <comptime> = -1 local a: array(integer, N) ]], "cannot have negative array size")
  expect.analyze_error([[local Array = @array(integer, 1); local a = Array.l]], "cannot index fields")
  expect.analyze_error([[local a: array(integer, 2); a[-1] = 1]], 'cannot index negative value')
  expect.analyze_error([[local a: array(integer, 2); a[2] = 1]], 'is out of bounds')
  expect.analyze_error([[local a: array(integer, 2); a['s'] = 1]], 'cannot index with value of type')
  expect.analyze_error([[local a: array(integer)]], 'can only infer array size for')
  expect.analyze_error([[local a: array(integer) = 1]], 'can only infer array size for')
  expect.analyze_error([[local a: *array(integer)]], 'cannot infer array size, use a fixed size')
  expect.analyze_error(
    [[local b; local a: array(integer, 2) <comptime> = {1,b}]],
    'can only assign to compile time expressions')
end)

it("indexing", function()
  expect.analyze_ast([[local a; local c = a[2] ]])
  expect.analyze_error([[local a = 1; a[1] = 2]], 'cannot index variable of type')
  expect.analyze_error([[local a = 1; a.b = 2]], 'cannot index field')
end)

it("records", function()
  expect.analyze_ast([[local R = @record{} local r: R]])
  expect.analyze_ast([[local a: record {x: boolean}; a.x = true]])
  expect.analyze_ast([[local a: record {x: boolean} = {}]])
  expect.analyze_ast([[local a: record {x: boolean} = {x = true}]])
  expect.analyze_ast([[local a: record {x: boolean}; a = {}]])
  expect.analyze_ast([[local a: record {x: boolean}; a = {x = true}]])
  expect.analyze_error([[local a: record {x: integer}; a.x = true]], "no viable type conversion")
  expect.analyze_error([[local a: record {x: boolean}; local b = a.y]], "cannot index field")
  expect.analyze_error([[local a: record {x: integer} = {x = true}]], "no viable type conversion")
  expect.analyze_error([[local a: record {x: boolean} = {y = 1}]], "is not present in record")
  expect.analyze_error([[local a: record {x: boolean} = {[x] = 1}]], "only string literals are allowed")
  expect.analyze_error([[local a: record {x: boolean} = {false,false}]], "field at index 2 is invalid")
  expect.analyze_ast([[
    local Record: type = @record{x: boolean}
    local a: Record, b: Record
    b = a
  ]])
  expect.analyze_ast([[
    local Record: type = @record{x: boolean}
    local a
    a = Record{x = true}
    a = Record{}
    a = Record{false}
  ]])
  expect.analyze_ast([[
    local Record: type = @record{x: integer, y: integer}
    local a
    a = Record{x=1, 2}
    a = Record{1, y=2}
  ]])
  expect.analyze_ast([[
    local Record = @record{x: boolean}
    local a <const> = Record{}
    local b <const> = Record{x=true}
  ]])
  expect.analyze_error([[
    local Record: type = @record{x: integer, y: integer}
    local a
    a = Record{y = 1, 2}
  ]], "field at index 3 is invalid")
  expect.analyze_error([[
    local a: record {x: boolean}, b: record {x: boolean}
    b = a
  ]], "no viable type conversion")
  expect.analyze_error([[
    local A, B = @record {x: boolean}, @record {x: boolean}
    local a: A, b: B
    b = a
  ]], "no viable type conversion")
  expect.analyze_error([[
    local Record
    local a <comptime> = Record{}
  ]], "can only assign to compile time expressions")
  expect.ast_type_equals(
    "local a: record {x: boolean}; local b = a.x",
    "local a: record {x: boolean}; local b: boolean = a.x")
  expect.ast_type_equals(
    "local a: record {x: boolean}; local b; b = a.x",
    "local a: record {x: boolean}; local b: boolean; b = a.x")
  expect.analyze_error([[
    local A, B = @record {x: boolean}, @record {x: boolean}
    local a: A, b: B
    b = a
  ]], "no viable type conversion")
  expect.analyze_error([[
    local A = @record {x: type}
  ]], "cannot be of compile-time type")
end)

it("records metamethods", function()
  expect.analyze_ast([[
    local R = @record{}
    function R:__atindex(x: integer): *integer return nilptr end
    function R:__len(): integer return 0 end
    local r: R
    local x = r[0]
    r[0] = x
    local len = #r
  ]])
  expect.analyze_error([[
    local R = @record{}
    function R:__atindex(x: integer): integer return 0 end
    local r: R
    r[0] = 1
  ]], "must return a pointer")
  expect.analyze_error([[
    local R = @record{}
    function R:__atindex(x: integer) return 0 end
    local r: R
    r[0] = 1
  ]], "must return a pointer")
  expect.analyze_error([[
    local R = @record{}
    local r: R
    local x = r[0]
  ]], "cannot index record")
  expect.analyze_error([[
    local R = @record{}
    local r: R
    local x = #r
  ]], "invalid operation")
  expect.analyze_error([[
    local R = @record{}
    local r: R
    local x = r + r
  ]], "invalid operation")
  expect.analyze_error([[
    local R = @record{f: function(*R, x: integer): integer}
    local r = R{}
    function r:f(x: boolean) return x end
  ]], "no viable type conversion")
end)

it("dependent functions resolution", function()
  expect.ast_type_equals([[
    local A = @record{x:number}
    function A:foo() return self.x end
    local a = A{}
    function A:boo() return a:foo() end
    function A.boo2() return a:foo() end
    local b = a:boo()
    local b2 = A.boo2()
  ]], [[
    local A = @record{x:number}
    function A:foo():number return self.x end
    local a = A{}
    function A:boo():number return a:foo() end
    function A.boo2():number return a:foo() end
    local b:number = a:boo()
    local b2: number = A.boo2()
  ]])

  expect.ast_type_equals([[
    local Foo = @record{x: integer}
    local foo = Foo{x=0}
    function Foo:f() return 1.0 end
    local function f() return foo:f() end
    local x = f()
  ]], [[
    local Foo: type = @record{x: integer}
    local foo: Foo = Foo{x=0}
    function Foo:f(): number return 1.0 end
    local function f(): number return foo:f() end
    local x: number = f()
  ]])
end)

it("record methods", function()
  expect.analyze_ast([[
    local vec2 = @record{x: integer, y: integer}
    function vec2.create(x: integer, y: integer) return vec2{x,y} end
    function vec2:length() return self.x + self.y end
    local v: vec2 = vec2.create(1,2)
    local l: integer = v:length()

    local vec2pointer = @*vec2
    function vec2pointer:len() return self.x + self.y end
    l = v:len()
  ]])
  expect.analyze_error([[
    local vec2 = @record{x: integer, y: integer}
    function vec2.gen(x: integer) vec2{x, x} end
    local a: vec2
    local b = a:gen(1)
  ]], "no viable type conversion")
  expect.analyze_error([[
    local vec2 = @record{x: integer, y: integer}
    local v: vec2 = vec2.create(1,2)
  ]], "cannot index meta field")
  expect.analyze_error([[
    local vec2 = @record{x: integer, y: integer}
    local v: vec2
    local x = v:length()
  ]], "cannot index meta field")
  expect.analyze_error([[
    local vec2 = @record{x: integer, y: integer}
    function vec2.create(x: integer, y: integer) return vec2{x,y} end
    function vec2.create(x: integer, y: integer) return vec2{x,y+1} end
  ]], "cannot redefine meta type field")
  expect.analyze_error([[
    local A = @record{}
    global A.a: integer
    global A.a: integer
  ]], "cannot redefine meta type field")
  expect.analyze_error([[
    local B = @record {a: integer}
    global B.lol: function():integer
    function B.lol() return 1 end
  ]], "cannot redefine meta type field")
  expect.analyze_error([[
    local R = @record{}
    function R.hello() end
    local x: R
    x:hello()
  ]], "the function cannot have arguments")
  expect.analyze_error([[
    local R = @record{}
    R:add()
  ]], 'cannot call method')
end)

it("record globals", function()
  expect.analyze_ast([[
    local Math = @record{}
    global Math.PI = 3.14
    local a = Math.PI
  ]])
  expect.analyze_ast([[
    local Math = @record{}
    global Math.mathnumber = @number
    local mathnumber = Math.mathnumber
    local a: mathnumber = 1
  ]])
  expect.analyze_error([[
    local Math = @record{}
    global Math.PI: integer = 3
    Math.PI = 3.14
  ]], "is fractional")
end)

it("type neasting", function()
  expect.analyze_ast([[
    local a: record{x: record{y: integer}}
    a.x.y = 1
    local b = a.x.y
  ]])
  expect.analyze_ast([[
    local a: record{x: record{y: integer}} = {x={y=1}}
  ]])
  expect.analyze_ast([[
    local a: record{a: array(integer, 2)}
    a.a = (@array(integer,2)){1,2}
    local b = a.a
  ]])
  expect.analyze_ast([[
    local a: record{a: array(integer, 2)} = {a={1,2}}
  ]])
end)

it("enums", function()
  expect.analyze_ast([[
    local a: enum{A=0}
    local b: enum(integer){A=0,B}
    local b: enum(byte){A=0,B,C}
    local b: enum(integer){A=0,B=1 + 2}
  ]])
  expect.analyze_ast([[
    local c <comptime> = 2
    local Enum = @enum{A=0,B=1,C=c}
    local e: Enum = Enum.A
    local i: number = e
  ]])
  expect.analyze_ast([[
    local Enum = @enum{A=0}
    local x <comptime> = Enum.A
  ]])
  expect.analyze_ast([[
    local Enum = @enum(byte){A=255}
  ]])
  expect.analyze_error([[
    local e: enum(byte){A=255}
    e = 257
  ]], "is out of range")
  expect.analyze_error([[
    local Enum = @enum(byte){A=256}
  ]], "is out of range")
  expect.analyze_error([[
    local Enum = @enum(byte){A=255,B}
  ]], "is out of range")
  expect.analyze_error([[
    local Enum = @enum(byte){A=256_integer}
  ]], "is out of range")
  expect.analyze_error([[
    local Enum = @enum{A=0,B=3}
    local e: Enum = Enum.A
    local i: string = e
  ]], "no viable type conversion")
  expect.analyze_error([[
    local Enum = @enum{A=0,B}
    local e: Enum = Enum.C
  ]], "cannot index field")
  expect.analyze_error([[
    local Enum = @enum{A,B=3}
  ]], "first enum field requires an initial value")
  expect.analyze_error([[
    local C: integer
    local Enum = @enum{A=C}
  ]], "enum fields can only be assigned to")
  expect.analyze_error([[
    local Enum = @enum{A=1.0}
  ]], "only integral types are allowed in enums")
  expect.analyze_error([[
    local Enum = @enum{A=1}
    local e: Enum
    print(e.A)
  ]], "cannot index field")
end)

it("pointers", function()
  expect.analyze_ast([[
    local a: pointer(integer) = nilptr
    local b: pointer = nilptr
    b = nilptr
    a = nilptr
  ]])
  expect.analyze_ast([[
    local x: usize = 1
    local p: pointer = (@pointer)(x)
    x = (@usize)(p)
  ]])
  expect.analyze_ast([[
    local a: *cchar
    local aa: *[0]cchar
    local b: *byte
    local bb: *[0]byte
    a = aa
    a = b
    a = bb
    aa = aa
    aa = b
    aa = bb
    b = a
    b = aa
    b = bb
    bb = a
    bb = aa
    bb = bb
  ]])
  expect.analyze_ast([[
    local a: **cchar
    local b: **byte
    b = a
  ]])
  expect.ast_type_equals(
    "local a = (@pointer)(nilptr) a = nilptr",
    "local a: pointer = (@pointer)(nilptr) a = nilptr")
  expect.ast_type_equals(
    "local a = nilptr a = (@pointer)(nilptr)",
    "local a: pointer = nilptr a = (@pointer)(nilptr)")
  expect.analyze_ast([[
    local a: pointer(integer) = nilptr
    local b: pointer = nilptr
    b = nilptr
    a = nilptr
  ]])
  expect.analyze_ast([[
    local a: pointer(integer)
    local b: pointer(void)
    b = a
  ]])
  expect.analyze_ast([[
    local a: pointer(integer)
    local b: pointer(integer)
    b = a
  ]])
  expect.analyze_ast([[
    local a: cstring
    local b: pointer(cchar)
    b = a
  ]])
  expect.analyze_error([[
    local x: byte = 1
    local p: pointer = (@pointer)(x)
  ]], "no viable type conversion")
  expect.analyze_error([[
    local p: pointer
    local x: byte = (@byte)(p)
  ]], "no viable type conversion")
  expect.analyze_error([[
    local a: pointer(integer)
    local b: pointer(boolean)
    b = a
  ]], "no viable type conversion")
  expect.analyze_error([[
    local a: pointer(integer)
    local b: pointer
    a = b
  ]], "no viable type conversion")
  expect.analyze_error([[local a: *integer, b: *number; b = a]], "no viable type conversion")
  expect.analyze_error("local a: *auto", "is not addressable thus cannot have a pointer")
  expect.analyze_error("local a: *type", "is not addressable thus cannot have a pointer")
end)

it("dereferencing and referencing", function()
  expect.analyze_ast([[local p: pointer(integer); local i = $p]])
  expect.analyze_ast([[local p: pointer(integer); local i = 1; p = &i]])
end)

it("automatic referencing", function()
  expect.analyze_ast([[
    local R = @record{x: integer}
    local r: R
    local function fr(x: *R) end
    fr(r)

    local A = @[4]integer
    local a: A
    local function fa(x: *A) end
    fa(a)
  ]])
  expect.analyze_error(
    [[local p: pointer(integer); local a: integer; p = a]],
    "no viable type conversion")
  expect.analyze_error([[
    local R = @record{x: integer}
    local p: pointer(R)
    local r: record{x: R}
    p = r.x
  ]], "no viable type conversion")
  expect.analyze_error([[
    local A = @record{x: integer}
    local B = @record{a: A}
    function B:f() local i: *A = self.a end
  ]], "no viable type conversion")
  expect.analyze_error([[
    local R = @record{x: integer}
    local p: pointer(R)
    local r: record{x: R}
    p = (@pointer(R))(r.x)
  ]], 'no viable type conversion')
  expect.analyze_error([[
    local R = @record{x: integer}
    local p: pointer(R)
    p = R{}
  ]], 'no viable type conversion')
  expect.analyze_error([[
    local R = @record{x: integer}
    local p: pointer(R)
    local function f(): R return R{} end
    p = f()
  ]], 'no viable type conversion')
  expect.analyze_error([[
    local R = @record{x: integer}
    local function fr(x: *R) end
    fr(R{})
  ]], 'cannot automatic reference rvalue')
end)

it("automatic dereferencing", function()
  expect.analyze_ast([[
    local R = @record{x: integer}
    local pr: pointer(R)
    local function fr(x: R) end
    fr(pr)

    local A = @[4]integer
    local pa: pointer(A)
    local function fa(x: A) end
    fa(pa)
  ]])
  expect.analyze_error([[
    local R = @record{x: integer}
    local p: pointer(R)
    local a: R = p
  ]], 'no viable type conversion')
  expect.analyze_error([[
    local A = @[4]integer
    local p: pointer(A)
    local a: A = p
  ]], 'no viable type conversion')
  expect.analyze_error([[
    local R = @record{x: integer}
    local p: pointer(R)
    local a: R = (@R)(p)
  ]], 'no viable type conversion')
  expect.analyze_error([[
    local p: pointer(integer)
    local a: integer = p
  ]], 'no viable type conversion')
  expect.analyze_error([[
    local p: pointer(integer)
    local a: number = 1
    p = a
  ]], 'no viable type conversion')
  expect.analyze_error([[
    local p: pointer
    local a: number = 1
    p = a
  ]], 'no viable type conversion')
end)

it("pointers to complex types", function()
  expect.analyze_ast([=[local p: pointer(record{x:isize}); p.x = 0]=])
  expect.analyze_ast([=[local p: pointer(array(isize, 10)); p[0] = 0]=])
  expect.analyze_error([=[local p: pointer(record{x:isize}); p.y = 0]=], "cannot index field")
  expect.analyze_error([=[local p: pointer(array(isize, 10)); p[-1] = 0]=], "cannot index negative value")
end)

it("type construction", function()
  expect.analyze_ast("local a = (@integer)()")
  expect.analyze_ast("local a = (@integer)(0)")
  expect.analyze_ast("local a = (@boolean)(false)")
  expect.analyze_ast("local a = (@string)('')")
  expect.analyze_ast("local a = (@any)(nil)")
  expect.analyze_error("local a = (@integer)(1,2)", "expected at most 1 argument")
  expect.analyze_error("local a = (@integer)(false)", "no viable type conversion")
  expect.analyze_error("local a = (@integer)(nil)", "no viable type conversion")
end)

it("type casting", function()
  expect.analyze_error([[
    local R = @record{}
    local a = 'b'
    local b = (@R)(a)
  ]], "no viable type conversion")
end)

it("annotations", function()
  expect.analyze_ast("local r: record{x: integer} <aligned(8)>")
  expect.analyze_ast("local Record <aligned(8)> = @record{x: integer}")
  expect.analyze_ast("local Record: type <aligned(8)> = @record{x: integer}")
  expect.analyze_error(
    "local function f() <cimport,nodecl> return 0 end",
    "body of an import function must be empty")
  expect.analyze_error("local a <cimport>", "must have an explicit type")
  expect.analyze_error("local a: integer <cimport,nodecl> = 2", "cannot assign imported variables")
  expect.analyze_error([[
    local function main1() <entrypoint> end
    local function main2() <entrypoint> end
  ]], "cannot have more than one function entrypoint")
  expect.analyze_error("local a <nodecl(1)>", "takes no arguments")
  expect.analyze_error("local a <entrypoint>", "is undefined for variables")
  expect.analyze_error("local a <codename(1)>", "arguments are invalid")
end)

it("cimport", function()
  expect.analyze_ast([[
    local FILE <cimport, nodecl, cinclude'<stdio.h>', forwarddecl> = @record{}
    local a: *FILE
    local FILE <cimport, nodecl, cinclude'<stdio.h>', forwarddecl> = @record{}
    local b: *FILE
    b = a
  ]])
end)

it("builtins", function()
  expect.ast_type_equals("local x; local a = type(x)", "local x; local a: string = type(x)")
  expect.ast_type_equals("local a = #@integer", "local a: isize = #@integer")
  expect.ast_type_equals("local a = likely(true)", "local a: boolean = likely(true)")
  expect.ast_type_equals("local a = unlikely(true)", "local a: boolean = unlikely(true)")
  expect.analyze_ast("error 'an error'")
  expect.analyze_ast("warn 'an warn'")
  expect.analyze_error("assert(true,'asd', 2)", 'expected at most')
  expect.analyze_error("print:find()", "cannot call method")
  expect.analyze_error("print():find()", 'cannot call type')
end)

it("require builtin", function()
  config.generator = 'lua'
  expect.analyze_ast("require 'examples.helloworld'")
  expect.analyze_ast("require 'somelualib'")
  expect.analyze_ast("local a = 'dynamiclib'; require(a)")
  config.generator = 'c'
  expect.analyze_ast("require 'examples.helloworld'")
  expect.analyze_error("require 'somelualib'", 'not found')
  expect.analyze_error("local a = 'dynamiclib'; require(a)", 'runtime require unsupported')
  config.generator = nil
end)

it("strict mode", function()
  expect.analyze_ast([[
    local a = 1
    local function f() return 3 end
    global b = 2
    global function g() return 4 end
    assert(a == 1 and b == 2 and f() == 3 and g() == 4)
  ]])
  expect.analyze_error("function f() return 0 end", "undeclared symbol")
  expect.analyze_error("a = 1", "undeclared symbol")
end)

it("concepts", function()
  expect.analyze_ast([[
    local an_integral = #[concept(function(x)
      return x.type.is_integral
    end)]#
    ## static_assert(an_integral.value:is_convertible_from_type(primtypes.integer))
    local an_integer_array = #[concept(function(x)
      return x.type:is_array_of(primtypes.integer)
    end)]#
    ## static_assert(an_integral.value ~= an_integer_array.value)
    local function f(x: an_integral) return x end
    local function g(x: an_integer_array) return #x end
    f(1_uinteger)
    f(2_uinteger)
    f(3)
    f(4)
    g((@[2]integer){1,2})
    g((@[3]integer){1,2,3})

    local function h(x: #[facultative_concept(integer)]#) end
    local function h(x: facultative(integer)) end
    local function g(x: #[overload_concept(integer,niltype)]#) end
    local function g(x: overload(integer,niltype)) end

    local R = @record{x: integer}
    local function f(a: R, x: facultative(integer)) end
    f(R{1})
  ]])
  expect.analyze_error([[
    local an_integral = #[concept(function(x)
      return x.type.is_integral
    end)]#
    local function f(x: an_integral) return x end
    f(true)
  ]], "could not match concept")
  expect.analyze_error([[
    local my_concept = #[concept(function(x)
      return primtypes.integer
    end)]#
    local function f(x: my_concept) return x end
    f(true)
  ]], "no viable type conversion")
  expect.analyze_error([[
    local an_integral = #[concept(function(x)
      return primtypes.type
    end)]#
    local function f(x: an_integral) return x end
    f(true)
  ]], "invalid return for concept")
  expect.analyze_error([[
    local an_integral = #[concept(function(x)
      return 1
    end)]#
    local function f(x: an_integral) return x end
    f(true)
  ]], "invalid return for concept")
  expect.analyze_error([[
    local R = 1
    local an_integral = #[concept(function(x)
      return R
    end)]#
    local function f(x: an_integral) return x end
    f(true)
  ]], "invalid return for concept")
  expect.analyze_ast([[
    local io = @record{x: integer}
    local function f(x: #[overload_concept({io})]#): integer return x.x end
    f(io{})
  ]])
  expect.analyze_error([[
    local function f(x: #[overload_concept({integer, string})]#) return x end
    f(true)
  ]], "cannot match overload concept")
  expect.analyze_error([[
    local function f(x: #[overload_concept({integer, 1})]#) return x end
    f(true)
  ]], "in overload concept definition")
  expect.analyze_error([[
    local function f(x: #[overload_concept(integer)]#) return x end
    f(true)
  ]], "cannot match overload concept")
end)

it("generics", function()
  expect.analyze_ast([[
    local myarray = #[generic(function(T, N) return types.ArrayType(T, N) end)]#
    local M: integer <comptime> = 4
    local x = @myarray(integer, (M))
  ]])
  expect.analyze_ast([[
    local int = @integer
    local proxy = #[generic(function(T) return int end)]#
    local x = @proxy(integer)
  ]])
  expect.analyze_error([[
    local proxy = #[generic(function(T) static_error('my fail') end)]#
    local x = @proxy(integer)
  ]], 'my fail')
  expect.analyze_error([[
    local proxy = 1
    local x = @proxy(integer)
  ]], 'is not a type')
  expect.analyze_error([[
    local myarray = #[generic(function(T, N) return types.ArrayType(T, N) end)]#
    local M: integer = 4
    local x = @myarray(integer, (M))
  ]], "isn't a compile time value")
  expect.analyze_error([[
    local myarray = #[generic(function(T, N) return types.ArrayType(T, N) end)]#
    local M: record{x: integer} <comptime> = {}
    local x = @myarray(integer, (M))
  ]], "is invalid for generics")
  expect.analyze_error([[
    local x = @integer(integer)
  ]], "cannot generalize")
  expect.analyze_error([[
    local myarray = #[generic(function() end)]#
    local i = 1
    local x = @integer(i)
  ]], "cannot generalize")
  expect.analyze_error([[
    local myarray = #[generic(function() end)]#
    local x = myarray(integer)
  ]], "cannot do type cast on generics")
  expect.analyze_error([[
    local myarray = #[generic(function() end)]#
    local x = @myarray(integer)
  ]], "expected a type or symbol in generic return")
  expect.analyze_error([[
    local X = 1
    local myarray = #[generic(function() return X end)]#
    local x = @myarray(integer)
  ]], "expected a symbol holding a type in generic return")
  expect.analyze_error([[
    local myarray = #[generic(function() end)]#
    local X
    local x = @myarray(X)
  ]], "isn't a compile time value")
  expect.analyze_error([[
    local x = @invalidgeneric(integer)
  ]], "is not defined")
end)

it("custom braces initialization", function()
  expect.analyze_ast([==[
    local vector = @record{data: [4]integer}
    ##[[
    vector.value.choose_braces_type = function(nodes)
      return types.ArrayType(primtypes.integer, 4)
    end
    ]]
    function vector.__convert(data: [4]integer): vector
      local v: vector
      v.data = data
      return v
    end
    local v: vector = {1,2,3,4}
    assert(v.data[0] == 1 and v.data[1] == 2 and v.data[2] == 3 and v.data[3] == 4)
  ]==])
  expect.analyze_error([==[
    local vector = @record{data: [4]integer}
    ##[[
    vector.value.choose_braces_type = function(nodes)
      return nil
    end
    ]]
    function vector.__convert(data: [4]integer): vector
      local v: vector
      v.data = data
      return v
    end
    local v: vector = {1,2,3,4}
    assert(v.data[0] == 1 and v.data[1] == 2 and v.data[2] == 3 and v.data[3] == 4)
  ]==], "choose_braces_type failed")
end)

it("do expressions", function()
  expect.analyze_ast("local a = (do return 1 end)")
  expect.analyze_error("local a = (do end)", "a return statement is missing")
  expect.analyze_error("local a = (do return 1, 2 end)", "can only return one argument")
end)

it("forward type declaration", function()
  expect.analyze_ast("local R <forwarddecl> = @record{}; R = @record{}; local S = @record{r: R}")
  expect.analyze_ast("local U <forwarddecl> = @union{}; U = @union{i: integer, n: number}; local S = @record{u: U}")
  expect.analyze_error("local R <forwarddecl> = @record{}; local S = @record{r: R}",
    "cannot be of forward declared type")
  expect.analyze_error("local R <forwarddecl> = @record{}; local r: R",
    "cannot be of forward declared type")
  expect.analyze_error("local R <forwarddecl> = @record{}; local A = @[4]R",
    "cannot be of forward declared type")
  expect.analyze_error("local R <forwarddecl> = @record{}; local f: function(x: R)",
    "cannot be of forward declared type")
  expect.analyze_error("local R <forwarddecl> = @record{}; local function f(x: R) end",
    "cannot be of forward declared type")
  expect.analyze_error("local R <forwarddecl> = @record{}; local function f(): R end",
    "cannot be of forward declared type")
  expect.analyze_error("local U <forwarddecl> = @union{}; local V = @union{u: U}",
    "cannot be of forward declared type")
end)

it("using annotation", function()
  expect.analyze_ast([[
    local MyEnum <using> = @enum{
      MYENUM_NONE = 0,
      MYENUM_ONE = 1,
    }
    local a: MyEnum = MYENUM_ONE
  ]])
  expect.analyze_ast([[
    local MyEnum <using> = @enum{MyEnumA = 0}
    local function f(x: auto) print(MyEnumA, x) end
    f(1)
  ]])
  expect.analyze_error([[
    local MyEnum <using> = @record{}
  ]], "annotation 'using' can only")
end)

it("union type", function()
  expect.analyze_ast([[local Union = @union{integer,number}; local a: Union]])
  expect.analyze_ast([[local u: union {b: boolean, i: integer}; u.b = true]])
  expect.analyze_ast([[local u: union{b: boolean, i: integer} = {}]])
  expect.analyze_ast([[local u: union{b: boolean, i: integer} = {b=true}]])
  expect.analyze_ast([[local u: union{b: boolean, i: integer} = {i=1}]])
  expect.analyze_error([[
    local u: union{b: boolean, i: integer}
    local v: union{b: boolean, n: number}
    u = v
  ]], "no viable type conversion")
  expect.analyze_error([[
    local U = @union{t: type, i: integer}
  ]], "cannot be of compile-time type")
  expect.analyze_error([[
    local u: union{b: boolean, i: integer} = {b = true, i = 1}
  ]], "unions can only be initialized with at most 1 field")
  expect.analyze_error([[
    local u: union{b: boolean, i: integer} = {i = true}
  ]], "no viable type conversion from")
  expect.analyze_error([[
    local u: union{b: boolean, i: integer} = {true}
  ]], "union field is missing a name")
  expect.analyze_error([[
    local u: union{b: boolean, i: integer} = {[1] = true}
  ]], "only string literals are allowed")
  expect.analyze_error([[
    local u: union{b: boolean, i: integer} = {c = true}
  ]], "is not present in union")
end)

it("variant type", function()
  expect.analyze_error("local Variant = @integer|number", "not implemented yet")
end)

it("optional type", function()
  expect.analyze_error("local OptionalInt = @?integer", "not implemented yet")
end)

it("side effects detection", function()
  expect.analyze_ast([[
    local X: integer

    local function f(x: integer): integer
      print(x)
      return x
    end
    ## assert(f.type.sideeffect == true)

    local function f(x: integer): integer
      return x
    end
    ## assert(f.type.sideeffect == false)

    local function f(x: integer): integer
      X = x
      return x
    end
    ## assert(f.type.sideeffect == true)

    local a: [4]integer = {f(1), f(2)}
    local u: union{x: integer, y:number} = {x=f(1)}

    local function f(x: integer) <nosideeffect>
      X = x
      return x
    end
    ## assert(f.type.sideeffect == false)
  ]])
end)

it("invalid type uses", function()
  expect.analyze_error([[local T: type]], "a type declaration must assign to a type")
  expect.analyze_error([[local T: type = nil]], "cannot assign a type to")
  expect.analyze_error([[local T: type = 1]], "cannot assign a type to")
  expect.analyze_error([[local V; local T: type = V]], "cannot assign a type to")
  expect.analyze_error([[local V; local T = @record{x: V}]], "invalid type")
  expect.analyze_error([[local V; local T = @union{x: V}]], "invalid type")
  expect.analyze_error([[local V; local T = @enum(V){A=0}]], "invalid type")
  expect.analyze_error([[local V; local T = @[4]V]], "invalid type")
  expect.analyze_error([[local V; local T = @*V]], "invalid type")
  expect.analyze_error([[local V; local T = @function(V): void]], "invalid type")
  expect.analyze_error([[local V; local T = @function(): V]], "invalid type")
  expect.analyze_error([[local V; local v = (@V)(1)]], "invalid type")
  expect.analyze_error([[local V; local V; local generic = #[generalize()]#; local v: generic(V)]],
    "isn't a compile time value")
end)

it("nocopy type annotation", function()
  expect.analyze_ast([[
    local R <nocopy> = @record{x: integer}
    local x: R
    local r: *R = &x
    local function f(x: R) end
    f(R{})

    local function g(): R
      local r: R
      return r
    end

    local function g(r: R): R
      return r
    end
  ]])
  expect.analyze_error([[
    local R <nocopy> = @record{x: integer}
    local x: R
    local r: R = x
  ]], "non copyable type")
  expect.analyze_error([[
    local R <nocopy> = @record{x: integer}
    local x: R
    local r: R
    r = x
  ]], "non copyable type")
  expect.analyze_error([[
    local R <nocopy> = @record{x: integer}
    local x: R
    local r = x]], "non copyable type")
  expect.analyze_error([[
    local R <nocopy> = @record{x: integer}
    local x: R
    local arr: [4]R = {x}
  ]], "non copyable type")
  expect.analyze_error([[
    local R <nocopy> = @record{x: integer}
    local x: R
    local r: record{x: R} = {x=x}
  ]], "non copyable type")
  expect.analyze_error([[
    local R <nocopy> = @record{x: integer}
    local x: R
    local u: union{x: R} = {x=x}
  ]], "non copyable type")
  expect.analyze_error([[
    local R <nocopy> = @record{x: integer}
    local x: R
    local function f(x: R) end
    f(x)
  ]], "non copyable type")
  expect.analyze_error([[
    local R <nocopy> = @record{x: integer}
    local x: R
    local function f(x: R) end
    f((@R)(x))
  ]], "non copyable type")
  expect.analyze_error([[
    local R <nocopy> = @record{x: integer}
    local x: R
    function R.f(x: R) end
    x:f()
  ]], "non copyable type")
  expect.analyze_error([[
    local R <nocopy> = @record{x: integer}
    local x: *R
    local r: R = $x
  ]], "non copyable type")
  expect.analyze_error([[
    local R <nocopy> = @record{x: integer}
    local r: R
    local function f(): R
      return r
    end
  ]], "non copyable type")
  expect.analyze_error([[
    local R <nocopy> = @record{x: integer}
    local x: *R
    local function f(x: R) end
    f(x)
  ]], "no viable type conversion")
end)

it("polymorphic varargs", function()
  expect.analyze_ast([[
    local function g() return 1 end
    local function f(...: varargs) return g(...) end
    f()
  ]])
  expect.analyze_error([[
    local function f(...: varargs)
      local a = 1 + ...
    end
    f()
  ]], "invalid operation between types 'int64' and 'niltype'")
end)

end)
