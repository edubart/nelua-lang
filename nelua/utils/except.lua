local class = require 'nelua.utils.class'
local metamagic = require 'nelua.utils.metamagic'
local tabler = require 'nelua.utils.tabler'
local stringer = require 'nelua.utils.stringer'
local traits = require 'nelua.utils.traits'

local Exception = class()

local function get_message_for_trace(self)
  local label = self.label or 'Exception'
  if self.message then
    return string.format('uncaught exception %s: %s', label, self.message)
  else
    return string.format('uncaught exception %s', label)
  end
end

function Exception:_init(params, level)
  level = (level or 1) + 2
  tabler.update(self, params)
  self.traceback = debug.traceback(get_message_for_trace(self), level)
end

function Exception:__tostring()
  return self:get_trace_message()
end

function Exception:get_message()
  return self.message or self.label or 'Exception'
end

function Exception:get_trace_message()
  return self.traceback or self:get_message()
end

local except = {}
except.Exception = Exception

local function raise(e, level)
  level = (level or 1) + 1
  if class.is_a(e, Exception) then
    error(e, level)
  elseif traits.is_string(e) then
    error(Exception({ message = e }, level), level)
  elseif traits.is_table(e) and rawequal(getmetatable(e), nil) then
    assert(e.message or e.label, 'exception table has no message or label')
    error(Exception(e, level), level)
  else --luacov:disable
    error('invalid exception object')
  end --luacov:enable
end

function except.raise(e, level)
  level = (level or 1) + 1
  raise(e, level)
end

function except.assertraise(cond, e)
  if not cond then raise(e, 2) end
  return cond
end

function except.assertraisef(cond, message, ...)
  if not cond then raise(stringer.pformat(message, ...), 2) end
  return cond
end

function except.is_exception(e, label)
  return class.is_a(e, Exception) and (not label or (label == e.label))
end

function except.reraise(e)
  if class.is_a(e, Exception) then
    e.traceback = debug.traceback(e.traceback)
  end
  error(e, 0)
end

local function try_error_handler(e)
  if class.is_a(e, Exception) then
    return e
  elseif type(e) == 'string' then
    return debug.traceback(e, 2)
  elseif metamagic.hasmetamethod(e, '__tostring') or type(e) == 'number' then
    return debug.traceback(tostring(e), 2)
  else --luacov:disable
    return debug.traceback(string.format('(error object is a %s value)', type(e)), 2)
  end --luacov:enable
end

-- try and catch only exceptions (no lua errors)
-- if no handler is supplied:
--    if an exception is raised then returns the `nil, exception`
--    if no exception is raised then returns true and the first `f` return argument
-- otherwise:
--    if the exception is not caught by the handler then it's raised again
--    an exception is considered caught when the call to the handler returns true
--    the handler can be a table of labeled exceptions function handlers or a function
function except.try(f, handler)
  local ok, e = xpcall(f, try_error_handler)
  if not ok then
    if class.is_a(e, Exception) then
      if handler then
        if traits.is_table(handler) then handler = handler[e.label or 'Exception'] end
        if handler and handler(e) then return true end
      else
        return nil, e
      end
    end
    except.reraise(e)
  end
  return true, e
end

return except
