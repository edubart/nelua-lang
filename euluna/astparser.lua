local class = require 'pl.class'
local re = require 'relabel'
local astnodes = require 'euluna.astnodes'
local tablex = require 'pl.tablex'
local ASTParser = class()

local astnodes_create = astnodes.create

local function to_astnode(pos, tag, ...)
  local ast = astnodes_create(tag, ...)
  ast.pos = pos
  return ast
end

function ASTParser:_init()
  local grammars = {}
  grammars.to_astnode = to_astnode
  self.grammars = grammars
  self.syntax_errors = {}
end

local function combine_grammars(grammars, defs)
  if defs then
    setmetatable(defs, { __index = grammars })
    return defs
  else
    return grammars
  end
end

function ASTParser:add_grammar(name, peg, defs)
  local grammars = self.grammars
  assert(grammars[name] == nil, 'grammar already exists')
  grammars[name] = re.compile(peg, combine_grammars(grammars, defs))
end

function ASTParser:add_grammars(namedpegs, defs)
  local grammars = self.grammars
  local combined_grammars = combine_grammars(grammars, defs)
  for name,peg in pairs(namedpegs) do
    assert(grammars[name] == nil, 'grammar already exists')
    grammars[name] = re.compile(peg, combined_grammars)
  end
end

function ASTParser:add_token(name, peg, defs)
  local grammars = self.grammars
  assert(grammars.SKIP, 'cannot set token without a SKIP grammar')
  assert(grammars[name] == nil, 'token already exists')
  grammars[name] = re.compile(peg, combine_grammars(self.grammars, defs)) * grammars.SKIP
end

function ASTParser:add_syntax_errors(syntax_errors)
  tablex.update(self.syntax_errors, syntax_errors)
end

local function generate_pretty_error(input, err)
  local colors = require 'term.colors'
  local NEARLENGTH = 20
  local pos = err.pos
  local linebegin = input:sub(math.max(pos-NEARLENGTH, 1), pos-1):match('[^\r\n]*$')
  local lineend = input:sub(pos, pos+NEARLENGTH):match('^[^\r\n]*')
  local linehelper = string.rep(' ', #linebegin) .. colors.bright(colors.green('^'))
  return string.format(
    "%s%d:%d: %ssyntax error:%s %s%s\n%s%s\n%s",
    tostring(colors.bright),
    err.line, err.col,
    tostring(colors.red),
    colors.reset .. colors.bright, err.msg or err.label,
    tostring(colors.reset),
    linebegin, lineend,
    linehelper)
end

function ASTParser:parse(input, name)
  if not name then
    name = 'sourcecode'
  end
  local grammars = self.grammars
  local grammar = grammars[name]
  assert(grammars[name], 'cannot parse input using a inexistent grammar')
  local ast, errlabel, errpos = grammar:match(input)
  if ast then
    return ast
  else
    local line, col = re.calcline(input, errpos)
    local err = { pos=errpos, line=line, col=col, label=errlabel, msg=self.syntax_errors[errlabel] }
    return nil, generate_pretty_error(input, err), err
  end
end

return ASTParser
