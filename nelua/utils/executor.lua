-- Executor module
--
-- The executor module is used to execute system commands,
-- such as running a C compiler or a built binary.

local tabler = require 'nelua.utils.tabler'
local pegger = require 'nelua.utils.pegger'
local platform = require 'nelua.utils.platform'
local fs = require 'nelua.utils.fs'

-- luacov:disable
local executor = {}

-- Execute a shell command, in a compatible and platform independent way.
local function execute(cmd)
  local res1,res2,res3 = os.execute(cmd)
  if res2 == "No error" and res3 == 0 and platform.is_windows then
    -- os.execute bug in Lua 5.2+ not reporting -1 properly on Windows
    res3 = -1
  end
  if platform.is_windows then
    return res3==0, res3
  else
    return not not res1, res3
  end
end

-- Quote and escape an argument for a command.
local function quote_arg(argument)
  if type(argument) == "table" then
    -- encode an entire table
    local r = {}
    for i, arg in ipairs(argument) do
      r[i] = quote_arg(arg)
    end

    return table.concat(r, " ")
  end
  -- only a single argument
  if platform.is_windows then
    if argument == "" or argument:find('[ \f\t\v]') then
      -- need to quote the argument, quotes need to be escaped with backslashes
      -- additionally, backslashes before a quote, escaped or not, need to be doubled
      -- see documentation for CommandLineToArgvW Windows function
      argument = '"' .. argument:gsub([[(\*)"]], [[%1%1\"]]):gsub([[\+$]], "%0%0") .. '"'
    end

    -- os.execute() uses system() C function, which on Windows passes command
    -- to cmd.exe. Escape its special characters.
    return (argument:gsub('["^<>!|&%%]', "^%0"))
  else
    if argument == "" or argument:find('[^a-zA-Z0-9_@%+=:,./-]') then
      -- to quote arguments on posix-like systems use single quotes
      -- to represent an embedded single quote close quoted string (')
      -- add escaped quote (\'), open quoted string again (')
      argument = "'" .. argument:gsub("'", [['\'']]) .. "'"
    end

    return argument
  end
end

-- Execute a shell command capturing stdout/stderr to a temporary files and returning the contents.
local function executeex(cmd, bin)
  local outfile = fs.tmpname()
  local errfile = fs.tmpname()

  if not platform.is_windows then
    -- adding '{' '}' braces captures crash messages to stderr
    -- in case of segfault of the running command
    cmd = '{ ' .. cmd .. '; }'
  end
  cmd = cmd .. " > " .. quote_arg(outfile) .. " 2> " .. quote_arg(errfile)

  local success, retcode = execute(cmd)
  local outcontent = fs.readfile(outfile, bin)
  local errcontent = fs.readfile(errfile, bin)
  os.remove(outfile)
  os.remove(errfile)
  return success, retcode, (outcontent or ""), (errcontent or "")
end

-- Execute a command capturing the stdour/stderr output if required.
local function pexec(exe, args, capture)
  local command = exe
  if args and #args > 0 then
    local strargs = tabler(args):imap(quote_arg):concat(' '):value()
    command = command .. ' ' .. strargs
  end
  if capture then
    return executeex(command)
  else
    return execute(command)
  end
end

-- Helper to split arguments to a table.
local function convertargs(exe, args)
  if not args then
    args = pegger.split_execargs(exe)
    exe = args[1]
    table.remove(args, 1)
  end
  return exe, args
end

-- Execute a command.
-- Args must be a table or nil, if args is nil then the args is extracted from exe.
-- Returns a true when successful and status code.
function executor.exec(exe, args)
  exe, args = convertargs(exe, args)
  return pexec(exe, args)
end

-- Execute a command capturing stdout/stderr.
-- Args must be a table or nil, if args is nil then the args is extracted from exe.
-- Returns a true when successful, the status code, stdout and stderr contents.
function executor.execex(exe, args)
  exe, args = convertargs(exe, args)
  return pexec(exe, args, true)
end

return executor
-- luacov:enable
