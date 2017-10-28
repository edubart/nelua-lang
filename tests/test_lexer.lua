local lexer = require 'euluna-compiler.lexer'
local syntax_errors = require "euluna-compiler.syntax_errors"
local inspect = require 'inspect'
local lpeg = require "lpeglabel"
local tablex = require 'pl.tablex'

require 'euluna-compiler.global'

require 'busted.runner'()

local function assert_match_all(pattern, strs)
  -- make sure pattern match everything
  pattern = (pattern * -lpeg.P(1))
  for k,v in pairs(strs) do
    local str = v
    local ast
    if type(k) == 'string' then
      str = k
      ast = v
    end
    local res, errnum, rest = pattern:match(str)
    if errnum then
      local errmsg = syntax_errors.int_to_label[errnum] or 'unknown error'
      error("no full match for: " .. inspect(str) .. ' (' .. errmsg .. ')')
    end
    if ast then
      if not tablex.deepcompare(ast, res) then
        error("ast does not match for: " .. inspect(str) ..
              "\nexpected => " .. inspect(ast) ..
              "\nbut got => " .. inspect(res))
      end
    end
    assert(rest == nil, msg)
  end
end

local function assert_match_non(pattern, strs)
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

local function assert_match_err(pattern, err, strs)
  -- make sure pattern match everything
  pattern = (pattern * -lpeg.P(1))
  for i,str in ipairs(strs) do
    local res, errnum = pattern:match(str)
    assert(syntax_errors.int_to_label[errnum] == err, "invalid error for: " .. inspect(str))
  end
end

describe("euluna lexer", function()
  it("Binary", function()
    assert_match_non(lexer.BINARY, {"1", "0.1", "0x1"})
    assert_match_err(lexer.BINARY, "MalformedNumber", {"0b", "0b2"})
    assert_match_all(lexer.BINARY, {"0b0", "0b101011001"})
  end)

  it("Hexadecimal", function()
    assert_match_non(lexer.HEXADECIMAL, {"0", "0.1"})
    assert_match_err(lexer.HEXADECIMAL, "MalformedNumber", {"0x", "0xG"})
    assert_match_all(lexer.HEXADECIMAL, {"0x0", "0x0123456789abcdef"})
  end)

  it("Decimal", function()
    assert_match_non(lexer.DECIMAL, {"0", "0x1"})
    assert_match_all(lexer.DECIMAL, {"0.123", "0.", ".0"})
  end)

  it("Exponential", function()
    assert_match_non(lexer.EXPONENTIAL, {"1", "0x0", "0.1"})
    assert_match_err(lexer.EXPONENTIAL, "MalformedNumber", {"1e*2"})
    assert_match_all(lexer.EXPONENTIAL,
      {"1.2e-3", ".1e2", ".0e+2", "1e-2", "1e+2", "1.e3", "1e1"})
  end)

  it("Integer", function()
    assert_match_all(lexer.INTEGER, {"1", "123"})
  end)

  it("Number", function()
    assert_match_all(lexer.NUMBER, {
      ["0b0101"] = { tag = "number", type = "binary", value = "0b0101" },
      ["0x1234"] = { tag = "number", type = "hexdecimal", value = "0x1234" },
      ["123.45"] = { tag = "number", type = "decimal", value = "123.45" },
      ["123456"] = { tag = "number", type = "integer", value = "123456" },
      ["1.2e+6"] = { tag = "number", type = "exponential", value = "1.2e+6" },
      ["123_f32"] = { tag = "number", type = "integer", value = "123", literal="f32" },
    })
  end)

  it("EscapeSequence", function()
    assert_match_err(lexer.ESCAPESEQUENCE, 'MalformedEscapeSequence', {
      "\\A",
      "\\u42",
      "\\xH",
      "\\x",
    })
    assert_match_all(lexer.ESCAPESEQUENCE, {
      ["\\a"] = "\a",
      ["\\b"] = "\b",
      ["\\f"] = "\f",
      ["\\n"] = "\n",
      ["\\r"] = "\r",
      ["\\t"] = "\t",
      ["\\v"] = "\v",
      ["\\\\"] = "\\",
      ["\\'"] = "'",
      ['\\"'] = '"',
      ['\\z \t\r\n'] = '',
      ['\\65'] = 'A',
      ['\\x41'] = 'A',
      ['\\u{41}'] = 'A',
    })
  end)

  it("LongString", function()
    assert_match_err(lexer.LONGSTRING, 'UnclosedLongString', {
      '[[','[=[]]','[[]'
    })
    assert_match_all(lexer.LONGSTRING, {
      "[[]]", "[=[]=]", "[==[]==]",
      "[[[]]", "[=[]]=]", "[==[]]]]==]",
      "[[test]]", "[=[test]=]", "[==[test]==]",
      "[[\nasd\n]]", "[=[\nasd\n]=]", "[==[\nasd\n]==]",
      ["[[\nasd\n]]"] = { tag='string', type='longstring', value="asd\n" },
      ["[==[\nasd\n]==]"] = { tag='string', type='longstring', value="asd\n" },
    })
  end)

  it("ShortString", function()
    assert_match_err(lexer.SHORTSTRING, 'UnclosedShortString', {
      '"', "'", '"\\"', "'\\\"", '"\n"'
    })
    assert_match_all(lexer.SHORTSTRING, {
      ['""'] = '',
      ["''"] = '',
      ['"test"'] = 'test',
      ["'test'"] = 'test',
    })
  end)

  it("String", function()
    assert_match_all(lexer.STRING, {
      '"asd"', "'asd'", "[[asd]]", "[=[asd]=]"
    })
  end)

  it("ShortComment", function()
    assert_match_non(lexer.SHORTCOMMENT, {
      '--asd\nasd',
    })
    assert_match_all(lexer.SHORTCOMMENT, {
      '--asd', '--asd\n'
    })
  end)

  it("LongComment", function()
    assert_match_non(lexer.LONGCOMMENT, {
      '--[[asd]]asd', '--[[asd]]\nasd',
    })
    assert_match_all(lexer.LONGCOMMENT, {
      '--[[]]', '--[==[]==]', '--[[asd]=]]', '--[=[asd]]\nasd]=]'
    })
  end)

  it("Comment", function()
    assert_match_non(lexer.COMMENT, {
      '--[[asd]]asd', '--asd\nasd',
    })
    assert_match_all(lexer.COMMENT, {
      '--[[asd]]', '--asd',
    })
  end)

  it("Keyword", function()
    assert_match_non(lexer.KEYWORD, {'myvar', 'function_', '_function' })
    assert_match_all(lexer.KEYWORD, {'function', 'return' })
  end)

  it("Identifier", function()
    assert_match_non(lexer.IDENTIFIER, {'function', 'return'})
    assert_match_all(lexer.IDENTIFIER, {'function_', '_function', 'myvar'})
  end)

  it("Symbols", function()
    assert_match_all(lexer.ADD, {'+'})
    assert_match_all(lexer.SHL, {'<<'})
    assert_match_all(lexer.LT, {'<'})
    assert_match_non(lexer.LT, {'<<'})
    assert_match_non(lexer.SHL, {'<'})
  end)
end)
