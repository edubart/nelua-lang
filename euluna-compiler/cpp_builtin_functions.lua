local builtins = {}

function builtins.print(scope, args)
  scope:add_include('<iostream>')
  scope:inline_code('std::cout << ')
  for _,arg in pairs(args) do
    scope:traverse_expr(arg)
    scope:inline_code(' << ')
  end
  scope:inline_code('std::endl;')
  scope:add_newline()
end

return builtins