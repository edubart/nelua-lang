local re = require 'relabel'

local utils = {}

function utils.assertf(cond, str, ...)
  return assert(cond, not cond and string.format(str, ...))
end

function utils.generate_pretty_error(input, errpos, errmsg)
  local line, col = re.calcline(input, errpos)
  local colors = require 'term.colors'
  local NEARLENGTH = 20
  local linebegin = input:sub(math.max(errpos-NEARLENGTH, 1), errpos-1):match('[^\r\n]*$')
  local lineend = input:sub(errpos, errpos+NEARLENGTH):match('^[^\r\n]*')
  local linehelper = string.rep(' ', #linebegin) .. colors.bright(colors.green('^'))
  return string.format(
    "%s%d:%d: %ssyntax error:%s %s%s\n%s%s\n%s\n",
    tostring(colors.bright),
    line, col,
    tostring(colors.red),
    colors.reset .. colors.bright, errmsg,
    tostring(colors.reset),
    linebegin, lineend,
    linehelper)
end

return utils
