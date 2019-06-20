local stringer = require 'euluna.utils.stringer'
local colors = require 'term.colors'

local console = {}
console.colors = colors

local color_reset = tostring(colors.reset)
local color_debug = tostring(colors.cyan)
local color_error = tostring(colors.red) .. tostring(colors.bright)
local color_warn = tostring(colors.yellow) .. tostring(colors.bright)
local color_info = nil

local function logcf(out, color, text)
  if color then
    out:write(color)
  end
  out:write(text)
  out:write('\n')
  if color then
    out:write(color_reset)
  end
  out:flush()
end

local pformat, pconcat = stringer.print_format, stringer.print_concat

function console.warnf(format, ...)  logcf(io.stderr, color_warn,  pformat(format, ...)) end
function console.errorf(format, ...) logcf(io.stderr, color_error, pformat(format, ...)) end
function console.debugf(format, ...) logcf(io.stderr, color_debug, pformat(format, ...)) end
function console.infof(format, ...)  logcf(io.stdout, color_info,  pformat(format, ...)) end

function console.warn(...)  logcf(io.stderr, color_warn,  pconcat(...)) end
function console.error(...) logcf(io.stderr, color_error, pconcat(...)) end
function console.debug(...) logcf(io.stderr, color_debug, pconcat(...)) end
function console.info(...)  logcf(io.stdout, color_info,  pconcat(...)) end

return console
