require 'busted.runner'()

local astbuilder = require 'euluna.syntaxdefs'().astbuilder
local assert = require 'spec.tools.assert'
local n = astbuilder.aster

describe("Euluna AST should", function()

it("create a valid ASTNode", function()
  local node = n.Number{'dec', '10'}
  assert(node)
  assert.same(node.tag, 'Number')
  assert.same({node:args()}, {'dec', '10'})
end)


it("error on invalid ASTNode", function()
  assert.has_error(function() n.Invalid{} end)
  assert.has_error(function() n.Block{1} end)
  assert.has_error(function() n.Block{ {1} } end)
end)

it("clone different ASTNode", function()
  local node =
    n.Block{ attr={someattr = true}, {
      n.Return{{
        n.Nil{attr={someattr = true}},
  }}}}
  local cloned = node:clone()
  assert(cloned.attr.someattr == nil)
  assert(#cloned.attr == 0)
  assert(cloned ~= node)
  assert(cloned[1] ~= node[1])
  assert(cloned[1][1] ~= node[1][1])
  assert.same(tostring(cloned), [[Block {
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
