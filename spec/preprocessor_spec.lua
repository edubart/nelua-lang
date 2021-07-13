local lester = require 'nelua.thirdparty.lester'
local describe, it = lester.describe, lester.it

local expect = require 'spec.tools.expect'

describe("preprocessor", function()

it("evaluate expressions", function()
  expect.ast_type_equals([=[
    local a = #['he' .. 'llo']#
    local b = #[math.sin(-math.pi/2)]#
    local c = #[true]#
    local d, d2, d3 = #[1.5e-30]#, #[1.5]#, #[1e-30]#
    local e = #[aster.Number{'1'}]#
    local a: [4]integer = #[{1,2,3,4}]#
    local r: record{x: integer, y: integer} = #[{x=1, y=2}]#
    local n: niltype = #[nil]#
  ]=], [[
    local a = 'hello'
    local b = -1
    local c = true
    local d, d2, d3 = 1.5e-30, 1.5, 1e-30
    local e = 1
    local a: [4]integer = {1,2,3,4}
    local r: record{x: integer, y: integer} = {x=1, y=2}
    local n: niltype = nil
  ]])
  expect.ast_type_equals([=[
    local a: [10]integer
    a[#[0]#] = 1
  ]=], [[
    local a: [10]integer
    a[0] = 1
  ]])
end)

it("evaluate names", function()
  expect.ast_type_equals([[
    #|'print'|# 'hello'
  ]], [[
    print 'hello'
  ]])
  expect.ast_type_equals([[
    local a <#|'codename'|# 'a'>
    local b <codename 'b'>
    local c <#|'codename'|#(#['c']#)>
  ]], [[
    local a <codename 'a'>
    local b <codename 'b'>
    local c <codename 'c'>
  ]])

  expect.analyze_error("local #|{}|#", "cannot convert preprocess value of lua type")
end)

it("parse if", function()
  expect.ast_type_equals("##[[ if true then ]] local a = 1 ##[[ end ]]", "local a = 1")
  expect.ast_type_equals("##[[ if false then ]] local a = 1 ##[[ end ]]", "")
  expect.ast_type_equals(
    "local function f() ##[[ if true then ]] return 1 ##[[ end ]] end",
    "local function f() return 1 end")
  expect.ast_type_equals([[
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
  expect.analyze_error("##[[ if true then ]]", "'end' expected")
end)

it("parse loops", function()
  expect.ast_type_equals([[
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
  expect.ast_type_equals([[
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
  expect.ast_type_equals([[
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
  expect.ast_type_equals([[
    local a: uint8 = 1
    local b: #[context.scope.symbols['a'].type]#
  ]], [[
    local a: uint8 = 1
    local b: uint8
  ]])
end)

it("check symbols inside functions", function()
  expect.analyze_ast([=[
    local function f(x: integer)
      ## assert(x.type == require 'nelua.typedefs'.primtypes.integer)
    end
  ]=])
end)

it("print symbol", function()
  expect.ast_type_equals([=[
    local a: integer <comptime> = 1
    local b: integer <const> = 2
    print(#[tostring(a)]#)
    print(#[tostring(b)]#)
  ]=], [[
    local a <comptime> = 1
    local b <const> = 2
    print 'a: int64 = 1'
    print 'b: int64'
  ]])
  expect.ast_type_equals([=[
    for i:integer=1,2 do
      print(i, #[tostring(i)]#)
    end
  ]=], [[
    for i=1,2 do
      print(i, 'i: int64')
    end
  ]])
  expect.ast_type_equals([[
    ## local aval = 1
    ## if true then
      local #|'a'|#: #|'integer'|# <comptime> = #[aval]#
      print(#[tostring(context.scope.symbols['a'])]#)
    ## end
  ]], [[
    local a <comptime> = 1
    print 'a: int64 = 1'
  ]])
end)

it("print enums", function()
  expect.ast_type_equals([[
    local Weekends = @enum{Friday=0, Saturday, Sunda}
    ## Weekends.value.fields[3].name = 'Sunday'
    ## for i,field in ipairs(Weekends.value.fields) do
      print(#[field.name .. ' ' .. tostring(field.value)]#)
    ## end
  ]], [[
    local Weekends = @enum{Friday=0, Saturday, Sunday}
    print 'Friday 0'
    print 'Saturday 1'
    print 'Sunday 2'
  ]])
end)

it("inject fields", function()
  expect.ast_type_equals([[
    local R = @record{x: integer, z: integer}
    ## R.value:add_field('y', primtypes.integer, 2)
    local U = @union{b: boolean, i: integer}
    ## U.value:add_field('n', primtypes.number, 2)
  ]], [[
    local R = @record{x: integer, y: integer, z: integer}
    local U = @union{b: boolean, y: number, i: integer}
  ]])
end)

it("print ast", function()
  expect.ast_type_equals([[
    local a = #[tostring(ast)]#
  ]], [=[
    local a = [[Block {
}]]
  ]=])
end)

it("print types", function()
  expect.ast_type_equals([[
    local n: float64
    local s: string
    local b: boolean
    local a: [2]int64
    local function f(a: int64, b: int64): (int64, int64) return 0,0 end
    local R: type = @record{a: integer, b: integer}
    function R:foo() return 1 end
    global R.v: integer = 1
    local r: R
    local tn = #[tostring(n.type)]#
    local ts = #[tostring(s.type)]#
    local tb = #[tostring(b.type)]#
    local ta = #[tostring(a.type)]#
    local tf = #[tostring(f.type)]#
    local tR = #[tostring(R.type)]#
    local tr = #[tostring(r.type)]#
  ]], [=[
    local n: float64
    local s: string
    local b: boolean
    local a: [2]int64
    local function f(a: int64, b: int64): (int64, int64) return 0,0 end
    local R: type = @record{a: integer, b: integer}
    function R:foo() return 1 end
    global R.v: integer = 1
    local r: R
    local tn = 'float64'
    local ts = 'string'
    local tb = 'boolean'
    local ta = 'array(int64, 2)'
    local tf = 'function(a: int64, b: int64): (int64, int64)'
    local tR = 'type'
    local tr = 'R'
  ]=])
end)

it("generate functions", function()
  expect.ast_type_equals([=[
    ## local function make_pow(N)
      local function #|'pow' .. N|#(x: integer)
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
  expect.ast_type_equals([=[
    ## local a = 1
    do
      do
        print(#[a]#)
      end
    end
  ]=], [[
    do do print(1) end end
  ]])
  expect.ast_type_equals([=[
    ## local MIN, MAX = 1, 2
    for i:integer=#[MIN]#,#[MAX]# do
      print(i, #[tostring(i)]#)
    end
  ]=], [[
    for i:integer=1,2 do
      print(i, 'i: int64')
    end
  ]])
end)

it("print config", function()
  expect.ast_type_equals([=[
    ## config.test = 'test'
    local a = #[config.test]#
  ]=], [[
    local a = 'test'
  ]])
end)

it("global preprocessor variables", function()
expect.ast_type_equals([=[
    ## TEST = 'test'
    local a = #[TEST]#
  ]=], [[
    local a = 'test'
  ]])

  expect.ast_type_equals([=[
    print(#[tostring(unitname)]#)
    ## unitname = 'unit'
    print(#[tostring(unitname)]#)
  ]=], [[
    print 'nil'
    ## strict = true
    print 'unit'
  ]])
end)

it("directives", function()
  expect.analyze_ast("## cinclude '<stdio.h>'")
  expect.analyze_error("## cinclude(false)", "invalid arguments for directive")
  expect.analyze_error("## inject_statement(aster.Directive{'invalid', {}})",
    "directive 'invalid' is undefined")
end)

it("call codes after inference", function()
  expect.analyze_ast("## after_inference(function() end)")
  expect.analyze_error("## after_inference(false)", "invalid arguments for preprocess")
end)

it("call codes after analyze pass", function()
  expect.analyze_ast("## after_analyze(function() end)")
  expect.analyze_error("## after_analyze(function() error 'errmsg' end)", "errmsg")
  expect.analyze_error("## after_analyze(false)", "invalid arguments for preprocess")
end)

it("inject nodes", function()
  expect.ast_type_equals([=[
    ## inject_astnode(aster.Call{{aster.String{"hello"}}, aster.Id{'print'}})
  ]=], [[
    print 'hello'
  ]])
end)

it("unpack ast nodes", function()
  expect.ast_type_equals([=[
    print(#[aster.unpack{}]#)
    print(#[aster.unpack{aster.Number{'1'}}]#)
    print(#[aster.unpack{aster.Number{'1'}, aster.Number{'2'}}]#)
  ]=], [[
    print()
    print(1)
    print(1, 2)
  ]])

  expect.ast_type_equals([=[
    local #[aster.unpack{aster.IdDecl{'a'}, aster.IdDecl{'b'}}]#
    global #[aster.unpack{aster.IdDecl{'a'}, aster.IdDecl{'b'}}]#
  ]=], [[
    local a, b
    global a, b
  ]])

  expect.ast_type_equals([=[
    local next
    for #[aster.unpack{aster.IdDecl{'i'}, aster.IdDecl{'v'}}]# in next do
    end
  ]=], [[
    local next
    for i,v in next do
    end
  ]])

  expect.ast_type_equals([=[
    local function f(#[aster.unpack{aster.IdDecl{'x', aster.Id{'integer'}},
                                    aster.IdDecl{'y', aster.Id{'integer'}}}]#)
      print(x, y)
    end
    f(1, 2)
  ]=], [[
    local function f(x: integer,
                     y: integer)
      print(x, y)
    end
    f(1, 2)
  ]])
end)

it("nested preprocessing", function()
  expect.ast_type_equals([[
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
  expect.analyze_ast([[ ## static_assert(true) ]])
  expect.analyze_error([[ ## static_error() ]], 'static error!')
  expect.analyze_error([[ ## static_error('my fail') ]], 'my fail')
  expect.analyze_error([[ ## static_assert(false) ]], 'static assertion failed')
  expect.analyze_error([[ ## static_assert(false, 'myfail') ]], 'myfail')

  expect.analyze_ast([[
    local a = 1
    local b = 1.0
    ## after_inference(function() static_assert(a.type == primtypes.integer) end)
    ## after_inference(function() static_assert(b.type == primtypes.number) end)
  ]])
end)

it("auto type", function()
  expect.analyze_ast([[
    local a: auto = 1
    ## assert(a.type == primtypes.integer)
  ]])
end)

it("multiple blocks", function()
  expect.analyze_ast([[
    ## assert(true)
    local function f(a: auto)
      ## assert(true)
      for i=1,4 do
        local a: #[primtypes.integer]# <comptime> = 2
        ## assert(a.type == primtypes.integer)
      end
    end
  ]])
end)

it("poly function", function()
  expect.analyze_ast([[
    local function f(a: auto)
      ## assert(a.type == primtypes.integer)
    end
    f(1)
  ]])
  expect.analyze_ast([[
    local function f(T: type, x: usize)
       ## assert(x.type == primtypes.usize and T.value == primtypes.integer)
       return x
    end

    f(@integer, 1)
  ]])
  expect.analyze_ast([[
    ## local counter = 0
    local function f() <polymorphic,alwayseval>
       ## counter = counter + 1
    end
    local x = 1
    f()
    f()
    ## after_inference(function() assert(counter == 2) end)
  ]])
  expect.analyze_ast([[
    local function f(x: auto)
      local r = 1.0 + x
      r = r + x
      ## after_inference(function() assert(r.type == primtypes.number) end)
      return r
    end

    local x = f(1.0)
    ## after_inference(function() assert(x.type == primtypes.number) end)
  ]])
  expect.analyze_ast([[
    local function f(T: type)
      return (@pointer(T))(nilptr)
    end

    do
      local p = f(@integer)
      ## after_inference(function() assert(p.type.is_pointer) end)
      p = nilptr
    end
  ]])
  expect.analyze_ast([=[
    local function inc(x: auto)
      local y = x + 1
      return y
    end
    assert(inc(0) == 1)
    assert(inc(1) == 2)
    assert(inc(2.0) == 3.0)

    ## local printtypes = {}
    local function printtype(x: auto)
      ## table.insert(printtypes, x.type.name)
      return x
    end
    assert(printtype(1) == 1)
    assert(printtype(3.14) == 3.14)
    assert(printtype(true) == true)
    assert(printtype(false) == false)
    local a: uint64 = 1
    assert(printtype(a) == 1)
    local b: uint64 = 1
    assert(printtype(b) == 1)
    ##[[ after_inference(function()
      local types = table.concat(printtypes, ' ')
      static_assert(types == 'int64 float64 boolean uint64', types)
    end) ]]
  ]=])
end)

it("report errors", function()
  expect.analyze_error("##[[ invalid() ]]", "a nil value")
  expect.analyze_error("##[[ for ]]", "expected near")
  expect.analyze_error("##[[ ast:raisef('ast error') ]]", "ast error")
  expect.analyze_error('local function f(x: auto): #[assert(false)]# return x end f(1)',
    "while preprocessing function return node")
  expect.analyze_error('local function f(x: auto): #[static_assert(false)]# return x end f(1)',
    "static assertion")
end)

it("preprocessor replacement", function()
  expect.ast_type_equals([=[
  local s = #[symbols.string]#
  local t = #[primtypes.table]#
  local ty = #[primtypes.type]#
  local n = #[primtypes.number]#
]=],[=[
  local s = @string
  local t = @table
  local ty = @type
  local n = @number
]=])
  expect.ast_type_equals([=[
  local int = @integer
  local a: #[int]#
]=],[=[
  local int = @integer
  local a: int
]=])
end)

it("preprocessor functions", function()
  expect.ast_type_equals([=[
    ## function f(name, tyname)
      global #|name|#: #|tyname|#
    ## end
    ## f('i', 'integer')
    ## f('n', 'number')
  ]=],[=[
    global i: integer
    global n: number
  ]=])
end)

it("macros", function()
  expect.ast_type_equals([=[
  ## function increment(a, amount)
    #|a.name|# = #|a.name|# + #[amount]#
  ## end
  local x = 0
  ## increment(x, 4)
  print(x)
]=],[=[
  local x = 0
  x = x + 4
  print(x)
]=])

  expect.ast_type_equals([=[
  ##[[
  function unroll(count, block)
    for i=1,count do
      block()
    end
  end
  ]]

  local counter = 1
  ## unroll(4, function()
    print(counter) -- outputs: 1 2 3 4
    counter = counter + 1
  ## end)
]=],[=[
  local counter = 1
  print(counter)
  counter = counter + 1
  print(counter)
  counter = counter + 1
  print(counter)
  counter = counter + 1
  print(counter)
  counter = counter + 1
]=])

  expect.ast_type_equals([=[
  ## local function gettype(T)
    local t = @#|T|#
    ## return t
  ## end

  local T: type = @#[gettype('byte')]#
  local v: T = 0
]=],[=[
  local t = @byte
  local T: type = @t
  local v: T = 0
]=])
end)

it("expression macros", function()
  expect.analyze_ast([=[
    ## local f = expr_macro(function(x, a, b)
      return (#[x]# << #[a]#) >> #[b]#
    ## end)

    local y <comptime> = #[f(0xff, 2, 3)]#
    ## assert(y.value:tonumber() == 127)
  ]=])

  expect.ast_type_equals([=[
  ## local f = expr_macro(function(x, a, b)
    #[x]# = #[b]#
    return #[a]#
  ## end)
  local a = 0
  local b = #[f]#(a, 0, a + 1)
]=],[=[
  local a = 0
  local b = (do
    a = a + 1
    return 0
  end)
]=])

  expect.analyze_error("local a = #[function() end]#", "cannot convert preprocess value of type")
end)

it("non hygienic macros", function()
  expect.ast_type_equals([=[
## local function inc()
  a = a + 1
## end
local a = 1
## inc()
]=],[=[
local a = 1
a = a + 1
]=])
end)

it("hygienic macros", function()
  expect.ast_type_equals([=[
## local point = hygienize(function(T)
  print('start')
  local T = #[T]#
  local Point = @record{x: T, y: T}
  print('end')
  ## return Point
## end)

do
  local PointInt = #[point(primtypes.integer)]#
  local a: PointInt = {1,2}
end
]=],[=[
print('start')
local T = @integer
local Point = @record{x: T, y: T}
print('end')

do
  local PointInt = @Point
  local a: PointInt = {1,2}
end
]=])
  expect.analyze_error([=[
## local inc = hygienize(function()
  a = a + 1
## end)
local a = 1
## inc()
]=], "undeclared symbol 'a'")
end)

it("generalize macro", function()
  expect.analyze_ast([=[
    ## local make_record = generalize(function(T)
      local RecordT = @record{ x: #[T]# }
      ## return RecordT
    ## end)
    local Foo = #[make_record(primtypes.integer)]#
    local foo: Foo
    ## assert(foo.type.fields.x.type == primtypes.integer)
]=])
  expect.analyze_ast([=[
    ## local make_record = generalize(function(T)
      local RecordT = @record{ x: #[T]# }
      ## return RecordT
    ## end)
    local Record = #[make_record]#
    local foo: Record(integer)
    ## assert(foo.type.fields.x.type == primtypes.integer)
]=])
  expect.analyze_error([=[
    ## local make_record = generalize(function(T)
      local RecordT = @record{ x: #[T]# }
    ## end)
    local Record = #[make_record]#
    local foo: Record(integer)
]=], "expected a type or symbol in generic return")
  expect.analyze_error([=[
    ## local make_record = generalize(function(T)
      local RecordT = @record{ x: #[T]# }
      ## return 1
    ## end)
    local Record = #[make_record]#
    local foo: Record(integer)
]=], "expected a type or symbol in generic return")
end)

it("compiler information", function()
  expect.analyze_ast([=[##[[
    local compiler = require 'nelua.ccompiler'
    local ccinfo = compiler.get_cc_info()
    local ccdefs = compiler.get_cc_defines('<stdbool.h>')
    if not ccinfo.is_cpp then
      assert(ccdefs.bool == '_Bool')
    end
  ]]]=])
end)

it("require override", function()
  expect.analyze_ast([=[##[[
    local console = require 'nelua.utils.console'
    assert(console)
  ]]]=])
  expect.analyze_error([=[##[[
    require 'nelua.utils.invalid'
  ]]]=], 'not found:')
end)

it("run brainfuck", function()
  expect.run('--generator c examples/brainfuck.nelua', 'Hello World!')
end)

end)
