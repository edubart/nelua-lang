
local assert = require 'luassert'
local inspect = require 'inspect'
local stringer = require 'euluna.utils.stringer'
local except = require 'euluna.utils.except'
local errorer = require 'euluna.utils.errorer'
local runner = require 'euluna.runner'
local typechecker = require 'euluna.typechecker'
local lua_generator = require 'euluna.luagenerator'
local c_generator = require 'euluna.cgenerator'
local euluna_syntax = require 'euluna.syntaxdefs'()
local euluna_parser = euluna_syntax.parser

function assert.ast_equals(expected_ast, ast)
  assert.same(tostring(expected_ast), tostring(ast))
end

function assert.peg_match_all(patt, subjects)
  for _,subject in ipairs(subjects) do
    local matchedpos = patt:match(subject)
    local slen = string.len(subject)
    errorer.assertf(matchedpos == slen+1, 'expected full match on "%s"', subject)
  end
end

function assert.peg_capture_all(peg, subjects)
  for subject,expected_ast in pairs(subjects) do
    if type(subject) == 'number' then
      subject = expected_ast
      expected_ast = nil
    end

    local ast = peg:match(subject)
    if expected_ast then
      assert.ast_equals(expected_ast, ast)
    else
      errorer.assertf(type(ast) == 'table', 'expected capture on "%s"', subject)
    end
  end
end

function assert.peg_error_all(peg, errname, subjects)
  for _,subject in ipairs(subjects) do
    local res, errlab = peg:match(subject)
    assert.same(errlab, errname)
    assert.same(res, nil)
  end
end

function assert.peg_match_none(peg, subjects)
  for _,subject in pairs(subjects) do
    local matchedpos = peg:match(subject)
    errorer.assertf(matchedpos == nil, 'expected no match on "%s"', subject)
  end
end

function assert.parse_ast(parser, input, expected_ast)
  local ast = assert(parser:parse(input))
  if expected_ast then
    assert.ast_equals(expected_ast, ast)
  else
    assert(ast, 'an valid ast was expected')
  end
  return ast
end

function assert.parse_ast_error(parser, input, expected_error)
  local ast,e = except.try(function()
    parser:parse(input)
  end)
  errorer.assertf(ast == nil and e.label == 'ParseError' and e.syntaxlabel == expected_error,
         'expected error "%s" while parsing', expected_error)
end

local function run(args)
  if type(args) == 'string' then
    args = stringer.split(args)
    setmetatable(args, nil)
  end
  local tmperr, tmpout = io.tmpfile(), io.tmpfile()
  local function rprint(...)
    return tmpout:write(stringer.print_concat(...) .. "\n")
  end
  -- hook print, stderr and stdout
  local ostderr, ostdout, oprint = io.stderr, io.stdout, _G.print
  _G.ostderr, _G.ostdout, _G.oprint = ostderr, ostdout, oprint
  io.stderr, io.stdout, _G.print = tmperr, tmpout, rprint
  -- run the test
  local ok, err = pcall(function()
    return runner.run(args)
  end)
  local status = 1
  if not ok then io.stderr:write(tostring(err) .. '\n')
  else
    status = err
  end
  -- remove hooks
  io.stderr, io.stdout, _G.print = ostderr, ostdout, oprint
  _G.ostderr, _G.ostdout, _G.oprint = nil, nil, nil
  tmperr:seek('set') tmpout:seek('set')
  local serr, sout = tmperr:read("*a"), tmpout:read("*a")
  tmperr:close() tmpout:close()
  return status, sout, serr
end

function assert.contains(expected, passedin)
  errorer.assertf(passedin:find(expected, 1, true),
    "Expected string to contains.\nPassed in:\n%s\nExpected:\n%s",
    passedin, expected)
end

function assert.run(args, expected_stdout)
  local status, sout, serr = run(args)
  errorer.assertf(status == 0, 'expected success status on %s:\n%s\n%s', inspect(args), serr, sout)
  if expected_stdout then
    assert.contains(expected_stdout, sout)
  end
end

function assert.run_error(args, expected_stderr)
  local status, sout, serr = run(args)
  errorer.assertf(status ~= 0, 'expected error status on %s:\n%s\n%s', inspect(args), serr, sout)
  if expected_stderr then
    assert.contains(expected_stderr, serr)
  end
end

function assert.generate_lua(euluna_code, lua_code)
  lua_code = lua_code or euluna_code
  local ast = assert.parse_ast(euluna_parser, euluna_code)
  assert(typechecker.analyze(ast, euluna_parser.astbuilder))
  local generated_code = assert(lua_generator.generate(ast))
  assert.same(stringer.rstrip(lua_code), stringer.rstrip(generated_code))
end

function assert.generate_c(euluna_code, c_code)
  local ast = assert.parse_ast(euluna_parser, euluna_code)
  ast = assert(typechecker.analyze(ast, euluna_parser.astbuilder))
  local generated_code = assert(c_generator.generate(ast))
  if not c_code then c_code = euluna_code end
  errorer.assertf(generated_code:find(c_code or '', 1, true),
    "Expected C code to contains.\nPassed in:\n%s\nExpected:\n%s",
    generated_code, c_code)
end

function assert.run_c(euluna_code, output)
  assert.run({'--generator', 'c', '--eval', euluna_code}, output)
end

function assert.run_error_c(euluna_code, output)
  assert.run_error({'--generator', 'c', '--eval', euluna_code}, output)
end

function assert.c_gencode_equals(code, expected_code)
  local ast = assert.parse_ast(euluna_parser, code)
  ast = assert(typechecker.analyze(ast, euluna_parser.astbuilder))
  local expected_ast = assert.parse_ast(euluna_parser, expected_code)
  expected_ast = assert(typechecker.analyze(expected_ast))
  local generated_code = assert(c_generator.generate(ast))
  local expected_generated_code = assert(c_generator.generate(expected_ast))
  assert.same(expected_generated_code, generated_code)
end

function assert.lua_gencode_equals(code, expected_code)
  local ast = assert.parse_ast(euluna_parser, code)
  ast = assert(typechecker.analyze(ast, euluna_parser.astbuilder))
  local expected_ast = assert.parse_ast(euluna_parser, expected_code)
  expected_ast = assert(typechecker.analyze(expected_ast))
  local generated_code = assert(lua_generator.generate(ast))
  local expected_generated_code = assert(lua_generator.generate(expected_ast))
  assert.same(expected_generated_code, generated_code)
end

function assert.analyze_ast(code, expected_ast)
  local ast = assert.parse_ast(euluna_parser, code)
  typechecker.analyze(ast, euluna_parser.astbuilder)
  if expected_ast then
    assert.same(tostring(expected_ast), tostring(ast))
  end
end

function assert.analyze_error(code, expected_error)
  local ast = assert.parse_ast(euluna_parser, code)
  local ok, e = except.try(function()
    typechecker.analyze(ast, euluna_parser.astbuilder)
  end)
  assert(not ok, "type analysis should fail")
  assert.contains(expected_error, e:get_message())
end

return assert
