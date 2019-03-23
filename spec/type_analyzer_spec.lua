require 'busted.runner'()

local assert = require 'spec.assert'
local euluna_std_default = require 'euluna.parsers.euluna_std_default'
local analyzer = require 'euluna.analyzers.types.analyzer'
local euluna_parser = euluna_std_default.parser
local euluna_aster = euluna_std_default.aster
local AST = function(...) return euluna_aster:AST(...) end
local TAST = function(...) return euluna_aster:TAST(...) end

local function assert_analyze_ast(euluna_code, expected_ast)
  local ast = assert.parse_ast(euluna_parser, euluna_code)
  analyzer.analyze(ast)
  assert.same(tostring(expected_ast), tostring(ast))
end

describe("Euluna should parse and generate Lua", function()

it("local variable", function()
  assert_analyze_ast([[
    local a: int
  ]],
    AST('Block', {
      AST('VarDecl', 'local', 'var', {
        TAST('int', 'TypedId', 'a', TAST('int', 'Type', 'int'))})
  }))

  assert_analyze_ast([[
    local a = 1
  ]],
    AST('Block', {
      AST('VarDecl', 'local', 'var',
        { TAST('int', 'TypedId', 'a') },
        { TAST('int', 'Number', 'int', '1') }),
  }))

  assert_analyze_ast([[
    local a: int = 1
  ]],
    AST('Block', {
      AST('VarDecl', 'local', 'var',
        { TAST('int', 'TypedId', 'a', TAST('int', 'Type', 'int')) },
        { TAST('int', 'Number', 'int', '1') }),
  }))

  assert_analyze_ast([[
    local a = 1
    f(a)
  ]],
    AST('Block', {
      AST('VarDecl', 'local', 'var',
        { TAST('int', 'TypedId', 'a') },
        { TAST('int', 'Number', 'int', '1') }),
      AST('Call', {},
        { TAST('int', 'Id', "a") },
        AST('Id', "f"),
        true
      )
  }))
end)

end)
