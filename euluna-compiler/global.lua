local inspect = require('inspect')

function dump(...)
  local args = {...}
  for k,v in pairs(args) do
    args[k] = inspect(v)
  end
  print(unpack(args))
end

function dump_ast(ast)
  print(inspect(ast, {
    process = function(item, path)
      local k = path[#path]
      if k ~= inspect.METATABLE and k ~= 'pos' then
        return item
      end
    end
  }))
end
