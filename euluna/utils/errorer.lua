local re = require 'relabel'

local errorer = {}

function errorer.assertf(cond, str, ...)
  return assert(cond, not cond and string.format(str, ...))
end

function errorer.errorf(str, ...)
  --luacov:disable
  error(string.format(str, ...), 2)
  --luacov:enable
end

function errorer.get_pretty_source_errmsg(src, srcname, errpos, errmsg, errname)
  local line, col = re.calcline(src, errpos)
  local colors = require 'term.colors'
  local NEARLENGTH = 20
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
