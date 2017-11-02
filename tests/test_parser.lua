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
            expr = { tag='number', type='integer', value="0" }
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
            expr = { tag='number', type='exponential', value="3.34e-50" }
          }
        }
      )
    end)

    it("string", function()
      assert_parse("return 'mystr'",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = { tag='string', value="mystr" }
          }
        }
      )
    end)

    it("boolean", function()
      assert_parse("return true",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = { tag='boolean', value=true }
          }
        }
      )
    end)

    it("nil", function()
      assert_parse("return nil",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = { tag = 'nil' }
          }
        }
      )
    end)

    it("table", function()
      assert_parse("return {}",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = { tag = 'Table', fields={} }
          }
        }
      )
    end)

    it("ellipsis", function()
      assert_parse("return ...",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = { tag = 'ellipsis' }
          }
        }
      )
    end)

    it("dot index", function()
      assert_parse("return os.time",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'DotIndex',
              index = 'time',
              what = {
                tag = 'identifier',
                name = 'os'
              }
            }
          }
        }
      )
    end)

    it("array index", function()
      assert_parse("return os[1]",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'ArrayIndex',
              index = {
                tag = 'number',
                type = 'integer',
                value = '1'
              },
              what = {
                tag = 'identifier',
                name = 'os',
              }
            }
          }
        }
      )
    end)

    it("global call", function()
      assert_parse("return os()",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'Call',
              args = {},
              what = {
                tag = 'identifier',
                name = 'os',
              }
            }
          }
        }
      )
    end)

    it("global call with arguments", function()
      assert_parse("return os(a,nil,true,'mystr',1.0,func(),...)",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'Call',
              args = {
                {tag="identifier", name='a'},
                {tag="nil"},
                {tag="boolean", value=true},
                {tag="string", value='mystr'},
                {tag="number", type='decimal', value='1.0'},
                {tag='Call', args={}, what={tag="identifier", name='func'}},
                {tag="ellipsis"},
              },
              what = {
                tag = 'identifier',
                name = 'os'
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
            expr = {
              tag = 'Call',
              args = {},
              what = {
                tag = 'DotIndex',
                index = 'time',
                what = {
                  tag = 'identifier',
                  name = 'os'
                }
              }
            }
          }
        }
      )
    end)

    it("method call", function()
      assert_parse("return os:time()",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'Invoke',
              name = 'time',
              args = {},
              what = {
                tag = 'identifier',
                name = 'os',
              }
            }
          }
        }
      )
    end)

    it("parethesis", function()
      assert_parse("return (0)",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = { tag='number', type='integer', value="0" }
          }
        }
      )
    end)

    it("simple binary operation", function()
      assert_parse("return 1 + 2",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'BinaryOp',
              op = "add",
              lhs = {tag='number', type='integer', value="1"},
              rhs = {tag='number', type='integer', value="2"}
            }
          }
        }
      )
    end)

    it("simple unary operation", function()
      assert_parse("return -1",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'UnaryOp',
              op = "neg",
              expr = {tag='number', type='integer', value="1"},
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
            expr = { tag = 'Table', fields={} }
          }
        }
      )
    end)

    it("with one value", function()
      assert_parse("return {1}",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'Table', 
              fields ={
                {tag='number', type='integer', value='1'} }
              } } } )
    end)

    it("with one field", function()
      assert_parse("return {a=1}",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'Table',
              fields ={
                { tag='pair',
                  key='a',
                  expr={tag='number', type='integer', value='1' }
              } } } } } )
    end)

    it("with multiple values", function()
      assert_parse("return {1,2,3}",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'Table',
              fields ={
                {tag='number', type='integer', value='1'},
                {tag='number', type='integer', value='2'},
                {tag='number', type='integer', value='3'}
              } } } } )
    end)

    it("with multiple fields", function()
      assert_parse([[return {
        a=a, [a]=a, [nil]=nil, [true]=true,
        ['mystr']='mystr', [1.0]=1.0, [func()]=func(),
        [...]=...
      }]],
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'Table',
              fields ={
                { tag='pair',
                  key='a',
                  expr={tag="identifier", name='a'} },
                { tag='pair',
                  key={tag="identifier", name='a'},
                  expr={tag="identifier", name='a'} },
                { tag='pair',
                  key={tag="nil"},
                  expr={tag="nil"} },
                { tag='pair',
                  key={tag="boolean", value=true},
                  expr={tag="boolean", value=true} },
                { tag='pair',
                  key={tag="string", value='mystr'},
                  expr={tag="string", value='mystr'} },
                { tag='pair',
                  key={tag="number", type='decimal', value='1.0'},
                  expr={tag="number", type='decimal', value='1.0'} },
                { tag='pair',
                  key={tag='Call', args={}, what={tag="identifier", name='func'}},
                  expr={tag='Call', args={}, what={tag="identifier", name='func'}} },
                { tag='pair',
                  key={tag="ellipsis"},
                  expr={tag="ellipsis"} }
              } } } } )
    end)

    it("with multiple values", function()
      assert_parse("return {a,nil,true,'mystr',1.0,func(),...}",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'Table',
              fields ={
                {tag="identifier", name='a'},
                {tag="nil"},
                {tag="boolean", value=true},
                {tag="string", value='mystr'},
                {tag="number", type='decimal', value='1.0'},
                {tag='Call', args={}, what={tag="identifier", name='func'}},
                {tag="ellipsis"},
              } } } } )
    end)

    it("nested", function()
      assert_parse("return {{}}",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'Table',
              fields ={
                { tag = 'Table', fields={} }
              } } } } )
    end)
  end)

  describe("should parse anonymous function", function()
    it("simple", function()
      assert_parse("return function() end",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'Function',
              args = {},
              body = { tag='block' }
            }
          }
        }
      )
    end)

    it("with one argument and one return", function()
      assert_parse("return function(a) return a+1 end",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'Function',
              args = {
                {tag="identifier", name='a'}
              },
              body = {
                tag='block',
                { tag = 'Return',
                  expr = {
                    tag = 'BinaryOp',
                    op = "add",
                    lhs = {tag='identifier', name="a"},
                    rhs = {tag='number', type='integer', value="1"}
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
            args = {},
            what = {
              tag = 'identifier',
              name = 'os'
            }
          }
        }
      )
    end)

    it("dot index", function()
      assert_parse("os.time()",
        { tag = 'TopBlock',
          { tag = 'Call',
            args = {},
            what = {
              tag = 'DotIndex',
              index = 'time',
              what = {
                tag = 'identifier',
                name = 'os',
              }
            }
          }
        }
      )
    end)

    it("method", function()
      assert_parse("os:time()",
        { tag = 'TopBlock',
          { tag = 'Invoke',
            name = 'time',
            args = {},
            what = {
              tag = 'identifier',
              name = 'os',
            }
          }
        }
      )
    end)

    it("array index", function()
      assert_parse("os[1]()",
        { tag = 'TopBlock',
          { tag = 'Call',
            args = {},
            what = {
              tag = 'ArrayIndex',
              index = {
                tag = 'number',
                type = 'integer',
                value = '1',
              },
              what = {
                tag = 'identifier',
                name = 'os',
              }
            }
          }
        }
      )
    end)

    it("chain", function()
      assert_parse("a.f().b.g()",
        { tag = 'TopBlock',
          { tag = 'Call',
            args = {},
            what = {
              tag = 'DotIndex',
              index = 'g',
              what = {
                tag = 'DotIndex',
                index = 'b',
                what = {
                  tag = 'Call',
                  args = {},
                  what = {
                    tag = 'DotIndex',
                    index = 'f',
                    what = {
                      tag = 'identifier',
                      name = 'a'
                    }
                  }
                }
              }
            }
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
            vars = {
              {tag='identifier', name='a'}
            },
            assigns = {
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
            vars = {
              {tag='identifier', name='a'},
              {tag='identifier', name='b'}
            },
            assigns = {
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
            vars = {
              {tag='identifier', name='a'},
              {tag='identifier', name='b'}
            },
            assigns = {
              { tag='Call',
                what={tag='identifier', name='f'},
                args={{tag='number', type='integer', value='1'}} },
              { tag='BinaryOp',
                op='add',
                lhs={tag='number', type='integer', value='1'},
                rhs={tag='number', type='integer', value='2'} }
            }
          }
        }
      )
    end)

    it("on simple expression", function()
      assert_parse("a.b = 1",
        { tag = 'TopBlock',
          { tag = 'Assign',
            vars = {
              { tag='DotIndex',
                index='b',
                what = {tag='identifier', name='a'}
              }
            },
            assigns = {
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
            vars = {
              { tag='ArrayIndex',
                index= {tag='number', type='integer', value='1'},
                what = {tag='identifier', name='a'}
              },
              { tag='DotIndex',
                index='b',
                what = {
                  tag='Call',
                  what={tag='identifier', name='f'},
                  args={{tag='number', type='integer', value='1'}}
                }
              },
              {tag='identifier', name='c'}
            },
            assigns = {
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
          { tag = "Decl",
            vars = { "a" },
            vartype = "local"
          }
        }
      )
    end)

    it("multiple local variables", function()
      assert_parse("local a, b",
        { tag = "TopBlock",
          { tag = "Decl",
            vars = { "a", "b" },
            vartype = "local"
          }
        }
      )
    end)
  end)

  describe("should parse definition for", function()
    it("local variable", function()
      assert_parse("local a = 1",
        { tag = 'TopBlock',
          { tag = 'AssignDef',
            vartype = 'local',
            vars = {
              'a'
            },
            assigns = {
              {tag='number', type='integer', value='1'}
            }
          }
        }
      )
    end)

    it("multiple local variables", function()
      assert_parse("local a, b = 1, 'str'",
        { tag = 'TopBlock',
          { tag = 'AssignDef',
            vartype = 'local',
            vars = { 'a', 'b' },
            assigns = {
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
          { tag = 'AssignDef',
            vartype = 'local',
            vars = { 'a' },
            assigns = {
              { tag = "Function",
                args = {},
                body = {tag = "block"}
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
            name ='a',
            vartype = 'local',
            args = {},
            body = {tag = "block"}
          }
        }
      )
    end)
  end)

  describe("should parse if statements", function()
    it("simple", function()
      assert_parse("if true then end",
        { tag = 'TopBlock',
          { tag = 'If',
            ifs = {
              { cond={tag='boolean', value=true}, block={tag='block'} }
            }
          }
        }
      )
    end)

    it("with multiple parts", function()
      assert_parse("if a then x=1 elseif b then x=2 else x=3 end",
        { tag = "TopBlock",
          { tag = "If",
            ifs = {
              { cond = {
                  tag = "identifier",
                  name = "a"
                },
                block = {
                  tag = "block",
                  { tag = "Assign",
                    assigns = {{tag = "number", type = "integer", value = "1"}},
                    vars = {{tag = "identifier", name = "x"}}
                } }
              },
              { cond = {
                  tag = "identifier",
                  name = "b"
                },
                block = {
                  tag = "block",
                  { assigns = {{tag = "number", type = "integer", value = "2"}},
                    tag = "Assign",
                    vars = { {tag = "identifier", name = "x"} }
                } }
              }
            },
            elseblock = {
              tag = "block",
              {  assigns = {{tag = "number", type = "integer", value = "3"}},
                tag = "Assign",
                vars = { { tag = "identifier", name = "x"} }
            } }
          },
        }
      )
    end)
  end)

  describe("should parse for statements", function()
    it("simple", function()
      assert_parse("for i=1,10 do end",
        { tag = "TopBlock",
          { tag = "ForNum",
            id = {
              tag = "identifier",
              name = "i"
            },
            begin_expr = {
              tag = "number",
              type = "integer",
              value = "1"
            },
            cmp_op = 'le',
            end_expr = {
              tag = "number",
              type = "integer",
              value = "10"
            },
            add_expr = nil,
            block = {
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
            id = {
              tag = "identifier",
              name = "i"
            },
            begin_expr = {
              tag = "number",
              type = "integer",
              value = "10"
            },
            cmp_op = 'gt',
            end_expr = {
              tag = "number",
              type = "integer",
              value = "0"
            },
            add_expr = {
              tag = 'UnaryOp',
              op = 'neg',
              expr = {
                tag = "number",
                type = "integer",
                value = "1"
              }
            },
            block = {
              tag = "block"
            },
          }
        }
      )
    end)
  end)

  describe("should parse expression operators", function()
    it("for `or`", function() assert_parse("return a or b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
        tag = 'BinaryOp',
        op = 'or',
        lhs = { tag = 'identifier', name='a' },
        rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `and`", function() assert_parse("return a and b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'and',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `<`", function() assert_parse("return a < b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'lt',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `>`", function() assert_parse("return a > b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'gt',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `<=`", function() assert_parse("return a <= b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'le',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `>=`", function() assert_parse("return a >= b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'ge',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `~=`", function() assert_parse("return a ~= b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'ne',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `==`", function() assert_parse("return a == b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'eq',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `|`", function() assert_parse("return a | b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'bor',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `~`", function() assert_parse("return a ~ b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'bxor',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `&`", function() assert_parse("return a & b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'band',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `<<`", function() assert_parse("return a << b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'shl',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `>>`", function() assert_parse("return a >> b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'shr',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `..`", function() assert_parse("return a .. b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'concat',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `+`", function() assert_parse("return a + b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'add',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `-`", function() assert_parse("return a - b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'sub',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `*`", function() assert_parse("return a * b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'mul',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `/`", function() assert_parse("return a / b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'div',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `//`", function() assert_parse("return a // b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'idiv',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `%`", function() assert_parse("return a % b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'mod',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
    }}}) end)

    it("for `not`", function() assert_parse("return not a",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'UnaryOp',
          op = 'not',
          expr = { tag = 'identifier', name='a' }
    }}}) end)

    it("for `#`", function() assert_parse("return # a",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'UnaryOp',
          op = 'len',
          expr = { tag = 'identifier', name='a' }
    }}}) end)

    it("for `-`", function() assert_parse("return - a",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'UnaryOp',
          op = 'neg',
          expr = { tag = 'identifier', name='a' }
    }}}) end)

    it("for `~`", function() assert_parse("return ~ a",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'UnaryOp',
          op = 'bnot',
          expr = { tag = 'identifier', name='a' }
    }}}) end)

    it("for `^`", function() assert_parse("return a ^ b",
      { tag = 'TopBlock', { tag = 'Return', expr = {
          tag = 'BinaryOp',
          op = 'pow',
          lhs = { tag = 'identifier', name='a' },
          rhs = { tag = 'identifier', name='b' }
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
            expr = {
              tag = 'BinaryOp',
              op = "or",
              lhs = {
                tag = 'BinaryOp',
                op = 'and',
                lhs = { tag='identifier', name='a'},
                rhs = { tag='identifier', name='b'},
              },
              rhs = { tag = 'identifier', name='c' }
            }
          }
        }
      )

      assert_parse("return a or b and c",
        { tag = 'TopBlock',
          { tag = 'Return',
            expr = {
              tag = 'BinaryOp',
              op = "or",
              lhs = { tag = 'identifier', name='a' },
              rhs = {
                tag = 'BinaryOp',
                op = 'and',
                lhs = { tag='identifier', name='b'},
                rhs = { tag='identifier', name='c'},
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
            expr = {
              tag = 'BinaryOp',
              op = "and",
              lhs = { tag = 'identifier', name='a' },
              rhs = {
                tag = 'BinaryOp',
                op = 'or',
                lhs = { tag='identifier', name='b'},
                rhs = { tag='identifier', name='c'},
              }
            }
          }
        }
      )
    end)

    it("respecting lua procedence rules", function()
      assert_parse("return a or b and c < d | e ~ f & g << h .. i + j * k ^ #l",
      { {
          expr = {
            lhs = {
              name = "a",
              tag = "identifier"
            },
            op = "or",
            rhs = {
              lhs = {
                name = "b",
                tag = "identifier"
              },
              op = "and",
              rhs = {
                lhs = {
                  name = "c",
                  tag = "identifier"
                },
                op = "lt",
                rhs = {
                  lhs = {
                    name = "d",
                    tag = "identifier"
                  },
                  op = "bor",
                  rhs = {
                    lhs = {
                      name = "e",
                      tag = "identifier"
                    },
                    op = "bxor",
                    rhs = {
                      lhs = {
                        name = "f",
                        tag = "identifier"
                      },
                      op = "band",
                      rhs = {
                        lhs = {
                          name = "g",
                          tag = "identifier"
                        },
                        op = "shl",
                        rhs = {
                          lhs = {
                            name = "h",
                            tag = "identifier"
                          },
                          op = "concat",
                          rhs = {
                            lhs = {
                              name = "i",
                              tag = "identifier"
                            },
                            op = "add",
                            rhs = {
                              lhs = {
                                name = "j",
                                tag = "identifier"
                              },
                              op = "mul",
                              rhs = {
                                lhs = {
                                  name = "k",
                                  tag = "identifier"
                                },
                                op = "pow",
                                rhs = {
                                  expr = {
                                    name = "l",
                                    tag = "identifier"
                                  },
                                  op = "len",
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
          expr = {
            lhs = {
              lhs = {
                name = "a",
                tag = "identifier"
              },
              op = "add",
              rhs = {
                name = "b",
                tag = "identifier"
              },
              tag = "BinaryOp"
            },
            op = "add",
            rhs = {
              name = "c",
              tag = "identifier"
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
          expr = {
            lhs = {
              name = "a",
              tag = "identifier"
            },
            op = "concat",
            rhs = {
              lhs = {
                name = "b",
                tag = "identifier"
              },
              op = "concat",
              rhs = {
                name = "c",
                tag = "identifier"
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
          expr = {
            lhs = {
              name = "a",
              tag = "identifier"
            },
            op = "pow",
            rhs = {
              lhs = {
                name = "b",
                tag = "identifier"
              },
              op = "pow",
              rhs = {
                name = "c",
                tag = "identifier"
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
