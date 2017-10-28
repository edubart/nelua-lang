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
      if path[#path] ~= inspect.METATABLE then
        return item
      end
    end
  }))
end
