local n = require 'nelua.aster'
local lester = require 'nelua.thirdparty.lester'
local expect = require 'spec.tools.expect'
local describe, it = lester.describe, lester.it
local expect_ast, expect_ast_error = expect.parse_ast, expect.parse_ast_error

describe("syntaxdefs", function()

it("empty file", function()
  expect_ast("", n.Block{})
  expect_ast(" \t\n", n.Block{})
  expect_ast(";", n.Block{})
end)

it("invalid syntax", function()
  expect_ast_error([[something]], 'UnexpectedSyntax')
end)

it("shebang", function()
  expect_ast("#!/usr/bin/env lua", n.Block{})
  expect_ast("#!/usr/bin/env lua\n", n.Block{})
end)

describe("comments", function()
  it("short", function()
    expect_ast("-- comment", n.Block{})
    expect_ast("-- comment\n", n.Block{})
    expect_ast("-- comment\n-- comment", n.Block{})
  end)
  it("long", function()
    expect_ast("--[[comment]]", n.Block{})
    expect_ast("--[[\nlong comment\n]]", n.Block{})
    expect_ast("--[[ a\nlong\ncomment ]]", n.Block{})
    expect_ast("--[=[ [[a\nlong\ncomment]] ]=]", n.Block{})
    expect_ast("--[==[ [[a\nlong\ncomment]] ]==]", n.Block{})
    expect_ast("--[[ a\nlong\r\ncomment ]]", n.Block{})
    expect_ast("--[[ a\nlong\r\ncomment ]]", n.Block{})
    expect_ast([=[if a then --[[f()]] end]=],
      n.Block{n.If{{n.Id{'a'}, n.Block{}
    }}})
  end)
end)

it("identifiers", function()
  expect_ast("local varname",
    n.Block{n.VarDecl{"local",{n.IdDecl{"varname", false}}}})
  expect_ast("local v, _if, if_, var123",
    n.Block{n.VarDecl{"local",{
      n.IdDecl{"v", false},
      n.IdDecl{"_if", false},
      n.IdDecl{"if_", false},
      n.IdDecl{"var123", false}
    }}})
end)

it("spaces", function()
  expect_ast("return a", n.Block{n.Return{n.Id{"a"}}})
  expect_ast("return\ta", n.Block{n.Return{n.Id{"a"}}})
  expect_ast("return\ra", n.Block{n.Return{n.Id{"a"}}})
  expect_ast("return\na", n.Block{n.Return{n.Id{"a"}}})
  expect_ast("return\fa", n.Block{n.Return{n.Id{"a"}}})
  expect_ast("return\va", n.Block{n.Return{n.Id{"a"}}})
end)

it("line breaks", function()
  expect_ast("--comment\nreturn", n.Block{n.Return{}})
  expect_ast("--comment\rreturn", n.Block{n.Return{}})
  expect_ast("--comment\n\rreturn", n.Block{n.Return{}})
  expect_ast("--comment\r\nreturn", n.Block{n.Return{}})
end)

describe("return", function()
  it("simple", function()
    expect_ast("return",
      n.Block{
        n.Return{}
    })
  end)
  it("with semicolon", function()
    expect_ast("return;",
      n.Block{
        n.Return{}
    })
  end)
  it("with value", function()
    expect_ast("return 0",
      n.Block{
        n.Return{
          n.Number{'0'}
    }})
  end)
  it("with multiple values", function()
    expect_ast("return 1,2,3",
      n.Block{
        n.Return{
          n.Number{'1'},
          n.Number{'2'},
          n.Number{'3'},
    }})
  end)
end)

describe("string", function()
  it("long", function()
    expect_ast('return [[]]', n.Block{n.Return{n.String{""}}})
    expect_ast('return [[test]]', n.Block{n.Return{n.String{"test"}}})
    expect_ast('return [[[]]', n.Block{n.Return{n.String{"["}}})
    expect_ast('return [[\ntest]]', n.Block{n.Return{n.String{"test"}}})
    expect_ast('return [[\ntest\n]]', n.Block{n.Return{n.String{"test\n"}}})

    expect_ast('return [=[]=]', n.Block{n.Return{n.String{""}}})
    expect_ast('return [=[test]=]', n.Block{n.Return{n.String{"test"}}})
    expect_ast('return [=[[]=]', n.Block{n.Return{n.String{"["}}})
    expect_ast('return [=[]]=]', n.Block{n.Return{n.String{"]"}}})

    expect_ast('return [==[]==]', n.Block{n.Return{n.String{""}}})
    expect_ast('return [==[test]==]', n.Block{n.Return{n.String{"test"}}})

    expect_ast_error("return [[", 'Expected_LONG_CLOSE')
    expect_ast_error("return [=[", 'Expected_LONG_CLOSE')
  end)
  it("short", function()
    expect_ast('return ""', n.Block{n.Return{n.String{""}}})
    expect_ast('return "test"', n.Block{n.Return{n.String{"test"}}})
    expect_ast("return ''", n.Block{n.Return{n.String{''}}})
    expect_ast("return 'test'", n.Block{n.Return{n.String{'test'}}})
    expect_ast([[return 'a\t\n\b']], n.Block{n.Return{n.String{'a\t\n\b'}}})
    expect_ast_error("return '", 'Expected_QUOTE_CLOSE')
    expect_ast_error('return "', 'Expected_QUOTE_CLOSE')
  end)
  it("literal", function()
    expect_ast('return "asd"u8', n.Block{n.Return{n.String{"asd", "u8"}}})
    expect_ast("return 'asd'hex", n.Block{n.Return{n.String{"asd", "hex"}}})
    expect_ast("return [[asd]]hex", n.Block{n.Return{n.String{"asd", "hex"}}})
  end)
  it("escape sequence", function()
    expect_ast([[return "\a"]], n.Block{n.Return{n.String{"\a"}}})
    expect_ast([[return "\b"]], n.Block{n.Return{n.String{"\b"}}})
    expect_ast([[return "\f"]], n.Block{n.Return{n.String{"\f"}}})
    expect_ast([[return "\n"]], n.Block{n.Return{n.String{"\n"}}})
    expect_ast([[return "\r"]], n.Block{n.Return{n.String{"\r"}}})
    expect_ast([[return "\t"]], n.Block{n.Return{n.String{"\t"}}})
    expect_ast([[return "\v"]], n.Block{n.Return{n.String{"\v"}}})
    expect_ast([[return "\\"]], n.Block{n.Return{n.String{"\\"}}})
    expect_ast([[return "\'"]], n.Block{n.Return{n.String{"\'"}}})
    expect_ast([[return "\""]], n.Block{n.Return{n.String{"\""}}})

    expect_ast('return "\\z \t\f\v\n\r"', n.Block{n.Return{n.String{""}}})
    expect_ast('return "a\\z \t\f\v\n\rb"', n.Block{n.Return{n.String{"ab"}}})

    expect_ast([[return "\u{41}"]], n.Block{n.Return{n.String{"\x41"}}})
    expect_ast([[return "\u{03C0}"]], n.Block{n.Return{n.String{"\xCF\x80"}}})

    expect_ast([[return "\x41"]], n.Block{n.Return{n.String{"\x41"}}})
    expect_ast([[return "\xff"]], n.Block{n.Return{n.String{"\xff"}}})
    expect_ast([[return "\xFF"]], n.Block{n.Return{n.String{"\xFF"}}})

    expect_ast([[return "\0"]], n.Block{n.Return{n.String{"\0"}}})
    expect_ast([[return "\65"]], n.Block{n.Return{n.String{"\65"}}})
    expect_ast([[return "\065"]], n.Block{n.Return{n.String{"\065"}}})

    expect_ast("return '\\\n'", n.Block{n.Return{n.String{"\n"}}})
    expect_ast("return '\\\r'", n.Block{n.Return{n.String{"\n"}}})
    expect_ast("return '\\\n\r'", n.Block{n.Return{n.String{"\n"}}})
    expect_ast("return '\\\r\n'", n.Block{n.Return{n.String{"\n"}}})

    expect_ast_error([[return "\A"]], 'Expected_ESCAPE')
    expect_ast_error([[return "\u42"]], 'Expected_ESCAPE')
    expect_ast_error([[return "\xH"]], 'Expected_ESCAPE')
    expect_ast_error([[return "\x"]], 'Expected_ESCAPE')
    expect_ast_error([[return "\x1"]], 'Expected_ESCAPE')
    expect_ast_error([[return "\u{}"]], 'Expected_ESCAPE')
    expect_ast_error([[return "\300"]], 'Expected_ESCAPE')
  end)
end)

describe("numbers", function()
  it("binary", function()
    expect_ast("return 0b0", n.Block{n.Return{n.Number{"0b0"}}})
    expect_ast("return 0b1", n.Block{n.Return{n.Number{"0b1"}}})
    expect_ast("return 0B1", n.Block{n.Return{n.Number{"0B1"}}})
    expect_ast("return 0b10101111", n.Block{n.Return{n.Number{"0b10101111"}}})
    expect_ast_error([[return 0b]], 'Expected_BIN_PREFIX')
    expect_ast_error([[return 0b2]], 'Expected_BIN_PREFIX')
    expect_ast_error([[return 0b012]], 'Expected_BIN_PREFIX')
  end)
  it("hexadecimal", function()
    expect_ast("return 0x0", n.Block{n.Return{n.Number{"0x0"}}})
    expect_ast("return 0x0123456789abcdef", n.Block{n.Return{n.Number{"0x0123456789abcdef"}}})
    expect_ast("return 0XABCDEF", n.Block{n.Return{n.Number{"0XABCDEF"}}})
    expect_ast_error([[return 0x]], 'Expected_HEX_PREFIX')
    expect_ast_error([[return 0xG]], 'Expected_HEX_PREFIX')
  end)
  it("integer", function()
    expect_ast("return 1", n.Block{n.Return{n.Number{"1"}}})
    expect_ast("return 0123456789", n.Block{n.Return{n.Number{"0123456789"}}})
  end)
  it("fractional", function()
    expect_ast("return .0", n.Block{n.Return{n.Number{".0"}}})
    expect_ast("return 0.", n.Block{n.Return{n.Number{"0."}}})
    expect_ast("return 0123.456789", n.Block{n.Return{n.Number{"0123.456789"}}})
    expect_ast("return 0x.FfffFFFF", n.Block{n.Return{n.Number{"0x.FfffFFFF"}}})
    expect_ast("return 0x.00000001", n.Block{n.Return{n.Number{"0x.00000001"}}})
    expect_ast("return 0Xabcdef.0", n.Block{n.Return{n.Number{"0Xabcdef.0"}}})
  end)
  it("exponential", function()
    expect_ast("return 1.2e-3", n.Block{n.Return{n.Number{"1.2e-3"}}})
    expect_ast("return .1e2", n.Block{n.Return{n.Number{".1e2"}}})
    expect_ast("return .0e+2", n.Block{n.Return{n.Number{".0e+2"}}})
    expect_ast("return 1e-2", n.Block{n.Return{n.Number{"1e-2"}}})
    expect_ast("return 1e+2", n.Block{n.Return{n.Number{"1e+2"}}})
    expect_ast("return 1.e3", n.Block{n.Return{n.Number{"1.e3"}}})
    expect_ast("return 1e1", n.Block{n.Return{n.Number{"1e1"}}})
    expect_ast("return 1.2e+6", n.Block{n.Return{n.Number{"1.2e+6"}}})
    expect_ast("return 0x3.3p3", n.Block{n.Return{n.Number{"0x3.3p3"}}})
    expect_ast("return 0x5.5P-5", n.Block{n.Return{n.Number{"0x5.5P-5"}}})
    expect_ast("return 0b1.1p2", n.Block{n.Return{n.Number{"0b1.1p2"}}})
    expect_ast("return 0x.0p-3", n.Block{n.Return{n.Number{"0x.0p-3"}}})
    expect_ast("return 0x.ABCDEFp+24", n.Block{n.Return{n.Number{"0x.ABCDEFp+24"}}})
    expect_ast_error([[return 0e]], 'Expected_EXP_DIGITS')
    expect_ast_error([[return 0ef]], 'Expected_EXP_DIGITS')
    expect_ast_error([[return 1e-]], 'Expected_EXP_DIGITS')
    expect_ast_error([[return 1e*2]], 'Expected_EXP_DIGITS')
  end)
  it("literal", function()
    expect_ast("return .1f", n.Block{n.Return{n.Number{".1", "f"}}})
    expect_ast("return 123u", n.Block{n.Return{n.Number{"123", "u"}}})
  end)
end)

describe("expression", function()
  it("number", function()
    expect_ast("return 3.34e-50, 0xff, 0.1",
      n.Block{
        n.Return{
          n.Number{'3.34e-50'},
          n.Number{'0xff'},
          n.Number{'0.1'},
    }})
  end)
  it("string", function()
    expect_ast([[return 'hi', "there"]],
      n.Block{
        n.Return{
          n.String{'hi'},
          n.String{'there'}
    }})
  end)
  it("boolean", function()
    expect_ast("return true, false",
      n.Block{
        n.Return{
          n.Boolean{true},
          n.Boolean{false}
    }})
  end)
  it("nil", function()
    expect_ast("return nil",
      n.Block{
        n.Return{
          n.Nil{},
    }})
  end)
  it("nilptr", function()
    expect_ast("return nilptr",
      n.Block{
        n.Return{
          n.Nilptr{},
    }})
  end)
  it("varargs", function()
    expect_ast("return ...",
      n.Block{
        n.Return{
          n.Varargs{},
    }})
  end)
  it("identifier", function()
    expect_ast("return a, _b",
      n.Block{
        n.Return{
          n.Id{'a'},
          n.Id{'_b'},
    }})
  end)
  it("initializer list", function()
    expect_ast("return {}, {a}, {a,b}, {a=b}, {[a] = b}",
      n.Block{
        n.Return{
          n.InitList{},
          n.InitList{n.Id{'a'}},
          n.InitList{n.Id{'a'}, n.Id{'b'}},
          n.InitList{n.Pair{'a', n.Id{'b'}}},
          n.InitList{n.Pair{n.Id{'a'}, n.Id{'b'}}},
    }})
  end)
  it("surrounded expression", function()
    expect_ast("return (a)",
      n.Block{
        n.Return{
          n.Paren{
            n.Id{'a'}
    }}})
  end)
  it("dot index", function()
    expect_ast("return a.b, a.b.c",
      n.Block{
        n.Return{
          n.DotIndex{'b',
            n.Id{'a'}
          },
          n.DotIndex{'c',
            n.DotIndex{'b',
              n.Id{'a'}
          }}
    }})
  end)
  it("array index", function()
    expect_ast("return a[b], a[b][c]",
      n.Block{
        n.Return{
          n.KeyIndex{
            n.Id{'b'},
            n.Id{'a'}
          },
          n.KeyIndex{
            n.Id{'c'},
            n.KeyIndex{
              n.Id{'b'},
              n.Id{'a'}
          }}
    }})
  end)
  it("anonymous function", function()
    expect_ast("return function() end, function(a, b: B): (C,D) end",
      n.Block{
        n.Return{
          n.Function{{}, false, false, n.Block{}},
          n.Function{
            { n.IdDecl{'a', false}, n.IdDecl{'b', n.Id{'B'}} },
            { n.Id{'C'}, n.Id{'D'} },
            false,
            n.Block{}
          }
    }})
  end)
  it("call global", function()
    expect_ast("return a()",
      n.Block{
        n.Return{
          n.Call{{}, n.Id{'a'}},
    }})
  end)
  it("call with arguments", function()
    expect_ast("return a(a, 'b', 1, f(), ...)",
      n.Block{
        n.Return{
          n.Call{{
            n.Id{'a'},
            n.String{'b'},
            n.Number{'1'},
            n.Call{{}, n.Id{'f'}},
            n.Varargs{},
          }, n.Id{'a'}},
    }})
  end)
  it("call field", function()
    expect_ast("return a.b()",
      n.Block{
        n.Return{
          n.Call{{}, n.DotIndex{'b', n.Id{'a'}}},
    }})
  end)
  it("call method", function()
    expect_ast("return a:b()",
      n.Block{
        n.Return{
          n.CallMethod{'b', {}, n.Id{'a'}},
    }})
  end)
  it("do expression", function()
    expect_ast("return (do in nil end)",
      n.Block{
        n.Return{
          n.DoExpr{n.Block{n.In{n.Nil{}}}},
    }})
  end)
end)

describe("table", function()
  it("complex fields", function()
    expect_ast([[return {
      a=a, [a]=a, [nil]=nil, [true]=true,
      ['mystr']='mystr', [1.0]=1.0, [func()]=func(),
      [...]=...
    }]],
      n.Block{
        n.Return{
          n.InitList{
            n.Pair{'a', n.Id{'a'}},
            n.Pair{n.Id{'a'}, n.Id{'a'}},
            n.Pair{n.Nil{}, n.Nil{}},
            n.Pair{n.Boolean{true}, n.Boolean{true}},
            n.Pair{n.String{'mystr'}, n.String{'mystr'}},
            n.Pair{n.Number{'1.0'}, n.Number{'1.0'}},
            n.Pair{n.Call{{}, n.Id{'func'}}, n.Call{{}, n.Id{'func'}}},
            n.Pair{n.Varargs{}, n.Varargs{}},
    }}})
  end)
  it("multiple values", function()
    expect_ast("return {a,nil,true,'mystr',1.0,func(),...}",
      n.Block{
        n.Return{
          n.InitList{
            n.Id{'a'},
            n.Nil{},
            n.Boolean{true},
            n.String{'mystr'},
            n.Number{'1.0'},
            n.Call{{}, n.Id{'func'}},
            n.Varargs{},
    }}})
  end)
  it("nested", function()
    expect_ast("return {{{}}}",
      n.Block{
        n.Return{
          n.InitList{n.InitList{n.InitList{}}}
    }})
  end)
end)

describe("call", function()
  it("simple", function()
    expect_ast("a()",
      n.Block{
        n.Call{{}, n.Id{'a'}},
    })
  end)
  it("dot index", function()
    expect_ast("a.b()",
      n.Block{
        n.Call{{}, n.DotIndex{'b', n.Id{'a'}}}
    })
  end)
  it("array index", function()
    expect_ast("a['b']()",
      n.Block{
        n.Call{{}, n.KeyIndex{n.String{'b'}, n.Id{'a'}}}
    })
  end)
  it("method", function()
    expect_ast("a:b()",
      n.Block{
        n.CallMethod{'b', {}, n.Id{'a'}}
    })
  end)
  it("nested", function()
    expect_ast("a(b())",
      n.Block{
        n.Call{{n.Call{{}, n.Id{'b'}}}, n.Id{'a'}},
    })
  end)
end)

describe("statement", function()
  describe("if", function()
    it("simple", function()
      expect_ast("if true then end",
        n.Block{
          n.If{{
            n.Boolean{true}, n.Block{}
      }}})
    end)
    it("with elseifs and else", function()
      expect_ast("if a then return x elseif b then return y else return z end",
        n.Block{
          n.If{{
            n.Id{'a'}, n.Block{n.Return{ n.Id{'x'} }},
            n.Id{'b'}, n.Block{n.Return{ n.Id{'y'} }},
          },
          n.Block{n.Return{ n.Id{'z'} }}
      }})
    end)
  end)

  describe("switch", function()
    it("simple", function()
      expect_ast("switch a case b then end",
        n.Block{
          n.Switch{
            n.Id{'a'},
            {{n.Id{'b'}}, n.Block{} }
      }})
    end)
    it("with else part", function()
      expect_ast("switch a case b then else end",
        n.Block{
          n.Switch{
            n.Id{'a'},
            {{n.Id{'b'}}, n.Block{}},
            n.Block{}
      }})
    end)
    it("multiple cases", function()
      expect_ast("switch a case b then case c then else end",
        n.Block{
          n.Switch{
            n.Id{'a'},
            {{n.Id{'b'}}, n.Block{},
             {n.Id{'c'}}, n.Block{}},
            n.Block{}
      }})
    end)
    it("multiple cases with shared block", function()
      expect_ast("switch a do case b, c then else end",
        n.Block{
          n.Switch{
            n.Id{'a'},
            {{n.Id{'b'}, n.Id{'c'}}, n.Block{}},
            n.Block{}
      }})
    end)
  end)

  describe("do", function()
    it("simple", function()
      expect_ast("do end",
        n.Block{
          n.Do{n.Block{}}
      })
    end)
    it("with statements", function()
      expect_ast("do print() end",
        n.Block{
          n.Do{n.Block{n.Call{{}, n.Id{'print'}}}}
      })
    end)
  end)

  describe("defer", function()
    it("simple", function()
      expect_ast("defer end",
        n.Block{
          n.Defer{n.Block{}}
      })
    end)
    it("with statements", function()
      expect_ast("defer print() end",
        n.Block{
          n.Defer{n.Block{n.Call{{}, n.Id{'print'}}}}
      })
    end)
  end)

  describe("loop", function()
    it("while", function()
      expect_ast("while a do end",
        n.Block{
          n.While{n.Id{'a'}, n.Block{}}
      })
    end)
    it("break and continue", function()
      expect_ast("while a do break end",
        n.Block{
          n.While{n.Id{'a'}, n.Block{n.Break{}}}
      })
      expect_ast("while a do continue end",
        n.Block{
          n.While{n.Id{'a'}, n.Block{n.Continue{}}}
      })
    end)
    it("repeat", function()
      expect_ast("repeat until a",
        n.Block{
          n.Repeat{n.Block{}, n.Id{'a'}}
      })
      expect_ast("repeat print() until a==b",
        n.Block{
          n.Repeat{
            n.Block{n.Call{{}, n.Id{'print'}}},
            n.BinaryOp{n.Id{'a'}, 'eq', n.Id{'b'}}
      }})
    end)
  end)

  describe("for", function()
    it("simple", function()
      expect_ast("for i=1,10 do end",
        n.Block{
          n.ForNum{
            n.IdDecl{'i', false},
            n.Number{'1'},
            false,
            n.Number{'10'},
            false,
            n.Block{}}
      })
    end)
    it("reverse with comparations", function()
      expect_ast("for i:number=10,>0,-1 do end",
        n.Block{
          n.ForNum{
            n.IdDecl{'i', n.Id{'number'}},
            n.Number{'10'},
            'gt',
            n.Number{'0'},
            n.UnaryOp{'unm', n.Number{'1'}},
            n.Block{}}
      })
    end)
    it("in", function()
      expect_ast("for i in a,b,c do end",
        n.Block{
          n.ForIn{
            { n.IdDecl{'i', false} },
            { n.Id{'a'}, n.Id{'b'}, n.Id{'c'} },
            n.Block{}}
      })
    end)
    it("in typed", function()
      expect_ast("for i:int8,j:int16,k:int32 in iter() do end",
        n.Block{
          n.ForIn{
            { n.IdDecl{'i', n.Id{'int8'}},
              n.IdDecl{'j', n.Id{'int16'}},
              n.IdDecl{'k', n.Id{'int32'}}
            },
            { n.Call{{}, n.Id{'iter'}} },
            n.Block{}}
      })
    end)
  end)

  describe("goto", function()
    it("simple", function()
      expect_ast("goto mylabel",
        n.Block{
          n.Goto{'mylabel'}
      })
    end)
    it("label", function()
      expect_ast("::mylabel::",
        n.Block{
          n.Label{'mylabel'}
      })
    end)
    it("complex", function()
      expect_ast("::mylabel:: f() if a then goto mylabel end",
        n.Block{
          n.Label{'mylabel'},
          n.Call{{}, n.Id{'f'}},
          n.If{{n.Id{'a'}, n.Block{n.Goto{'mylabel'}}}}
      })
    end)
  end)

  describe("variable declaration", function()
    it("local variable", function()
      expect_ast([[
        local a
        local a: integer
      ]],
        n.Block{
          n.VarDecl{'local', {n.IdDecl{'a', false}}},
          n.VarDecl{'local', {n.IdDecl{'a', n.Id{'integer'}}}}
      })
    end)
    it("local variable assignment", function()
      expect_ast([[
        local a = b
        local a: integer = b
      ]],
        n.Block{
          n.VarDecl{'local', {n.IdDecl{'a', false}}, {n.Id{'b'}}},
          n.VarDecl{'local', {n.IdDecl{'a', n.Id{'integer'}}}, {n.Id{'b'}}}
      })
    end)
    it("non local variable", function()
      expect_ast("global a: integer",
        n.Block{
          n.VarDecl{'global', {n.IdDecl{'a', n.Id{'integer'}}}}
      })
    end)
    it("variable annotations", function()
      expect_ast([[
        local a = b
        local a <const> = b
        local a: any <comptime> = b
      ]],
        n.Block{
          n.VarDecl{'local', {n.IdDecl{'a', false}}, {n.Id{'b'}}},
          n.VarDecl{'local', {n.IdDecl{'a', false, {n.Annotation{'const'}}}}, {n.Id{'b'}}},
          n.VarDecl{'local', {n.IdDecl{'a', n.Id{'any'}, {n.Annotation{'comptime'}}}}, {n.Id{'b'}}},
      })
    end)
    it("variable mutabilities", function()
      expect_ast([[
        local a <const> = b
        global a <const> = b
        local a <const>, b <comptime> = c, d
      ]],
        n.Block{
          n.VarDecl{'local', {n.IdDecl{'a', false, {n.Annotation{'const'}} }}, {n.Id{'b'}}},
          n.VarDecl{'global', {n.IdDecl{'a', false, {n.Annotation{'const'}} }}, {n.Id{'b'}}},
          n.VarDecl{'local', {
            n.IdDecl{'a', false, {n.Annotation{'const'}}},
            n.IdDecl{'b', false, {n.Annotation{'comptime'}}}
          }, {n.Id{'c'},n.Id{'d'}}}
      })
    end)
    it("variable multiple assigments", function()
      expect_ast("local a,b,c = x,y,z",
        n.Block{
          n.VarDecl{'local',
            { n.IdDecl{'a', false}, n.IdDecl{'b', false}, n.IdDecl{'c', false} },
            { n.Id{'x'}, n.Id{'y'}, n.Id{'z'} }},
      })
    end)
    it("record global variables", function()
      expect_ast("global a.b: integer",
        n.Block{
          n.VarDecl{'global', {n.IdDecl{n.DotIndex{'b',n.Id{'a'}}, n.Id{'integer'}}}}
      })
    end)
  end)

  describe("assignment", function()
    it("simple", function()
      expect_ast("a = b",
        n.Block{
          n.Assign{
            { n.Id{'a'} },
            { n.Id{'b'} }},
      })
    end)
    it("multiple", function()
      expect_ast("a,b,c = x,y,z",
        n.Block{
          n.Assign{
            { n.Id{'a'}, n.Id{'b'}, n.Id{'c'} },
            { n.Id{'x'}, n.Id{'y'}, n.Id{'z'} }},
      })
    end)
    it("on indexes", function()
      expect_ast("a.b, a[b], a[b][c], f(a).b = x,y,z,w",
        n.Block{
          n.Assign{
            { n.DotIndex{'b', n.Id{'a'}},
              n.KeyIndex{n.Id{'b'}, n.Id{'a'}},
              n.KeyIndex{n.Id{'c'}, n.KeyIndex{n.Id{'b'}, n.Id{'a'}}},
              n.DotIndex{'b', n.Call{{n.Id{'a'}}, n.Id{'f'}}},
            },
            { n.Id{'x'}, n.Id{'y'}, n.Id{'z'}, n.Id{'w'} }}
      })
    end)
    it("on calls", function()
      expect_ast("f().a, a.b()[c].d = 1, 2",
        n.Block{
          n.Assign{{
            n.DotIndex{"a", n.Call{{}, n.Id{"f"}}},
            n.DotIndex{
                "d",
                n.KeyIndex{
                  n.Id{"c"},
                  n.Call{{}, n.DotIndex{"b", n.Id{"a"}}}
                }
              }
            },
            { n.Number{"1"},
              n.Number{"2"}
            }
      }})
    end)
  end)

  describe("function", function()
    it("simple", function()
      expect_ast("function f() end",
        n.Block{
          n.FuncDef{false, n.Id{'f'}, {}, false, false, n.Block{} }
      })
    end)
    it("varargs", function()
      expect_ast("function f(...) end",
        n.Block{
          n.FuncDef{false, n.Id{'f'}, {n.VarargsType{}}, false, false, n.Block{} }
      })
    end)
    it("typed varargs", function()
      expect_ast("function f(...: cvarargs) end",
        n.Block{
          n.FuncDef{false, n.Id{'f'}, {n.VarargsType{'cvarargs'}}, false, false, n.Block{} }
      })
    end)
    it("local and typed", function()
      expect_ast("local function f(a, b: integer): string end",
        n.Block{
          n.FuncDef{'local', n.IdDecl{'f'},
            { n.IdDecl{'a', false}, n.IdDecl{'b', n.Id{'integer'}} },
            { n.Id{'string'} },
            false,
            n.Block{} }
      })
    end)
    it("global and typed", function()
      expect_ast("global function f(a, b: integer): string end",
        n.Block{
          n.FuncDef{'global', n.IdDecl{'f'},
            { n.IdDecl{'a', false}, n.IdDecl{'b', n.Id{'integer'}} },
            { n.Id{'string'} },
            false,
            n.Block{} }
      })
    end)
    it("global and typed with annotations", function()
      expect_ast("global function f(a <const>, b: integer <const>): string <inline> end",
        n.Block{
          n.FuncDef{'global', n.IdDecl{'f'},
            { n.IdDecl{'a', false, {n.Annotation{'const'}}},
              n.IdDecl{'b', n.Id{'integer'}, {n.Annotation{'const'}}} },
            { n.Id{'string'} },
            { n.Annotation{'inline'} },
            n.Block{} }
      })
    end)
    it("with colon index", function()
      expect_ast("function a:f() end",
        n.Block{
          n.FuncDef{false, n.ColonIndex{'f', n.Id{'a'}}, {}, false, false, n.Block{} }
      })
    end)
    it("with dot index", function()
      expect_ast("function a.f() end",
        n.Block{
          n.FuncDef{false, n.DotIndex{'f', n.Id{'a'}}, {}, false, false, n.Block{} }
      })
    end)
  end)
end)

describe("operator", function()
  it("'or'", function()
    expect_ast("return a or b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'or', n.Id{'b'}
    }}})
  end)
  it("'and'", function()
    expect_ast("return a and b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'and', n.Id{'b'}
    }}})
  end)
  it("'<'", function()
    expect_ast("return a < b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'lt', n.Id{'b'}
    }}})
  end)
  it("'>'", function()
    expect_ast("return a > b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'gt', n.Id{'b'}
    }}})
  end)
  it("'<='", function()
    expect_ast("return a <= b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'le', n.Id{'b'}
    }}})
  end)
  it("'>='", function()
    expect_ast("return a >= b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'ge', n.Id{'b'}
    }}})
  end)
  it("'~='", function()
    expect_ast("return a ~= b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'ne', n.Id{'b'}
    }}})
  end)
  it("'=='", function()
    expect_ast("return a == b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'eq', n.Id{'b'}
    }}})
  end)
  it("'|'", function()
    expect_ast("return a | b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'bor', n.Id{'b'}
    }}})
  end)
  it("'~'", function()
    expect_ast("return a ~ b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'bxor', n.Id{'b'}
    }}})
  end)
  it("'&'", function()
    expect_ast("return a & b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'band', n.Id{'b'}
    }}})
  end)
  it("'<<'", function()
    expect_ast("return a << b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'shl', n.Id{'b'}
    }}})
  end)
  it("'>>'", function()
    expect_ast("return a >> b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'shr', n.Id{'b'}
    }}})
  end)
  it("'>>>'", function()
    expect_ast("return a >>> b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'asr', n.Id{'b'}
    }}})
  end)
  it("'..'", function()
    expect_ast("return a .. b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'concat', n.Id{'b'}
    }}})
  end)
  it("'+'", function()
    expect_ast("return a + b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'add', n.Id{'b'}
    }}})
  end)
  it("'-'", function()
    expect_ast("return a - b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'sub', n.Id{'b'}
    }}})
  end)
  it("'*'", function()
    expect_ast("return a * b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'mul', n.Id{'b'}
    }}})
  end)
  it("'/'", function()
    expect_ast("return a / b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'div', n.Id{'b'}
    }}})
  end)
  it("'//'", function()
    expect_ast("return a // b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'idiv', n.Id{'b'}
    }}})
  end)
  it("'///'", function()
    expect_ast("return a /// b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'tdiv', n.Id{'b'}
    }}})
  end)
  it("'%'", function()
    expect_ast("return a % b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'mod', n.Id{'b'}
    }}})
  end)
  it("'%%%'", function()
    expect_ast("return a %%% b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'tmod', n.Id{'b'}
    }}})
  end)
  it("'not'", function()
    expect_ast("return not a",
      n.Block{
        n.Return{
          n.UnaryOp{'not', n.Id{'a'}
    }}})
  end)
  it("'#'", function()
    expect_ast("return #a",
      n.Block{
        n.Return{
          n.UnaryOp{'len', n.Id{'a'}
    }}})
  end)
  it("'-'", function()
    expect_ast("return -a",
      n.Block{
        n.Return{
          n.UnaryOp{'unm', n.Id{'a'}
    }}})
  end)
  it("'~'", function()
    expect_ast("return ~a",
      n.Block{
        n.Return{
          n.UnaryOp{'bnot', n.Id{'a'}
    }}})
  end)
  it("'&'", function()
    expect_ast("return &a",
      n.Block{
        n.Return{
          n.UnaryOp{'ref', n.Id{'a'}
    }}})
  end)
  it("'*'", function()
    expect_ast("$a = b",
      n.Block{
        n.Assign{
          {n.UnaryOp{'deref',n.Id{'a'}}},
          {n.Id{'b'}
    }}})
    expect_ast("$(&i) = b",
      n.Block{
        n.Assign{
          {n.UnaryOp{'deref',n.Paren{n.UnaryOp{"ref", n.Id{"i"}}}}},
          {n.Id{'b'}
    }}})
    expect_ast("return $a",
      n.Block{
        n.Return{
          n.UnaryOp{'deref', n.Id{'a'}
    }}})
  end)
  it("'^'", function()
    expect_ast("return a ^ b",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{'a'}, 'pow', n.Id{'b'}
    }}})
  end)
