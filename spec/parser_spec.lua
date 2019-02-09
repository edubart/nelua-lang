require 'busted.runner'()

local assert = require 'utils.assert'
local astnodes = require 'euluna.astnodes'
local AST = astnodes.create
local euluna_parser = require 'euluna.langs.euluna_parser'

describe("Euluna parser should parse", function()

it("empty file", function()
  assert.parse_ast(euluna_parser, "", AST('Block', {}))
  assert.parse_ast(euluna_parser, " \t\n", AST('Block', {}))
  assert.parse_ast(euluna_parser, ";", AST('Block', {}))
end)

it("invalid statement", function()
  assert.parse_ast_error(euluna_parser, [[something]], 'UnexpectedSyntaxAtEOF')
end)

it("shebang", function()
  assert.parse_ast(euluna_parser, [[#!/usr/bin/env lua]], AST('Block', {}))
  assert.parse_ast(euluna_parser, [[#!/usr/bin/env lua\n]], AST('Block', {}))
end)

it("comments", function()
  assert.parse_ast(euluna_parser, [=[-- line comment
--[[
multiline comment
]]]=], AST('Block', {}))
end)

describe("return", function()
  it("simple", function()
    assert.parse_ast(euluna_parser, "return",
      AST('Block', {
        AST('Stat_Return')}))
  end)
  it("with semicolon", function()
    assert.parse_ast(euluna_parser, "return;",
      AST('Block', {
        AST('Stat_Return')}))
  end)
  it("with value", function()
    --[[
    assert.parse_ast(euluna_parser, "return 0",
      AST('Block', {
        AST('Stat_Return', {
          AST('Number', 'int', '0')})}))
    ]]
  end)
end)

describe("live grammar change for", function()
  it("return keyword", function()
    euluna_parser:add_keyword("do_return")
    euluna_parser:set_pegs([[
      %stat_return <-
        ({} %DO_RETURN -> 'Stat_Return' %SEMICOLON?) -> to_astnode
    ]])
    euluna_parser:remove_keyword("return")

    assert.parse_ast(euluna_parser, "do_return",
      AST('Block', {
        AST('Stat_Return')}))
    assert.parse_ast_error(euluna_parser, "return", 'UnexpectedSyntaxAtEOF')
  end)

  it("return keyword (revert)", function()
    euluna_parser:add_keyword("return")
    euluna_parser:set_pegs([[
      %stat_return <-
        ({} %RETURN -> 'Stat_Return' %SEMICOLON?) -> to_astnode
    ]])
    euluna_parser:remove_keyword("do_return")

    assert.parse_ast(euluna_parser, "return",
      AST('Block', {
        AST('Stat_Return')}))
    assert.parse_ast_error(euluna_parser, "do_return", 'UnexpectedSyntaxAtEOF')
  end)
end)

end)
