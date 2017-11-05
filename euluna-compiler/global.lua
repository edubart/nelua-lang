local inspect = require('inspect')
local stringx = require('pl.stringx')
stringx.import()

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

function izip(t1, t2)
  local i = 0
  return function()
    i = i + 1
    local a, b = t1[i], t2[i]
    if a ~= nil or b ~= nil then
      return i, a, b
    end
  end
end
