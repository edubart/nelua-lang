local assert = require 'luassert'
local stringer = require 'nelua.utils.stringer'
local except = require 'nelua.utils.except'
local errorer = require 'nelua.utils.errorer'
local pegger = require 'nelua.utils.pegger'
local runner = require 'nelua.runner'
local analyzer = require 'nelua.analyzer'
local fs = require 'nelua.utils.fs'
local traits = require 'nelua.utils.traits'
local lua_generator = require 'nelua.luagenerator'
local c_generator = require 'nelua.cgenerator'
local differ = require 'spec.tools.differ'
local nelua_syntax = require 'nelua.syntaxdefs'()
local config = require 'nelua.configer'.get()
local nelua_parser = nelua_syntax.parser

-- config setup for the test suite
config.check_ast_shape = true
config.quiet = true
config.lua_version = '5.3'

-- use cache subfolder while testing
config.cache_dir = fs.join(config.cache_dir, 'spec')

assert.config = { srcname = nil }

function assert.same_string(expected, passedin)
  if expected ~= passedin then --luacov:disable
    error('Expected strings to be the same, difference:\n' ..
      differ(expected, passedin):tostring({colored = true, context=3}))
  end --luacov:enable
end

function assert.contains(expected, passedin)
  errorer.assertf(passedin:find(expected, 1, true),
    "Expected string to contains.\nPassed in:\n%s\nExpected:\n%s",
    passedin, expected)
end

function assert.ast_equals(expected_ast, ast)
  assert.same_string(tostring(expected_ast), tostring(ast))
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
  local ast = assert(parser:parse(input, assert.config.srcname))
  if expected_ast then
    assert.ast_equals(expected_ast, ast)
  else
    assert(ast, 'an valid ast was expected')
  end
  return ast
end

function assert.parse_ast_error(parser, input, expected_error)
  local ast,e = except.try(function()
    parser:parse(input, assert.config.srcname)
  end)
  errorer.assertf(ast == nil and e.label == 'ParseError' and e.syntaxlabel == expected_error,
         'expected error "%s" while parsing', expected_error)
end

--luacov:disable
local function pretty_traceback_errhandler(e)
  if type(e) == 'string' then
    local msg = debug.traceback(e, 2)
    local i = msg:find('\n%s+[%w%s%/%\\%.%-_ ]+busted[/\\]+[a-z]+%.lua')
    if i then
      msg = msg:sub(1, i) .. '        (...busted...)\n'
    end
    return msg
  else
    return e
  end
end
--luacov:enable

local function run(args)
  if type(args) == 'string' then
    args = stringer.split(args)
    setmetatable(args, nil)
  end
  local tmperr, tmperrname = fs.tmpfile()
  local tmpout, tmpoutname = fs.tmpfile()
  local function rprint(...) return tmpout:write(stringer.pconcat(...) .. "\n") end
  -- hook print, stderr and stdout
  local ostderr, ostdout, oprint = io.stderr, io.stdout, _G.print
  _G.ostderr, _G.ostdout, _G.oprint = ostderr, ostdout, oprint
  io.stderr, io.stdout, _G.print = tmperr, tmpout, rprint
  -- run the test
  local ok, err = xpcall(function()
    return runner.run(args, true)
  end, pretty_traceback_errhandler)
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
  serr, sout = pegger.normalize_newlines(serr), pegger.normalize_newlines(sout)
  tmperr:close() tmpout:close()
  fs.deletefile(tmperrname) fs.deletefile(tmpoutname)
  return status, sout, serr
end

function assert.run(args, expected_stdout, expected_stderr)
  local status, sout, serr = run(args)
  errorer.assertf(status == 0, 'expected success status in run:\n%s\n%s', serr, sout)
  if expected_stdout then
    assert.contains(expected_stdout, sout)
  end
  if expected_stderr then
    assert.contains(expected_stderr or '', serr)
  else
    assert.same('', serr)
  end
end

function assert.run_error(args, expected_stderr)
  local status, sout, serr = run(args)
  errorer.assertf(status ~= 0, 'expected error status in run:\n%s\n%s', serr, sout)
  if expected_stderr then
    assert.contains(expected_stderr, serr)
  end
end

