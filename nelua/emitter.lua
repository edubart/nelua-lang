--[[
Emitter class.

The emitter is used to concatenate chunk of texts into a large text,
it's used by generators to build the target source file.
]]

local class = require 'nelua.utils.class'
local errorer = require 'nelua.utils.errorer'

-- The emitter class.
local Emitter = class()
-- Used to quickly check whether a table is an emitter.
Emitter._emitter = true

-- Default indentation.
local INDENT_SPACES = '  '
-- Metatable for indentation cache.
local indents_mt = {}
-- Indentation cache.
local indents = setmetatable({}, indents_mt)

-- Auto generate indent string on demand.
function indents_mt.__index(self, depth)
  local indent = string.rep(INDENT_SPACES, depth)
  self[depth] = indent
  return indent
end

--[[
Initializes emitter using `context` and at indentation depth `depth`.
If `depth` is omitted than 0 is used, that is, the emitter begins with no indentation.
]]
function Emitter:_init(context, depth)
  depth = depth or 0
  self.chunks = {} -- list of strings to be concatenated
  self.depth = depth -- current indentation depth
  self.indent = indents[depth] -- current indentation string
  self.context = context -- current context
end

-- Increments indentation by 1.
function Emitter:inc_indent()
  local depth = self.depth + 1
  self.depth = depth
  self.indent = indents[depth]
end

-- Decrements indentation by 1.
function Emitter:dec_indent()
  local depth = self.depth - 1
  self.depth = depth
  self.indent = indents[depth]
end

-- Adds `...` values.
function Emitter:add(...)
  for i=1,select('#', ...) do
    self:add_value((select(i, ...)))
  end
end

-- Adds `...` values and a new line.
function Emitter:add_ln(...)
  if ... then
    self:add(...)
  end
  local chunks = self.chunks
  chunks[#chunks+1] = '\n'
end

-- Adds indentation, and `...` values.
function Emitter:add_indent(...)
  local chunks = self.chunks
  local indent = self.indent
  if indent ~= '' then
    chunks[#chunks+1] = indent
  end
  if ... then
    self:add(...)
  end
end

-- Adds indentation, `...` values and a new line.
function Emitter:add_indent_ln(...)
  local chunks = self.chunks
  local indent = self.indent
  if indent ~= '' then
    chunks[#chunks+1] = indent
  end
  if ... then
    self:add(...)
  end
  chunks[#chunks+1] = '\n'
end

-- Adds values from list `list` separated by separator `sep`.
function Emitter:add_list(list, sep)
  if #list == 0 then return end
  sep = sep or ', '
  local chunks = self.chunks
  for i=1,#list do
    if i > 1 and #sep > 0 then chunks[#chunks+1] = sep end
    self:add_value(list[i])
  end
end

-- Adds string `s`.
function Emitter:add_text(s)
  if s == '' then return end
  local chunks = self.chunks
  chunks[#chunks+1] = s
end

-- Adds builtin function `name` evaluated with arguments `...`.
function Emitter:add_builtin(name, ...)
  local chunks = self.chunks
  chunks[#chunks+1] = self.context:ensure_builtin(name, ...)
end

-- Adds type name for type `type`.
function Emitter:add_type(type)
  local chunks = self.chunks
  chunks[#chunks+1] = self.context:ensure_type(type)
end

-- Adds number `n` converted to a string.
function Emitter:add_number(n)
  local chunks = self.chunks
  chunks[#chunks+1] = tostring(n)
end

-- Adds boolean `b` converted to a boolean.
function Emitter:add_boolean(b)
  local chunks = self.chunks
  chunks[#chunks+1] = tostring(not not b)
end

--[[
Adds value `value`.
The value will be automatically converted to a string according to its kind.
]]
function Emitter:add_value(value)
  local ty = type(value)
  if ty == 'string' then -- a string
    self:add_text(value)
  elseif ty == 'table' then
    if value._astnode then -- a node
      self.context:traverse_node(value, self)
    elseif value._type then -- a type
      self:add_type(value)
    elseif value._symbol then -- a symbol
      self:add_text(self.context:declname(value))
    else -- a list
      self:add_list(value)
    end
  elseif ty == 'number' then -- a number
    self:add_number(value)
  elseif ty == 'boolean' then -- a boolean
    self:add_boolean(value)
  else --luacov:disable
    errorer.errorf('emitter cannot add value of type "%s"', ty)
  end  --luacov:enable
end

-- Get current position in the chunk list.
function Emitter:get_pos()
  return #self.chunks
end

-- Checks if the chunk list is empty.
function Emitter:is_empty()
  return #self.chunks == 0
end

-- Remove all chunks from `pos+1` up to the last chunk.
function Emitter:trim(pos)
  local chunks = self.chunks
  while #chunks > pos do
    chunks[#chunks] = nil
  end
end

-- Concatenates all chunks into a large string.
function Emitter:generate()
  return table.concat(self.chunks)
end

return Emitter
