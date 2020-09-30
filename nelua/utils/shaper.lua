-- Shaper module
--
-- This is an interface to the tableshape module with additional
-- shape checkers to be used in the compiler.

local shaper = require 'nelua.thirdparty.tableshape'.types
local tabler = require 'nelua.utils.tabler'
local traits = require 'nelua.utils.traits'
local class = require 'nelua.utils.class'

-- Additional shape check functions.
shaper.optional_boolean = shaper.boolean:is_optional()

shaper.arithmetic = shaper.custom(function(v)
  return traits.is_arithmetic(v), 'expected an arithmetic'
end):describe('arithmetic')

shaper.integral = shaper.custom(function(v)
  return traits.is_integral(v), 'expected an integral'
end):describe('integral')

shaper.symbol = shaper.custom(function(v)
  return traits.is_symbol(v), 'expected a symbol'
end):describe('Symbol')

shaper.astnode = shaper.custom(function(v)
  return traits.is_astnode(v), 'expected a node'
end):describe('ASTNode')

shaper.attr = shaper.custom(function(v)
  return traits.is_attr(v), 'expected an attr'
end):describe('Attr')

shaper.type = shaper.custom(function(v)
  return traits.is_type(v), 'expected a type'
end):describe('Type')

-- Utility to create a type check to check weather a shape is an ASTNode.
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
