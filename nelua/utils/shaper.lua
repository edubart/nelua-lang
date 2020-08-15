local shaper = require 'nelua.thirdparty.tableshape'.types
local tabler = require 'nelua.utils.tabler'
local traits = require 'nelua.utils.traits'

-- Additional shape check functions.
shaper.arithmetic = shaper.custom(function(v)
  return traits.is_arithmetic(v), 'expected an arithmetic'
end)

shaper.integral = shaper.custom(function(v)
  return traits.is_integral(v), 'expected an integral'
end)

shaper.symbol = shaper.custom(function(v)
  return traits.is_symbol(v), 'expected a symbol'
end)

shaper.astnode = shaper.custom(function(v)
  return traits.is_astnode(v), 'expected a node'
end)

shaper.attr = shaper.custom(function(v)
  return traits.is_attr(v), 'expected an attr'
end)

shaper.type = shaper.custom(function(v)
  return traits.is_type(v), 'expected a type'
end)

shaper.optional_boolean = shaper.boolean:is_optional()

-- Fork the shape definition from another shape definition.
function shaper.fork_shape(baseshape, desc)
  local shape = shaper.shape(desc)
  tabler.update(shape.shape, baseshape.shape)
  return shape
end

return shaper
