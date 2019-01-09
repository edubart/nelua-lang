require 'busted.runner'()

local assert = require 'utils.assert'
local astnodes = require 'euluna.astnodes'
local AST = astnodes.create

describe("Euluna parser should parse", function()

it("empty file", function()
  assert.parse_ast("", AST('Block', {}))
  assert.parse_ast(" \t\n", AST('Block', {}))
  assert.parse_ast(";", AST('Block', {}))
end)

it("invalid statement", function()
  assert.parse_ast_error([[something]], 'UnexpectedSyntaxAtEOF')
end)

it("shebang", function()
  assert.parse_ast([[#!/usr/bin/env lua]], AST('Block', {}))
  assert.parse_ast([[#!/usr/bin/env lua\n]], AST('Block', {}))
end)

it("comments", function()
  assert.parse_ast([=[-- line comment
--[[
multiline comment
]]]=], AST('Block', {}))
end)

describe("return", function()
  it("simple", function()
    assert.parse_ast("return",
      AST('Block', {
        AST('Return')}))
  end)
  it("with semicolon", function()
    assert.parse_ast("return;",
      AST('Block', {
        AST('Return')}))
  end)
  it("with value", function()
    --[[
    assert.parse_ast("return 0",
      AST('Block', {
        AST('Return', {
          AST('Number', 'int', '0')})}))
    ]]
  end)
end)

end)
