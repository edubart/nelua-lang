local lpeg = require "lpeglabel"
local inspect = require 'inspect'
local syntax_errors = require "euluna-compiler.syntax_errors"
local parser = require 'euluna-compiler.parser'
local assert = require 'luassert'
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

function assert_ast(ast, expected_ast)
  ast = restrict(expected_ast, ast)
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
    --dump_ast(ast)
    assert_ast(ast, expected_ast)
  end
end

function assert_parse_error(code, expected_err)
  expected_err = expected_err or ''
  local ast, err = parser.parse(code)
  if err then
    assert(err.label == expected_err)
  else
    assert(false, "expected error ".. expected_err)
  end
end
