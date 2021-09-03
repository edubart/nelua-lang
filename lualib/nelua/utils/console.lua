--[[
Console module

The console module is used to print colored information on the terminal
when compiling, such as errors, warnings and information.
]]

local stringer = require 'nelua.utils.stringer'
local pformat, pconcat = stringer.pformat, stringer.pconcat
local colors = {}
local console = {colors=colors}

local colorvalues = {
  -- attributes
  reset      = 0,
  clear      = 0,
  default    = 0,
  bright     = 1,
  dim        = 2,
  underscore = 4,
  blink      = 5,
  reverse    = 7,
  hidden     = 8,

  -- foreground
  black   = 30,
  red     = 31,
  green   = 32,
  yellow  = 33,
  blue    = 34,
  magenta = 35,
  cyan    = 36,
  white   = 37,

  -- background
  onblack   = 40,
  onred     = 41,
  ongreen   = 42,
  onyellow  = 43,
  onblue    = 44,
  onmagenta = 45,
  oncyan    = 46,
  onwhite   = 47,
}

-- Create color string to be used in the console.
local function remake_colors()
  for k,v in pairs(colorvalues) do
    colors[k] = colors.enabled and (string.char(27)..'['..tostring(v)..'m') or ''
  end
end

-- Helper to setup the default colors used for errors, warnings, etc..
local function setup_default_colors()
  colors.debug = colors.cyan
  colors.debug2 = colors.green .. colors.bright
  colors.error = colors.red .. colors.bright
  colors.warn = colors.yellow .. colors.bright
  colors.info = nil
end

-- Find isatty() function in 'sys' or 'term' module.
local function get_isatty() --luacov:disable
  local has_sys, sys = pcall(require, 'sys')
  if has_sys and sys.isatty then
    return sys.isatty
  else
    local has_term, termcore = pcall(require, 'term')
    if has_term and termcore.isatty then
      return termcore.isatty
    end
    return nil
  end
end --luacov:enable

-- Check whether the console supports colored output.
function console.is_colors_supported()
  local isatty = get_isatty()
  -- coloring is supported if the stdout is a file and a TTY terminal
  return io.type(io.stdout) == 'file' and isatty ~= nil and isatty(io.stdout) == true
end

-- Enable or disable the coloring output in the console.
function console.set_colors_enabled(enabled)
  if colors.enabled == enabled then return end
  colors.enabled = enabled
  remake_colors()
  -- need to setup the default colors
  setup_default_colors()
end

-- Print a colored text to the console output.
function console.logex(out, color, text)
  if color then out:write(tostring(color)) end
  out:write(text)
  out:write('\n')
  if color then out:write(tostring(colors.reset)) end
  out:flush()
end
local logex = console.logex

-- Formatted logging functions (string.format style)
function console.warnf(format, ...)  logex(io.stderr, colors.warn,  pformat(format, ...)) end
function console.errorf(format, ...) logex(io.stderr, colors.error, pformat(format, ...)) end
function console.debugf(format, ...) logex(io.stdout, colors.debug, pformat(format, ...)) end
function console.debug2f(format, ...) logex(io.stdout, colors.debug2, pformat(format, ...)) end
function console.infof(format, ...)  logex(io.stdout, colors.info,  pformat(format, ...)) end
function console.logf(format, ...)   logex(io.stdout, nil,  pformat(format, ...)) end
function console.logerrf(format, ...)logex(io.stderr, nil,  pformat(format, ...)) end

-- Logging functions (print style).
function console.warn(...)  logex(io.stderr, colors.warn,  pconcat(...)) end
function console.error(...) logex(io.stderr, colors.error, pconcat(...)) end
function console.debug(...) logex(io.stdout, colors.debug, pconcat(...)) end
function console.debug2(...) logex(io.stdout, colors.debug2, pconcat(...)) end
function console.info(...)  logex(io.stdout, colors.info,  pconcat(...)) end
function console.log(...)   logex(io.stdout, nil,  pconcat(...)) end
function console.logerr(...)logex(io.stderr, nil,  pconcat(...)) end

-- Guess if colors should be enabled on the running terminal.
console.set_colors_enabled(console.is_colors_supported())

return console
