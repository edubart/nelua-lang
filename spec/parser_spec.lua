require 'busted.runner'()

local assert = require 'utils.assert'
local astnodes = require 'euluna.astnodes'
local AST = astnodes.create
local euluna_parser = require 'euluna.langs.euluna_parser'

describe("Euluna should parse", function()

--------------------------------------------------------------------------------
-- empty file
--------------------------------------------------------------------------------
it("empty file", function()
  assert.parse_ast(euluna_parser, "", AST('Block', {}))
  assert.parse_ast(euluna_parser, " \t\n", AST('Block', {}))
  assert.parse_ast(euluna_parser, ";", AST('Block', {}))
end)

--------------------------------------------------------------------------------
-- invalid syntax
--------------------------------------------------------------------------------
it("invalid syntax", function()
  assert.parse_ast_error(euluna_parser, [[something]], 'UnexpectedSyntaxAtEOF')
end)

--------------------------------------------------------------------------------
-- shebang
--------------------------------------------------------------------------------
it("shebang", function()
  assert.parse_ast(euluna_parser, [[#!/usr/bin/env lua]], AST('Block', {}))
  assert.parse_ast(euluna_parser, [[#!/usr/bin/env lua\n]], AST('Block', {}))
end)

--------------------------------------------------------------------------------
-- comments
--------------------------------------------------------------------------------
it("comments", function()
  assert.parse_ast(euluna_parser, [=[-- line comment
--[[
multiline comment
]]]=], AST('Block', {}))
end)

--------------------------------------------------------------------------------
-- return statement
--------------------------------------------------------------------------------
describe("return", function()
  it("simple", function()
    assert.parse_ast(euluna_parser, "return",
      AST('Block', {
        AST('Stat_Return', {})
    }))
  end)
  it("with semicolon", function()
    assert.parse_ast(euluna_parser, "return;",
      AST('Block', {
        AST('Stat_Return', {})
    }))
  end)
  it("with value", function()
    assert.parse_ast(euluna_parser, "return 0",
      AST('Block', {
        AST('Stat_Return', {
          AST('Number', 'int', '0')
    })}))
  end)
  it("with multiple values", function()
    assert.parse_ast(euluna_parser, "return 1,2,3",
      AST('Block', {
        AST('Stat_Return', {
          AST('Number', 'int', '1'),
          AST('Number', 'int', '2'),
          AST('Number', 'int', '3'),
    })}))
  end)
end)

--------------------------------------------------------------------------------
-- expressions
--------------------------------------------------------------------------------
describe("expression", function()
  it("number", function()
    assert.parse_ast(euluna_parser, "return 3.34e-50",
      AST('Block', {
        AST('Stat_Return', {
          AST('Number', 'exp', '3.34', '-50'),
    })}))
  end)
  it("string", function()
    assert.parse_ast(euluna_parser, [[return 'hi', "there"]],
      AST('Block', {
        AST('Stat_Return', {
          AST('String', 'hi'),
          AST('String', 'there')
    })}))
  end)
  it("boolean", function()
    assert.parse_ast(euluna_parser, "return true, false",
      AST('Block', {
        AST('Stat_Return', {
          AST('Boolean', true),
          AST('Boolean', false)
    })}))
  end)
  it("nil", function()
    assert.parse_ast(euluna_parser, "return nil",
      AST('Block', {
        AST('Stat_Return', {
          AST('Nil'),
    })}))
  end)
  it("varargs", function()
    assert.parse_ast(euluna_parser, "return ...",
      AST('Block', {
        AST('Stat_Return', {
          AST('Varargs'),
    })}))
  end)
  it("identifier", function()
    assert.parse_ast(euluna_parser, "return a, _b",
      AST('Block', {
        AST('Stat_Return', {
          AST('Id', 'a'),
          AST('Id', '_b'),
    })}))
  end)
  it("surrounded", function()
    assert.parse_ast(euluna_parser, "return (a)",
      AST('Block', {
        AST('Stat_Return', {
          AST('Id', 'a'),
    })}))
  end)
  it("dot index", function()
    assert.parse_ast(euluna_parser, "return a.b, a.b.c",
      AST('Block', {
        AST('Stat_Return', {
          AST('DotIndex', 'b',
            AST('Id', 'a')
          ),
          AST('DotIndex', 'c',
            AST('DotIndex', 'b',
              AST('Id', 'a')
          ))
    })}))
  end)
  it("array index", function()
    assert.parse_ast(euluna_parser, "return a[b], a[b][c]",
      AST('Block', {
        AST('Stat_Return', {
          AST('ArrayIndex',
            AST('Id', 'b'),
            AST('Id', 'a')
          ),
          AST('ArrayIndex',
            AST('Id', 'c'),
            AST('ArrayIndex',
              AST('Id', 'b'),
              AST('Id', 'a')
          ))
    })}))
  end)
end)

--------------------------------------------------------------------------------
-- operators
--------------------------------------------------------------------------------
describe("operator", function()
  it("'or'", function()
    assert.parse_ast(euluna_parser, "return a or b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'or', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'and'", function()
    assert.parse_ast(euluna_parser, "return a and b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'and', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'<'", function()
    assert.parse_ast(euluna_parser, "return a < b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'lt', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'>'", function()
    assert.parse_ast(euluna_parser, "return a > b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'gt', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'<='", function()
    assert.parse_ast(euluna_parser, "return a <= b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'le', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'>='", function()
    assert.parse_ast(euluna_parser, "return a >= b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'ge', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'~='", function()
    assert.parse_ast(euluna_parser, "return a ~= b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'ne', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'=='", function()
    assert.parse_ast(euluna_parser, "return a == b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'eq', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'|'", function()
    assert.parse_ast(euluna_parser, "return a | b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'bor', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'~'", function()
    assert.parse_ast(euluna_parser, "return a ~ b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'bxor', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'&'", function()
    assert.parse_ast(euluna_parser, "return a & b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'band', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'<<'", function()
    assert.parse_ast(euluna_parser, "return a << b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'shl', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'>>'", function()
    assert.parse_ast(euluna_parser, "return a >> b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'shr', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'..'", function()
    assert.parse_ast(euluna_parser, "return a .. b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'concat', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'+'", function()
    assert.parse_ast(euluna_parser, "return a + b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'add', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'-'", function()
    assert.parse_ast(euluna_parser, "return a - b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'sub', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'*'", function()
    assert.parse_ast(euluna_parser, "return a * b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'mul', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'/'", function()
    assert.parse_ast(euluna_parser, "return a / b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'div', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'%'", function()
    assert.parse_ast(euluna_parser, "return a % b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'mod', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("'not'", function()
    assert.parse_ast(euluna_parser, "return not a",
      AST('Block', {
        AST('Stat_Return', {
          AST('UnaryOp', 'not', AST('Id', 'a')
    )})}))
  end)
  it("'#'", function()
    assert.parse_ast(euluna_parser, "return #a",
      AST('Block', {
        AST('Stat_Return', {
          AST('UnaryOp', 'len', AST('Id', 'a')
    )})}))
  end)
  it("'-'", function()
    assert.parse_ast(euluna_parser, "return -a",
      AST('Block', {
        AST('Stat_Return', {
          AST('UnaryOp', 'neg', AST('Id', 'a')
    )})}))
  end)
  it("'~'", function()
    assert.parse_ast(euluna_parser, "return ~a",
      AST('Block', {
        AST('Stat_Return', {
          AST('UnaryOp', 'bnot', AST('Id', 'a')
    )})}))
  end)
  it("'^'", function()
    assert.parse_ast(euluna_parser, "return a ^ b",
      AST('Block', {
        AST('Stat_Return', {
          AST('BinaryOp', 'pow', AST('Id', 'a'), AST('Id', 'b')
    )})}))
  end)
  it("ternary if", function()
    assert.parse_ast(euluna_parser, "return a if c else b",
      AST('Block', {
        AST('Stat_Return', {
          AST('TernaryOp', 'if', AST('Id', 'a'), AST('Id', 'c'), AST('Id', 'b')
    )})}))
  end)
end)

--------------------------------------------------------------------------------
-- operators precedence rules
--------------------------------------------------------------------------------
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
describe("operators following precedence rules for", function()
  --TODO
end)

--------------------------------------------------------------------------------
-- live grammar change
--------------------------------------------------------------------------------
describe("live grammar change for", function()
  it("return keyword", function()
    euluna_parser:add_keyword("do_return")
    euluna_parser:set_pegs([[
      %stat_return <-
        ({} %DO_RETURN -> 'Stat_Return' {| (%expr (%COMMA %expr)*)? |} %SEMICOLON?) -> to_astnode
    ]])
    euluna_parser:remove_keyword("return")

    assert.parse_ast(euluna_parser, "do_return",
      AST('Block', {
        AST('Stat_Return', {})}))
    assert.parse_ast_error(euluna_parser, "return", 'UnexpectedSyntaxAtEOF')
  end)

  it("return keyword (revert)", function()
    euluna_parser:add_keyword("return")
    euluna_parser:set_pegs([[
      %stat_return <-
        ({} %RETURN -> 'Stat_Return' {| (%expr (%COMMA %expr)*)? |} %SEMICOLON?) -> to_astnode
    ]])
    euluna_parser:remove_keyword("do_return")

    assert.parse_ast(euluna_parser, "return",
      AST('Block', {
        AST('Stat_Return', {})}))
    assert.parse_ast_error(euluna_parser, "do_return", 'UnexpectedSyntaxAtEOF')
  end)
end)

end)