local function pretty_input_onerror(input, f)
  local ok, err = xpcall(f, pretty_traceback_errhandler)
  errorer.assertf(ok, '%s\ninput:\n%s', err, input)
end

function assert.generate_lua(nelua_code, expected_code)
  expected_code = expected_code or nelua_code
  local ast, context = assert.analyze_ast(nelua_code)
  local generated_code
  pretty_input_onerror(nelua_code, function()
    generated_code = assert(lua_generator.generate(ast, context))
  end)
  assert.same_string(stringer.rtrim(expected_code), stringer.rtrim(generated_code))
end

function assert.generate_c(nelua_code, expected_code, ispattern)
  local ast, context = assert.analyze_ast(nelua_code)
  local generated_code
  pretty_input_onerror(nelua_code, function()
    generated_code = assert(c_generator.generate(ast, context))
  end)
  if not expected_code then expected_code = nelua_code end
  if traits.is_string(expected_code) then
    expected_code = {expected_code}
  end
  for _,ecode in ipairs(expected_code) do
    errorer.assertf(generated_code:find(ecode or '', 1, not ispattern),
      "Expected C code to contains.\nPassed in:\n%s\nExpected:\n%s",
      generated_code, ecode)
  end
end

function assert.run_c_from_file(file, expected_stdout, expected_stderr)
  assert.run({'--generator', 'c', file}, expected_stdout, expected_stderr)
end

function assert.run_c(nelua_code, expected_stdout, expected_stderr)
  assert.run({'--generator', 'c', '--eval', nelua_code}, expected_stdout, expected_stderr)
end

function assert.run_error_c(nelua_code, output)
  assert.run_error({'--generator', 'c', '--eval', nelua_code}, output)
end

function assert.lua_gencode_equals(code, expected_code)
  local ast, context = assert.analyze_ast(code)
  local expected_ast, expected_context = assert.analyze_ast(expected_code)
  local generated_code = assert(lua_generator.generate(ast, context))
  local expected_generated_code = assert(lua_generator.generate(expected_ast, expected_context))
  assert.same_string(expected_generated_code, generated_code)
end

function assert.c_gencode_equals(code, expected_code)
  local ast, context = assert.analyze_ast(code)
  local expected_ast, expected_context = assert.analyze_ast(expected_code)
  local generated_code = assert(c_generator.generate(ast, context))
  local expected_generated_code = assert(c_generator.generate(expected_ast, expected_context))
  assert.same_string(expected_generated_code, generated_code)
end

function assert.analyze_ast(code, expected_ast)
  local ast = assert.parse_ast(nelua_parser, code)
  local context
  pretty_input_onerror(code, function()
    context = analyzer.analyze(ast, nelua_parser)
  end)
  if expected_ast then
    assert.same_string(tostring(expected_ast), tostring(ast))
  end
  return ast, context
end

local function filter_ast_for_check(t)
  for k,v in pairs(t) do
    if type(k) == 'number' then
      if traits.is_astnode(v) and v.attr.type and v.attr.type.is_type then
        -- remove type nodes because they are optional
        t[k] = nil
      elseif type(v) == 'table' then
        filter_ast_for_check(v)
      end
    elseif k == 'attr' and traits.is_astnode(t) then
      -- remove generated strings
      v.codename = nil
      v.name = nil
      v.methodsym = nil
      v.pseudoargattrs = nil
      v.pseudoargtypes = nil
    end
  end
  return t
end

function assert.ast_type_equals(code, expected_code)
  local ast = assert.analyze_ast(code)
  local expected_ast = assert.analyze_ast(expected_code)
  filter_ast_for_check(ast)
  filter_ast_for_check(expected_ast)
  assert.same_string(tostring(expected_ast), tostring(ast))
end

function assert.analyze_error(code, expected_error)
  local ast = assert.parse_ast(nelua_parser, code)
  local ok, e = except.try(function()
    analyzer.analyze(ast, nelua_parser)
  end)
  pretty_input_onerror(code, function()
    if expected_error then
      errorer.assertf(not ok, "type analysis should fail with error '%s'", expected_error)
      assert.contains(expected_error, e:get_message())
    else
      errorer.assertf(not ok, "type analysis should fail")
    end
  end)
end

return assert
