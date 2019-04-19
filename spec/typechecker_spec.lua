require 'busted.runner'()

local assert = require 'spec.assert'
local config = require 'euluna.configer'.get()
local n = require 'euluna.syntaxdefs'().astbuilder.aster
local bn = require 'euluna.utils.bn'

describe("Euluna should check types for", function()

it("local variable", function()
  assert.analyze_ast("local a: integer",
    n.Block { {
      n.VarDecl { 'local', 'var',
        { n.IdDecl{ assign=true, type='int64', 'a', 'var',
          n.Type { type='int64', 'integer'}}}
      }
    } }
  )

  assert.analyze_ast("local a: integer = 1",
    n.Block { {
      n.VarDecl { 'local', 'var',
        { n.IdDecl{ assign=true, type='int64', 'a', 'var',
          n.Type { type='int64', 'integer'}}},
        { n.Number{
          type='int64',
          value=bn.fromdec('1'),
          'dec', '1'}}
      }
    } }
  )

  assert.analyze_ast("local a = 1; f(a)",
    n.Block { {
      n.VarDecl { 'local', 'var',
        { n.IdDecl { assign=true, type='int64', 'a', 'var' }},
        { n.Number {
          type='int64',
          value=bn.fromdec('1'),
          'dec', '1'
        }}
      },
      n.Call { callee_type='any', type='any',
        { n.Id { type='int64', "a"} },
        n.Id { type='any', "f"},
        true
    }
  }})

  assert.c_gencode_equals("local a = 1", "local a: integer = 1")
  assert.analyze_error("local a: integer = 'string'", "is not coercible with")
  assert.analyze_error("local a: uint8 = 1.0", "is not coercible with")
  assert.analyze_error("local a: uint8 = {1.0}", "cannot be initialized using a table literal")
  assert.analyze_error("local a, b = 1,2,3", "too many expressions in declaration")
end)

it("numeric types coercion", function()
  assert.analyze_ast([[
    local u:uint, u8:uint8, u16:uint16, u32:uint32, u64:uint64 = 1,1,1,1,1
    local i:int, i8:int8, i16:int16, i32:int32, i64:int64 = 1,1,1,1,1
    local f32: float32, f64: float64 = 1,1
  ]])
  assert.analyze_ast([[
    local a: uint16 = 1 + 1_u16
    local b: uint16 = 1 + 1
    local b: int16 = -1
  ]])
  assert.c_gencode_equals("local a = 1 + 1_u16", "local a: uint16 = 1 + 1_u16")
  assert.c_gencode_equals("local a = 1 + 2.0_f32", "local a: float32 = 1 + 2.0_f32")
end)

it("numeric ranges", function()
  assert.analyze_ast([[
    local u:uint, u8:uint8, u16:uint16, u32:uint32, u64:uint64 = 0,0,0,0,0
  ]])
  assert.analyze_ast([[
    local u:uint = 18446744073709551616_u
    local u8:uint8, u16:uint16, u32:uint32, u64:uint64 = 256,65536,4294967296,18446744073709551616
  ]])
  assert.analyze_error([[local u = -1_u]], "is out of range")
  assert.analyze_error([[local u = -1_u8]], "is out of range")
  assert.analyze_error([[local u = -1_u16]], "is out of range")
  assert.analyze_error([[local u = -1_u32]], "is out of range")
  assert.analyze_error([[local u = -1_u64]], "is out of range")
  assert.analyze_error([[local u = 18446744073709551617_u]], 'is out of range')
  assert.analyze_error([[local u = 257_u8]], 'is out of range')
  assert.analyze_error([[local u = 65537_u16]], 'is out of range')
  assert.analyze_error([[local u = 4294967297_u32]], 'is out of range')
  assert.analyze_error([[local u = 18446744073709551617_u64]], 'is out of range')

  assert.analyze_ast([[
    local i:int = -9223372036854775808_i
    local i8:int8, i16:int16, i32:int32, i64:int64 = -128,-32768,-2147483648,-9223372036854775808
  ]])
  assert.analyze_ast([[
    local i:int = 9223372036854775807_i
    local i8:int8, i16:int16, i32:int32, i64:int64 = 127,32767,2147483647,9223372036854775807
  ]])
  assert.analyze_error([[local i = -9223372036854775809_i64]], 'is out of range')
  assert.analyze_error([[local i = -129_i8]], 'is out of range')
  assert.analyze_error([[local i = -32769_i16]], 'is out of range')
  assert.analyze_error([[local i = -2147483649_i32]], 'is out of range')
  assert.analyze_error([[local i = -9223372036854775809_i64]], 'is out of range')
  assert.analyze_error([[local i = 9223372036854775808_i]], 'is out of range')
  assert.analyze_error([[local i = 128_i8]], 'is out of range')
  assert.analyze_error([[local i = 32768_i16]], 'is out of range')
  assert.analyze_error([[local i = 2147483648_i32]], 'is out of range')
  assert.analyze_error([[local i = 9223372036854775808_i64]], 'is out of range')
end)

it("typed var initialization", function()
  assert.lua_gencode_equals("local a: integer", "local a: integer = 0")
  assert.lua_gencode_equals("local a: boolean", "local a: boolean = false")
  assert.lua_gencode_equals("local a: arraytable<integer>", "local a: arraytable<integer> = {}")
end)

it("loop variables", function()
  assert.c_gencode_equals("for i=1,10 do end", "for i:integer=1,10 do end")
  assert.c_gencode_equals("for i=1,10,2 do end", "for i:integer=1,10,2 do end")
  assert.c_gencode_equals("for i=0_i,1_i-1 do end", "for i:int=0_i,1_i-1 do end")
  assert.analyze_error("for i:uint8=1.0,10 do end", "is not coercible with")
  assert.analyze_error("for i:uint8=1_u8,10 do end", "is not coercible with")
  assert.analyze_error("for i:uint8=1_u8,10_u8,2 do end", "is not coercible with")
end)

it("variable assignments", function()
  assert.c_gencode_equals("local a; a = 1", "local a: integer; a = 1")
  assert.analyze_error("local a: integer; a = 's'", "is not coercible with")
  assert.analyze_error("local a, b; a, b = 1,2,3", "too many expressions in assign")
end)

it("unary operators", function()
  assert.c_gencode_equals("local a = not b", "local a: boolean = not b")
  assert.c_gencode_equals("local a = -1", "local a: integer = -1")
end)

it("binary operators", function()
  assert.c_gencode_equals("local a = 1_u32 << 1", "local a: uint32 = 1_u32 << 1")
  assert.c_gencode_equals("local a = 1_u16 >> 1_u32", "local a: uint16 = 1_u16 >> 1_u32")
  assert.c_gencode_equals("local a = 1 + 2", "local a: integer = 1 + 2")
  assert.c_gencode_equals("local a = 1 + 2.0", "local a: number = 1 + 2.0")
  assert.c_gencode_equals("local a = 1_f32 + 2.0_f32", "local a: float32 = 1_f32 + 2.0_f32")
  assert.c_gencode_equals("local a = 1_i8 + 2_u8", "local a: int16 = 1_i8 + 2_u8")
  assert.c_gencode_equals("local a = 2 ^ 2", "local a: number = 2 ^ 2")
  assert.c_gencode_equals("local a = 2 // 2", "local a: integer = 2 // 2")
  assert.c_gencode_equals("local a = 2 / 2", "local a: number = 2 / 2")
  assert.analyze_error("local a = 1 + 's'", "is not defined for type")
  assert.analyze_error("local a = 1 / 0", "divizion by zero")
  assert.analyze_error("local a = 1 / -0", "divizion by zero")
  assert.analyze_error("local a = 1 // 0", "divizion by zero")
  assert.analyze_error("local a = 1 % 0", "divizion by zero")
end)

it("binary conditional operators", function()
  assert.c_gencode_equals("local a = 1 and 2", "local a: integer = 1 and 2")
  assert.c_gencode_equals("local a = 1_i8 and 2_u8", "local a: int16 = 1_i8 and 2_u8")
end)

it("operation with parenthesis", function()
  assert.c_gencode_equals("local a = -(1)", "local a: integer = -(1)")
end)

it("recursive late deduction", function()
  assert.c_gencode_equals([[
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
  assert.c_gencode_equals([[
    local a = 1_integer
    local b = a + 1
  ]],[[
    local a: integer = 1_integer
    local b: integer = a + 1
  ]])
  assert.c_gencode_equals([[
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
    local function f(a: integer) end
    function f(a: integer) end
  ]])
  assert.analyze_ast([[
    local f: function<(integer): string>
    function f(a: integer): string end
  ]])
  assert.analyze_error([[
    local f: int
    function f(a: integer) return 0 end
  ]], "is not coercible with")
  assert.analyze_error([[
    local function f(a: integer) end
    function f(a: integer, b:integer) end
  ]], "is not coercible with")
  assert.analyze_error([[
    local function f(a: integer) end
    function f(a: string) end
  ]], "is not coercible with")
  assert.analyze_error([[
    local function f(): integer, string end
    function f(): integer end
  ]], "is not coercible with")
  assert.analyze_error([[
    local f: function<():integer, string>
    function f(): integer end
  ]], "is not coercible with")
end)

it("function return", function()
  assert.c_gencode_equals(
    "local function f() return 0 end",
    "local function f(): integer return 0 end"
  )
  assert.c_gencode_equals([[
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
  assert.analyze_error([[
    local function f(): string return 0 end
  ]], "is not coercible with")
end)

it("function call", function()
  assert.c_gencode_equals([[
    local function f() return 0 end
    local a = f()
  ]],[[
    local function f(): integer return 0 end
    local a: integer = f()
  ]])
  assert.analyze_ast([[local function f(a: integer) end; f(1_u32)]])
  assert.analyze_ast([[local function f(a) end; f() f(1)]])
  assert.analyze_error([[local a: integer = 1; a()]], "attempt to call a non callable variable")
  assert.analyze_error([[local function f(a: integer) end; f('a')]], "is not coercible with")
  assert.analyze_error([[local function f(a: integer) end; f(1,1)]], "expected at most 1 arguments but got 2")
  assert.analyze_error([[local function f(a: integer) end; f()]], "expected an argument at index 1")
end)

it("array tables", function()
  assert.analyze_ast([[
    local a: arraytable<boolean>
    local b: arraytable<boolean>
    b = a
  ]])
  assert.analyze_ast([[
    local a: arraytable<boolean>
    local len = #a
  ]])
  assert.analyze_ast([[
    local a: arraytable<boolean> = {}
    local b: arraytable<boolean> = {false, true}
    local c = @arraytable<boolean>{false, true}
    local d: arraytable<boolean>; d = {false, true}
    local function f(a: arraytable<boolean>) end
    f({false, true})
  ]])
  assert.c_gencode_equals([[
    local a: arraytable<boolean>
    local b = a[0]
  ]],[[
    local a: arraytable<boolean>
    local b: boolean = a[0]
  ]])
  assert.analyze_error([[
    local a: arraytable<integer>
    local b: arraytable<boolean>
    b = a
  ]], "is not coercible with")
  assert.analyze_error([[
    local a: arraytable<integer> = {false}
  ]], "is not coercible with")
  assert.analyze_error([[
    local a: arraytable<integer> = {a = 1}
  ]], "fields are not allowed")
  assert.analyze_error([[
    local a: arraytable<boolean>
    local b: arraytable<integer>
    b = a
  ]], "is not coercible with")
end)

it("arrays", function()
  assert.analyze_ast([[local a: array<integer, 10>; a[0] = 1]])
  assert.analyze_ast([[local a: array<integer, 2> = {1,2}]])
  assert.analyze_ast([[local a: array<integer, 2>; a[0] = 1; a[1] = 2]])
  assert.analyze_ast([[local a: array<integer, 2>; a = {1,2}]])
  assert.analyze_ast([[local a: array<integer, 10>, b: array<integer, 10>; b = a]])
  assert.analyze_ast([[local a: arraytable<boolean>; local len = #a]])
  assert.analyze_error([[local a: array<integer, 2> = {1}]], 'expected 2 values but got 1')
  assert.analyze_error([[local a: array<integer, 2> = {1,2,3}]], 'expected 2 values but got 3')
  assert.analyze_error([[local a: array<integer, 2> = {1.0,2.0}]], 'is not coercible with')
  assert.analyze_error([[local a: array<integer, 2> = {a=0,2}]], 'fields are not allowed')
  assert.analyze_error([[local a: array<integer, 10>, b: array<integer, 11>; b = a]], "is not coercible with")
  assert.analyze_error([[local a: array<integer, 10>; a[0] = 1.0]], "is not coercible with")
  assert.analyze_error([[local a: array<integer, 1.0>]], "expected a valid decimal integral")
  assert.analyze_error([[local Array = @array<integer, 1>; local a = Array.l]], "cannot index fields")
  assert.analyze_error([[local a: array<integer, 2> = {1}]], 'expected 2 values but got 1')
  assert.analyze_error([[local a: array<integer, 2>; a[-1] = 1]], 'trying to index negative value')
  assert.analyze_error([[local a: array<integer, 2>; a[2] = 1]], 'is out of bounds')
  assert.analyze_error([[local a: array<integer, 2>; a['s'] = 1]], 'trying to index with non integral value')
end)

it("records", function()
  assert.analyze_ast([[local a: record {x: boolean}; a.x = true]])
  assert.analyze_ast([[local a: record {x: boolean} = {x = true}]])
  assert.analyze_ast([[local a: record {x: boolean}; a = {x = true}]])
  assert.analyze_ast([[local a: record {x: boolean}; local len = #a]])
  assert.analyze_error([[local a: record {x: boolean}; a.x = 1]], "is not coercible with")
  assert.analyze_error([[local a: record {x: boolean}; local b = a.y]], "does not have field named")
  assert.analyze_error([[local a: record {x: boolean} = {x = 1}]], "is not coercible with")
  assert.analyze_error([[local a: record {x: boolean} = {y = 1}]], "is not present in record")
  assert.analyze_error([[local a: record {x: boolean} = {[x] = 1}]], "only string literals are allowed")
  assert.analyze_error([[local a: record {x: boolean} = {false}]], "only named fields are allowed")
  assert.analyze_ast([[
    local Record: type = @record{x: boolean}
    local a: Record, b: Record
    b = a
  ]])
  assert.analyze_error([[
    local a: record {x: boolean}, b: record {x: boolean}
    b = a
  ]], "is not coercible with")
  assert.analyze_error([[
    local A, B = @record {x: boolean}, @record {x: boolean}
    local a: A, b: B
    b = a
  ]], "is not coercible with")
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
    local a: record{a: array<integer, 2>}
    a.a = @array<integer,2>{1,2}
    local b = a.a
  ]])
  assert.analyze_ast([[
    local a: record{a: array<integer, 2>} = {a={1,2}}
  ]])
end)

it("enums", function()
  assert.analyze_ast([[
    local a: enum{A=0}
    local b: enum<integer>{A=0,B}
  ]])
  assert.analyze_ast([[
    local Enum = @enum{A=0,B=3}
    local e: Enum = Enum.A
    local i: number = e
  ]])
  assert.analyze_error([[
    local Enum = @enum<uint8>{A=256}
  ]], "is not coercible with")
  assert.analyze_error([[
    local Enum = @enum{A=0,B=3}
    local e: Enum = Enum.A
    local i: string = e
  ]], "is not coercible with")
  assert.analyze_error([[
    local Enum = @enum{A=0,B}
    local e: Enum = Enum.C
  ]], "does not have field named")
  assert.analyze_error([[
    local Enum = @enum{A,B=3}
  ]], "first field requires a initial value")
  assert.analyze_error([[
    local Enum = @enum{A=1,B}
  ]], "a field with value 0 is always required")
  assert.analyze_error([[
    local Enum = @enum{A=1.0}
  ]], "only integral numbers are allowed in enums")
end)

it("pointers", function()
  assert.analyze_ast([[
    local a: pointer<integer>
    local b: pointer
    b = a
  ]])
  assert.analyze_ast([[
    local a: pointer<integer>
    local b: pointer<integer>
    b = a
  ]])
  assert.analyze_error([[
    local a: pointer<integer>
    local b: pointer<boolean>
    b = a
  ]], "is not coercible with")
  assert.analyze_error([[
    local a: pointer<integer>
    local b: pointer
    a = b
  ]], "is not coercible with")
end)

it("type construction", function()
  assert.analyze_ast("local a = @integer(0)")
  assert.analyze_ast("local a = @boolean(false)")
  assert.analyze_ast("local a = @string('')")
  assert.analyze_ast("local a = @any(nil)")
  assert.analyze_error("local a = @integer()", "expected one argument")
  assert.analyze_error("local a = @integer(1,2)", "expected one argument")
  assert.analyze_error("local a = @integer(false)", "is not coercible with")
  assert.analyze_error("local a = @integer(nil)", "is not coercible with")
end)

it("strict mode", function()
  config.strict = true
  assert.analyze_error("a = 1", "undeclarated symbol")
  assert.analyze_error("local a; local a", "shadows pre declarated symbol")
  config.strict = false
end)

end)
