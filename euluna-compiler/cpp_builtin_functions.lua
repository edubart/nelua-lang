local builtins = {}

function builtins.print(scope, args)
  scope:add_include('<iostream>')
  scope:add('std::cout << ')
  for i,arg in ipairs(args) do
    if i > 1 then
      scope:add("'\\t' << ")
    end
    scope:traverse_tostring(arg)
    scope:add(' << ')
  end
  scope:add('std::endl')
end

return builtins
