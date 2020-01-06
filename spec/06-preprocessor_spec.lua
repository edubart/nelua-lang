require 'busted.runner'()

local assert = require 'spec.tools.assert'

describe("Nelua preprocessor should", function()

it("evaluate expressions", function()
  assert.ast_type_equals([=[
    local a = #['he' .. 'llo']#
    local b = #[math.sin(-math.pi/2)]#
    local c = #[true]#
    local d = #[math.pi]#
    local e = #[aster.Number{'dec','1'}]#
  ]=], [[
    local a = 'hello'
    local b = -1
    local c = true
    local d = 3.1415926535897931
    local e = 1
  ]])
  assert.ast_type_equals([=[
    local a: integer[10]
    a[#[0]#] = 1
  ]=], [[
    local a: integer[10]
    a[0] = 1
  ]])
  assert.analyze_error("local a = #[function() end]#", "unable to convert preprocess value of type")
end)

it("evaluate names", function()
  assert.ast_type_equals([[
    #('print')# 'hello'
  ]], [[
    print 'hello'
  ]])
  assert.ast_type_equals([[
    local a <#('codename')# 'a'>
    local b <codename 'b'>
    local c <#('codename')##['c']#>
  ]], [[
    local a <codename 'a'>
    local b <codename 'b'>
    local c <codename 'c'>
  ]])
end)

it("parse if", function()
  assert.ast_type_equals("##[[ if true then ]] local a = 1 ##[[ end ]]", "local a = 1")
  assert.ast_type_equals("##[[ if false then ]] local a = 1 ##[[ end ]]", "")
  assert.ast_type_equals(
    "local function f() ##[[ if true then ]] return 1 ##[[ end ]] end",
    "local function f() return 1 end")
  assert.ast_type_equals([[
    local function f()
      ## if true then
        return 1
      ## else
        return 0
      ## end
    end
  ]], [[
    local function f()
      return 1
    end
  ]])
  assert.analyze_error("##[[ if true then ]]", "'end' expected")
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
      a = a + #[i]#
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
    local b: #[symbols['a'].type]#
  ]], [[
    local a: uint8 = 1
    local b: uint8
  ]])
end)

it("check symbols inside functions", function()
  assert.analyze_ast([=[
    ## strict = true
    local function f(x: integer)
      ## assert(symbols.x.type == require 'nelua.typedefs'.primtypes.integer)
    end
  ]=])
end)

