local lpeg = require "lpeglabel"
local inspect = require 'inspect'
local syntax_errors = require "euluna-compiler.syntax_errors"
local parser = require 'euluna-compiler.parser'
local cppgen = require 'euluna-compiler.cpp_generator'
local cppcompiler = require 'euluna-compiler.cpp_compiler'
local assert = require 'luassert'
local stringx = require 'pl.stringx'
require 'euluna-compiler.global'

assert:set_parameter("TableFormatLevel", 16)

-- return a version of t2 that only contains fields present in t1 (recursively)
local function restrict(t1, t2)
  if type(t1) == 'table' and type(t2) == 'table' then
    local out = {}
    for k,_ in pairs(t1) do
      if k ~= 'pos' then
        out[k] = restrict(t1[k], t2[k])
      end
    end
    return out
  else
    return t2
  end
end

local function filter(t)
  if type(t) == 'table' then
    local out = {}
    for k,_ in pairs(t) do
      if k ~= 'pos' then
        out[k] = filter(t[k])
      end
    end
    return out
  else
    return t
  end
end

function assert_ast(ast, expected_ast, restricted)
  if restricted then
    ast = restrict(expected_ast, ast)
  else
    ast = filter(ast)
    expected_ast = filter(expected_ast)
  end
  assert.are.same(expected_ast, ast)
end

function assert_match_all(pattern, strs)
  -- make sure pattern match everything
  pattern = (pattern * -lpeg.P(1))
  for k,v in pairs(strs) do
    local str = v
    local expected_ast
    if type(k) == 'string' then
      str = k
      expected_ast = v
    end
    local ast, errnum, rest = pattern:match(str)
    if errnum then
      local errmsg = syntax_errors.int_to_label[errnum] or 'unknown error'
      error("no full match for: " .. inspect(str) .. ' (' .. errmsg .. ')')
    end
    if expected_ast then
      assert_ast(ast, expected_ast)
    end
    assert(rest == nil, msg)
  end
end

function assert_match_non(pattern, strs)
  -- make sure pattern match everything
  pattern = (pattern * -lpeg.P(1))
  for i,str in ipairs(strs) do
    local res, errnum = pattern:match(str)
    if errnum ~= nil and errnum ~= 0 then
      error("match error for: " .. inspect(str) .. ' (' .. tostring(syntax_errors.int_to_label[errnum]) .. ')')
    end
    assert(res == nil, "match for: " .. inspect(str))
  end
end

function assert_match_err(pattern, err, strs)
  -- make sure pattern match everything
  pattern = (pattern * -lpeg.P(1))
  for i,str in ipairs(strs) do
    local res, errnum = pattern:match(str)
    assert(syntax_errors.int_to_label[errnum] == err, "invalid error for: " .. inspect(str))
  end
end

function assert_parse(str, expected_ast)
  local ast, err = parser.parse(str)
  assert(ast, inspect(err))
  if expected_ast then
    assert_ast(ast, expected_ast)
  end
  return ast, err
end

function assert_generate_cpp(ast, expected_code)
  local generated_code = stringx.strip(cppgen.generate(ast))
  expected_code = stringx.strip(expected_code)
  assert.is.same(expected_code, generated_code)
end

function assert_generate_cpp_and_run(ast, expected_output, expected_ret)
  local generated_code = stringx.strip(cppgen.generate(ast))
  expected_output = stringx.strip(expected_output)
  local ok, ret, stdout, stderr = cppcompiler.compile_and_run(generated_code)
  assert.is.same(expected_output, stdout)
  if expected_ret then
    assert.is.same(expected_ret, ret)
  end
  assert.is.same('', stderr)
  if expected_ret == 0 or expected_ret == nil then
    assert.is_true(ok)
  end
end

function assert_generate_cpp(ast, expected_code)
  local generated_code = stringx.strip(cppgen.generate(ast))
  expected_code = stringx.strip(expected_code)
  assert.is.same(expected_code, generated_code)
end

function assert_equivalent_parse(a, b)
  assert_ast(assert_parse(a), assert_parse(b))
end

function assert_parse_error(code, expected_err)
  expected_err = expected_err or ''
  local ast, err = parser.parse(code)
  assert.is.same(expected_err, err and err.label)
end