end)

describe("operators following precedence rules for", function()
  --[[
  Operator precedence in Lua follows the table below, from lower
  to higher priority:
    or
    and
    <     >     <=    >=    ~=    ==
    |
    ~
    &
    <<    >>
    ..
    +     -
    *     /     //    %
    unary operators (not   #     -     ~)
    ^
  All binary operators are left associative, except for `^´ (exponentiation)
  and `..´ (concatenation), which are right associative.
  ]]
  it("`and` and `or`", function()
    expect_ast("return a and b or c",
      n.Block{
        n.Return{
          n.BinaryOp{n.BinaryOp{n.Id{"a"}, "and", n.Id{"b"}}, "or", n.Id{"c"}}
        }
    })
    expect_ast("return a or b and c",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{"a"}, "or", n.BinaryOp{n.Id{"b"}, "and", n.Id{"c"}}}
        }
    })
    expect_ast("return a and (b or c)",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{"a"}, "and", n.Paren{n.BinaryOp{n.Id{"b"}, "or", n.Id{"c"}}}}
        }
    })
  end)
  it("lua precedence rules", function()
    expect_ast("return a or b and c < d | e ~ f & g << h .. i + j * k ^ #l",
      n.Block{
        n.Return{
          n.BinaryOp{n.Id{"a"}, "or",
            n.BinaryOp{n.Id{"b"},"and",
              n.BinaryOp{n.Id{"c"}, "lt",
                n.BinaryOp{n.Id{"d"}, "bor",
                  n.BinaryOp{n.Id{"e"}, "bxor",
                    n.BinaryOp{n.Id{"f"}, "band",
                      n.BinaryOp{n.Id{"g"}, "shl",
                        n.BinaryOp{n.Id{"h"}, "concat",
                          n.BinaryOp{n.Id{"i"}, "add",
                            n.BinaryOp{n.Id{"j"}, "mul",
                              n.BinaryOp{n.Id{"k"}, "pow",
                                n.UnaryOp{"len", n.Id{"l"}
    }}}}}}}}}}}}}})
  end)
  it("lua associative rules", function()
    expect_ast("return a + b + c",
    n.Block{
      n.Return{
        n.BinaryOp{
          n.BinaryOp{n.Id{"a"}, "add", n.Id{"b"}},
          "add",
          n.Id{"c"}
    }}})
    expect_ast("return a .. b .. c",
    n.Block{
      n.Return{
        n.BinaryOp{n.Id{"a"}, "concat",
          n.BinaryOp{n.Id{"b"}, "concat", n.Id{"c"}}
    }}})
    expect_ast("return a ^ b ^ c",
    n.Block{
      n.Return{
        n.BinaryOp{n.Id{"a"}, "pow",
          n.BinaryOp{n.Id{"b"}, "pow", n.Id{"c"}}
    }}})
  end)
