
local assert = require 'luassert'

local function recursive_remove_pos(t)
  if type(t) == 'table' then
    for _,v in ipairs(t) do
      recursive_remove_pos(v)
    end
    t.pos = nil
  end
end

function assert.ast_equals(ast, expected_ast)
  recursive_remove_pos(ast)
  assert.same(expected_ast, ast)
end

function assert.pattern_match_all(patt, subjects)
  for _,subject in ipairs(subjects) do
    local matchedpos = patt:match(subject)
    local slen = string.len(subject)
    assert(matchedpos == slen+1, string.format('expected full match on "%s"', subject))
  end
end

function assert.pattern_capture_all(patt, subjects)
  for subject,expected_ast in pairs(subjects) do
    if type(subject) == 'number' then
      subject = expected_ast
      expected_ast = nil
    end

    local ast = patt:match(subject)
    if expected_ast then
      assert.ast_equals(ast, expected_ast)
    else
      assert(type(ast) == 'table', string.format('expected capture on "%s"', subject))
    end
  end
end

function assert.pattern_error_all(patt, errname, subjects)
  for _,subject in ipairs(subjects) do
    local res, errlab = patt:match(subject)
    assert.same(errlab, errname)
    assert.same(res, nil)
  end
end

function assert.pattern_match_none(patt, subjects)
  for _,subject in pairs(subjects) do
    local matchedpos = patt:match(subject)
    assert(matchedpos == nil, string.format('expected no match on "%s"', subject))
  end
end

function assert.parse_ast(input, expected_ast, parser)
  if not parser then
    parser = require 'euluna.parser'
  end
  local ast = assert(parser:parse(input))
  if expected_ast then
    assert.ast_equals(ast, expected_ast)
  else
    assert(ast, 'expected')
  end
end

function assert.parse_ast_error(input, expected_error, parser)
  if not parser then
    parser = require 'euluna.parser'
  end
  local ast, _, errdetails = parser:parse(input)
  assert(ast == nil and errdetails and errdetails.label == expected_error,
         string.format('expected error "%s" while parsing', expected_error))
end

return assert