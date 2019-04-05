local traits = {}

function traits.is_string(v)
  return type(v) == 'string'
end

function traits.is_number(v)
  return type(v) == 'number'
end

function traits.is_table(v)
  return type(v) == 'table'
end

function traits.is_boolean(v)
  return type(v) == 'boolean'
end

function traits.is_astnode(v)
  return type(v) == 'table' and v._astnode
end

return traits
