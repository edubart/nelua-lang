require 'busted.runner'()

local assert = require 'spec.assert'
local euluna_syntax = require 'euluna.syntaxdefs'()
local analyzer = require 'euluna.typechecker'
local c_generator = require 'euluna.cgenerator'
local lua_generator = require 'euluna.luagenerator'
local euluna_parser = euluna_syntax.parser
local euluna_astbuilder = euluna_syntax.astbuilder
local except = require 'euluna.utils.except'
local config = require 'euluna.configer'.get()
local n = euluna_astbuilder.aster

local function assert_c_gencode_equals(code, expected_code)
  local ast = assert.parse_ast(euluna_parser, code)
  ast = assert(analyzer.analyze(ast, euluna_parser.astbuilder))
  local expected_ast = assert.parse_ast(euluna_parser, expected_code)
  expected_ast = assert(analyzer.analyze(expected_ast))
  local generated_code = assert(c_generator.generate(ast))
  local expected_generated_code = assert(c_generator.generate(expected_ast))
  assert.same(expected_generated_code, generated_code)
end

local function assert_lua_gencode_equals(code, expected_code)
  local ast = assert.parse_ast(euluna_parser, code)
  ast = assert(analyzer.analyze(ast, euluna_parser.astbuilder))
  local expected_ast = assert.parse_ast(euluna_parser, expected_code)
  expected_ast = assert(analyzer.analyze(expected_ast))
  local generated_code = assert(lua_generator.generate(ast))
  local expected_generated_code = assert(lua_generator.generate(expected_ast))
  assert.same(expected_generated_code, generated_code)
end

local function assert_analyze_ast(code, expected_ast)
  local ast = assert.parse_ast(euluna_parser, code)
  analyzer.analyze(ast, euluna_parser.astbuilder)
  if expected_ast then
    assert.same(tostring(expected_ast), tostring(ast))
  end
end

local function assert_analyze_error(code, expected_error)
  local ast = assert.parse_ast(euluna_parser, code)
  local ok, e = except.try(function()
    analyzer.analyze(ast, euluna_parser.astbuilder)
  end)
  assert(not ok, "type analysis should fail")
  assert.contains(expected_error, e:get_message())
end

