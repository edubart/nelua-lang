local re = require 'relabel'
local colors = require 'euluna.utils.console'.colors
local stringer = require 'euluna.utils.stringer'

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

function errorer.get_pretty_source_errmsg(src, srcname, errpos, errmsg, errname)
  local line, col = re.calcline(src, errpos)
  local NEARLENGTH = 120
  local linebegin = src:sub(math.max(errpos-NEARLENGTH, 1), errpos-1):match('[^\r\n]*$')
  local lineend = src:sub(errpos, errpos+NEARLENGTH):match('^[^\r\n]*')
  local linehelper = string.rep(' ', #linebegin) .. colors.bright(colors.green('^'))
  return string.format(
    "%s:%s%d:%d: %s%s:%s %s%s\n%s%s\n%s\n",
    srcname or '',
    tostring(colors.bright),
    line, col,
    tostring(colors.red),
    errname or 'error',
    colors.reset .. colors.bright, errmsg,
    tostring(colors.reset),
    linebegin, lineend,
    linehelper)
end

return errorer
