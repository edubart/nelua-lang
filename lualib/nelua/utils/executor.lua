--[[
Executor module

The executor module is used to execute system commands,
such as running a C compiler or external applications.
]]

local tabler = require 'nelua.utils.tabler'
local pegger = require 'nelua.utils.pegger'
local platform = require 'nelua.utils.platform'
local fs = require 'nelua.utils.fs'

-- luacov:disable
local executor = {}

-- List of common POSIX signals
local signals = {
  [1] = {name='SIGHUP', desc='Hangup'},
  [2] = {name='SIGINT', desc='Interrupt'},
  [3] = {name='SIGQUIT', desc='Quit'},
  [4] = {name='SIGILL', desc='Illegal instruction'},
  [5] = {name='SIGTRAP', desc='Trap'},
  [6] = {name='SIGABRT', desc='Aborted'},
  [7] = {name='SIGBUS', desc='Bus error'},
  [8] = {name='SIGFPE', desc='Floating point exception'},
  [9] = {name='SIGKILL', desc='Killed'},
  [10] = {name='SIGUSR1', desc='User defined signal 1'},
  [11] = {name='SIGSEGV', desc='Segmentation fault'},
  [12] = {name='SIGUSR2', desc='User defined signal 2'},
  [13] = {name='SIGPIPE', desc='Broken pipe'},
  [14] = {name='SIGALRM', desc='Alarm clock'},
  [15] = {name='SIGTERM', desc='Terminated'},
}

-- Convert a signal code to a nice error message.
local function get_signal_errmsg(sigcode)
  local sig = signals[sigcode]
  if sig then
    return string.format('%s (%s)', sig.desc, sig.name)
  end
  return string.format('Killed by signal %d', sigcode)
end

--[[
Execute a shell command, in a compatible and platform independent way.
Returns true on success, plus exit reason ("exit" or "signal") and status code.
]]
local function execute(cmd)
  local ok, reason, status = os.execute(cmd)
  if reason == "No error" and status == 0 and platform.is_windows then
    -- os.execute bug in Lua 5.2+ not reporting -1 properly on Windows
    status = -1
    reason = 'Execute error'
  end
  if platform.is_windows then
    return status==0, reason, status
  else
    return not not ok, reason, status
  end
end

-- Quote and escape an argument for a command.
local function quote_arg(argument)
  -- only a single argument
  if platform.is_windows then
    -- os.execute() uses system() C function, which on Windows passes command
    -- to cmd.exe. Escape its special characters.
    argument = argument:gsub('["^<>!|&%%]', "^%0")
    if argument == "" or argument:find('[ \f\t\v]') then
      -- need to quote the argument, quotes need to be escaped with backslashes
      -- additionally, backslashes before a quote, escaped or not, need to be doubled
      -- see documentation for CommandLineToArgvW Windows function
      argument = '"' .. argument:gsub([[(\*)"]], [[%1%1\"]]):gsub([[\+$]], "%0%0") .. '"'
    end
    return argument
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
local function executeex(command, bin)
  local outfile = fs.tmpname()
  local errfile = fs.tmpname()
  if not platform.is_windows then
    -- adding '{' '}' braces captures crash messages to stderr
    -- in case of segfault of the running command
    command = '{ ' .. command .. '; }'
  end
  command = command .. " > " .. quote_arg(outfile) .. " 2> " .. quote_arg(errfile)
  local success, reason, status = execute(command)
  local outcontent = fs.readfile(outfile, bin) or ''
  local errcontent = fs.readfile(errfile, bin) or ''
  fs.deletefile(outfile)
  fs.deletefile(errfile)
  if reason == 'signal' then
    local sigerrmsg = get_signal_errmsg(status)
    if #errcontent > 0 then
      if not errcontent:find('\n$') then
        errcontent = errcontent..'\n'
      end
      errcontent = errcontent..sigerrmsg..'\n'
    else
      errcontent = sigerrmsg
    end
    status = -1
  end
  return success, status, outcontent, errcontent
end

-- Execute a command capturing the stdour/stderr output if required.
local function pexec(exe, args, capture)
  local command = quote_arg(exe)
  if args and #args > 0 then
    local strargs = table.concat(tabler.imap(args, quote_arg), ' ')
    command = command .. ' ' .. strargs
  end
  if capture then
    return executeex(command)
  else
    local success, reason, status = execute(command)
    if reason == 'signal' then
      io.stderr:write(get_signal_errmsg(status), '\n')
      io.stderr:flush()
      status = -1
    end
    return success, status
  end
end

-- Helper to split arguments to a table.
function executor.convertargs(exe, args)
  if not args then
    args = pegger.split_execargs(exe)
    exe = args[1]
    table.remove(args, 1)
  end
  return exe, args
end

--[[
Execute a command.
Args must be a table or nil, if args is nil then the args is extracted from exe.
Returns a true when successful and status code.
]]
function executor.exec(exe, args)
  exe, args = executor.convertargs(exe, args)
  return pexec(exe, args)
end

--[[
Execute a command capturing stdout/stderr.
Args must be a table or nil, if args is nil then the args is extracted from exe.
Returns a true when successful, the status code, stdout and stderr contents.
]]
function executor.execex(exe, args)
  exe, args = executor.convertargs(exe, args)
  return pexec(exe, args, true)
end

--[[
Execute a command returning it's stdout.
Args must be a table or nil, if args is nil then the args is extracted from exe.
Returns the stdout plus stderr on success, otherwise nil plus an error message and status code.
]]
function executor.evalex(exe, args)
  exe, args = executor.convertargs(exe, args)
  local ok, status, stdout, stderr = pexec(exe, args, true)
  if ok and status == 0 then
    return stdout, stderr, status
  end
  local err
  if stderr and #stderr > 0 then
    err = stderr
  else
    err = 'command exited with code ' .. status
  end
  return nil, err, status
end

-- Like `executor.evalex`, but returns only stdout on success and raises an error on failure.
function executor.eval(exe, args)
  local stdout, stderr = executor.evalex(exe, args)
  if not stdout then
    error('failed to evaluate command:\n'..stderr)
  end
  return stdout
end

--[[
Like `executor.exec`,
but stdout/stderr is redirected to `io` stdout/stderr if `redirect` is true.
]]
function executor.rexec(exe, args, redirect)
  if redirect then
    local stdout, stderr, status = executor.evalex(exe, args)
    if stdout then
      io.stdout:write(stdout)
      io.stdout:flush()
    end
    if stderr then
      io.stderr:write(stderr)
      io.stderr:flush()
    end
    return not not stdout, status
  else
    return executor.exec(exe, args)
  end
end

return executor
-- luacov:enable
