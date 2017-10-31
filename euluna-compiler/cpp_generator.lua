local cpp_generator = {}

local function make_context(args)
  return {
    args = args,
    code = {}
  }
end

local function traverse_ast(ctx, node, stack)
  for _,cnode in ipairs(node) do
    if cnode.tag == 'return_stat' then
      traverse_ast(ctx, cnode)
      -- declare functions and variables
    end
  end
end

local function code_main(ctx, ast)
  return [[
int main() {
  return 0;
}
]]
end

function cpp_generator.generate(ast, args)
  local ctx = make_context(args)
  assert(ast, "nil ast")
  traverse_ast(ctx, ast)

  local main = code_main(ctx, ast)
  table.insert(ctx.code, main)

  return table.concat(ctx.code)
end

return cpp_generator
