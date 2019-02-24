require 'busted.runner'()

local assert = require 'utils.assert'
local euluna_parser = require 'euluna.parsers.euluna_parser'
local lua_generator = require 'euluna.generators.lua_generator'
local stringx = require 'pl.stringx'
local function assert_generate_lua(euluna_code, lua_code)
  local ast = assert.parse_ast(euluna_parser, euluna_code)
  local generated_code = assert(lua_generator:generate(ast))
  assert.same(stringx.rstrip(generated_code), stringx.rstrip(lua_code))
end

describe("Euluna should parse and generate Lua", function()

it("empty file", function()
  assert_generate_lua("", "")
end)
it("returns", function()
  assert_generate_lua("return", "return")
  assert_generate_lua("return 1", "return 1")
end)
it("do block", function()
  assert_generate_lua("do return end", "do\n  return\nend")
end)
end)