require 'busted.runner'()

local assert = require 'utils.assert'
local astnodes = require 'euluna.astnodes'
local AST = astnodes.create
local euluna_parser = require 'euluna.langs.euluna_parser'

describe("Euluna should parse", function()

--------------------------------------------------------------------------------
-- empty file
--------------------------------------------------------------------------------
it("empty file", function()
  assert.parse_ast(euluna_parser, "", AST('Block', {}))
  assert.parse_ast(euluna_parser, " \t\n", AST('Block', {}))
  assert.parse_ast(euluna_parser, ";", AST('Block', {}))
end)

--------------------------------------------------------------------------------
-- invalid syntax
--------------------------------------------------------------------------------
it("invalid syntax", function()
  assert.parse_ast_error(euluna_parser, [[something]], 'UnexpectedSyntaxAtEOF')
end)

--------------------------------------------------------------------------------
-- shebang
--------------------------------------------------------------------------------
it("shebang", function()
  assert.parse_ast(euluna_parser, [[#!/usr/bin/env lua]], AST('Block', {}))
  assert.parse_ast(euluna_parser, [[#!/usr/bin/env lua\n]], AST('Block', {}))
end)

--------------------------------------------------------------------------------
-- comments
--------------------------------------------------------------------------------
it("comments", function()
  assert.parse_ast(euluna_parser, [=[-- line comment
--[[
multiline comment
]]]=], AST('Block', {}))
end)

--------------------------------------------------------------------------------
-- return statement
--------------------------------------------------------------------------------
describe("return", function()
  it("simple", function()
    assert.parse_ast(euluna_parser, "return",
      AST('Block', {
        AST('Stat_Return', {})
    }))
  end)
  it("with semicolon", function()
    assert.parse_ast(euluna_parser, "return;",
      AST('Block', {
        AST('Stat_Return', {})
    }))
  end)
  it("with value", function()
    assert.parse_ast(euluna_parser, "return 0",
      AST('Block', {
        AST('Stat_Return', {
          AST('Number', 'int', '0')
    })}))
  end)
  it("with multiple values", function()
    assert.parse_ast(euluna_parser, "return 1,2,3",
      AST('Block', {
        AST('Stat_Return', {
          AST('Number', 'int', '1'),
          AST('Number', 'int', '2'),
          AST('Number', 'int', '3'),
    })}))
  end)
end)

--------------------------------------------------------------------------------
-- expressions
--------------------------------------------------------------------------------
describe("expression", function()
  it("number", function()
    assert.parse_ast(euluna_parser, "return 3.34e-50",
      AST('Block', {
        AST('Stat_Return', {
          AST('Number', 'exp', '3.34', '-50'),
    })}))
  end)
  it("string", function()
    assert.parse_ast(euluna_parser, [[return 'hi', "there"]],
      AST('Block', {
        AST('Stat_Return', {
          AST('String', 'hi'),
          AST('String', 'there')
    })}))
  end)
  it("boolean", function()
    assert.parse_ast(euluna_parser, "return true, false",
      AST('Block', {
        AST('Stat_Return', {
          AST('Boolean', true),
          AST('Boolean', false)
    })}))
  end)
  it("nil", function()
    assert.parse_ast(euluna_parser, "return nil",
      AST('Block', {
        AST('Stat_Return', {
          AST('Nil'),
    })}))
  end)
  it("varargs", function()
    assert.parse_ast(euluna_parser, "return ...",
      AST('Block', {
        AST('Stat_Return', {
          AST('Varargs'),
    })}))
  end)
end)


--------------------------------------------------------------------------------
-- operators
--------------------------------------------------------------------------------
describe("operator", function()
  it("OR", function()
    assert.parse_ast(euluna_parser, "return 1 or 2",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp',
            'or',
            AST('Number', 'int', '1'),
            AST('Number', 'int', '2')
    )})}))
  end)
  it("AND", function()
    assert.parse_ast(euluna_parser, "return 1 and 2",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp',
            'and',
            AST('Number', 'int', '1'),
            AST('Number', 'int', '2')
    )})}))
  end)
end)

--------------------------------------------------------------------------------
-- live grammar change
--------------------------------------------------------------------------------
describe("live grammar change for", function()
  it("return keyword", function()
    euluna_parser:add_keyword("do_return")
    euluna_parser:set_pegs([[
      %stat_return <-
        ({} %DO_RETURN -> 'Stat_Return' {| (%expr (%COMMA %expr)*)? |} %SEMICOLON?) -> to_astnode
    ]])
    euluna_parser:remove_keyword("return")

    assert.parse_ast(euluna_parser, "do_return",
      AST('Block', {
        AST('Stat_Return', {})}))
    assert.parse_ast_error(euluna_parser, "return", 'UnexpectedSyntaxAtEOF')
  end)

  it("return keyword (revert)", function()
    euluna_parser:add_keyword("return")
    euluna_parser:set_pegs([[
      %stat_return <-
        ({} %RETURN -> 'Stat_Return' {| (%expr (%COMMA %expr)*)? |} %SEMICOLON?) -> to_astnode
    ]])
    euluna_parser:remove_keyword("do_return")

    assert.parse_ast(euluna_parser, "return",
      AST('Block', {
        AST('Stat_Return', {})}))
    assert.parse_ast_error(euluna_parser, "do_return", 'UnexpectedSyntaxAtEOF')
  end)
end)

end)
