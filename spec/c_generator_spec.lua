require 'busted.runner'()

local assert = require 'spec.assert'
local euluna_parser = require 'euluna.parsers.euluna_parser'
local c_generator = require 'euluna.generators.c_generator'
local stringx = require 'pl.stringx'

local function assert_generate_c(euluna_code, c_code)
  local ast = assert.parse_ast(euluna_parser, euluna_code)
  local generated_code = assert(c_generator:generate(ast))
  assert.same(stringx.rstrip(c_code), stringx.rstrip(generated_code))
end

describe("Euluna should parse and generate Lua", function()

it("empty file", function()
  assert_generate_c("", [[int main() {
    return 0;
}]])
end)

it("return", function()
  assert_generate_c("return", [[int main() {
    return 0;
}]])
  assert_generate_c("return 1", [[int main() {
    return 1;
}]])
end)

end)