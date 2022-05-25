local class = require 'nelua.utils.class'
local types = require 'nelua.types'
local typedefs = require 'nelua.typedefs'
local tabler = require 'nelua.utils.tabler'
local config = require 'nelua.configer'.get()
local console = require 'nelua.utils.console'
local Symbol = require 'nelua.symbol'
local primtypes = typedefs.primtypes

local Scope = class()

Scope._scope = true

-- Defines a new builtin symbol.
local function make_builtin_symbol(name, attr)
  local type = attr.type
  local symbol = Symbol(attr)
  symbol.name = symbol.name or name
  symbol.codename = 'nelua_' .. name
  symbol.used = true
  symbol.const = true
  symbol.builtin = true
  symbol.staticstorage = true
  if type.is_function then
    type.sideeffect = not not symbol.sideeffect
    type:suggest_nickname(name)
  end
  return symbol
end

-- Defines a new primitive type symbol.
local function make_primtype_symbol(name, primtype)
  local symbol = Symbol{
    name = name,
    codename = primtype.codename,
    type = primtypes.type,
    value = primtype,
    staticstorage = true,
    vardecl = true,
    lvalue = true,
    global = true,
  }
  primtype.symbol = symbol
  return symbol
end

-- Called when indexing an undefined symbol in root scope.
local function rootscope_symbols__index(symbols, key)
  local symbol
  local builtin_attr = typedefs.builtin_attrs[key]
  if builtin_attr then -- getting a builtin symbol for the first time
    symbol = make_builtin_symbol(key, builtin_attr)
  else
    local primtype = primtypes[key]
    if primtype then -- getting a primitive symbol for the first time
      symbol = make_primtype_symbol(key, primtype)
    end
  end
  if symbol then -- found symbol
    symbol.scope = getmetatable(symbols).rootscope
    symbols[key] = symbol -- cached it
    return symbol
  end
end

-- Create a new scope for a context.
function Scope.create_root(context, node)
  local rootscope = setmetatable({
    node = node,
    context = context,
    children = {},
    labels = {},
    symbols = {},
    usednames = {},
    is_root = true,
    is_function = true,
    is_resultbreak = true,
  }, Scope)
  setmetatable(rootscope.symbols, {
    __index = rootscope_symbols__index,
    rootscope = rootscope,
  })
  return rootscope
end

