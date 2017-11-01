require 'tests/testcommon'
require 'busted.runner'()

local lexer = require 'euluna-compiler.lexer'

describe("Euluna lexer", function()
  it("should parse shebang", function()
    assert_match_all(lexer.SHEBANG, {"#!/usr/env lua"})
    assert_match_non(lexer.SHEBANG, {"a#!/usr/env lua"})
  end)

  describe("should parse number", function()
    it("binary", function()
      assert_match_all(lexer.NUMBER, {
        ["0b0"] = { tag = "number", type = "binary", value = "0b0" },
        ["0b0101"] = { tag = "number", type = "binary", value = "0b0101" },
      })
    end)

    it("hexadecimal", function()
      assert_match_all(lexer.NUMBER, {
        ["0x0"] = { tag = "number", type = "hexadecimal", value = "0x0" },
        ["0x0123456789abcdef"] = { tag = "number", type = "hexadecimal", value = "0x0123456789abcdef" },
      })
    end)

    it("integer", function()
      assert_match_all(lexer.NUMBER, {
        ["1"] = { tag = "number", type = "integer", value = "1" },
        ["0123456789"] = { tag = "number", type = "integer", value = "0123456789" },
      })
    end)

    it("decimal", function()
      assert_match_all(lexer.NUMBER, {
        [".0"] = { tag = "number", type = "decimal", value = ".0" },
        ["0."] = { tag = "number", type = "decimal", value = "0." },
        ["123.456789"] = { tag = "number", type = "decimal", value = "123.456789" },
      })
    end)

    it("exponential", function()
      assert_match_all(lexer.NUMBER, {
        ["1.2e-3"] = {tag = "number", type="exponential", value="1.2e-3"},
        [".1e2"] = {tag = "number", type="exponential", value=".1e2"},
        [".0e+2"] = {tag = "number", type="exponential", value=".0e+2"},
        ["1e-2"] = {tag = "number", type="exponential", value="1e-2"},
        ["1e+2"] = {tag = "number", type="exponential", value="1e+2"},
        ["1.e3"] = {tag = "number", type="exponential", value="1.e3"},
        ["1e1"] = {tag = "number", type="exponential", value="1e1"},
        ["1.2e+6"] = { tag = "number", type = "exponential", value = "1.2e+6" },
      })
    end)

    it("literal", function()
      assert_match_all(lexer.NUMBER, {
        ["12_f32"] = { tag = "number", type = "integer", value = "12", literal="f32" },
      })
    end)

    it("malformed", function()
      assert_match_err(lexer.NUMBER, "MalformedNumber", {"0b", "0b2", "0x", "0xG", "1e*2"})
    end)
  end)

  it("should escape sequence", function()
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
      ['\\\n'] = '\n',
      ['\\\r'] = '\n',
      ['\\\r\n'] = '\n',
      ['\\\n\r'] = '\n',
    })
  end)

  describe("should parse string", function()
    it("long", function()
      assert_match_err(lexer.STRING, 'UnclosedLongString', {
        '[[','[=[]]','[[]'
      })
      assert_match_all(lexer.STRING, {
        "[[]]", "[=[]=]", "[==[]==]",
        "[[[]]", "[=[]]=]", "[==[]]]]==]",
        "[[test]]", "[=[test]=]", "[==[test]==]",
        "[[\nasd\n]]", "[=[\nasd\n]=]", "[==[\nasd\n]==]",
        ["[[\nasd\n]]"] = {tag='string', value="asd\n"},
        ["[==[\nasd\n]==]"] = {tag='string', value="asd\n"},
      })
    end)

    it("short", function()
      assert_match_err(lexer.STRING, 'UnclosedShortString', {
        '"', "'", '"\\"', "'\\\"", '"\n"'
      })
      assert_match_all(lexer.STRING, {
        ['""'] = {tag='string', value=''},
        ["''"] = {tag='string', value=''},
        ['"test"'] = {tag='string', value='test'},
        ["'test'"] = {tag='string', value='test'},
        ['"a\\t\\nb"'] = {tag='string', value='a\t\nb'},
      })
    end)

    it("general", function()
      assert_match_all(lexer.STRING, {
        '"asd"', "'asd'", "[[asd]]", "[=[asd]=]"
      })
    end)
  end)

  describe("should parse comment", function()
    it("short", function()
      assert_match_non(lexer.SHORTCOMMENT, {
        '--asd\nasd',
      })
      assert_match_all(lexer.SHORTCOMMENT, {
        '--asd', '--asd\n'
      })
    end)

    it("long", function()
      assert_match_non(lexer.LONGCOMMENT, {
        '--[[asd]]asd', '--[[asd]]\nasd',
      })
      assert_match_all(lexer.LONGCOMMENT, {
        '--[[]]', '--[==[]==]', '--[[asd]=]]', '--[=[asd]]\nasd]=]'
      })
    end)

    it("general", function()
      assert_match_non(lexer.COMMENT, {'--[[asd]]asd', '--asd\nasd'})
      assert_match_all(lexer.COMMENT, {'--[[asd]]', '--asd' })
    end)
  end)

  it("should parse keyword", function()
    assert_match_non(lexer.KEYWORD, {'myvar', 'function_', '_function' })
    assert_match_all(lexer.KEYWORD, {'function', 'return' })
  end)

  it("should parse identifier name", function()
    assert_match_non(lexer.NAME, {'function', 'return'})
    assert_match_all(lexer.NAME, {'function_', '_function', 'myvar'})
  end)

  it("should parse especial symbol", function()
    assert_match_all(lexer.ADD, {'+'}, {'+ \n\t\r\v'})
    assert_match_all(lexer.SUB, {'-'})
    assert_match_all(lexer.DIV, {'/'})
    assert_match_non(lexer.SUB, {'--'})
    assert_match_non(lexer.DIV, {'//'})
    assert_match_non(lexer.LT, {'<=', '<<'})
    assert_match_non(lexer.GT, {'>=', '>>'})
    assert_match_non(lexer.BXOR, {'~='})
    assert_match_non(lexer.ASSIGN, {'=='})
    assert_match_non(lexer.LBRACKET, {'[['})
    assert_match_non(lexer.CONCAT, {'...'})
    assert_match_non(lexer.DOT, {'...', '..'})
    assert_match_non(lexer.COLON, {'::'})
  end)
end)
