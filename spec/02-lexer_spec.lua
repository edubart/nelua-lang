require 'busted.runner'()

local assert = require 'spec.assert'
local euluna_parser = require 'euluna.syntaxdefs'().parser
local euluna_astbuilder = euluna_parser.astbuilder
local n = euluna_astbuilder.aster
local pegs = euluna_parser.defs

describe("Euluna parser should parse", function()

--------------------------------------------------------------------------------
-- spaces
-----------------------------------------------------a---------------------------
it("spaces", function()
  assert.peg_match_all(pegs.SPACE, {
    ' ', '\t', '\n', '\r',
  })
  assert.peg_match_none(pegs.SPACE, {
    'a'
  })
end)

it("line breaks", function()
  assert.peg_match_all(pegs.LINEBREAK, {
    "\n\r", "\r\n", "\n", "\r",
  })
  assert.peg_match_none(pegs.LINEBREAK, {
    ' ',
    '\t'
  })
end)

--------------------------------------------------------------------------------
-- shebang
--------------------------------------------------------------------------------
it("shebang", function()
  assert.peg_match_all(pegs.SHEBANG, {
    "#!/usr/bin/euluna",
    "#!anything can go here"
  })
  assert.peg_match_none(pegs.SHEBANG, {
    "#/usr/bin/euluna",
    "/usr/bin/euluna",
    " #!/usr/bin/euluna"
  })
end)

--------------------------------------------------------------------------------
-- comments
--------------------------------------------------------------------------------
it("comments", function()
  assert.peg_match_all(pegs.SHORTCOMMENT, {
    "-- a comment"
  })
  assert.peg_match_all(pegs.LONGCOMMENT, {
    "--[[ a\nlong\ncomment ]]",
    "--[=[ [[a\nlong\ncomment]] ]=]",
    "--[==[ [[a\nlong\ncomment]] ]==]"
  })
  assert.peg_match_all(pegs.COMMENT, {
    "--[[ a\nlong\r\ncomment ]]",
    "-- a comment"
  })
end)

--------------------------------------------------------------------------------
-- keywords
--------------------------------------------------------------------------------
it("keywords", function()
  assert.peg_match_all(pegs.KEYWORD, {
    'if', 'for', 'while'
  })
  assert.peg_match_none(pegs.KEYWORD, {
    'IF', '_if', 'fi_',
  })
end)

--------------------------------------------------------------------------------
-- identifiers
--------------------------------------------------------------------------------
it("identifiers", function()
  assert.peg_capture_all(pegs.cNAME, {
    ['varname'] = 'varname',
    ['_if'] = '_if',
    ['if_'] = 'if_',
    ['var123'] = 'var123'
  })
  assert.peg_capture_all(pegs.cID, {
    ['_varname'] = n.Id{'_varname'}
  })
  assert.peg_match_none(pegs.cNAME, {
    '123a', 'if', '-varname', 'if', 'else'
  })
end)

--------------------------------------------------------------------------------
-- numbers
--------------------------------------------------------------------------------
describe("numbers", function()
  it("binary", function()
    assert.peg_capture_all(pegs.cNUMBER, {
      ["0b0"] = n.Number{"bin", "0"},
      ["0b1"] = n.Number{"bin", "1"},
      ["0b10101111"] = n.Number{"bin", "10101111"},
    })
  end)
  it("hexadecimal", function()
    assert.peg_capture_all(pegs.cNUMBER, {
      ["0x0"] = n.Number{"hex", "0"},
      ["0x0123456789abcdef"] = n.Number{"hex", "0123456789abcdef"},
      ["0xABCDEF"] = n.Number{"hex", "ABCDEF"},
    })
  end)
  it("integer", function()
    assert.peg_capture_all(pegs.cNUMBER, {
      ["1"] = n.Number{"int", "1"},
      ["0123456789"] = n.Number{"int", "0123456789"},
    })
  end)
  it("decimal", function()
    assert.peg_capture_all(pegs.cNUMBER, {
      [".0"] = n.Number{"dec", ".0"},
      ["0."] = n.Number{"dec", "0."},
      ["0123.456789"] = n.Number{"dec", "0123.456789"},
    })
  end)
  it("exponential", function()
    assert.peg_capture_all(pegs.cNUMBER, {
      ["1.2e-3"] = n.Number{"exp", {"1.2" , "-3"}},
      [".1e2"] = n.Number{"exp", {".1", "2"}},
      [".0e+2"] = n.Number{"exp", {".0", "+2"}},
      ["1e-2"] = n.Number{"exp", {"1", "-2"}},
      ["1e+2"] = n.Number{"exp", {"1", "+2"}},
      ["1.e3"] = n.Number{"exp", {"1.", "3"}},
      ["1e1"] = n.Number{"exp", {"1", "1"}},
      ["1.2e+6"] = n.Number{"exp", {"1.2", "+6"}},
    })
  end)
  it("literal", function()
    assert.peg_capture_all(pegs.cNUMBER, {
      [".1f"] = n.Number{"dec", ".1", "f"},
      ["123u"] = n.Number{"int", "123", "u"},
    })
  end)
  it("malformed", function()
    assert.peg_error_all(pegs.cNUMBER, "MalformedHexadecimalNumber", {
      "0x",
      "0xG",
    })
    assert.peg_error_all(pegs.cNUMBER, "MalformedBinaryNumber", {
      "0b",
      "0b2",
      "0b012"
    })
    assert.peg_error_all(pegs.cNUMBER, "MalformedExponentialNumber", {
      "0e",
      "0ef",
      "1e*2"
    })
  end)
end)

--------------------------------------------------------------------------------
-- escape sequence
--------------------------------------------------------------------------------
it("escape sequence", function()
  assert.peg_error_all(pegs.cESCAPESEQUENCE, 'MalformedEscapeSequence', {
    "\\A",
    "\\u42",
    "\\xH",
    "\\x",
    "\\x1",
    "\\u{}",
    "\\300"
  })
  assert.peg_capture_all(pegs.cESCAPESEQUENCE, {
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
    ['\\0'] = '\0',
    ['\\65'] = 'A',
    ['\\065'] = 'A',
    ['\\x41'] = 'A',
    ['\\u{41}'] = 'A',
    ['\\\n'] = '\n',
    ['\\\r'] = '\n',
    ['\\\r\n'] = '\n',
    ['\\\n\r'] = '\n',
  })
end)

--------------------------------------------------------------------------------
-- string
--------------------------------------------------------------------------------
describe("string", function()
  it("long", function()
    assert.peg_capture_all(pegs.cSTRING, {
      "[[]]", "[=[]=]", "[==[]==]",
      "[[[]]", "[=[]]=]", "[==[]]]]==]",
      "[[test]]", "[=[test]=]", "[==[test]==]",
      "[[\nasd\n]]", "[=[\nasd\n]=]", "[==[\nasd\n]==]",
      ["[[\nasd\n]]"] = n.String{"asd\n"},
      ["[==[\nasd\n]==]"] = n.String{"asd\n"}
    })
    assert.peg_error_all(pegs.cSTRING, 'UnclosedLongString', {
      '[[', '[=[]]', '[[]',
    })
  end)

  it("short", function()
    assert.peg_capture_all(pegs.cSTRING, {
      ['""'] = n.String{''},
      ["''"] = n.String{''},
      ['"test"'] = n.String{'test'},
      ["'test'"] = n.String{'test'},
      ['"a\\t\\nb"'] = n.String{'a\t\nb'}
    })
    assert.peg_error_all(pegs.cSTRING, 'UnclosedShortString', {
      '"', "'", '"\\"', "'\\\"", '"\n"',
    })
  end)

  it("literal", function()
    assert.peg_capture_all(pegs.cSTRING, {
      ['"asd"u8'] = n.String{"asd", "u8"},
      ["'asd'hex"] = n.String{"asd", "hex"},
      ["[[asd]]hex"] = n.String{"asd", "hex"},
    })
  end)
end)

--------------------------------------------------------------------------------
-- boolean
--------------------------------------------------------------------------------
it("boolean", function()
  assert.peg_capture_all(pegs.cBOOLEAN, {
    ["true"] = n.Boolean{true},
    ["false"] = n.Boolean{false},
  })
  assert.peg_match_none(pegs.cBOOLEAN, {
    'False', 'FALSE', 'True', 'TRUE',
  })
end)

--------------------------------------------------------------------------------
-- operators and symbols
--------------------------------------------------------------------------------
it("operators and symbols", function()
  assert.peg_match_all(pegs.ADD, {'+'})
  assert.peg_match_all(pegs.SUB, {'-'})
  assert.peg_match_all(pegs.MUL, {'*'})
  assert.peg_match_all(pegs.MOD, {'%'})
  assert.peg_match_all(pegs.DIV, {'/'})
  assert.peg_match_all(pegs.POW, {'^'})

  assert.peg_match_all(pegs.BAND, {'&'})
  assert.peg_match_all(pegs.BOR, {'|'})
  assert.peg_match_all(pegs.SHL, {'<<'})
  assert.peg_match_all(pegs.SHR, {'>>'})

  assert.peg_match_all(pegs.EQ, {'=='})
  assert.peg_match_all(pegs.NE, {'~='})
  assert.peg_match_all(pegs.LE, {'<='})
  assert.peg_match_all(pegs.GE, {'>='})
  assert.peg_match_all(pegs.LT, {'<'})
  assert.peg_match_all(pegs.GT, {'>'})

  assert.peg_match_all(pegs.NEG, {'-'})
  assert.peg_match_all(pegs.LEN, {'#'})
  assert.peg_match_all(pegs.BNOT, {'~'})
  assert.peg_match_all(pegs.TOSTR, {'$'})

  assert.peg_match_all(pegs.LPAREN, {'('})
  assert.peg_match_all(pegs.RPAREN, {')'})
  assert.peg_match_all(pegs.LBRACKET, {'['})
  assert.peg_match_all(pegs.RBRACKET, {']'})
  assert.peg_match_all(pegs.LCURLY, {'{'})
  assert.peg_match_all(pegs.RCURLY, {'}'})
  assert.peg_match_all(pegs.LANGLE, {'<'})
  assert.peg_match_all(pegs.RANGLE, {'>'})

  assert.peg_match_all(pegs.SEMICOLON, {';'})
  assert.peg_match_all(pegs.COMMA, {','})
  assert.peg_match_all(pegs.SEPARATOR, {';', ','})
  assert.peg_match_all(pegs.ELLIPSIS, {'...'})
  assert.peg_match_all(pegs.CONCAT, {'..'})
  assert.peg_match_all(pegs.DOT, {'.'})
  assert.peg_match_all(pegs.DBLCOLON, {'::'})
  assert.peg_match_all(pegs.COLON, {':'})
  assert.peg_match_all(pegs.AT, {'@'})
  assert.peg_match_all(pegs.DOLLAR, {'$'})
  assert.peg_match_all(pegs.QUESTION, {'?'})

  assert.peg_match_none(pegs.SUB, {'--'})
  assert.peg_match_none(pegs.LT, {'<<', '<='})
  assert.peg_match_none(pegs.BXOR, {'~='})
  assert.peg_match_none(pegs.ASSIGN, {'=='})

  assert.peg_match_none(pegs.NEG, {'--'})
  assert.peg_match_none(pegs.BNOT, {'~='})
  assert.peg_match_none(pegs.LBRACKET, {'[['})

  assert.peg_match_none(pegs.CONCAT, {'...'})
  assert.peg_match_none(pegs.DOT, {'...', '..'})
  assert.peg_match_none(pegs.COLON, {'::'})
end)

end)
