-- Executor module
--
-- The executor module is used by the compiler to execute system commands,
-- such as running a C compiler or a built binary.

local tabler = require 'nelua.utils.tabler'
local stringer = require 'nelua.utils.stringer'
local pegger = require 'nelua.utils.pegger'
local platform = require 'nelua.utils.platform'
local fs = require 'nelua.utils.fs'

local executor = {}

-- luacov:disable

-- This does a custom implementation of the system's exec command for POSIX platforms.
-- It's only used when luaposix is available.
-- Usually it's faster than the lua execute function because it skips shell creation,
-- by doing a fork + exec.
-- When this is available the compiler test suite runs faster.
local hasposix, posix_pexec = pcall(function()
  local unistd = require 'posix.unistd'
  local wait = require 'posix.sys.wait'.wait
  local poll = require 'posix.poll'
  local envpath = os.getenv('PATH')

  return function(exe, args, redirect)
    args = args or {}

    -- find the executable
    local exepath = fs.abspath(exe)
    if exe ~= exepath and not exe:find(fs.sep, 1, true) then
      exepath = nil
      if envpath then
        local paths = stringer.split(envpath, ':')
        for _, pathprefix in ipairs(paths) do
          local trypath = fs.join(pathprefix, exe)
          if fs.isfile(trypath) then
            exepath = trypath
            break
          end
        end
      end
    end
    if not exepath then
      return false, 127, "", string.format("%s: command not found\n", exe)
    end
    args[0] = exe

    -- piped fork and exec
    io.stderr:flush()
    io.stdout:flush()
    local outfd, outwfd, errfd, errwfd
    if redirect then
      outfd, outwfd = unistd.pipe()
      errfd, errwfd = unistd.pipe()
    end
    local pid, errmsg = unistd.fork()
    assert(pid, errmsg)
    if pid == 0 then
      if redirect then
        unistd.close(outfd) unistd.close(errfd)
        unistd.dup2(outwfd, unistd.STDOUT_FILENO) unistd.dup2(errwfd, unistd.STDERR_FILENO)
      end
      local _, err = unistd.exec(exepath, args)
      -- this is reached only when it fails
      io.stderr:write(err)
      io.stderr:flush()
      unistd._exit(127)
    end
    local ssout = {}
    local sserr = {}
    if redirect then
      unistd.close(outwfd)
      unistd.close(errwfd)
      local fds = {
         [outfd] = {events={IN=true}, ss=ssout},
         [errfd] = {events={IN=true}, ss=sserr}
      }
      repeat
        poll.poll(fds, -1)
        for fd in pairs(fds) do
          if fds[fd].revents.IN then
            local r = unistd.read(fd, 8192)
            if r and #r > 0 then
              table.insert(fds[fd].ss, r)
            end
          end
          if fds[fd].revents.HUP then
            unistd.close(fd)
            fds[fd] = nil
          end
        end
      until not next(fds)
    end
    local _, reason, status = wait(pid)
    local ok = (reason == 'exited') and status == 0
    if redirect then
      unistd.close(outfd) unistd.close(errfd)
      local sout = table.concat(ssout)
      local serr = table.concat(sserr)
      return ok, status, sout, serr
    else
      return ok, status
    end
  end
end)

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
local function lua_pexec(exe, args, capture)
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

local pexec = hasposix and posix_pexec or lua_pexec

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

-- luacov:enable

-- Execute a command capturing stdout/stderr.
-- Args must be a table or nil, if args is nil then the args is extracted from exe.
-- Returns a true when successful, the status code, stdout and stderr contents.
function executor.execex(exe, args)
  exe, args = convertargs(exe, args)
  return pexec(exe, args, true)
end

return executor
