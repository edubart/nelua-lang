-- Except module
--
-- The except module implements an exception system used by the compiler.
-- In this system exceptions can be raised, cough and raised again when needed.
-- An exception always have label and traceback.
-- The label is used to differentiate exceptions when needed,
-- tracebacks are stored when an exception is created or raised again.
-- The exceptions can store user defined additional information too.
-- The compiler uses this system to differentiate compile time errors from lua errors,
-- and to raise, catch or forward compile time errors for generating pretty tracebacks.

local class = require 'nelua.utils.class'
local metamagic = require 'nelua.utils.metamagic'
local tabler = require 'nelua.utils.tabler'
local stringer = require 'nelua.utils.stringer'
local traits = require 'nelua.utils.traits'

-- The exception class that is raised through the raise() function.
local Exception = class()

-- Helper to format the message of a traceback.
local function get_message_for_trace(self)
  local label = self.label or 'Exception'
  if self.message then
    return self.message
  else
    return string.format('uncaught exception %s', label)
  end
end

-- Initializes an exception from a table of fields and a trace level.
function Exception:_init(params, level)
  level = (level or 1) + 2
  tabler.update(self, params)
  self.traceback = debug.traceback(get_message_for_trace(self), level)
end

-- Gets the message of an exception.
function Exception:get_message()
  return self.message or self.label or 'Exception'
end

-- Gets the message of an exception with traceback included.
function Exception:get_trace_message()
  return self.traceback or self:get_message()
end

-- Converts an exception to a pretty message.
function Exception:__tostring()
  return self:get_trace_message()
end

local except = {}
except.Exception = Exception

-- Helper to raise an error object converting it to an exception as necessary.
local function raise(e, level)
  level = (level or 1) + 1 -- must increment the level for the traceback
  if class.is(e, Exception) then -- e already is an exception
    error(e, level)
  elseif traits.is_string(e) then -- e is a string, convert to an exception
    error(Exception({ message = e }, level), level)
  elseif traits.is_table(e) and rawequal(getmetatable(e), nil) then
    -- e is a table, must be a body for an exception with a message and label
    assert(e.message or e.label, 'exception table has no message or label')
    error(Exception(e, level), level)
  else --luacov:disable
    error('invalid exception object')
  end --luacov:enable
end

-- Raises an exception.
function except.raise(e, level)
  level = (level or 1) + 1 -- must increment the level for the traceback
  raise(e, level)
end

-- Throw an exception if a condition is not met.
function except.assertraise(cond, e)
  if not cond then raise(e, 2) end
  return cond
end

-- Throw an exception from a formatted message if a condition is not met.
function except.assertraisef(cond, message, ...)
  if not cond then raise(stringer.pformat(message, ...), 2) end
  return cond
end

-- Check whether the input is an exception of the desired label.
function except.isexception(e, label)
  return class.is(e, Exception) and (not label or (label == e.label))
end

-- Raise an exception or error again, appending more tracebacks.
function except.reraise(e)
  if class.is(e, Exception) then
    -- already an exception, append more traceback
    e.traceback = debug.traceback(e.traceback)
  end
  error(e, 0)
end

-- Helper for handling a lua errors, appending a traceback if the error object is not an exception.
local function tryerrhandler(e)
  if class.is(e, Exception) then
    return e
  elseif traits.is_string(e) then
    return debug.traceback(e, 2)
  elseif metamagic.hasmetamethod(e, '__tostring') or traits.is_number(e) then
    return debug.traceback(tostring(e), 2)
  else --luacov:disable
    return debug.traceback(string.format('(error object is a %s value)', type(e)), 2)
  end --luacov:enable
end

-- Try and catch only exceptions (never lua errors). It does a lua protected call.
-- When no handler is supplied:
--    If any exception is raised then returns nil plus the exception.
--    If no exception is raised then returns true plus the first return of `f`.
-- When a handler is supplied:
--    If the exception is not caught by the handler then it's raised again.
--    An exception is considered caught when the call to the handler returns true.
--    The handler can be a table of labeled exceptions function handlers or a function.
function except.try(f, handler)
  local ok, e = xpcall(f, tryerrhandler)
  if not ok then
    if class.is(e, Exception) then
      if handler then
        if traits.is_table(handler) then handler = handler[e.label or 'Exception'] end
        if handler and handler(e) then return true end
      else
        return nil, e
      end
    end
    -- the exception was not handled, raise again
    except.reraise(e)
  end
  -- success, return true and the first return of f
  return true, e
end

-- Try and catch any exception or lua error. It does a lua protected call.
function except.trycall(f, ...)
  return xpcall(f, tryerrhandler, ...)
end

return except
