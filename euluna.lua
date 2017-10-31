require('euluna-compiler.global')

local argparse = require('argparse')
local parser = require('euluna-compiler.parser')
local cppcoder = require('euluna-compiler.cpp_generator')
local cppcompiler = require('euluna-compiler.cpp_compiler')
local plfile = require('pl.file')

local argparser = argparse("euluna", "Euluna Compiler v0.1")
argparser:argument("inputfile", "Input source file")
argparser:flag('--print-ast', 'Print the AST')
local args = argparser:parse()

local input = assert(plfile.read(args.inputfile))
local ast = assert(parser.parse(input, args))

if args.print_ast then
  dump_ast(ast)
  return
end

print('\n=== Generated AST:')
dump_ast(ast)

local generated_code = cppcoder.generate(ast, args)

print('\n=== Generated C++:')
print(generated_code)

--local outputfile = args.inputfile:gsub('.euluna', '')
local outputfile = 'example'

local ok, ret, stdout, stderr = cppcompiler.compile_and_run(generated_code, outputfile)

if stdout and #stdout > 0 then
  io.stdout:write(stdout)
end
if stderr and #stderr > 0 then
  io.stderr:write(stderr)
end

return ret