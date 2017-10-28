require('compat53')
require('euluna-compiler.global')

local argparse = require('argparse')
local parser = require('euluna-compiler.parser')
local checker = require('euluna-compiler.checker')
local cppcoder = require('euluna-compiler.cppcoder')
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

dump_ast(ast)

assert(checker.check(ast, input, args))

local generated_code = cppcoder.generate(ast, args)
