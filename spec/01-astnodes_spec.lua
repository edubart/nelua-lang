require 'busted.runner'()

local astbuilder = require 'euluna.syntaxdefs'().astbuilder
local assert = require 'spec.assert'
local AST = function(...) return astbuilder:AST(...) end

describe("Euluna AST should", function()

--------------------------------------------------------------------------------
-- AST syntax validity
--------------------------------------------------------------------------------
it("create a valid ASTNode", function()
  local ast = AST('Number', 'int', '10')
  assert(ast)
  assert.same(ast.tag, 'Number')
  assert.same({ast:args()}, {'int', '10'})
end)


--------------------------------------------------------------------------------
-- AST error checking
--------------------------------------------------------------------------------
it("error on invalid ASTNode", function()
  assert.has_error(function() AST('Invalid') end)
  assert.has_error(function() AST('Block', 1) end)
  assert.has_error(function() AST('Block', {1}) end)
end)

end)