-- Create a new scope from the current one, current symbols are visible in the new scope.
function Scope:fork(node)
  local context = self.context
  local scope = setmetatable({
    node = node,
    context = context,
    parent = self,
    is_topscope = self.is_root or self.is_require,
    children = {},
    labels = {},
    usednames = {},
    symbols = setmetatable({}, {__index = self.symbols})
  }, Scope)
  local children = self.children
  children[#children+1] = scope
  return scope
end

-- Clear the symbols and saved resolution data for this scope.
function Scope:clear_symbols()
  self.symbols = setmetatable({}, {__index = self.parent.symbols})
  self.possible_rettypes = nil
  self.has_unknown_return = nil
end

-- Search for a up scope matching a property.
function Scope:get_up_scope_of_kind(kind)
  while self and not self[kind] do
    self = self.parent
  end
  return self
end

-- Search for a up scope matching any property.
function Scope:get_up_scope_of_any_kind(kind1, kind2)
  while self and not (self[kind1] or self[kind2]) do
    self = self.parent
  end
  return self
end

-- Return the first upper scope that is a function.
function Scope:get_up_function_scope()
  local upfunctionscope = self.upfunctionscope
  if not upfunctionscope then
    upfunctionscope = self:get_up_scope_of_kind('is_function')
    self.upfunctionscope = upfunctionscope
  end
  return upfunctionscope
end

-- Return the first upper scope that is a do expression.
function Scope:get_up_doexpr_scope()
  local upreturnscope = self.upreturnscope
  if not upreturnscope then
    upreturnscope = self:get_up_scope_of_kind('is_doexpr')
    self.upreturnscope = upreturnscope
  end
  return upreturnscope
end

-- Return the first upper scope that would process loop statements.
function Scope:get_up_loop_scope()
  local uploopscope = self.uploopscope
  if not uploopscope then
    uploopscope = self:get_up_scope_of_kind('is_loop')
    self.uploopscope = uploopscope
  end
  return uploopscope
end

local function iterate_up_scopes_next(initscope, scope)
  if scope then
    return scope.parent
  end
  return initscope
end

-- Iterator to traverse all up scopes.
function Scope:iterate_up_scopes()
  return iterate_up_scopes_next, self, nil
end

-- Search for a common upper scope between two scopes.
function Scope:find_shared_up_scope(scope)
  local upscopes = {}
  for upscope in scope:iterate_up_scopes() do
    upscopes[upscope] = true
  end
  for upscope in self:iterate_up_scopes() do
    if upscopes[upscope] then
      return upscope
    end
  end
end

-- Search for labels backtracking upper scopes.
function Scope:find_label(name)
  repeat
    local label = self.labels[name]
    if label then
      return label, self
    end
    self = self.parent
  until (not self or self.is_function)
end

function Scope:add_label(label)
  self.labels[label.name] = label
end

function Scope:add_defer_block(blocknode)
  local deferblocks = self.deferblocks
  if not deferblocks then
    deferblocks = {}
    self.deferblocks = deferblocks
  end
  deferblocks[#deferblocks+1] = blocknode
end

--[[
Generates a unique identifier name prefixed with `name` in the current scope.
Returns "name_N" where N is an integral number that starts for 1,
and increments every generate call.
]]
function Scope:generate_name(name, compact)
  local count = (self.usednames[name] or 0) + 1
  self.usednames[name] = count
  if count > 1 or not compact then
    return name..'_'..count
  end
  return name
end

function Scope:make_checkpoint()
  local parent = self.parent
  local parentcheck
  if parent and not parent.is_root then
    parentcheck = parent:make_checkpoint()
  end
  local checkpoint = {
    symbols = tabler.copy(self.symbols),
    parentcheck = parentcheck
  }
  return checkpoint
end

function Scope:set_checkpoint(checkpoint)
  tabler.clear(self.symbols)
  tabler.update(self.symbols, checkpoint.symbols)
  if checkpoint.parentcheck then
    self.parent:set_checkpoint(checkpoint.parentcheck)
  end
end

function Scope:merge_checkpoint(checkpoint)
  tabler.update(self.symbols, checkpoint.symbols)
  if checkpoint.parentcheck then
    self.parent:merge_checkpoint(checkpoint.parentcheck)
  end
end

function Scope:push_checkpoint(checkpoint)
  if not self.checkpointstack then
    self.checkpointstack = {}
  end
  table.insert(self.checkpointstack, self:make_checkpoint())
  self:set_checkpoint(checkpoint)
end

function Scope:pop_checkpoint()
  local oldcheckpoint = table.remove(self.checkpointstack)
  self:merge_checkpoint(oldcheckpoint)
end

function Scope:add_symbol(symbol)
  local key = symbol.anonymous and symbol or symbol.name
  local symbols = self.symbols
  local oldsymbol = symbols[key]
  if oldsymbol then
    if oldsymbol == symbol or symbols[symbol] then -- symbol already registered
      return
    end
    -- shadowing a symbol with the same name
    if oldsymbol == self.context.state.inpolydef then
      -- symbol definition of a poly function
      key = symbol
    else
      -- shadowing an usual variable
      if rawget(symbols, key) == oldsymbol then -- the old symbol is really in this scope
        -- this symbol will be overridden but we still need to list it for the resolution
        symbols[oldsymbol] = oldsymbol
      end
      symbol.shadows = true
    end
  end
  symbols[key] = symbol -- store by key
  symbols[#symbols+1] = symbol -- store in order
  if not symbol.type then -- the symbol is unresolved
    local unresolved_symbols = self.unresolved_symbols
    if not unresolved_symbols then
      unresolved_symbols = {}
      self.unresolved_symbols = unresolved_symbols
    end
    if not unresolved_symbols[symbol] then
      unresolved_symbols[symbol] = true
      local context = self.context
      context.unresolvedcount = context.unresolvedcount + 1
    end
  end
end

function Scope:delay_resolution(force)
  if not force then
    -- ignore if an upper scope is already delaying the resolution
    for upscope in self:iterate_up_scopes() do
      if upscope.delay then
        return
      end
    end
  end
  self.delay = true
end

function Scope:finish_symbol_resolution(symbol)
  local unresolved_symbols = self.unresolved_symbols
  if unresolved_symbols and unresolved_symbols[symbol] then
    unresolved_symbols[symbol] = nil
    local context = self.context
    context.unresolvedcount = context.unresolvedcount - 1
  end
end

function Scope:resolve_symbols()
  local unresolved_symbols = self.unresolved_symbols
  if not unresolved_symbols then
    return 0
  end
  local count = 0
  if next(unresolved_symbols) then
    local unknownlist = {}
    local context = self.context
    -- first resolve any symbol with known possible types
    for symbol in next,unresolved_symbols do
      if symbol.type == nil then
        if symbol:resolve_type() then
          count = count + 1
        elseif count == 0 then
          unknownlist[#unknownlist+1] = symbol
        end
      end
      if symbol.type then
        self:finish_symbol_resolution(symbol)
      end
    end
    -- if nothing was resolved previously then try resolve symbol with unknown possible types
    if count == 0 and #unknownlist > 0 and not context.rootscope.delay then
      -- [disabled] try to infer the type only for the first unknown symbol
      --table.sort(unknownlist, function(a,b) return a.node.pos < b.node.pos end)
      for i=1,#unknownlist do
        local symbol = unknownlist[i]
        local force = context.state.anyphase and primtypes.any or not symbol:is_waiting_resolution()
        if symbol:resolve_type(force) then
          self:finish_symbol_resolution(symbol)
          count = count + 1
        end
        --break
      end
    end
  else
    self.unresolved_symbols = nil
  end
  return count
end

function Scope:add_return_type(index, type, value, refnode)
  if not type then
    -- ignore the unknown types in recursive functions
    if refnode then
      for symbol in refnode:walk_symbols() do
        if symbol == self.funcsym or symbol == self.polysym then
          return
        end
      end
    end
    self.has_unknown_return = refnode or true
  elseif self.has_unknown_return == refnode then
    self.has_unknown_return = nil
  end
  if type and type.is_void then -- void must be converted to nil
    type = primtypes.niltype
  end
  local possible_rettypes = self.possible_rettypes
  if not possible_rettypes then
    possible_rettypes = {}
    self.possible_rettypes = possible_rettypes
  end
  local rettypes = possible_rettypes[index]
  if not rettypes then
    possible_rettypes[index] = {[1] = type}
  elseif type and not tabler.ifind(rettypes, type) then
    rettypes[#rettypes+1] = type
  end
  if value then
    self.retvalues = self.retvalues or {}
    self.retvalues[index] = value
  end
end

function Scope:resolve_return_types()
  if self.rettypes or not self.is_resultbreak then -- not on a return block or already resolved
    return 0
  end
  local possible_rettypes = self.possible_rettypes
  local resolved_rettypes = self.resolved_rettypes
  if possible_rettypes then
    if not resolved_rettypes then
      resolved_rettypes = {}
      self.resolved_rettypes = resolved_rettypes
    end
    if next(possible_rettypes) then
      for i,candidate_rettypes in pairs(possible_rettypes) do
        local rettype = types.find_common_type(candidate_rettypes) or primtypes.any
        if rettype ~= resolved_rettypes[i] then
          resolved_rettypes[i] = rettype
        end
      end
    end
  end
  if not self.has_unknown_return then -- resolved
    self.rettypes = resolved_rettypes or {}
    self.has_unknown_return = nil
    self.resoved_rettypes = nil
    self.possible_rettypes = nil
    if not self.is_root then -- avoid resolving again in root scope
      return math.max(#self.rettypes, 1)
    end
  end
  return 0
end

function Scope:resolve()
  local count = self:resolve_symbols() + self:resolve_return_types()
  if config.debug_scope_resolve and count > 0 then
    console.info(self.node:format_message('info', "scope resolved %d symbols", count))
  end
  if self.delay then
    self.delay = nil
    count = count + 1
  end
  self.resolved_once = true
  return count
end

return Scope
