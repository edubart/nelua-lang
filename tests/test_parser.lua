require 'tests/testcommon'
require 'busted.runner'()

describe("euluna parser", function()
  it("Basic pasing", function()
    assert_parse([[]], {})
    assert_parse_error([[asdasd]], 'InvalidStatement')
  end)

  it("Shebang", function()
    assert_parse([[#!/usr/bin/env lua]], {})
    assert_parse([[#!/usr/bin/env lua\n]], {})
  end)

  it("Comments", function()
    assert_parse([=[
      -- line comment
      --[[
        multiline comment
      ]]
    ]=], {})
  end)

  it("Return", function()
    assert_parse("return",
      { tag = 'top_block',
        { tag = 'return_stat' }
      }
    )

    assert_parse("return;",
      { tag = 'top_block',
        { tag = 'return_stat' }
      }
    )

    assert_parse("return 0",
      { tag = 'top_block',
        { tag = 'return_stat',
          expr = { tag = 'number', value = "0" }
        }
      }
    )

    assert_parse("return ((0))",
      { tag = 'top_block',
        { tag = 'return_stat',
          expr = { tag = 'number', value = "0" }
        }
      }
    )

  end)

  it("Operators", function()
    assert_parse("return 1+2",
      { tag = 'top_block',
        { tag = 'return_stat',
          expr = {
            tag = 'binary_op',
            op = "add",
            lhs = {value="1"},
            rhs = {value="2"}
          }
        }
      }
    )
  end)

  it("Expressions operators precedence", function()
    assert_parse("return a and b or c",
      { tag = 'top_block',
        { tag = 'return_stat',
          expr = {
            tag = 'binary_op',
            op = "or",
            lhs = {
              tag = 'binary_op',
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
      { tag = 'top_block',
        { tag = 'return_stat',
          expr = {
            tag = 'binary_op',
            op = "or",
            lhs = { tag = 'identifier', name='a' },
            rhs = {
              tag = 'binary_op',
              op = 'and',
              lhs = { tag='identifier', name='b'},
              rhs = { tag='identifier', name='c'},
            }
          }
        }
      }
    )

    -- force priority
    assert_parse("return a and (b or c)",
      { tag = 'top_block',
        { tag = 'return_stat',
          expr = {
            tag = 'binary_op',
            op = "and",
            lhs = { tag = 'identifier', name='a' },
            rhs = {
              tag = 'binary_op',
              op = 'or',
              lhs = { tag='identifier', name='b'},
              rhs = { tag='identifier', name='c'},
            }
          }
        }
      }
    )

    -- priority from low to high
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
                                tag = "unary_op"
                              },
                              tag = "binary_op"
                            },
                            tag = "binary_op"
                          },
                          tag = "binary_op"
                        },
                        tag = "binary_op"
                      },
                      tag = "binary_op"
                    },
                    tag = "binary_op"
                  },
                  tag = "binary_op"
                },
                tag = "binary_op"
              },
              tag = "binary_op"
            },
            tag = "binary_op"
          },
          tag = "binary_op"
        },
        tag = "return_stat"
      },
      tag = "top_block"
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
            tag = "binary_op"
          },
          op = "add",
          rhs = {
            name = "c",
            tag = "identifier"
          },
          tag = "binary_op"
        },
        tag = "return_stat"
      },
      tag = "top_block"
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
            tag = "binary_op"
          },
          tag = "binary_op"
        },
        tag = "return_stat"
      },
      tag = "top_block"
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
            tag = "binary_op"
          },
          tag = "binary_op"
        },
        tag = "return_stat"
      },
      tag = "top_block"
    })

  end)
end)
