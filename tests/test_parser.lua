require 'tests/testcommon'
require 'busted.runner'()

describe("Euluna parser", function()
  describe("should do basic parsing", function()
    it("for empty file", function()
      assert_parse([[]], {tag="TopBlock"})
    end)
    it("for invalid statement", function()
      assert_parse_error([[asdasd]], 'ExpectedEOF')
    end)
  end)

  it("should parse shebang", function()
    assert_parse([[#!/usr/bin/env lua]], {tag="TopBlock"})
    assert_parse([[#!/usr/bin/env lua\n]], {tag="TopBlock"})
  end)

  describe("should parse comment", function()
    it("combination", function()
      assert_parse([=[
        -- line comment
        --[[
          multiline comment
        ]]
      ]=], {tag="TopBlock"})
    end)
  end)

  describe("should parse return", function()
    it("empty", function()
      assert_parse("return",
        { tag = 'TopBlock',
          { tag = 'Return' }
        }
      )
    end)

    -- return with semiclon
    it("with semiclon", function()
      assert_parse("return;",
        { tag = 'TopBlock',
          { tag = 'Return' }
        }
      )
    end)

    it("with value", function()
      assert_parse("return 0",
        { tag = 'TopBlock',
          { tag = 'Return',
            { tag='number', type='integer', value="0" }
          }
        }
      )
    end)

    --[[
    it("with multiple values", function()
      assert_parse("return 1,2,3",
      )
    end)
    ]]
  end)

  describe("should parse expression", function()
    it("number", function()
      assert_parse("return 3.34e-50",
        { tag = 'TopBlock',
          { tag = 'Return',
            { tag='number', type='exponential', value="3.34e-50" }
          }
        }
      )
    end)

    it("string", function()
      assert_parse("return 'mystr'",
        { tag = 'TopBlock',
          { tag = 'Return',
            { tag='string', value="mystr" }
          }
        }
      )
    end)

    it("boolean", function()
      assert_parse("return true",
        { tag = 'TopBlock',
          { tag = 'Return',
            { tag='boolean', value=true }
          }
        }
      )
      assert_parse("return false",
        { tag = 'TopBlock',
          { tag = 'Return',
            { tag='boolean', value=false }
          }
        }
      )
    end)

    it("Nil", function()
      assert_parse("return nil",
        { tag = 'TopBlock',
          { tag = 'Return',
            { tag = 'Nil' }
          }
        }
      )
    end)

    it("table", function()
      assert_parse("return {}",
        { tag = 'TopBlock',
          { tag = 'Return',
            { tag = 'Table' }
          }
        }
      )
    end)

    it("ellipsis", function()
      assert_parse("return ...",
        { tag = 'TopBlock',
          { tag = 'Return',
            { tag = 'Ellipsis' }
          }
        }
      )
    end)

    it("dot index", function()
      assert_parse("return os.time",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'DotIndex',
              {
                tag = 'Id',
                'os'
              },
              'time'
            }
          }
        }
      )
    end)

    it("array index", function()
      assert_parse("return os[1]",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'ArrayIndex',
              {
                tag = 'Id',
                'os',
              },
              {
                tag = 'number',
                type = 'integer',
                value = '1'
              },
            }
          }
        }
      )
    end)

    it("global call", function()
      assert_parse("return os()",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'Call',
              {
                tag = 'Id',
                'os',
              },
              {}
            }
          }
        }
      )
    end)

    it("global call with arguments", function()
      assert_parse("return os(a,nil,true,'mystr',1.0,func(),...)",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'Call',
              {
                tag = 'Id',
                'os'
              },
              {
                {tag="Id", 'a'},
                {tag="Nil"},
                {tag="boolean", value=true},
                {tag="string", value='mystr'},
                {tag="number", type='decimal', value='1.0'},
                {tag='Call', {tag="Id", 'func'}, {}},
                {tag="Ellipsis"},
              }
            }
          }
        }
      )
    end)

    it("field call", function()
      assert_parse("return os.time()",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'Call',
              {
                tag = 'DotIndex',
                {
                  tag = 'Id',
                  'os'
                },
                'time'
              },
              {}
            }
          }
        }
      )
    end)

    it("method call", function()
      assert_parse("return os:time()",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'Invoke',
              {
                tag = 'Id',
                'os',
              },
              'time',
              {}
            }
          }
        }
      )
    end)

    it("parethesis", function()
      assert_parse("return (0)",
        { tag = 'TopBlock',
          { tag = 'Return',
            { tag='number', type='integer', value="0" }
          }
        }
      )
    end)

    it("simple binary operation", function()
      assert_parse("return 1 + 2",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'BinaryOp',
              "add",
              {tag='number', type='integer', value="1"},
              {tag='number', type='integer', value="2"}
            }
          }
        }
      )
    end)

    it("simple unary operation", function()
      assert_parse("return -1",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'UnaryOp',
              "neg",
              {tag='number', type='integer', value="1"},
            }
          }
        }
      )
    end)
  end)

  describe("should parse table", function()
    it("empty", function()
      assert_parse("return {}",
        { tag = 'TopBlock',
          { tag = 'Return',
            { tag = 'Table' }
          }
        }
      )
    end)

    it("with one value", function()
      assert_parse("return {1}",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'Table',
              {tag='number', type='integer', value='1'} }
              } } )
    end)

    it("with one field", function()
      assert_parse("return {a=1}",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'Table',
              { tag='Pair',
                'a',
                {tag='number', type='integer', value='1' }
              } } } } )
    end)

    it("with multiple values", function()
      assert_parse("return {1,2,3}",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'Table',
              {tag='number', type='integer', value='1'},
              {tag='number', type='integer', value='2'},
              {tag='number', type='integer', value='3'}
              } } } )
    end)

    it("with multiple fields", function()
      assert_parse([[return {
        a=a, [a]=a, [nil]=nil, [true]=true,
        ['mystr']='mystr', [1.0]=1.0, [func()]=func(),
        [...]=...
      }]],
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'Table',
              { tag='Pair',
                'a',
                {tag="Id", 'a'} },
              { tag='Pair',
                {tag="Id", 'a'},
                {tag="Id", 'a'} },
              { tag='Pair',
                {tag="Nil"},
                {tag="Nil"} },
              { tag='Pair',
                {tag="boolean", value=true},
                {tag="boolean", value=true} },
              { tag='Pair',
                {tag="string", value='mystr'},
                {tag="string", value='mystr'} },
              { tag='Pair',
                {tag="number", type='decimal', value='1.0'},
                {tag="number", type='decimal', value='1.0'} },
              { tag='Pair',
                {tag='Call', {tag="Id", 'func'}, {}},
                {tag='Call', {tag="Id", 'func'}, {}} },
              { tag='Pair',
                {tag="Ellipsis"},
                {tag="Ellipsis"} }
              } } } )
    end)

    it("with multiple values", function()
      assert_parse("return {a,nil,true,'mystr',1.0,func(),...}",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'Table',
              {tag="Id", 'a'},
              {tag="Nil"},
              {tag="boolean", value=true},
              {tag="string", value='mystr'},
              {tag="number", type='decimal', value='1.0'},
              {tag='Call', {tag="Id", 'func'}, {}},
              {tag="Ellipsis"},
              } } } )
    end)

    it("nested", function()
      assert_parse("return {{}}",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'Table',
                { tag = 'Table' }
              } } } )
    end)
  end)

  describe("should parse anonymous function", function()
    it("simple", function()
      assert_parse("return function() end",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'Function',
              {},
              { tag='block' }
            }
          }
        }
      )
    end)

    it("with one argument and one return", function()
      assert_parse("return function(a) return a+1 end",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'Function',
              {'a'},
              {
                tag='block',
                { tag = 'Return',
                  {
                    tag = 'BinaryOp',
                    "add",
                    {tag='Id', "a"},
                    {tag='number', type='integer', value="1"}
                  }
                }
              }
            }
          }
        }
      )
    end)
  end)

  describe("should parse function call", function()
    it("simple", function()
      assert_parse("os()",
        { tag = 'TopBlock',
          { tag = 'Call',
            {
              tag = 'Id',
              'os'
            },
            {}
          }
        }
      )
    end)

    it("dot index", function()
      assert_parse("os.time()",
        { tag = 'TopBlock',
          { tag = 'Call',
            {
              tag = 'DotIndex',
              {
                tag = 'Id',
                'os',
              },
              'time'
            },
            {}
          }
        }
      )
    end)

    it("method", function()
      assert_parse("os:time()",
        { tag = 'TopBlock',
          { tag = 'Invoke',
            {
              tag = 'Id',
              'os',
            },
            'time',
            {}
          }
        }
      )
    end)

    it("array index", function()
      assert_parse("os[1]()",
        { tag = 'TopBlock',
          { tag = 'Call',
            {
              tag = 'ArrayIndex',
              {
                tag = 'Id',
                'os',
              },
              {
                tag = 'number',
                type = 'integer',
                value = '1',
              }
            },
            {}
          }
        }
      )
    end)

    it("chain", function()
      assert_parse("a.f().b.g()",
        { tag = 'TopBlock',
          { tag = 'Call',
            {
              tag = 'DotIndex',
              {
                tag = 'DotIndex',
                {
                  tag = 'Call',
                  {
                    tag = 'DotIndex',
                    {
                      tag = 'Id',
                      'a'
                    },
                    'f'
                  },
                  {}
                },
                'b'
              },
              'g'
            },
            {}
          }
        }
      )
    end)
  end)

  describe("should parse assignment", function()
    it("for simple variable", function()
      assert_parse("a = 1",
        { tag = 'TopBlock',
          { tag = 'Assign',
            {
              {tag='Id', 'a'}
            },
            {
              {tag='number', type='integer', value='1'}
            }
          }
        }
      )
    end)

    it("for multiple variables", function()
      assert_parse("a, b = 1, 2",
        { tag = 'TopBlock',
          { tag = 'Assign',
            {
              {tag='Id', 'a'},
              {tag='Id', 'b'}
            },
            {
              {tag='number', type='integer', value='1'},
              {tag='number', type='integer', value='2'}
            }
          }
        }
      )
    end)

    it("with expressions", function()
      assert_parse("a, b = f(1), 1+2",
        { tag = 'TopBlock',
          { tag = 'Assign',
            {
              {tag='Id', 'a'},
              {tag='Id', 'b'}
            },
            {
              { tag='Call',
                {tag='Id', 'f'},
                {{tag='number', type='integer', value='1'}} },
              { tag='BinaryOp',
                'add',
                {tag='number', type='integer', value='1'},
                {tag='number', type='integer', value='2'} }
            }
          }
        }
      )
    end)

    it("on simple expression", function()
      assert_parse("a.b = 1",
        { tag = 'TopBlock',
          { tag = 'Assign',
            {
              { tag='DotIndex',
                {tag='Id', 'a'},
                'b',
              }
            },
            {
              {tag='number', type='integer', value='1'}
            }
          }
        }
      )
    end)

    it("on multiple expressions", function()
      assert_parse("a[1], (f(1)).b, c = 1, 2, 3",
        { tag = 'TopBlock',
          { tag = 'Assign',
            {
              { tag='ArrayIndex',
                {tag='Id', 'a'},
                {tag='number', type='integer', value='1'}
              },
              { tag='DotIndex',
                {
                  tag='Call',
                  {tag='Id', 'f'},
                  {{tag='number', type='integer', value='1'}}
                },
                'b',
              },
              {tag='Id', 'c'}
            },
            {
              {tag='number', type='integer', value='1'},
              {tag='number', type='integer', value='2'},
              {tag='number', type='integer', value='3'},
            }
          }
        }
      )
    end)
  end)

  describe("should parse declaration for", function()
    it("local variable", function()
      assert_parse("local a",
        { tag = "TopBlock",
          { tag = "VarDecl",
            {"local", 'var'},
            { "a" }
          }
        }
      )
    end)

    it("multiple local variables", function()
      assert_parse("local a, b",
        { tag = "TopBlock",
          { tag = "VarDecl",
            {"local", 'var'},
            { "a", "b" }
          }
        }
      )
    end)
  end)

  describe("should parse definition for", function()
    it("local variable", function()
      assert_parse("local a = 1",
        { tag = 'TopBlock',
          { tag = 'VarDecl',
            { 'local', 'var' },
            { 'a' },
            {{tag='number', type='integer', value='1'}}
          }
        }
      )
    end)

    it("multiple local variables", function()
      assert_parse("local a, b = 1, 'str'",
        { tag = 'TopBlock',
          { tag = 'VarDecl',
            { 'local', 'var' },
            { 'a', 'b' },
            {
              {tag='number', type='integer', value='1'},
              {tag='string', value='str'}
            }
          }
        }
      )
    end)

    it("for local function with assign", function()
      assert_parse("local a = function() end",
        { tag = 'TopBlock',
          { tag = 'VarDecl',
            {'local', 'var'},
            { 'a' },
            {
              { tag = "Function",
                {},
                {tag = "block"}
              }
            }
          }
        }
      )
    end)

    it("for local function", function()
      assert_parse("local function a() end",
        { tag = 'TopBlock',
          { tag = 'FunctionDef',
            'local',
            'a',
            {},
            {tag = "block"}
          }
        }
      )
    end)
  end)

  describe("should parse if statement", function()
    it("simple", function()
      assert_parse("if true then end",
        { tag = 'TopBlock',
          { tag = 'If',
            {
              { {tag='boolean', value=true}, {tag='block'} }
            }
          }
        }
      )
    end)

    it("with multiple parts", function()
      assert_parse("if a then x=1 elseif b then x=2 else x=3 end",
        { tag = "TopBlock",
          { tag = "If",
            {
              { { tag = "Id",
                  "a"
                },
                { tag = "block",
                  { tag = "Assign",
                    {{tag = "Id", "x"}},
                    {{tag = "number", type = "integer", value = "1"}}
                } }
              },
              { { tag = "Id",
                  "b"
                },
                { tag = "block",
                  { tag = "Assign",
                    {{tag = "Id", "x"}},
                    {{tag = "number", type = "integer", value = "2"}}
                } }
              }
            },
            { tag = "block",
              { tag = "Assign",
                {{ tag = "Id", "x"}},
                {{tag = "number", type = "integer", value = "3"}}
            } }
          },
        }
      )
    end)
  end)

  describe("should parse switch statement", function()
    it("simple", function()
      assert_parse("switch a case true then end",
        { tag = 'TopBlock',
          { tag = 'Switch',
            {tag='Id', 'a'},
            {
              {{tag='boolean', value=true}, {tag='block'} }
            }
          }
        }
      )
    end)
    it("mutiple cases and else", function()
      assert_parse("switch a case true then case false then else end",
        { tag = 'TopBlock',
          { tag = 'Switch',
            {tag='Id', 'a'},
            {
              {{tag='boolean', value=true}, {tag='block'}},
              {{tag='boolean', value=false}, {tag='block'}}
            },
            {tag='block'}
          }
        }
      )
    end)
  end)

  describe("should parse try statement", function()
    it("simple", function()
      assert_parse("try end",
        { tag = 'TopBlock',
          { tag = 'Try',
            { tag = 'block' },
            {}
          }
        }
      )
    end)

    it("with catch all", function()
      assert_parse("try catch end",
        { tag = 'TopBlock',
          { tag = 'Try',
            { tag = 'block' },
            {},
            { tag = 'block' },
          }
        }
      )
    end)

    it("with finally", function()
      assert_parse("try finally end",
        { tag = 'TopBlock',
          { tag = 'Try',
            { tag = 'block' },
            {},
            nil,
            { tag = 'block' },
          }
        }
      )
    end)

    it("with all catche, catch all and finally", function()
      assert_parse("try catch(e) catch finally end",
        { tag = 'TopBlock',
          { tag = 'Try',
            { tag = 'block' },
            { {'e', { tag = 'block' }} },
            { tag = 'block' },
            { tag = 'block' },
          }
        }
      )
    end)
  end)

  describe("should parse throw statement", function()
    it("with all catche, catch all and finally", function()
      assert_parse("throw 'hello'",
        { tag = 'TopBlock',
          { tag = 'Throw',
            {tag = 'string', value = 'hello'}
          }
        }
      )
    end)
  end)

  describe("should parse for statement", function()
    it("simple", function()
      assert_parse("for i=1,10 do end",
        { tag = "TopBlock",
          { tag = "ForNum",
            "i",
            {
              tag = "number",
              type = "integer",
              value = "1"
            },
            'le',
            {
              tag = "number",
              type = "integer",
              value = "10"
            },
            nil,
            {
              tag = "block"
            },
          }
        }
      )
    end)

    it("reverse with comparations", function()
      assert_parse("for i=10,>0,-1 do end",
        { tag = "TopBlock",
          { tag = "ForNum",
            "i",
            {
              tag = "number",
              type = "integer",
              value = "10"
            },
            'gt',
            {
              tag = "number",
              type = "integer",
              value = "0"
            },
            {
              tag = 'UnaryOp',
              'neg',
              {
                tag = "number",
                type = "integer",
                value = "1"
              }
            },
            {
              tag = "block"
            },
          }
        }
      )
    end)
  end)

  describe("should parse while statement", function()
    it("simple", function()
      assert_parse("while true do end",
        { tag = "TopBlock",
          { tag = "While",
            {
              tag = 'boolean',
              value = true
            },
            { tag='block' }
          }
        }
      )
    end)

    it("with statments", function()
      assert_parse("while a==1 do print() end",
        { tag = "TopBlock",
          { tag = "While",
            {
              tag = "BinaryOp",
              "eq",
              { tag = "Id", "a" },
              { tag = "number", type = "integer", value = "1" }
            },
            {
              tag='block',
              { tag = "Call",
                { tag = "Id", "print" },
                {}
              }
            }
          }
        }
      )
    end)
  end)

  describe("should parse repeat statement", function()
    it("simple", function()
      assert_parse("repeat until true",
        { tag = "TopBlock",
          { tag = "Repeat",
            { tag='block' },
            { tag = 'boolean',
              value = true
            }
          }
        }
      )
    end)

    it("with statments", function()
      assert_parse("repeat print() until a==1",
        { tag = "TopBlock",
          { tag = "Repeat",
            {
              tag='block',
              { tag = "Call",
                { tag = "Id", "print" },
                {}
              }
            },
            {
              tag = "BinaryOp",
              "eq",
              { tag = "Id", "a" },
              { tag = "number", type = "integer", value = "1" }
            }
          }
        }
      )
    end)
  end)

  describe("should parse do statement", function()
    it("simple", function()
      assert_parse("do end",
        { tag = "TopBlock",
          { tag = "Do" }
        }
      )
    end)

    it("with statments", function()
      assert_parse("do print() end",
        { tag = "TopBlock",
          { tag = "Do",
            { tag = 'Call',
              {
                tag = 'Id',
                'print'
              },
              {}
            }
          }
        }
      )
    end)
  end)

  describe("should parse loop statement", function()
    it("break", function()
      assert_parse("while true do break end",
        { tag = "TopBlock",
          { tag = "While",
            {
              tag = 'boolean',
              value = true
            },
            {
              tag='block',
              {tag = 'Break'}
            }
          }
        }
      )
    end)

    it("continue", function()
      assert_parse("while true do continue end",
        { tag = "TopBlock",
          { tag = "While",
            {
              tag = 'boolean',
              value = true
            },
            {
              tag='block',
              {tag = 'Continue'}
            }
          }
        }
      )
    end)
  end)

  describe("should parse defer statement", function()
    it("simple", function()
      assert_parse("defer end",
        { tag = "TopBlock",
          { tag = "Defer" }
        }
      )
    end)
  end)

  describe("should parse goto statement", function()
    it("label", function()
      assert_parse("::mylabel::",
        { tag = "TopBlock",
          { tag = "Label", 'mylabel' }
        }
      )
    end)
    it("goto", function()
      assert_parse("goto mylabel",
        { tag = "TopBlock",
          { tag = "Goto", 'mylabel' }
        }
      )
    end)
  end)

  describe("should parse function statement", function()
    it("simple", function()
      assert_parse("function f() end",
        { tag = "TopBlock",
          { tag = "FunctionDef",
            nil,
            "f",
            {},
            {
              tag='block',
            }
          }
        }
      )
    end)
    it("local", function()
      assert_parse("local function f() end",
        { tag = "TopBlock",
          { tag = "FunctionDef",
            'local',
            "f",
            {},
            {
              tag='block',
            }
          }
        }
      )
    end)
  end)

  describe("should parse expression operators", function()
    it("for `or`", function() assert_parse("return a or b",
      { tag = 'TopBlock', { tag = 'Return', {
        tag = 'BinaryOp',
        'or',
        { tag = 'Id', 'a' },
        { tag = 'Id', 'b' }
    }}}) end)

    it("for `and`", function() assert_parse("return a and b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'and',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `<`", function() assert_parse("return a < b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'lt',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `>`", function() assert_parse("return a > b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'gt',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `<=`", function() assert_parse("return a <= b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'le',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `>=`", function() assert_parse("return a >= b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'ge',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `~=`", function() assert_parse("return a ~= b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'ne',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `==`", function() assert_parse("return a == b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'eq',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `|`", function() assert_parse("return a | b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'bor',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `~`", function() assert_parse("return a ~ b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'bxor',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `&`", function() assert_parse("return a & b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'band',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `<<`", function() assert_parse("return a << b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'shl',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `>>`", function() assert_parse("return a >> b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'shr',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `..`", function() assert_parse("return a .. b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'concat',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `+`", function() assert_parse("return a + b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'add',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `-`", function() assert_parse("return a - b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'sub',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `*`", function() assert_parse("return a * b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'mul',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `/`", function() assert_parse("return a / b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'div',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `%`", function() assert_parse("return a % b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'mod',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for `not`", function() assert_parse("return not a",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'UnaryOp',
          'not',
          { tag = 'Id', 'a' }
    }}}) end)

    it("for `#`", function() assert_parse("return # a",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'UnaryOp',
          'len',
          { tag = 'Id', 'a' }
    }}}) end)

    it("for `-`", function() assert_parse("return - a",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'UnaryOp',
          'neg',
          { tag = 'Id', 'a' }
    }}}) end)

    it("for `~`", function() assert_parse("return ~ a",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'UnaryOp',
          'bnot',
          { tag = 'Id', 'a' }
    }}}) end)

    it("for `^`", function() assert_parse("return a ^ b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'BinaryOp',
          'pow',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'b' }
    }}}) end)

    it("for terinary if", function() assert_parse("return a if c else b",
      { tag = 'TopBlock', { tag = 'Return', {
          tag = 'TernaryOp',
          'if',
          { tag = 'Id', 'a' },
          { tag = 'Id', 'c' },
          { tag = 'Id', 'b' }
    }}}) end)
  end)

  describe("should parse expression operators following precedence rules", function()
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
    it("for equivalent expressions", function()
      assert_equivalent_parse(
        "return a+i < b/2+1",
        "return (a+i) < ((b/2)+1)"
      )
      assert_equivalent_parse(
        "return 5+x^2*8",
        "return 5+((x^2)*8)"
      )
      assert_equivalent_parse(
        "return a < y and y <= z",
        "return (a < y) and (y <= z)"
      )
      assert_equivalent_parse(
        "return -x^2",
        "return -(x^2)"
      )
      assert_equivalent_parse(
        "return x^y^z",
        "return x^(y^z)"
      )
    end)

    it("for `and` and `or`", function()
      assert_parse("return a and b or c",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'BinaryOp',
              "or",
              {
                tag = 'BinaryOp',
                'and',
                { tag='Id', 'a'},
                { tag='Id', 'b'},
              },
              { tag = 'Id', 'c' }
            }
          }
        }
      )

      assert_parse("return a or b and c",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'BinaryOp',
              "or",
              { tag = 'Id', 'a' },
              {
                tag = 'BinaryOp',
                'and',
                { tag='Id', 'b'},
                { tag='Id', 'c'},
              }
            }
          }
        }
      )
    end)

    it("with forced priority", function()
      assert_parse("return a and (b or c)",
        { tag = 'TopBlock',
          { tag = 'Return',
            {
              tag = 'BinaryOp',
              "and",
              { tag = 'Id', 'a' },
              {
                tag = 'BinaryOp',
                'or',
                { tag='Id', 'b'},
                { tag='Id', 'c'},
              }
            }
          }
        }
      )
    end)

    it("respecting lua procedence rules", function()
      assert_parse("return a or b and c < d | e ~ f & g << h .. i + j * k ^ #l",
      { {
          {
            "or",
            {
              "a",
              tag = "Id"
            },
            {
              "and",
              {
                "b",
                tag = "Id"
              },
              {
                "lt",
                {
                  "c",
                  tag = "Id"
                },
                {
                  "bor",
                  {
                    "d",
                    tag = "Id"
                  },
                  {
                    "bxor",
                    {
                      "e",
                      tag = "Id"
                    },
                    {
                      "band",
                      {
                        "f",
                        tag = "Id"
                      },
                      {
                        "shl",
                        {
                          "g",
                          tag = "Id"
                        },
                        {
                          "concat",
                          {
                            "h",
                            tag = "Id"
                          },
                          {
                            "add",
                            {
                              "i",
                              tag = "Id"
                            },
                            {
                              "mul",
                              {
                                "j",
                                tag = "Id"
                              },
                              {
                                "pow",
                                {
                                  "k",
                                  tag = "Id"
                                },
                                {
                                  "len",
                                  {
                                    "l",
                                    tag = "Id"
                                  },
                                  tag = "UnaryOp"
                                },
                                tag = "BinaryOp"
                              },
                              tag = "BinaryOp"
                            },
                            tag = "BinaryOp"
                          },
                          tag = "BinaryOp"
                        },
                        tag = "BinaryOp"
                      },
                      tag = "BinaryOp"
                    },
                    tag = "BinaryOp"
                  },
                  tag = "BinaryOp"
                },
                tag = "BinaryOp"
              },
              tag = "BinaryOp"
            },
            tag = "BinaryOp"
          },
          tag = "Return"
        },
        tag = "TopBlock"
      })

      -- left associative
      assert_parse("return a + b + c",
      { {
          {
            "add",
            {
              "add",
              {
                "a",
                tag = "Id"
              },
              {
                "b",
                tag = "Id"
              },
              tag = "BinaryOp"
            },
            {
              "c",
              tag = "Id"
            },
            tag = "BinaryOp"
          },
          tag = "Return"
        },
        tag = "TopBlock"
      })

      -- right associative
      assert_parse("return a .. b .. c",
      { {
          {
            "concat",
            {
              "a",
              tag = "Id"
            },
            {
              "concat",
              {
                "b",
                tag = "Id"
              },
              {
                "c",
                tag = "Id"
              },
              tag = "BinaryOp"
            },
            tag = "BinaryOp"
          },
          tag = "Return"
        },
        tag = "TopBlock"
      })

      -- right associative
      assert_parse("return a ^ b ^ c",
      { {
          {
            "pow",
            {
              "a",
              tag = "Id"
            },
            {
              "pow",
              {
                "b",
                tag = "Id"
              },
              {
                "c",
                tag = "Id"
              },
              tag = "BinaryOp"
            },
            tag = "BinaryOp"
          },
          tag = "Return"
        },
        tag = "TopBlock"
      })
    end)
  end)
end)
