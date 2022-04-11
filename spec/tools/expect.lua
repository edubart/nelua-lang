local expect = require 'nelua.thirdparty.lester'.expect
local stringer = require 'nelua.utils.stringer'
local except = require 'nelua.utils.except'
local errorer = require 'nelua.utils.errorer'
local pegger = require 'nelua.utils.pegger'
local runner = require 'nelua.runner'
local analyzer = require 'nelua.analyzer'
local AnalyzerContext = require 'nelua.analyzercontext'
local fs = require 'nelua.utils.fs'
local traits = require 'nelua.utils.traits'
local lua_generator = require 'nelua.luagenerator'
local c_generator = require 'nelua.cgenerator'
local differ = require 'spec.tools.differ'
local config = require 'nelua.configer'.get()
local primtypes = require 'nelua.typedefs'.primtypes
local aster = require 'nelua.aster'

-- config setup for the test suite
config.check_ast_shape = true
config.check_type_shape = true
config.quiet = true
config.lua_version = '5.4'
config.pragmas.abort = 'exit'
config.redirect_exec = true

-- use cache subfolder while testing
config.cache_dir = fs.join(config.cache_dir, 'spec')

expect.config = { srcname = nil }

function expect.same_string(expected, passedin)
  if expected ~= passedin then --luacov:disable
    error('Expected strings to be the same, difference:\n' ..
      differ(expected, passedin):tostring({colored = true, context=3}))
  end --luacov:enable
end

function expect.contains(expected, passedin)
  errorer.assertf(passedin:find(expected, 1, true),
    "Expected string to contains.\nPassed in:\n%s\nExpected:\n%s",
    passedin, expected)
end

function expect.ast_equals(expected_ast, ast)
  expect.same_string(tostring(expected_ast), tostring(ast))
end

function expect.parse_ast(input, expected_ast)
  local ast = aster.parse(input, expect.config.srcname)
  if expected_ast then
    expect.ast_equals(expected_ast, ast)
  else
    assert(ast, 'an valid ast was expected')
  end
  return ast
end

function expect.parse_ast_error(input, expected_error)
  local ast,e = except.try(function()
    aster.parse(input, expect.config.srcname)
  end)
  errorer.assertf(ast == nil and e.label == 'ParseError' and e.errlabel == expected_error,
         'expected error "%s" while parsing, but got "%s"', expected_error, e and e.errlabel)
end

--luacov:disable
local function pretty_traceback_errhandler(e)
  if type(e) == 'string' then
    local msg = debug.traceback(e, 2)
    local i = msg:find('\n%s+[%w%s%/%\\%.%-_ ]+lester.lua')
    if i then
      msg = msg:sub(1, i) .. '        (...lester...)\n'
    end
    return msg
  else
    return e
  end
end
--luacov:enable

local function cleanup_nelua_state()
  -- cleanup nelua state by previous runs
  primtypes.string.metafields = {}
end

local function run(args)
  cleanup_nelua_state()
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

function expect.run(args, expected_stdout, expected_stderr)
  local status, sout, serr = run(args)
  errorer.assertf(status == 0, 'expected success status in run:\n%s\n%s', serr, sout)
  if expected_stdout then
    expect.contains(expected_stdout, sout)
  end
  if expected_stderr then
    expect.contains(expected_stderr or '', serr)
  else
    expect.equal('', serr)
  end
end

--[[
function expect.execute(exe, expected_stdout)
  local executor = require 'nelua.utils.executor'
  local ccompiler = require 'nelua.ccompiler'
  if ccompiler.get_cc_info().is_windows then exe = exe .. '.exe' end
  exe = fs.abspath(exe)
  local ok, status, sout, serr = executor.execex(exe)
  errorer.assertf(ok and status == 0, 'expected success status in execute:\n%s\n%s', serr, sout)
  if expected_stdout then
    sout = sout:gsub('\r','')
    expect.contains(expected_stdout, sout)
  end
  expect.equal('', serr)
end
]]

function expect.run_error(args, expected_stderr, expects_success)
  local status, sout, serr = run(args)
  if expects_success then
    errorer.assertf(status == 0, 'expected success status in run:\n%s\n%s', serr, sout)
  else
    errorer.assertf(status ~= 0, 'expected error status in run:\n%s\n%s', serr, sout)
  end
  if expected_stderr then
    if traits.is_table(expected_stderr) then
      for _,eerr in ipairs(expected_stderr) do
        expect.contains(eerr, serr)
      end
    else
      expect.contains(expected_stderr, serr)
    end
  end