describe("Euluna should check types for", function()

it("local variable", function()
  assert_analyze_ast("local a: integer",
    n.Block { {
      n.VarDecl { 'local', 'var',
        { n.IdDecl{ assign=true, type='int64', 'a', 'var', n.Type { type='int64', 'integer'}} }
      }
    } }
  )

  assert_analyze_ast("local a: integer = 1",
    n.Block { {
      n.VarDecl { 'local', 'var',
        { n.IdDecl{ assign=true, type='int64', 'a', 'var', n.Type { type='int64', 'integer'}} },
        { n.Number{ type='int64', 'int', '1'} }
      }
    } }
  )

  assert_analyze_ast("local a = 1; f(a)",
    n.Block { {
      n.VarDecl { 'local', 'var',
        { n.IdDecl { assign=true, type='int64', 'a', 'var' } },
        { n.Number { type='int64', 'int', '1' } }
      },
      n.Call { callee_type='any', type='any', {},
        { n.Id { type='int64', "a"} },
        n.Id { type='any', "f"},
        true
    }
  }})

  assert_c_gencode_equals("local a = 1", "local a: integer = 1")
  assert_analyze_error("local a: integer = 'string'", "is not conversible with")
  assert_analyze_error("local a: uint8 = 1.0", "is not conversible with")
end)

it("typed var initialization", function()
  assert_lua_gencode_equals("local a: integer", "local a: integer = 0")
  assert_lua_gencode_equals("local a: boolean", "local a: boolean = false")
  assert_lua_gencode_equals("local a: table<integer>", "local a: table<integer> = {}")
end)

it("loop variables", function()
  assert_c_gencode_equals("for i=1,10 do end", "for i:integer=1,10 do end")
  assert_c_gencode_equals("for i=1,10,2 do end", "for i:integer=1,10,2 do end")
  assert_c_gencode_equals("for i=0_i,1_i-1 do end", "for i:integer=0_i,1_i-1 do end")
  assert_analyze_error("for i:uint8=1.0,10 do end", "is not conversible with")
  assert_analyze_error("for i:uint8=1_u8,10 do end", "is not conversible with")
  assert_analyze_error("for i:uint8=1_u8,10_u8,2 do end", "is not conversible with")
end)

it("variable assignments", function()
  assert_c_gencode_equals("local a; a = 1", "local a: integer; a = 1")
  assert_analyze_error("local a: integer; a = 's'", "is not conversible with")
end)

it("unary operators", function()
  assert_c_gencode_equals("local a = not b", "local a: boolean = not b")
  assert_c_gencode_equals("local a = -1", "local a: integer = -1")
  assert_analyze_error("local a = -1_u", "is not defined for type")
end)

it("binary operators", function()
  assert_c_gencode_equals("local a = 1 + 2", "local a: integer = 1 + 2")
  assert_c_gencode_equals("local a = 1 + 2.0", "local a: number = 1 + 2.0")
  assert_c_gencode_equals("local a = 1_i8 + 2_u8", "local a: int16 = 1_i8 + 2_u8")
  assert_analyze_error("local a = 1 + 's'", "is not defined for type")
  assert_analyze_error("local a = -1_u", "is not defined for type")
end)

it("binary conditional operators", function()
  assert_c_gencode_equals("local a = 1 and 2", "local a: integer = 1 and 2")
  assert_c_gencode_equals("local a = 1_i8 and 2_u8", "local a: int16 = 1_i8 and 2_u8")
end)

it("operation with parenthesis", function()
  assert_c_gencode_equals("local a = -(1)", "local a: integer = -(1)")
end)

it("recursive late deduction", function()
  assert_c_gencode_equals([[
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
  assert_c_gencode_equals([[
    local a = 1_integer
    local b = a + 1
  ]],[[
    local a: integer = 1_integer
    local b: integer = a + 1
  ]])
  assert_c_gencode_equals([[
    local limit = 1_integer
    for i=1,limit do end
  ]],[[
    local limit = 1_integer
    for i:integer=1,limit do end
  ]])
end)

it("function definition", function()
  assert_analyze_ast([[
    local f
    function f() end
  ]])
  assert_analyze_ast([[
    local function f(a: integer) end
    function f(a: integer) end
  ]])
  assert_analyze_ast([[
    local f: function<(integer): string>
    function f(a: integer): string end
  ]])
  assert_analyze_error([[
    local f: int
    function f(a: integer) return 0 end
  ]], "is not conversible with")
  assert_analyze_error([[
    local function f(a: integer) end
    function f(a: integer, b:integer) end
  ]], "is not conversible with")
  assert_analyze_error([[
    local function f(a: integer) end
    function f(a: string) end
  ]], "is not conversible with")
  assert_analyze_error([[
    local function f(): integer, string end
    function f(): integer end
  ]], "is not conversible with")
  assert_analyze_error([[
    local f: function<():integer, string>
    function f(): integer end
  ]], "is not conversible with")
end)

it("function return", function()
  assert_c_gencode_equals(
    "local function f() return 0 end",
    "local function f(): integer return 0 end"
  )
  assert_c_gencode_equals([[
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
  assert_analyze_error([[
    local function f(): string return 0 end
  ]], "is not conversible with")
end)

it("function call", function()
  assert_c_gencode_equals([[
    local function f() return 0 end
    local a = f()
  ]],[[
    local function f(): integer return 0 end
    local a: integer = f()
  ]])
  assert_analyze_error([[
    local a: integer = 1
    a()
  ]], "attempt to call a non callable variable")
  assert_analyze_error([[
    local function f(a: integer) end
    f('a')
  ]], "is not conversible with")
end)

it("array tables", function()
  assert_analyze_ast([[
    local a: table<boolean>
    local b: table<boolean>
    b = a
  ]])
  assert_c_gencode_equals([[
    local a: table<boolean>
    local b = a[0]
  ]],[[
    local a: table<boolean>
    local b: boolean = a[0]
  ]])
  assert_analyze_error([[
    local a: table<integer>
    local b: table<boolean>
    b = a
  ]], "is not conversible with")
  assert_analyze_error([[
    local a: table<integer, boolean>
    local b: table<integer, integer>
    b = a
  ]], "is not conversible with")
end)

it("strict mode", function()
  config.strict = true
  assert_analyze_error("a = 1", "undeclarated symbol")
  assert_analyze_error("local a; local a", "shadows pre declarated symbol")
  config.string = false
end)

end)