end)

describe("type expression", function()
  it("function", function()
    expect_ast("local f: function()",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'f', n.FuncType{{}}}}
    }})
    expect_ast("local f: function(integer): string",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'f', n.FuncType{{n.Id{'integer'}}, {n.Id{'string'}}}}}
    }})
    expect_ast("local f: function(x: integer): string",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'f', n.FuncType{{n.IdDecl{'x',n.Id{'integer'}}}, {n.Id{'string'}}}}}
    }})
    expect_ast("local f: function(x: integer, y: integer): string",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'f', n.FuncType{
            { n.IdDecl{'x',n.Id{'integer'}}, n.IdDecl{'y',n.Id{'integer'} }
          }, {n.Id{'string'}}}}}
    }})
    expect_ast("local f: function(integer, uinteger):(string, boolean)",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'f', n.FuncType{
            {n.Id{'integer'}, n.Id{'uinteger'}},
            {n.Id{'string'}, n.Id{'boolean'}}}}}
    }})
  end)
  it("array type", function()
    expect_ast("local a: array(integer, 10)",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'a', n.ArrayType{n.Id{'integer'}, n.Number{'10'}}}}
    }})
    expect_ast("local a: array(integer, 2 >> 1)",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'a', n.ArrayType{n.Id{'integer'},
            n.BinaryOp{n.Number{"2"}, "shr", n.Number{"1"}}}}}
    }})
    expect_ast("local a: [10]integer",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'a', n.ArrayType{n.Id{'integer'}, n.Number{'10'}}}}
    }})
    expect_ast("local a: [10][20]integer",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'a',
            n.ArrayType{
              n.ArrayType{n.Id{'integer'}, n.Number{'20'}},
              n.Number{'10'}}}}
    }})
    expect_ast("local a: []integer",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'a', n.ArrayType{n.Id{'integer'}}}}
    }})
    expect_ast("local a: array(integer)",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'a', n.ArrayType{n.Id{'integer'}}}}
    }})
  end)
  it("record type", function()
    expect_ast("local r: record{a: integer}",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'r', n.RecordType{n.RecordField{'a', n.Id{'integer'}}}}}
    }})
    expect_ast("local r: record{a: integer, b: boolean}",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'r', n.RecordType{
            n.RecordField{'a', n.Id{'integer'}},
            n.RecordField{'b', n.Id{'boolean'}}}}}
    }})
    expect_ast(
      "local r: record{f: function(integer, uinteger):(string, boolean), t: array(integer, 4)}",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'r', n.RecordType{
            n.RecordField{'f', n.FuncType{
              {n.Id{'integer'}, n.Id{'uinteger'}},
              {n.Id{'string'}, n.Id{'boolean'}}}},
            n.RecordField{'t', n.ArrayType{n.Id{'integer'}, n.Number{'4'}}}}}}}
    })
    expect_ast("local r: record{a: record{c: integer}, b: boolean}",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'r', n.RecordType{
            n.RecordField{'a', n.RecordType{
              n.RecordField{'c', n.Id{'integer'}}
            }},
            n.RecordField{'b', n.Id{'boolean'}}}}}}
    })
  end)
  it("union type", function()
    expect_ast("local u: union{a: integer, b: number}",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'u', n.UnionType{
            n.UnionField{'a', n.Id{'integer'}},
            n.UnionField{'b', n.Id{'number'}}}}}
    }})
    expect_ast("local u: union{integer, number, pointer}",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'u', n.UnionType{
            n.UnionField{false, n.Id{'integer'}},
            n.UnionField{false, n.Id{'number'}},
            n.UnionField{false, n.PointerType{}}}}}
    }})
  end)
  it("variant type", function()
    expect_ast("local v: variant(integer, number, pointer)",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'v', n.VariantType{
            n.Id{'integer'},
            n.Id{'number'},
            n.PointerType{}}}}
    }})
    expect_ast("local v: integer | niltype",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'v', n.VariantType{
            n.Id{'integer'},
            n.Id{'niltype'}}}}
    }})
    expect_ast("local v: integer | string | niltype",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'v', n.VariantType{
            n.Id{'integer'},
            n.Id{'string'},
            n.Id{'niltype'}}}}
    }})
  end)
  it("optional type", function()
    expect_ast("local u: ?integer",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'u', n.OptionalType{n.Id{'integer'}}}}
    }})
    expect_ast("local u: ?*integer",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'u', n.OptionalType{n.PointerType{n.Id{'integer'}}}}}
    }})
  end)
  it("enum type", function()
    expect_ast("local e: enum{a}",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'e', n.EnumType{false,{n.EnumField{'a'}}}}}
    }})
    expect_ast("local e: enum(integer){a,b=2,c=b,}",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'e', n.EnumType{n.Id{'integer'}, {
            n.EnumField{'a'},
            n.EnumField{'b', n.Number{'2'}},
            n.EnumField{'c', n.Id{'b'}}
    }}}}}})
  end)
  it("pointer type", function()
    expect_ast("local p: pointer",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'p', n.PointerType{}}}
    }})
    expect_ast("local p: pointer(integer)",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'p', n.PointerType{n.Id{'integer'}}}}
    }})
    expect_ast("local p: *integer",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'p', n.PointerType{n.Id{'integer'}}}}
    }})
    expect_ast("local p: **integer",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'p', n.PointerType{n.PointerType{n.Id{'integer'}}}}}
    }})
  end)
  it("generic type", function()
    expect_ast("local r: somegeneric(integer, 4)",
      n.Block{
        n.VarDecl{'local', {
          n.IdDecl{'r', n.GenericType{n.Id{"somegeneric"}, {
            n.Id{'integer'}, n.Number{"4"}}}}}
    }})
    expect_ast("local r: somegeneric(array(integer, 4), *integer)",
      n.Block{
        n.VarDecl{'local', {
          n.IdDecl{'r', n.GenericType{n.Id{"somegeneric"}, {
            n.ArrayType{n.Id{'integer'}, n.Number{'4'}},
            n.PointerType{n.Id{"integer"}}
    }}}}}})
  end)
  it("complex types", function()
    expect_ast("local p: [10]*[10]*integer",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'p',
            n.ArrayType{
              n.PointerType{
                n.ArrayType{
                  n.PointerType{n.Id{"integer"}},
                  n.Number{"10"}
                }
            },
            n.Number{"10"}
    }}}}})
  end)
  it("type instantiation", function()
    expect_ast("local Integer = @integer",
      n.Block{
        n.VarDecl{'local',
          {n.IdDecl{'Integer', false}},
          {n.Type{n.Id{'integer'}}}
    }})
    expect_ast("local MyRecord = @record{a: integer}",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'MyRecord', false}},
          { n.Type{n.RecordType{n.RecordField{'a', n.Id{'integer'}}}}}
    }})
  end)
  it("type cast", function()
    expect_ast("local a = (@integer)(0)",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'a', false}},
          { n.Call{{n.Number{"0"}},n.Paren{n.Type{n.Id{"integer"}}}}
        }
    }})
  end)
  it("namespaced types", function()
    expect_ast("local a: Namespace.Class",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'a', n.DotIndex{"Class", n.Id{"Namespace"}}}
        }
    }})
    expect_ast("local a: Namespace1.Namespace2.Class",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'a', n.DotIndex{"Class", n.DotIndex{"Namespace2", n.Id{"Namespace1"}}}}
        }
    }})
  end)
