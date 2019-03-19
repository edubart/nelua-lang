local class = require 'pl.class'
local lpeg = require 'lpeglabel'
local re = require 'relabel'
local tablex = require 'pl.tablex'
local utils = require 'euluna.utils'
local unpack = table.unpack or unpack
local assertf = utils.assertf
local Parser = class()

lpeg.setmaxstack(1024)

function Parser:_init()
  self.keywords = {}
  self.syntax_errors = {}
  self.defs = {}
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

local function recompile_peg(selfdefs, pegdesc)
  local combined_defs = inherit_defs(selfdefs, pegdesc.defs)
  local compiled_patt = re.compile(pegdesc.patt, combined_defs)
  if pegdesc.modf then
    compiled_patt = pegdesc.modf(compiled_patt, selfdefs)
  end
  selfdefs[pegdesc.name] = compiled_patt
end

function Parser:set_shaper(shaper)
  self.shaper = shaper

  local function to_astnode(pos, tag, ...)
    local node = shaper:create(tag, ...)
    node.pos = pos
    node.src = self.input
    return node
  end

  local defs = self.defs
  defs.to_astnode = to_astnode
  defs.to_chain_unary_op = function(pos, tag, opnames, expr)
    for i=#opnames,1,-1 do
      local opname = opnames[i]
      expr = to_astnode(pos, tag, opname, expr)
    end
    return expr
  end

  defs.to_binary_op = function(pos, tag, lhs, opname, rhs)
    if rhs then
      return to_astnode(pos, tag, opname, lhs, rhs)
    end
    return lhs
  end

  defs.to_chain_binary_op = function(pos, tag, matches)
    local lhs = matches[1]
    for i=2,#matches,2 do
      local opname, rhs = matches[i], matches[i+1]
      lhs = to_astnode(pos, tag, opname, lhs, rhs)
    end
    return lhs
  end

  defs.to_chain_ternary_op = function(pos, tag, matches)
    local lhs = matches[1]
    for i=2,#matches,3 do
      local opname, mid, rhs = matches[i], matches[i+1], matches[i+2]
      lhs = to_astnode(pos, tag, opname, lhs, mid, rhs)
    end
    return lhs
  end

  defs.to_chain_index_or_call = function(primary_expr, exprs, inblock)
    local last_expr = primary_expr
    if exprs then
      for _,expr in ipairs(exprs) do
        table.insert(expr, last_expr)
        last_expr = to_astnode(unpack(expr))
      end
    end
    if inblock then
      table.insert(last_expr, true)
    end
    return last_expr
  end

  defs.to_nil = function() return nil end
  defs.to_true = function() return true end
  defs.to_false = function() return false end

  for _,pegdesc in pairs(self.pegdescs) do
    recompile_peg(defs, pegdesc)
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
    recompile_peg(self.defs, pegdesc)
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
    defs = defs,
    modf = modf,
    deps = deps
  }
  if must_recompile then
    recompile_dependencies_for(self, name)
  end
end

function Parser:remove_peg(name)
  assertf(self.defs[name], 'cannot remove non existent peg "%s"', name)
  local refs = cascade_dependencies_for(self.pegdescs, name)
  assertf(#refs == 0, 'cannot remove peg "%s" that has references', name)
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
  assertf(pattdescs, 'invalid multiple pegs patterns syntax for:\n%s', combined_patts)
  for _,pattdesc in ipairs(pattdescs) do
    local name, content = pattdesc[1], pattdesc[2]
    local patt = string.format('%s <- %s', name, content)
    self:set_peg(name, patt, defs, modf)
  end
end

function Parser:match(name, input)
  local peg = self.defs[name]
  assertf(peg, 'cannot match an input to inexistent peg "%s"', name)
  self.input = input
  local res, errlabel, errpos = peg:match(input)
  self.input = nil
  return res, errlabel, errpos
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
  assertf(tablex.find(self.keywords, keyword) == nil, 'keyword "%s" already exists', keyword)
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
  assertf(i, 'keyword "%s" to remove not found', keyword)
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

function Parser:parse(input, name)
  if not name then
    name = 'sourcecode'
  end
  local ast, errlabel, errpos = self:match(name, input)
  if ast then
    return ast
  else
    local errmsg = self.syntax_errors[errlabel] or errlabel
    return nil, utils.generate_pretty_error(input, errpos, errmsg), errlabel
  end
end

function Parser:clone()
  local clone = Parser()
  tablex.update(clone.keywords, self.keywords)
  tablex.update(clone.syntax_errors, self.syntax_errors)
  tablex.update(clone.defs, self.defs)
  tablex.update(clone.pegdescs, self.pegdescs)
  clone:set_shaper(self.shaper)
  return clone
end

return Parser
