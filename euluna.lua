#!/usr/bin/env lua

require('euluna-compiler.global')

local argparse = require('argparse')
local parser = require('euluna-compiler.parser')
local cppcoder = require('euluna-compiler.cpp_generator')
local cppcompiler = require('euluna-compiler.cpp_compiler')
local plfile = require('pl.file')

local argparser = argparse("euluna", "Euluna Compiler v0.1")
argparser:argument("inputfile", "Input source file")
argparser:option('--cc', 'Compiler', 'gcc')
argparser:flag('--print-ast', 'Print the AST')
argparser:flag('--print-codegen', 'Print the generated code')
local options = argparser:parse()

local input = assert(plfile.read(options.inputfile))
local ast = assert(parser.parse(input, options))

if options.print_ast then
  dump_ast(ast)
  return
end

if options.print_ast then
  print('\n=== Generated AST:')
  dump_ast(ast)
end

local generated_code = cppcoder.generate(ast, options)

if options.print_codegen then
  print('\n=== Generated C++:')
  print(generated_code)
end

local outputfile = options.inputfile:gsub('.euluna', '')

local ok, ret, stdout, stderr = cppcompiler.compile_and_run(generated_code, outputfile, options)

if stdout and #stdout > 0 then
  io.stdout:write(stdout)
end
if stderr and #stderr > 0 then
  io.stderr:write(stderr)
end

return ret
