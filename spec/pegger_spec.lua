local lester = require 'nelua.thirdparty.lester'
local describe, it = lester.describe, lester.it

local expect = require 'spec.tools.expect'
local pegger = require 'nelua.utils.pegger'

describe("pegger", function()

it("c double quoting", function()
  local q = pegger.double_quote_c_string
  expect.equal(q [[hello world]], [["hello world"]])
  expect.equal(q [["]], [["\""]])
  expect.equal(q [[']], [["'"]])
  expect.equal(q [[\]], [["\\"]])
  expect.equal(q "\t", [["\t"]])
  expect.equal(q "\a", [["\a"]])
  expect.equal(q "\b", [["\b"]])
  expect.equal(q "\f", [["\f"]])
  expect.equal(q "\n", [["\n"]])
  expect.equal(q "\r", [["\r"]])
  expect.equal(q "\v", [["\v"]])
  expect.equal(q "\001", [["\001"]])
  expect.equal(q "\255", [["\377"]])

  -- trigraphs
  expect.equal(q "??=", [["?\?="]])
  expect.equal(q "??/", [["?\?/"]])
  expect.equal(q "??'", [["?\?'"]])
  expect.equal(q "??(", [["?\?("]])
  expect.equal(q "??)", [["?\?)"]])
  expect.equal(q "??!", [["?\?!"]])
  expect.equal(q "??<", [["?\?<"]])
  expect.equal(q "??>", [["?\?>"]])
  expect.equal(q "??-", [["?\?-"]])
end)

end)