it("print symbol", function()
  assert.ast_type_equals([=[
    local a: integer <comptime> = 1
    local b: integer <const> = 2
    print #[tostring(symbols.a)]#
    print #[tostring(symbols.b)]#
  ]=], [[
    local a <comptime> = 1
    local b <const> = 2
    print 'a: int64 <comptime> = 1'
    print 'b: int64 <const>'
  ]])
  assert.ast_type_equals([=[
    for i:integer=1,2 do
      print(i, #[tostring(symbols.i)]#)
    end
  ]=], [[
    for i=1,2 do
      print(i, 'i: int64')
    end
  ]])
  assert.ast_type_equals([[
    ## local aval = 1
    ## if true then
      local #('a')#: #('integer')# <comptime> = #[aval]#
      print #[tostring(scope:get_symbol('a'))]#
    ## end
  ]], [[
    local a <comptime> = 1
    print 'a: int64 <comptime> = 1'
  ]])
end)

it("print enums", function()
  assert.ast_type_equals([[
    local Weekends = @enum { Friday=0, Saturday, Sunda }
    ## symbols.Weekends.value.fields[3].name = 'Sunday'
    ## for i,field in ipairs(symbols.Weekends.value.fields) do
      print(#[field.name .. ' ' .. tostring(field.value)]#)
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
    local a = #[tostring(ast)]#
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
    local function f(a: int64, b: int64): (int64, int64) return 0,0 end
    local R: type = @record{a: integer, b: integer}
    function R:foo() return 1 end
    global R.v: integer = 1
    local r: R
    local tn = #[tostring(symbols.n.type)]#
    local ts = #[tostring(symbols.s.type)]#
    local tb = #[tostring(symbols.b.type)]#
    local ta = #[tostring(symbols.a.type)]#
    local tf = #[tostring(symbols.f.type)]#
    local tR = #[tostring(symbols.R.type)]#
    local tRmt = #[tostring(symbols.R.value.metatype)]#
    local tr = #[tostring(symbols.r.type)]#
  ]], [=[
    local n: float64
    local s: string
    local b: boolean
    local a: int64[2]
    local function f(a: int64, b: int64): (int64, int64) return 0,0 end
    local R: type = @record{a: integer, b: integer}
    function R:foo() return 1 end
    global R.v: integer = 1
    local r: R
    local tn = 'float64'
    local ts = 'string'
    local tb = 'boolean'
    local ta = 'array(int64, 2)'
    local tf = 'function(int64, int64): (int64, int64)'
    local tR = 'type'
    local tRmt = 'metatype{foo: function(pointer(record{a:int64, b:int64})): int64, v: int64}'
    local tr = 'record{a:int64, b:int64}'
  ]=])
end)

it("generate functions", function()
  assert.ast_type_equals([=[
    ## local function make_pow(N)
      local function #('pow' .. N)#(x: integer)
        local r = 1
        ## for i=1,N do
          r = r*x
        ## end
        return r
      end
    ## end

    ##[[
    make_pow(2)
    make_pow(3)
    ]]
  ]=], [[
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
        print #[a]#
      end
    end
  ]=], [[
    do do print(1) end end
  ]])
  assert.ast_type_equals([=[
    ## local MIN, MAX = 1, 2
    for i:integer=#[MIN]#,#[MAX]# do
      print(i, #[tostring(symbols.i)]#)
    end
  ]=], [[
    for i:integer=1,2 do
      print(i, 'i: int64')
    end
  ]])
end)

it("print config", function()
  assert.ast_type_equals([=[
    ## config.test = 'test'
    local a = #[config.test]#
  ]=], [[
    local a = 'test'
  ]])
end)

it("global preprocessor variables", function()
assert.ast_type_equals([=[
    ## TEST = 'test'
    local a = #[TEST]#
  ]=], [[
    local a = 'test'
  ]])
end)

it("strict mode", function()
  assert.ast_type_equals([=[
    print(#[tostring(strict)]#)
    ## strict = true
    print(#[tostring(strict)]#)
    local function f(a: integer)
      ## if true then
        print(a)
      ## end
    end
    f(1)
  ]=], [[
    print 'false'
    ## strict = true
    print 'true'
    local function f(a: integer)
      print(a)
    end
    f(1)
  ]])

  assert.analyze_error("## strict = 1", "invalid type for preprocess")
end)

it("function pragmas", function()
  assert.analyze_ast("## afterinfer(function() end)")
  assert.analyze_error("## afterinfer(false)", "invalid arguments for preprocess")
end)

it("inject nodes", function()
  assert.ast_type_equals([=[
    ## addnode(aster.Call{{aster.String{"hello"}}, aster.Id{'print'}, true})
  ]=], [[
    print 'hello'
  ]])
end)

it("nested preprocessing", function()
  assert.ast_type_equals([[
    ## if true then
      if true then
        ## cinclude 'lala'
        local a =1
      end
    ## end
  ]], [[
    if true then
      ## cinclude 'lala'
      local a = 1
    end
  ]])
end)

it("check function", function()
  assert.analyze_ast([[ ## staticassert(true) ]])
  assert.analyze_error([[ ## staticassert(false) ]], 'static assertion failed')
  assert.analyze_error([[ ## staticassert(false, 'myfail') ]], 'myfail')

  assert.analyze_ast([[
    local a = 1
    local b = 1.0
    ## afterinfer(function() staticassert(symbols.a.type == primtypes.integer) end)
    ## afterinfer(function() staticassert(symbols.b.type == primtypes.number) end)
  ]])
end)

it("auto type", function()
  assert.analyze_ast([[
    local a: auto = 1
    ## assert(symbols.a.type == primtypes.integer)
  ]])
end)

it("multiple blocks", function()
  assert.analyze_ast([[
    ## assert(true)
    local function f(a: auto)
      ## assert(true)
      for i=1,4 do
        local a: #[primtypes.integer]# <comptime> = 2
        ## assert(symbols.a.type == primtypes.integer)
      end
    end
  ]])
end)

it("lazy function", function()
  assert.analyze_ast([[
    local function f(a: auto)
      ## assert(symbols.a.type == primtypes.integer)
    end
    f(1)
  ]])
  assert.analyze_ast([=[
    ## local printtypes = {}
    local function printtype(x: auto)
      ##[[
      if symbols.x.type:is_float() then
        table.insert(printtypes, 'float')
      elseif symbols.x.type:is_integral() then
        table.insert(printtypes, 'integral')
      elseif symbols.x.type:is_boolean() then
        table.insert(printtypes, 'boolean')
      end
      ]]
      return x
    end
    assert(printtype(1) == 1)
    assert(printtype(3.14) == 3.14)
    assert(printtype(true) == true)
    assert(printtype(false) == false)
    ##[[ afterinfer(function()
      local types = table.concat(printtypes, ' ')
      staticassert(types == 'integral float boolean', types)
    end) ]]
  ]=])
end)

it("report errors", function()
  assert.analyze_error("##[[ invalid() ]]", "attempt to call")
  assert.analyze_error("##[[ for ]]", "expected near")
  assert.analyze_error("##[[ ast:raisef('ast error') ]]", "ast error")
end)

it("run brainfuck", function()
  assert.run('--generator c examples/brainfuck.nelua', 'Hello World!')
end)

end)