end)

describe("annotation", function()
  it("variable", function()
    expect_ast("local a <annot>",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'a', false, {n.Annotation{'annot'}}}}
    }})
    expect_ast("local a <annot>",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'a', false, {n.Annotation{'annot'}}}}
    }})
    expect_ast("local a <annot1, annot2>",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'a', false, {n.Annotation{'annot1'}, n.Annotation{'annot2'}}}}
    }})
  end)
  it("function", function()
    expect_ast("local function f() <annot> end",
      n.Block{
        n.FuncDef{'local', n.IdDecl{'f'}, {}, false, {n.Annotation{'annot'}}, n.Block{} }
    })
  end)
end)

describe("preprocessor", function()
  it("one line", function()
    expect_ast("##f()",
      n.Block{
        n.Preprocess{"f()"}
    })
    expect_ast("##\nlocal a",
      n.Block{
        n.Preprocess{""},
        n.VarDecl{'local', { n.IdDecl{'a', false}}}
    })
  end)
  it("multiline", function()
    expect_ast("##[[if true then\nend]]",
      n.Block{
        n.Preprocess{"if true then\nend"}
    })
    expect_ast("##[=[if true then\nend]=]",
      n.Block{
        n.Preprocess{"if true then\nend"}
    })
    expect_ast("##[==[if true then\nend]==]",
      n.Block{
        n.Preprocess{"if true then\nend"}
    })
  end)
  it("emitting nodes", function()
    expect_ast("##[[if true then]] print 'hello' ##[[end]]",
      n.Block{
        n.Preprocess{"if true then"},
        n.Call{{n.String {"hello"}}, n.Id{"print"}},
        n.Preprocess{"end"}
    })
  end)
  it("eval expression", function()
    expect_ast("print(#['hello ' .. 'world']#)",
      n.Block{
        n.Call{{n.PreprocessExpr{"'hello ' .. 'world'"}}, n.Id{"print"}}
    })
    expect_ast("print(#[a[1]]#)",
      n.Block{
        n.Call{{n.PreprocessExpr{"a[1]"}}, n.Id{"print"}}
    })
    expect_ast("#[a]#()",
      n.Block{
        n.Call{{}, n.PreprocessExpr{"a"}}
    })
    expect_ast("#[a]# = 1",
      n.Block{
        n.Assign{{n.PreprocessExpr{"a"}}, {n.Number{"1"}}}
    })
  end)
  it("replacement macro syntax sugar", function()
    expect_ast("local a = f!(1)",
      n.Block{
        n.VarDecl{
          "local",
          {n.IdDecl{"a", false}},
          {n.Call{{n.Number{"1"}}, n.PreprocessExpr{"f"}}}
    }})
  end)
  it("eval name", function()
    expect_ast("::#|a|#::",
      n.Block{
        n.Label{n.PreprocessName{"a"}}
    })
    expect_ast("::#|a|#::",
      n.Block{
        n.Label{n.PreprocessName{"a"}}
    })
    expect_ast("goto #|a|#",
      n.Block{
        n.Goto{n.PreprocessName{"a"}}
    })
    expect_ast("return #|a|#.#|b|#",
      n.Block{
        n.Return{n.DotIndex{n.PreprocessName{"b"}, n.Id{n.PreprocessName{"a"}}}}
    })
    expect_ast("function #|a|#:#|b|#() end",
      n.Block{
        n.FuncDef{false,
        n.ColonIndex{n.PreprocessName{"b"}, n.Id{n.PreprocessName{"a"}}},
        {}, false, false, n.Block{} },
    })
    expect_ast("#|a|#:#|b|#()",
      n.Block{
        n.CallMethod{n.PreprocessName{"b"}, {}, n.Id{n.PreprocessName{"a"}}},
    })
    expect_ast("return {#|a|# = b}",
      n.Block{
        n.Return{n.InitList{n.Pair{n.PreprocessName{"a"}, n.Id{'b'}}}}
    })
    expect_ast("local #|a|#: #|b|# <#|c|#>",
      n.Block{
        n.VarDecl{'local', {
          n.IdDecl{
            n.PreprocessName{"a"},
            n.Id{n.PreprocessName{"b"}},
            {n.Annotation{n.PreprocessName{"c"}}}
    }}}})
  end)
end)

describe("utf8 character", function()
  -- '\xCF\x80' is UTF-8 code for greek 'pi' character
  it("function", function()
    expect_ast("local \xCF\x80",
      n.Block{
        n.VarDecl{'local',
          { n.IdDecl{'\xCF\x80', false} }
    }})
  end)
end)

end)
