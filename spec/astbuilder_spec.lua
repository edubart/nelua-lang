local lusted = require 'nelua.thirdparty.lusted'
local describe, it = lusted.describe, lusted.it

local astbuilder = require 'nelua.syntaxdefs'().astbuilder
local expect = require 'spec.tools.expect'
local Attr = require 'nelua.attr'
local n = astbuilder.aster

describe("astbuilder", function()

it("create a valid ASTNode", function()
  local node = n.Number{'dec', '10'}
  assert(node)
  expect.equal(node.tag, 'Number')
  expect.equal({node:args()}, {'dec', '10'})
end)


it("error on invalid ASTNode", function()
  expect.fail(function() n.Invalid{} end)
  expect.fail(function() n.Block{1} end)
  expect.fail(function() n.Block{{1}} end)
  expect.fail(function() n.Block{{'a'}} end,
    [[invalid shape while creating AST node "Block": field 1: array item 1: expected "aster.Node"]])
  expect.fail(function() astbuilder:create('Invalid') end)
end)

it("clone different ASTNode", function()
  local node =
    n.Block{attr=Attr{someattr = true}, {
      n.Return{{
        n.Nil{attr=Attr{someattr = true}},
  }}}}
  local cloned = node:clone()
  assert(cloned.attr.someattr == nil)
  assert(#cloned.attr == 0)
  assert(cloned ~= node)
  assert(cloned[1] ~= node[1])
  assert(cloned[1][1] ~= node[1][1])
  expect.equal(tostring(cloned), [[Block {
  {
    Return {
      {
        Nil {
        }
      }
    }
  }
}]])
end)

end)