end

local function pretty_input_onerror(input, f)
  local ok, err = xpcall(f, pretty_traceback_errhandler)
  errorer.assertf(ok, '%s\ninput:\n%s', err, input)
end

function expect.generate_lua(nelua_code, expected_code)
  expected_code = expected_code or nelua_code
  local _, context = expect.analyze_ast(nelua_code, nil, 'lua')
  local generated_code
  pretty_input_onerror(nelua_code, function()
    generated_code = assert(lua_generator.generate(context))
  end)
  expect.same_string(stringer.rtrim(expected_code), stringer.rtrim(generated_code))
end

function expect.generate_c(nelua_code, expected_code, ispattern)
  local _, context = expect.analyze_ast(nelua_code, nil, 'c')
  local generated_code
  pretty_input_onerror(nelua_code, function()
    generated_code = assert(c_generator.generate(context))
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

function expect.run_c_from_file(file, expected_stdout, expected_stderr)
  expect.run({'--generator', 'c', file}, expected_stdout, expected_stderr)
end

function expect.run_c(nelua_code, expected_stdout, expected_stderr)
  expect.run({'--generator', 'c', '--eval', nelua_code}, expected_stdout, expected_stderr)
end

function expect.run_error_c(nelua_code, output, expect_success)
  expect.run_error({'--generator', 'c', '--eval', nelua_code}, output, expect_success)
end

function expect.lua_gencode_equals(code, expected_code)
  local _, context = expect.analyze_ast(code, nil, 'lua')
  local _, expected_context = expect.analyze_ast(expected_code)
  local generated_code = assert(lua_generator.generate(context))
  local expected_generated_code = assert(lua_generator.generate(expected_context))
  expect.same_string(expected_generated_code, generated_code)
end

function expect.c_gencode_equals(code, expected_code)
  local _, context = expect.analyze_ast(code, nil, 'c')
  local _, expected_context = expect.analyze_ast(expected_code, nil, 'c')
  local generated_code = assert(c_generator.generate(context))
  local expected_generated_code = assert(c_generator.generate(expected_context))
  expect.same_string(expected_generated_code, generated_code)
end

function expect.analyze_ast(code, expected_ast, generator)
  local ast = expect.parse_ast(code)
  generator = generator or config.generator
  local context = AnalyzerContext(analyzer.visitors, ast, generator)
  pretty_input_onerror(code, function()
    analyzer.analyze(context)
  end)
  if expected_ast then
    expect.same_string(tostring(expected_ast), tostring(ast))
  end
  return ast, context
end

local function filter_ast_for_check(t)
  if t._astnode then
    assert(t.shape(t))
  end
  for k,v in pairs(t) do
    if type(k) == 'number' then
      if traits.is_astnode(v) and v.attr.type and v.attr.type.is_type then
        -- check type shape
        assert(v.attr.value:shape())
        -- remove type nodes because they are optional
        t[k] = false
      elseif type(v) == 'table' then
        filter_ast_for_check(v)
        -- remove empty tables, because they may be omitted
        if getmetatable(v) == nil and #v == 0 then
          t[k] = false
        end
      end
    elseif k == 'attr' and traits.is_astnode(t) then
      -- remove some generated strings
      v.codename = nil
      v.name = nil
      v.methodsym = nil
      v.forcesymbol = nil
      v.pseudoargattrs = nil
      v.pseudoargtypes = nil
      v.value = nil
    elseif k == 'pattr' then
      t[k] = nil
    end
  end
  -- trim trailing falsy values
  for i=#t,1,-1 do
    if not t[i] then
      t[i] = nil
    else
      break
    end
  end
end

function expect.ast_type_equals(code, expected_code)
  local ast = expect.analyze_ast(code)
  local expected_ast = expect.analyze_ast(expected_code)
  filter_ast_for_check(ast)
  filter_ast_for_check(expected_ast)
  expect.same_string(tostring(expected_ast), tostring(ast))
end

function expect.analyze_error(code, expected_error)
  local ast = expect.parse_ast(code)
  local ok, e = except.try(function()
    local context = AnalyzerContext(analyzer.visitors, ast, config.generator)
    analyzer.analyze(context)
  end)
  pretty_input_onerror(code, function()
    if expected_error then
      errorer.assertf(not ok, "type analysis should fail with error '%s'", expected_error)
      expect.contains(expected_error, e:get_message())
    else
      errorer.assertf(not ok, "type analysis should fail")
    end
  end)
end

return expect
