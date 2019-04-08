local builtins = {}

function builtins.idiv(_, _, emitter, lnode, rnode)
  emitter:add('math.floor(', lnode, ' / ', rnode, ')')
end

return builtins
