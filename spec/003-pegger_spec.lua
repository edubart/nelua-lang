require 'busted.runner'()

local assert = require 'spec.tools.assert'
local pegger = require 'nelua.utils.pegger'

describe("Nelua pegger should work for", function()

it("c double quoting", function()
  local q = pegger.double_quote_c_string
  assert.same(q [[hello world]], [["hello world"]])
  assert.same(q [["]], [["\""]])
  assert.same(q [[']], [["'"]])
  assert.same(q [[\]], [["\\"]])
  assert.same(q "\t", [["\t"]])
  assert.same(q "\a", [["\a"]])
  assert.same(q "\b", [["\b"]])
  assert.same(q "\f", [["\f"]])
  assert.same(q "\n", [["\n"]])
  assert.same(q "\r", [["\r"]])
  assert.same(q "\v", [["\v"]])
  assert.same(q "\001", [["\001"]])
  assert.same(q "\255", [["\377"]])

  -- trigraphs
  assert.same(q "??=", [["?\?="]])
  assert.same(q "??/", [["?\?/"]])
  assert.same(q "??'", [["?\?'"]])
  assert.same(q "??(", [["?\?("]])
  assert.same(q "??)", [["?\?)"]])
  assert.same(q "??!", [["?\?!"]])
  assert.same(q "??<", [["?\?<"]])
  assert.same(q "??>", [["?\?>"]])
  assert.same(q "??-", [["?\?-"]])
end)

end)
