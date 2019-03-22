
local assert = require 'luassert'
local runner = require 'euluna.runner'
local stringx = require 'pl.stringx'
local inspect = require 'inspect'
local assertf = require 'euluna.utils.errorer'.assertf

function assert.ast_equals(expected_ast, ast)
  assert.same(tostring(expected_ast), tostring(ast))
end

function assert.peg_match_all(patt, subjects)
  for _,subject in ipairs(subjects) do
    local matchedpos = patt:match(subject)
    local slen = string.len(subject)
    assertf(matchedpos == slen+1, 'expected full match on "%s"', subject)
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
      assertf(type(ast) == 'table', 'expected capture on "%s"', subject)
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
    assertf(matchedpos == nil, 'expected no match on "%s"', subject)
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
  local ast, _, errlabel = parser:parse(input)
  assertf(ast == nil and errlabel and errlabel == expected_error,
         'expected error "%s" while parsing', expected_error)
end

local function run(args)
  if type(args) == 'string' then
    args = stringx.split(args)
    setmetatable(args, nil)
  end
  local tmperr, tmpout = io.tmpfile(), io.tmpfile()
  local function rprint(...)
    return tmpout:write(table.concat({...}, "\t") .. "\n")
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
  if not ok then
    io.stderr:write(err .. '\n')
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
  assertf(passedin:find(expected, 1, true),
    "Expected string to contains.\nPassed in:\n%s\nExpected:\n%s",
    passedin, expected)
end

function assert.run(args, expected_stdout)
  local status, sout, serr = run(args)
  assertf(status == 0, 'expected success status on %s:\n%s\n%s', inspect(args), serr, sout)
  if expected_stdout then
    assert.contains(expected_stdout, sout)
  end
end

function assert.run_error(args, expected_stderr)
  local status, sout, serr = run(args)
  assertf(status ~= 0, 'expected error status on %s:\n%s\n%s', inspect(args), serr, sout)
  if expected_stderr then
    assert.contains(expected_stderr, serr)
  end
end

return assert