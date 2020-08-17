-- Erroer module
--
-- The erroer module is used by the compiler to generate and print pretty error messages.

local re = require 'relabel'
local colors = require 'nelua.utils.console'.colors
local stringer = require 'nelua.utils.stringer'

local errorer = {}

-- Throw a formatted error message if condition is not met.
function errorer.assertf(cond, message, ...)
  if not cond then
    error(stringer.pformat(message, ...), 2)
  end
  return cond
end

-- Throw a formatted error message.
function errorer.errorf(message, ...)
  error(stringer.pformat(message, ...), 2)
end

-- Helper to generate pretty error messages associated with line and column from a source.
local function get_pretty_source_pos_errmsg(src, errline, errcol, errmsg, errname)
  local srcname = src and src.name or ''
  local colbright, colreset = colors.bright, colors.reset

  -- extract the line from the source
  local line = stringer.getline(src.content, errline)

  -- generate a line helper to assist showing the exact line column for the error
  local linehelper = string.rep(' ', errcol-1)..colbright..colors.green..'^'..colreset
  local errtraceback = ''

  -- extract traceback from message, to move it to the end of the message
  local tracebackpos = errmsg:find('stack traceback:', 1, true)
  if tracebackpos then
    errtraceback = '\n' .. errmsg:sub(tracebackpos)
    errmsg = errmsg:sub(1, tracebackpos)
  end

  -- choose the color for the message
  local errcolor = colreset
  if string.find(errname, 'error', 1, true) then
    errcolor = colors.error
  end
  local errmsgcolor = colreset..colbright

  -- generate the error message
  return string.format("%s:%d:%d: %s: %s\n%s\n%s\n%s",
    srcname..colbright, errline, errcol, errcolor..errname, errmsgcolor..errmsg..colreset,
    line, linehelper, errtraceback)
end

-- Generate a pretty error message associated with a character position from a source.
function errorer.get_pretty_source_pos_errmsg(src, errpos, errmsg, errname)
  local line, col = re.calcline(src.content, errpos)
  return get_pretty_source_pos_errmsg(src, line, col, errmsg, errname)
end

-- Generate a pretty error message associated with line and column from a source.
function errorer.get_pretty_source_line_errmsg(src, errline, errmsg, errname)
  local line, col = errline, 1
  return get_pretty_source_pos_errmsg(src, line, col, errmsg, errname)
end

return errorer
