local class = require 'pl.class'
local re = require 'relabel'
local tablex = require 'pl.tablex'
local Grammar = require 'euluna.grammar'
local Parser = class(Grammar)
local to_astnode = require('euluna.astnodes').to_astnode

function Parser:_init()
  self:super()
  self:set_peg_func('to_astnode', to_astnode)
  self.keywords = {}
  self.statements = {}
  self.syntax_errors = {}
end

local function token_peg_generator(p, defs)
  return p * defs.SKIP
end

function Parser:set_token_peg(name, patt, defs)
  assert(self.defs.SKIP, 'cannot set token without a SKIP peg')
  return self:set_peg(name, patt, defs, token_peg_generator)
end

function Parser:set_token_pegs(combined_peg, defs)
  assert(self.defs.SKIP, 'cannot set token without a SKIP peg')
  return self:set_pegs(combined_peg, defs, token_peg_generator)
end

local function recompile_keyword_peg(self)
  local keyword_names = tablex.imap(function(k) return k:upper() end, self.keywords)
  local keyword_patt = string.format('%%%s', table.concat(keyword_names, '/%'))
  self:set_token_peg('KEYWORD', keyword_patt)
end

local function internal_add_keyword(self, keyword)
  local keyword_name = keyword:upper()
  assert(self.defs.IDSUFFIX, 'cannot add keyword without a IDSUFFIX peg')
  assert(tablex.find(self.keywords, keyword) == nil, 'keyword already exists')
  table.insert(self.keywords, keyword)
  self:set_token_peg(keyword_name, string.format("'%s' !%%IDSUFFIX", keyword))
end

function Parser:add_keyword(keyword)
  internal_add_keyword(self, keyword)
  recompile_keyword_peg(self)
end

function Parser:remove_keyword(keyword)
  local keyword_name = keyword:upper()
  local i = tablex.find(self.keywords, keyword)
  assert(i, 'keyword to remove not found')
  table.remove(self.keywords, i)
  recompile_keyword_peg(self)
  self:remove_peg(keyword_name)
end

local function recompile_statement_peg(self)
  local statement_patt = string.format('%%%s', table.concat(self.statements, '/%'))
  self:set_token_peg('statement', statement_patt)
end

function Parser:add_statement(statement_name, patt, defs)
  assert(tablex.find(self.statements, statement_name) == nil, 'statement already exists')
  table.insert(self.statements, statement_name)
  self:set_peg(statement_name, patt, defs)
  recompile_statement_peg(self)
end

function Parser:add_keywords(keywords)
  for _,keyword in ipairs(keywords) do
    internal_add_keyword(self, keyword)
  end
  recompile_keyword_peg(self)
end

function Parser:add_syntax_errors(syntax_errors)
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

function Parser:parse(input, name)
  if not name then
    name = 'sourcecode'
  end
  local ast, errlabel, errpos = self:match(name, input)
  if ast then
    return ast
  else
    local line, col = re.calcline(input, errpos)
    local err = {
      pos=errpos,
      line=line,
      col=col,
      label=errlabel,
      msg=self.syntax_errors[errlabel]
    }
    return nil, generate_pretty_error(input, err), err
  end
end

return Parser
