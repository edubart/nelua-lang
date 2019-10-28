local luabuiltins = {}

local operators = {}
luabuiltins.operators = operators

function operators.idiv(_, _, emitter, lnode, rnode)
  emitter:add('math.floor(', lnode, ' / ', rnode, ')')
end

local builtins = {}
luabuiltins.builtins = builtins

function builtins.bit()
end

return luabuiltins
