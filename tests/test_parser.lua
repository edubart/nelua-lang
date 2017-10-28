local parser = require 'euluna-compiler.parser'
local inspect = require 'inspect'
require 'euluna-compiler.global'

require 'busted.runner'()

local function assert_parse(code, err)
  local ast, err = parser.parse(code)
  assert(ast, inspect(err))
end

local function assert_parse_error(code, expected_err)
  expected_err = expected_err or ''
  local ast, err = parser.parse(code)
  if err then
    assert(err.label == expected_err)
  else
    assert(false, "expected error ".. expected_err)
  end
end

describe("euluna parser", function()
  it("parse eof", function()
    assert_parse([[]])
    assert_parse_error([[asdasd]], 'EOFError')
  end)

  it("parse shebang", function()
    assert_parse([[#!/usr/bin/env lua]])
    assert_parse([[#!/usr/bin/env lua\n]])
  end)

  it("parse comments", function()
    assert_parse([[
      -- line comment
      --[[
        multiline comment
      ]%]
    ]])
  end)

  it("parse return", function()
    assert_parse([[
      wont match
      return lol
    ]])
  end)
end)
