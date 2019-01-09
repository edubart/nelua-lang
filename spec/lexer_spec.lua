require 'busted.runner'()

local lexer = require 'euluna.lexer'
local assert = require 'utils.assert'
local astnodes = require 'euluna.astnodes'
local AST = astnodes.create
local lexer_grammars = lexer.grammars

describe("Euluna lexer should parse", function()

it("spaces", function()
  assert.pattern_match_all(lexer_grammars.SPACE, {
    ' ', '\t', '\n', '\r',
  })
  assert.pattern_match_none(lexer_grammars.SPACE, {
    'a'
  })
end)

it("line breaks", function()
  assert.pattern_match_all(lexer_grammars.LINEBREAK, {
    "\n\r", "\r\n", "\n", "\r",
  })
  assert.pattern_match_none(lexer_grammars.LINEBREAK, {
    ' ',
    '\t'
  })
end)

it("shebang", function()
  assert.pattern_match_all(lexer_grammars.SHEBANG, {
    "#!/usr/bin/euluna",
    "#!anything can go here"
  })
  assert.pattern_match_none(lexer_grammars.SHEBANG, {
    "#/usr/bin/euluna",
    "/usr/bin/euluna",
    " #!/usr/bin/euluna"
  })
end)

it("comments", function()
  assert.pattern_match_all(lexer_grammars.SHORTCOMMENT, {
    "-- a comment"
  })
  assert.pattern_match_all(lexer_grammars.LONGCOMMENT, {
    "--[[ a\nlong\ncomment ]]",
    "--[=[ [[a\nlong\ncomment]] ]=]",
    "--[==[ [[a\nlong\ncomment]] ]==]"
  })
  assert.pattern_match_all(lexer_grammars.COMMENT, {
    "--[[ a\nlong\r\ncomment ]]",
    "-- a comment"
  })
end)

it("keywords", function()
  assert.pattern_match_all(lexer_grammars.KEYWORD, {
    'if', 'for', 'while'
  })
  assert.pattern_match_none(lexer_grammars.KEYWORD, {
    'IF', '_if', 'fi_',
  })
end)

it("identifiers", function()
  assert.pattern_capture_all(lexer_grammars.cIDENTIFIER, {
    ['varname'] = 'varname',
    ['_if'] = '_if',
    ['if_'] = 'if_',
    ['var123'] = 'var123'
  })
  assert.pattern_match_none(lexer_grammars.cIDENTIFIER, {
    '123a', 'if', '-varname',
  })
end)

describe("numbers", function()
  it("binary", function()
    assert.pattern_capture_all(lexer_grammars.cNUMBER, {
      ["0b0"] = AST("Number", "bin", "0"),
      ["0b1"] = AST("Number", "bin", "1"),
      ["0b10101111"] = AST("Number", "bin", "10101111"),
    })
  end)
  it("hexadecimal", function()
    assert.pattern_capture_all(lexer_grammars.cNUMBER, {
      ["0x0"] = AST("Number", "hex", "0"),
      ["0x0123456789abcdef"] = AST("Number", "hex", "0123456789abcdef"),
      ["0xABCDEF"] = AST("Number", "hex", "ABCDEF"),
    })
  end)
  it("integer", function()
    assert.pattern_capture_all(lexer_grammars.cNUMBER, {
      ["1"] = AST("Number", "int", "1"),
      ["0123456789"] = AST("Number", "int", "0123456789"),
    })
  end)
  it("decimal", function()
    assert.pattern_capture_all(lexer_grammars.cNUMBER, {
      [".0"] = AST("Number", "dec", ".0"),
      ["0."] = AST("Number", "dec", "0."),
      ["0123.456789"] = AST("Number", "dec", "0123.456789"),
    })
  end)
  it("exponential", function()
    assert.pattern_capture_all(lexer_grammars.cNUMBER, {
      ["1.2e-3"] = AST("Number", "exp", "1.2" , "-3"),
      [".1e2"] = AST("Number", "exp", ".1", "2"),
      [".0e+2"] = AST("Number", "exp", ".0", "+2"),
      ["1e-2"] = AST("Number", "exp", "1", "-2"),
      ["1e+2"] = AST("Number", "exp", "1", "+2"),
      ["1.e3"] = AST("Number", "exp", "1.", "3"),
      ["1e1"] = AST("Number", "exp", "1", "1"),
      ["1.2e+6"] = AST("Number", "exp", "1.2", "+6"),
    })
  end)
  it("literal", function()
    assert.pattern_capture_all(lexer_grammars.cNUMBER, {
      [".1f"] = AST("Number", "dec", ".1", "f"),
      ["123u"] = AST("Number", "int", "123", "u"),
    })
  end)
  it("malformed", function()
    assert.pattern_error_all(lexer_grammars.cNUMBER, "MalformedHexadecimalNumber", {
      "0x",
      "0xG",
    })
    assert.pattern_error_all(lexer_grammars.cNUMBER, "MalformedBinaryNumber", {
      "0b",
      "0b2",
      "0b012"
    })
    assert.pattern_error_all(lexer_grammars.cNUMBER, "MalformedExponentialNumber", {
      "0e",
      "0ef",
      "1e*2"
    })
  end)
end)

it("escape sequence", function()
  assert.pattern_error_all(lexer_grammars.cESCAPESEQUENCE, 'MalformedEscapeSequence', {
    "\\A",
    "\\u42",
    "\\xH",
    "\\x",
  })
  assert.pattern_capture_all(lexer_grammars.cESCAPESEQUENCE, {
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

describe("string", function()
  it("long", function()
    assert.pattern_capture_all(lexer_grammars.cSTRING, {
      "[[]]", "[=[]=]", "[==[]==]",
      "[[[]]", "[=[]]=]", "[==[]]]]==]",
      "[[test]]", "[=[test]=]", "[==[test]==]",
      "[[\nasd\n]]", "[=[\nasd\n]=]", "[==[\nasd\n]==]",
      ["[[\nasd\n]]"] = AST('String', "asd\n"),
      ["[==[\nasd\n]==]"] = AST('String', "asd\n"),
    })
    assert.pattern_error_all(lexer_grammars.cSTRING, 'UnclosedLongString', {
      '[[', '[=[]]', '[[]',
    })
  end)

  it("short", function()
    assert.pattern_capture_all(lexer_grammars.cSTRING, {
      ['""'] = {''},
      ["''"] = {''},
      ['"test"'] = AST('String', 'test'),
      ["'test'"] = AST('String', 'test'),
      ['"a\\t\\nb"'] = AST('String', 'a\t\nb'),
    })
    assert.pattern_error_all(lexer_grammars.cSTRING, 'UnclosedShortString', {
      '"', "'", '"\\"', "'\\\"", '"\n"',
    })
  end)

  it("literal", function()
    assert.pattern_capture_all(lexer_grammars.cSTRING, {
      ['"asd"u8'] = AST("String", "asd", "u8"),
      ["'asd'hex"] = AST("String", "asd", "hex"),
      ["[[asd]]hex"] = AST("String", "asd", "hex"),
    })
  end)
end)

it("boolean", function()
  assert.pattern_capture_all(lexer_grammars.cBOOLEAN, {
    ["true"] = AST("Boolean", true),
    ["false"] = AST("Boolean", false),
  })
  assert.pattern_match_none(lexer_grammars.cBOOLEAN, {
    'False', 'FALSE', 'True', 'TRUE',
  })
end)

it("operators and symbols", function()
  assert.pattern_match_all(lexer_grammars.ADD, {'+'})
  assert.pattern_match_all(lexer_grammars.SUB, {'-'})
  assert.pattern_match_all(lexer_grammars.MUL, {'*'})
  assert.pattern_match_all(lexer_grammars.MOD, {'%'})
  assert.pattern_match_all(lexer_grammars.DIV, {'/'})
  assert.pattern_match_all(lexer_grammars.POW, {'^'})

  assert.pattern_match_all(lexer_grammars.BAND, {'&'})
  assert.pattern_match_all(lexer_grammars.BOR, {'|'})
  assert.pattern_match_all(lexer_grammars.SHL, {'<<'})
  assert.pattern_match_all(lexer_grammars.SHR, {'>>'})

  assert.pattern_match_all(lexer_grammars.EQ, {'=='})
  assert.pattern_match_all(lexer_grammars.NE, {'~=', '!='})
  assert.pattern_match_all(lexer_grammars.LE, {'<='})
  assert.pattern_match_all(lexer_grammars.GE, {'>='})
  assert.pattern_match_all(lexer_grammars.LT, {'<'})
  assert.pattern_match_all(lexer_grammars.GT, {'>'})

  assert.pattern_match_all(lexer_grammars.NEG, {'-'})
  assert.pattern_match_all(lexer_grammars.LEN, {'#'})
  assert.pattern_match_all(lexer_grammars.BNOT, {'~'})
  assert.pattern_match_all(lexer_grammars.TOSTRING, {'$'})

  assert.pattern_match_all(lexer_grammars.LPAREN, {'('})
  assert.pattern_match_all(lexer_grammars.RPAREN, {')'})
  assert.pattern_match_all(lexer_grammars.LBRACKET, {'['})
  assert.pattern_match_all(lexer_grammars.RBRACKET, {']'})
  assert.pattern_match_all(lexer_grammars.LCURLY, {'{'})
  assert.pattern_match_all(lexer_grammars.RCURLY, {'}'})
  assert.pattern_match_all(lexer_grammars.LANGLE, {'<'})
  assert.pattern_match_all(lexer_grammars.RANGLE, {'>'})

  assert.pattern_match_all(lexer_grammars.SEMICOLON, {';'})
  assert.pattern_match_all(lexer_grammars.COMMA, {','})
  assert.pattern_match_all(lexer_grammars.SEPARATOR, {';', ','})
  assert.pattern_match_all(lexer_grammars.ELLIPSIS, {'...'})
  assert.pattern_match_all(lexer_grammars.CONCAT, {'..'})
  assert.pattern_match_all(lexer_grammars.DOT, {'.'})
  assert.pattern_match_all(lexer_grammars.DBLCOLON, {'::'})
  assert.pattern_match_all(lexer_grammars.COLON, {':'})
  assert.pattern_match_all(lexer_grammars.AT, {'@'})
  assert.pattern_match_all(lexer_grammars.DOLLAR, {'$'})

  assert.pattern_match_none(lexer_grammars.SUB, {'--'})
  assert.pattern_match_none(lexer_grammars.LT, {'<<', '<='})
  assert.pattern_match_none(lexer_grammars.BXOR, {'~='})
  assert.pattern_match_none(lexer_grammars.ASSIGN, {'=='})

  assert.pattern_match_none(lexer_grammars.NEG, {'--'})
  assert.pattern_match_none(lexer_grammars.BNOT, {'~='})
  assert.pattern_match_none(lexer_grammars.LBRACKET, {'[['})

  assert.pattern_match_none(lexer_grammars.CONCAT, {'...'})
  assert.pattern_match_none(lexer_grammars.DOT, {'...', '..'})
  assert.pattern_match_none(lexer_grammars.COLON, {'::'})
end)

end)
