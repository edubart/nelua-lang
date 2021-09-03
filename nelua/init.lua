--[[
This script is usually called with 'nelua-lua -lnelua',
we should remove that first '-lnelua' argument.
]]
local args = _G.arg
for i=1,#args do
  if args[i] == '-lnelua' then
    table.remove(args, i)
  end
end

-- Run the Nelua compiler.
os.exit(require'nelua.runner'.run(args))
