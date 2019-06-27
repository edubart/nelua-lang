require 'busted.runner'()

local assert = require 'spec.tools.assert'
local config = require 'nelua.configer'.get()

describe("Nelua preprocessor should", function()

it("evaluate expressions", function()
  assert.ast_type_equals([=[
    local a = #['he' .. 'llo']
    local b = #[math.sin(-math.pi/2)]
    local c = #[true]
    local d = #[math.pi]
    local e = #[aster.Number{'dec','1'}]
  ]=], [[
    local a = 'hello'
    local b = -1
    local c = true
    local d = 3.1415926535898
    local e = 1
  ]])
  assert.ast_type_equals([=[
    local a: integer[10]
    a[#[0]] = 1
  ]=], [[
    local a: integer[10]
    a[0] = 1
  ]])
  assert.analyze_error("local a = #[function() end]", "unable to convert preprocess value of type")
end)

it("evaluate names", function()
  assert.ast_type_equals([[
    #('print') 'hello'
  ]], [[
    print 'hello'
  ]])
end)

it("parse if", function()
  assert.ast_type_equals("[##[ if true then ]##] local a = 1 [##[ end ]##]", "local a = 1")
  assert.ast_type_equals("[##[ if false then ]##] local a = 1 [##[ end ]##]", "")
  assert.ast_type_equals([[
    local function f() [##[ if true then ]##] return 1 [##[ end ]##] end
  ]],[[
    local function f() return 1 end
  ]])
  assert.ast_type_equals([[
    local function f()
      ## if true then
        return 1
      ## end
    end
  ]], [[
    local function f()
      return 1
    end
  ]])
  assert.analyze_error("[##[ if true then ]##]", "'end' expected")
end)

it("parse loops", function()
  assert.ast_type_equals([[
    local a = 2
    ## for i=1,4 do
      a = a * 2
    ## end
  ]], [[
    local a = 2
    a = a * 2
    a = a * 2
    a = a * 2
    a = a * 2
  ]])
  assert.ast_type_equals([[
    local a = 0
    ## for i=1,3 do
      do
        ## if i == 1 then
          a = a + 1
        ## elseif i == 2 then
          a = a + 2
        ## elseif i == 3 then
          a = a + 3
        ## end
      end
    ## end
  ]], [[
    local a = 0
    do a = a + 1 end
    do a = a + 2 end
    do a = a + 3 end
  ]])
  assert.ast_type_equals([[
    local a = 0
    ## for i=1,3 do
      a = a + #[i]
      for i=1,4,2 do end
    ## end
  ]], [[
    local a = 0
    a = a + 1
    for i=1,4,2 do end
    a = a + 2
    for i=1,4,2 do end
    a = a + 3
    for i=1,4,2 do end
  ]])
end)

it("inject other symbol type", function()
  assert.ast_type_equals([[
    local a: uint8 = 1
    local b: #[symbols['a'].attr.type]
  ]], [[
    local a: uint8 = 1
    local b: uint8
  ]])
end)

it("print symbol", function()
  assert.ast_type_equals([=[
    local a: compconst integer = 1
    local b: const integer = 2
    print #[tostring(symbols.a)]
    print #[tostring(symbols.b)]
  ]=], [[
    local a: compconst = 1
    local b: const = 2
    print 'symbol<a: compconst int64 = 1>'
    print 'symbol<b: const int64>'
  ]])
  assert.ast_type_equals([=[
    for i:integer=1,2 do
      print(i, #[tostring(symbols.i)])
    end
  ]=], [[
    for i=1,2 do
      print(i, 'symbol<i: int64>')
    end
  ]])
  assert.ast_type_equals([[
    ## local aval = 1
    ## if true then
      local #('a'): compconst #('integer') = #[aval]
      print #[tostring(scope:get_symbol('a'))]
    ## end
  ]], [[
    local a: compconst = 1
    print 'symbol<a: compconst int64 = 1>'
  ]])
end)

it("print enums", function()
  assert.ast_type_equals([[
    local Weekends = @enum { Friday=0, Saturday, Sunda }
    ## symbols.Weekends.attr.holdedtype.fields[3].name = 'Sunday'
    ## for i,field in ipairs(symbols.Weekends.attr.holdedtype.fields) do
      print(#[field.name .. ' ' .. tostring(field.value)])
    ## end
  ]], [[
    local Weekends = @enum { Friday=0, Saturday, Sunday }
    print 'Friday 0'
    print 'Saturday 1'
    print 'Sunday 2'
  ]])
end)

it("print ast", function()
  assert.ast_type_equals([[
    local a = #[tostring(ast)]
  ]], [=[
    local a = [[Block {
  {
  }
}]]
  ]=])
end)

it("print types", function()
  assert.ast_type_equals([[
    local n: float64
    local s: string
    local b: boolean
    local a: int64[2]
    local function f(a: int64, b: int64): int64, int64 return 0,0 end
    local function g(a: boolean | string) end
    local R: type = @record{a: integer, b: integer}
    function R:foo() return 1 end
    global R.v: integer = 1
    local r: R
    local tn = #[tostring(symbols.n.attr.type)]
    local ts = #[tostring(symbols.s.attr.type)]
    local tb = #[tostring(symbols.b.attr.type)]
    local ta = #[tostring(symbols.a.attr.type)]
    local tf = #[tostring(symbols.f.attr.type)]
    local tg = #[tostring(symbols.g.attr.type)]
    local tR = #[tostring(symbols.R.attr.type)]
    local tRmt = #[tostring(symbols.R.attr.holdedtype.metatype)]
    local tr = #[tostring(symbols.r.attr.type)]
  ]], [=[
    local n: float64
    local s: string
    local b: boolean
    local a: int64[2]
    local function f(a: int64, b: int64): int64, int64 return 0,0 end
    local function g(a: boolean | string) end
    local R: type = @record{a: integer, b: integer}
    function R:foo() return 1 end
    global R.v: integer = 1
    local r: R
    local tn = 'float64'
    local ts = 'string'
    local tb = 'boolean'
    local ta = 'array<int64, 2>'
    local tf = 'function<(int64, int64): int64, int64>'
    local tg = 'function<(boolean | string)>'
    local tR = 'type'
    local tRmt = 'metatype{foo: function<(pointer<record{a:int64, b:int64}>): int64>v: int64}'
    local tr = 'record{a:int64, b:int64}'
  ]=])
end)

it("generate functions", function()
  assert.ast_type_equals([[
    ## local function make_pow(N)
      local function #('pow' .. N)(x: integer)
        local r = 1
        ## for i=1,N do
          r = r*x
        ## end
        return r
      end
    ## end

    [##[
    make_pow(2)
    make_pow(3)
    ]##]
  ]], [[
    local function pow2(x: integer)
      local r = 1
      r = r * x
      r = r * x
      return r
    end
    local function pow3(x: integer)
      local r = 1
      r = r * x
      r = r * x
      r = r * x
      return r
    end
  ]])
end)

it("print symbol", function()
  assert.ast_type_equals([=[
    ## local a = 1
    do
      do
        print #[a]
      end
    end
  ]=], [[
    do do print(1) end end
  ]])
  assert.ast_type_equals([=[
    ## local MIN, MAX = 1, 2
    for i:integer=#[MIN],#[MAX] do
      print(i, #[tostring(symbols.i)])
    end
  ]=], [[
    for i:integer=1,2 do
      print(i, 'symbol<i: int64>')
    end
  ]])
end)

it("print config", function()
  assert.ast_type_equals([=[
    local a = #[config.cc]
  ]=], [[
    local a = 'gcc'
  ]])
end)

it("strict mode", function()
  config.strict = true
  assert.ast_type_equals([=[
    ## local dummy = 1
    local function f(a: integer)
      ## if true then
        print(a)
      ## end
    end
    f(1)
  ]=], [[
    local function f(a: integer)
      print(a)
    end
    f(1)
  ]])
  config.strict = false
end)

it("report errors", function()
  assert.analyze_error("[##[ invalid() ]##]", "attempt to call")
end)

it("run brainfuck", function()
  assert.run('--generator c examples/brainfuck.nelua', 'Hello World!')
end)

end)
