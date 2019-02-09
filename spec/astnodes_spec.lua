require 'busted.runner'()

local astnodes = require 'euluna.astnodes'
local assert = require 'utils.assert'

describe("AST Node", function()

it("should create a valid ASTNode", function()
  local ast = astnodes.create('Number', 'int', '10')
  assert(ast)
  assert.same(ast.tag, 'Number')
  assert.same({ast:args()}, {'int', '10'})
end)
it("should throw error on invalid ASTNode", function()
  assert.has_error(function() astnodes.create(1, 'Invalid') end)
end)

end)
