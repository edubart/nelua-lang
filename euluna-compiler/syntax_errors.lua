local syntax_errors = {}

local errors = {
  { label = "SyntaxError", msg = "syntax error" },
  { label = "MalformedNumber", msg = "malformed number" },
  { label = "UnclosedLongString", msg = "unclosed long string" },
  { label = "UnclosedShortString", msg = "unclosed short string" },
  { label = "UnclosedLongComment", msg = "unclosed long comment" },
  { label = "UnclosedParenthesis", msg = "unclosed parenthesis" },
  { label = "UnclosedBracket", msg = "unclosed bracket" },
  { label = "UnclosedCurly", msg = "unclosed curly braces, did you forget `}`?" },
  { label = "UnclosedFunction", msg = 'unclosed function, did you forget `end`?'},
  { label = "MalformedEscapeSequence", msg = "malformed escape sequence" },
  { label = "ExpectedFunctionBody", msg = "expected function body"},
  { label = "ExpectedParenthesis", msg = "expected parenthesis `()`" },
  { label = "ExpectedIdentifier", msg = "expected identifier" },
  { label = "ExpectedCall", msg = "expected call"},
  { label = "ExpectedAssignment", msg = "expected assignment"},
  { label = "ExpectedExpression", msg = "expected expression"},
  { label = "ExpectedMethodIdentifier", msg = "expected method identifier"},
  { label = "ExpectedEOF", msg = "unexpected character(s), expected EOF" },
  { label = "ExpectedThen", msg = "expected `then` keyword"},
  { label = "ExpectedEnd", msg = "expected `end` keyword"},
  { label = "ExpectedDo", msg = "expected `do` keyword"},
  { label = "ExpectedIdentifier", msg = "expected identifier" },
  { label = "ExpectedForRange", msg = "expected for range"},
}

syntax_errors.label_to_msg = {}
syntax_errors.label_to_int = {}
syntax_errors.int_to_label = {}
syntax_errors.int_to_msg   = {}

do
  for i, t in pairs(errors) do
    local label = assert(t.label)
    local msg   = assert(t.msg)
    syntax_errors.label_to_msg[label] = msg
    syntax_errors.label_to_int[label] = i
    syntax_errors.int_to_label[i] = label
    syntax_errors.int_to_msg[i] = msg
  end
end

syntax_errors.int_to_label[0] = "PEGMatchError"
syntax_errors.int_to_msg[0] = "PEG match error"

return syntax_errors
