
local assert = require 'luassert'
local runner = require 'euluna.runner'
local stringx = require 'pl.stringx'
local inspect = require 'inspect'

-- upper table display limit
assert:set_parameter("TableFormatLevel", 16)

-- inject dump utility while testing
_G.dump = require 'utils.dump'

function assert.ast_equals(expected_ast, ast)
  assert.same(tostring(expected_ast), tostring(ast))
end

function assert.peg_match_all(patt, subjects)
  for _,subject in ipairs(subjects) do
    local matchedpos = patt:match(subject)
    local slen = string.len(subject)
    assert(matchedpos == slen+1, string.format('expected full match on "%s"', subject))
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
      assert(type(ast) == 'table', string.format('expected capture on "%s"', subject))
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
    assert(matchedpos == nil, string.format('expected no match on "%s"', subject))
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
  local ast, _, errdetails = parser:parse(input)
  assert(ast == nil and errdetails and errdetails.label == expected_error,
         string.format('expected error "%s" while parsing', expected_error))
end

local stderr = io.stderr
local stdout = io.stdout
local print = _G.print

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
  io.stderr, io.stdout, _G.print = tmperr, tmpout, rprint
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
  io.stderr, io.stdout, _G.print = stderr, stdout, print
  tmperr:seek('set') tmpout:seek('set')
  local serr, sout = tmperr:read("*a"), tmpout:read("*a")
  tmperr:close() tmpout:close()
  return status, sout, serr
end

function assert.contains(expected, passedin)
  assert(passedin:find(expected, 1, true),
    string.format("Expected string to contains.\nPassed in:\n%s\nExpected:\n%s",
    passedin, expected))
end

function assert.run(args, expected_stdout)
  local status, sout, serr = run(args)
  assert(status == 0, string.format('expected success status on %s:\n%s\n%s', inspect(args), serr, sout))
  if expected_stdout then
    assert.contains(expected_stdout, sout)
  end
end

function assert.run_error(args, expected_stderr)
  local status, sout, serr = run(args)
  assert(status ~= 0, string.format('expected error status on %s:\n%s\n%s', inspect(args), serr, sout))
  if expected_stderr then
    assert.contains(expected_stderr, serr)
  end
end

return assert