local re = require 'relabel'
local colors = require 'nelua.utils.console'.colors
local stringer = require 'nelua.utils.stringer'

local errorer = {}

--luacov:disable
function errorer.assertf(cond, message, ...)
  if not cond then
    error(stringer.pformat(message, ...), 2)
  end
  return cond
end

function errorer.errorf(message, ...)
  error(stringer.pformat(message, ...), 2)
end
--luacov:enable

local function getline(text, lineno)
  local i = 0
  local lineend = 0
  local linestart
  repeat
    linestart = lineend+1
    lineend = string.find(text, '\n', linestart)
    i = i + 1
  until not lineend or i == lineno
  if lineend then
    lineend = lineend - 1
  end
  return string.sub(text, linestart, lineend)
end

local function get_pretty_source_pos_errmsg(src, srcname, errline, errcol, errmsg, errname)
  local line = getline(src, errline)
  local linebegin = line:sub(1, errcol-1)
  local lineend = line:sub(errcol)
  local linehelper = string.rep(' ', #linebegin) ..
    colors.bright .. colors.green .. '^' .. colors.reset
  local errmsg1, errmsg2 = errmsg, ''
  local tracebackpos = errmsg:find('stack traceback:', 1, true)
  if tracebackpos then
    errmsg1 = errmsg:sub(1, tracebackpos)
    errmsg2 = '\n' .. errmsg:sub(tracebackpos)
  end
  return string.format(
    "%s:%s%d:%d: %s%s:%s %s%s\n%s%s\n%s\n%s",
    srcname or '',
    tostring(colors.bright),
    errline, errcol,
    tostring(colors.red),
    errname or 'error',
    colors.reset .. colors.bright, errmsg1, tostring(colors.reset),
    linebegin, lineend,
    linehelper,
    errmsg2)
end

function errorer.get_pretty_source_pos_errmsg(src, srcname, errpos, errmsg, errname)
  local line, col = re.calcline(src, errpos)
  return get_pretty_source_pos_errmsg(src, srcname, line, col, errmsg, errname)
end

function errorer.get_pretty_source_line_errmsg(src, srcname, errline, errmsg, errname)
  local line, col = errline, 1
  return get_pretty_source_pos_errmsg(src, srcname, line, col, errmsg, errname)
end

return errorer
