local class = require 'pl.class'
local re = require 'relabel'
local tablex = require 'pl.tablex'
local Parser = class()
local to_astnode = require('euluna.astnodes').to_astnode

function Parser:_init()
  self.keywords = {}
  self.syntax_errors = {}
  self.defs = {to_astnode = to_astnode}
  self.pegdescs = {}
end

local function inherit_defs(parent_defs, defs)
  if defs then
    setmetatable(defs, { __index = parent_defs })
    return defs
  else
    return parent_defs
  end
end

local function get_peg_deps(patt, defs, full_defs)
  if not defs then return {} end
  local deps = {}
  local proxy_defs = {}
  setmetatable(proxy_defs, {
    __index = function(_, name)
      if defs[name] then
        table.insert(deps, name)
      end
      return full_defs[name]
    end
  })
  re.compile(patt, proxy_defs)
  return deps
end

local function cascade_dependencies_for(pegdescs, name, list)
  list = list or {}
  for pegname,pegdesc in pairs(pegdescs) do
    if pegdesc.deps then
      for _,depname in ipairs(pegdesc.deps) do
        if depname == name and not list[pegname] then
          list[pegname] = true
          table.insert(list, pegdesc)
          cascade_dependencies_for(pegdescs, pegname, list)
        end
      end
    end
  end
  return list
end

local function recompile_dependencies_for(self, name)
  local to_recompile = cascade_dependencies_for(self.pegdescs, name)
  for _,pegdesc in ipairs(to_recompile) do
    local compiled_patt = re.compile(pegdesc.patt, pegdesc.defs)
    if pegdesc.modf then
      compiled_patt = pegdesc.modf(compiled_patt, self.defs)
    end
    self.defs[pegdesc.name] = compiled_patt
  end
end

function Parser:set_peg(name, patt, defs, modf)
  local combined_defs = inherit_defs(self.defs, defs)
  local compiled_patt = re.compile(patt, combined_defs)
  local deps = get_peg_deps(patt, self.defs, combined_defs)
  if modf then
    compiled_patt = modf(compiled_patt, self.defs)
  end
  local must_recompile = (self.defs[name] ~= nil)
  self.defs[name] = compiled_patt
  self.pegdescs[name] = {
    name = name,
    patt = patt,
    defs = combined_defs,
    modf = modf,
    deps = deps
  }
  if must_recompile then
    recompile_dependencies_for(self, name)
  end
end

function Parser:remove_peg(name)
  assert(self.defs[name], 'cannot remove non existent peg')
  local refs = cascade_dependencies_for(self.pegdescs, name)
  assert(#refs == 0, 'cannot remove peg that has references')
  self.defs[name] = nil
  self.pegdescs[name] = nil
end

local combined_peg_pat = re.compile([[
pegs       <- {| (comment/peg)+ |}
peg        <- {| peg_head {peg_char*} |}
peg_head   <- %s* '%' {[-_%w]+} %s* '<-' %s*
peg_char   <- !next_peg .
next_peg   <- linebreak %s* '%' [-_%w]+ %s* '<-' %s*
comment    <- %s* '--' (!linebreak .)* linebreak?
]] ..
"linebreak <- [%nl]'\r' / '\r'[%nl] / [%nl] / '\r'"
)

function Parser:set_pegs(combined_patts, defs, modf)
  local pattdescs = combined_peg_pat:match(combined_patts)
  assert(pattdescs, 'invalid multiple pegs patterns syntax')
  for _,pattdesc in ipairs(pattdescs) do
    local name, content = pattdesc[1], pattdesc[2]
    local patt = string.format('%s <- %s', name, content)
    self:set_peg(name, patt, defs, modf)
  end
end

function Parser:match(name, input)
  local peg = self.defs[name]
  assert(peg, 'cannot match an input to an inexistent peg in Parser')
  return peg:match(input)
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

function Parser:clone()
  return tablex.deepcopy(self)
end

return Parser
