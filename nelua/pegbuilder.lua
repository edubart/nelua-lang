local class = require 'nelua.utils.class'
local tabler = require 'nelua.utils.tabler'
local errorer = require 'nelua.utils.errorer'
local pegger = require 'nelua.utils.pegger'

local PEGBuilder = class()

function PEGBuilder:_init()
  self.group_pegs = {}
  self.pegs = {}
  self.defs = {}
end

local function merge_defs(self, defs)
  if not defs then return end
  for dname,def in pairs(defs) do
    errorer.assertf(self.defs[dname] == nil, 'conflict defs for "%s"', dname)
    self.defs[dname] = def
  end
end

local function recompile_group_peg(self, groupname)
  local group = self.group_pegs[groupname]
  local patt = table.concat(group, '/')
  self:set_peg(groupname, patt, nil, true)
end

function PEGBuilder:add_group_peg(groupname, name, patt, defs, overwrite)
  local group = self.group_pegs[groupname]
  if not group then
    group = {}
    self.group_pegs[groupname] = group
  end
  local fullname = string.format('%s_%s', groupname, name)
  if tabler.ifind(group, fullname) then
    errorer.assertf(overwrite, 'group peg "%s" already exists', fullname)
  else
    table.insert(group, fullname)
  end
  merge_defs(self, defs)
  recompile_group_peg(self, groupname)
  self:set_peg(fullname, patt, nil, overwrite)
end

function PEGBuilder:set_peg(name, patt, defs, overwrite)
  local has_peg = self.pegs[name] ~= nil
  errorer.assertf(not has_peg or overwrite, 'cannot overwrite peg "%s"', name)
  if not has_peg then
    table.insert(self.pegs, name)
  end
  self.pegs[name] = patt
  merge_defs(self, defs)
end

function PEGBuilder:set_pegs(combined_patts, defs, overwrite)
  local pattdescs = pegger.split_grammar_patts(combined_patts)
  for _,pattdesc in ipairs(pattdescs) do
    self:set_peg(pattdesc.name, pattdesc.patt, nil, overwrite)
  end
  merge_defs(self, defs)
end

function PEGBuilder:build()
  local pegs = self.pegs
  local text = tabler(pegs)
    :imap(function(name) return string.format('%s <- %s', name, pegs[name]) end)
    :concat('\n'):value()
  return text, self.defs
end

function PEGBuilder:clone()
  local clone = PEGBuilder()
  tabler.update(clone.group_pegs, self.group_pegs)
  tabler.update(clone.pegs, self.pegs)
  tabler.update(clone.defs, self.defs)
  return clone
end

return PEGBuilder
