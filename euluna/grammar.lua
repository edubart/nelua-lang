
local class = require 'pl.class'
local re = require 'relabel'
local tablex = require 'pl.tablex'
local assertf = require 'euluna.utils'.assertf
local Grammar = class()

function Grammar:_init()
  self.group_pegs = {}
  self.pegs = {}
  self.defs = {}
end

local function merge_defs(self, defs)
  if not defs then return end
  for dname,def in pairs(defs) do
    assertf(self.defs[dname] == nil, 'conflict defs for "%s"', dname)
    self.defs[dname] = def
  end
end

local function recompile_group_peg(self, groupname)
  local group = self.group_pegs[groupname]
  local patt = table.concat(group, '/')
  self:set_peg(groupname, patt, nil, true)
end

function Grammar:add_group_peg(groupname, name, patt, defs)
  local group = self.group_pegs[groupname]
  if not group then
    group = {}
    self.group_pegs[groupname] = group
  end
  local fullname = string.format('%s_%s', groupname, name)
  assertf(tablex.find(group, fullname) == nil, 'group peg "%s" already exists', fullname)
  table.insert(group, fullname)
  merge_defs(self, defs)
  recompile_group_peg(self, groupname)
  self:set_peg(fullname, patt)
end

local combined_peg_pat = re.compile([[
pegs       <- {| (comment/peg)+ |}
peg        <- {| peg_head {peg_char*} |}
peg_head   <- %s* {[-_%w]+} %s* '<-' %s*
peg_char   <- !next_peg .
next_peg   <- linebreak %s* [-_%w]+ %s* '<-' %s*
comment    <- %s* '--' (!linebreak .)* linebreak?
]] ..
"linebreak <- [%nl]'\r' / '\r'[%nl] / [%nl] / '\r'"
)

function Grammar:set_peg(name, patt, defs, overwrite)
  local has_peg = self.pegs[name] ~= nil
  assertf(not has_peg or overwrite, 'cannot overwrite peg "%s"', name)
  if not has_peg then
    table.insert(self.pegs, name)
  end
  self.pegs[name] = patt
  merge_defs(self, defs)
end

function Grammar:set_pegs(combined_patts, defs, overwrite)
  local pattdescs = combined_peg_pat:match(combined_patts)
  assertf(pattdescs, 'invalid multiple pegs patterns syntax: %s', combined_patts)
  for _,pattdesc in ipairs(pattdescs) do
    local name, patt = pattdesc[1], pattdesc[2]
    self:set_peg(name, patt, nil, overwrite)
  end
  merge_defs(self, defs)
end

function Grammar:build()
  local pegs = self.pegs
  local text = table.concat(tablex.imap(function(name)
    return string.format('%s <- %s', name, pegs[name])
  end, pegs), '\n')
  return text, self.defs
end

function Grammar:clone()
  return tablex.deepcopy(self)
end

return Grammar
