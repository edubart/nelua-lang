
local class = require 'pl.class'
local re = require 'relabel'
local Grammar = class()

function Grammar:_init()
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

function Grammar:set_peg(name, patt, defs, modf)
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

function Grammar:remove_peg(name)
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

function Grammar:set_pegs(combined_patts, defs, modf)
  local pattdescs = combined_peg_pat:match(combined_patts)
  assert(pattdescs, 'invalid multiple pegs patterns syntax')
  for _,pattdesc in ipairs(pattdescs) do
    local name, content = pattdesc[1], pattdesc[2]
    local patt = string.format('%s <- %s', name, content)
    self:set_peg(name, patt, defs, modf)
  end
end

function Grammar:set_peg_func(name, f)
  self.defs[name] = f
end

function Grammar:match(name, input)
  local peg = self.defs[name]
  assert(peg, 'cannot match an input to an inexistent peg in grammar')
  return peg:match(input)
end

return Grammar