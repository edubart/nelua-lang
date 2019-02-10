
local assert = require 'luassert'

-- inject dump utility while testing
_G.dump = require 'utils.dump'

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
      assert.ast_equals(ast, expected_ast)
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
  --if expected_ast then
    assert.ast_equals(ast, expected_ast)
  --else
  --  assert(ast, 'expected')
  --end
end

function assert.parse_ast_error(parser, input, expected_error)
  local ast, _, errdetails = parser:parse(input)
  assert(ast == nil and errdetails and errdetails.label == expected_error,
         string.format('expected error "%s" while parsing', expected_error))
end

return assert