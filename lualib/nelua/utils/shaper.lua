--[[
Shaper module

This is an interface to the `tableshape` module with additional
shape checkers to be used in the compiler.
]]

local shaper = require 'nelua.thirdparty.tableshape'.types
local tabler = require 'nelua.utils.tabler'
local traits = require 'nelua.utils.traits'
local class = require 'nelua.utils.class'

-- Shape for an optional boolean.
shaper.optional_boolean = shaper.boolean:is_optional()

-- Shape for a value that can be either `false` or `nil`.
shaper.falsy = shaper.custom(function(v)
  return not v, 'expected false or nil'
end)

-- Shape for a scalar value (a lua number or a big number).
shaper.scalar = shaper.custom(function(v)
  return traits.is_scalar(v), 'expected an scalar'
end):describe('scalar')

-- Shape for an integral number.
shaper.integral = shaper.custom(function(v)
  return traits.is_integral(v), 'expected an integral'
end):describe('integral')

-- Shape for an AST Node.
shaper.astnode = shaper.custom(function(v)
  return traits.is_astnode(v), 'expected a node'
end):describe('ASTNode')

-- Shape for an Attr.
shaper.attr = shaper.custom(function(v)
  return traits.is_attr(v), 'expected an attr'
end):describe('Attr')

-- Shape for a symbol.
shaper.symbol = shaper.custom(function(v)
  return traits.is_symbol(v), 'expected a symbol'
end):describe('Symbol')

-- Shape for a Scope.
shaper.scope = shaper.custom(function(v)
  return traits.is_scope(v), 'expected a scope'
end):describe('Scope')

-- Shape for a Type.
shaper.type = shaper.custom(function(v)
  return traits.is_type(v), 'expected a type'
end):describe('Type')

-- Utility to create a type check to check whether a shape is an ASTNode.
function shaper.ast_node_of(nodeklass)
  return shaper.custom(function(val)
    if class.is(val, nodeklass) then return true end
    return nil, string.format('expected type aster.%s, got "%s"', nodeklass.tag, type(val))
  end):describe('"aster.'..nodeklass.tag..'"')
end

-- Utility to fork a shape definition from another shape definition.
function shaper.fork_shape(baseshape, desc)
  local shape = shaper.shape(desc)
  tabler.update(shape.shape, baseshape.shape)
  return shape
end

return shaper
