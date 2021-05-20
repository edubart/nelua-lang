--[[
Erroer module

The erroer module is used to format and print pretty error messages.
]]

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
local function get_pretty_source_pos_errmsg(srcname, lineno, colno, line, errmsg, errname, len)
  local colbright, colreset = colors.bright, colors.reset
  local lineloc = ''
  if line then
    -- count number of tabs and spaces up to the text
    local ntabs = select(2, line:sub(1,colno-1):gsub('\t',''))
    local nspaces = colno-1-ntabs
    -- generate a line helper to assist showing the exact line column for the error
    local linehelper = string.rep('\t', ntabs)..string.rep(' ', nspaces)..colbright..colors.green..'^'..colreset
    if len and len > 1 then
      -- remove comments and trailing spaces
      local trimmedline = line:sub(1,colno+len-1):gsub('%-%-.*',''):gsub('%s+$','')
      len = math.min(#trimmedline-colno, len)
      linehelper = linehelper..colors.magenta..string.rep('~',len)..colreset
    end
    lineloc = '\n'..line..'\n'..linehelper
  end
  local errtraceback = ''
  -- extract traceback from message, to move it to the end of the message
  local tracebackpos = errmsg:find('%s*stack traceback%:')
  if tracebackpos then
    errtraceback = '\n'..errmsg:sub(tracebackpos)
    errmsg = errmsg:sub(1, tracebackpos-1)
  end
  -- choose the color for the message
  local errcolor = colreset
  if string.find(errname, 'error', 1, true) then
    errcolor = colors.error
  elseif string.find(errname, 'warning', 1, true) then
    errcolor = colors.warn
  end
  -- generate the error message
  return srcname..colbright..':'..lineno..':'..colno..': '..
         errcolor..errname..': '..colreset..colbright..errmsg..colreset..
         lineloc..errtraceback..'\n'
end

-- Generate a pretty error message associated with a character position from a source.
function errorer.get_pretty_source_pos_errmsg(src, pos, endpos, errmsg, errname)
  local lineno, colno, line = stringer.calcline(src.content, pos)
  local ncols = endpos and (endpos-pos)
  local srcname = src and src.name or ''
  return get_pretty_source_pos_errmsg(srcname, lineno, colno, line, errmsg, errname, ncols)
end

-- Generate a pretty error message associated with line and column from a source.
function errorer.get_pretty_source_line_errmsg(src, errline, errmsg, errname)
  local lineno, colno = errline, 1
  local line = stringer.getline(src.content, lineno)
  local srcname = src and src.name or ''
  return get_pretty_source_pos_errmsg(srcname, lineno, colno, line, errmsg, errname)
end

return errorer
