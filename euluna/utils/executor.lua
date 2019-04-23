local plutil = require 'pl.utils'
local tabler = require 'euluna.utils.tabler'
local stringer = require 'euluna.utils.stringer'
local pegger = require 'euluna.utils.pegger'

local executor = {}

-- luacov:disable

-- try to use luaposix exec (faster because we skil shell creation)
local hasposix, posix_pexec = pcall(function()
  local unistd = require 'posix.unistd'
  local wait = require 'posix.sys.wait'.wait
  local plpath = require 'pl.path'

  return function(exe, args)
    args = args or {}

    -- find the executable
    local exepath = plpath.abspath(exe)
    if exe ~= exepath and not exe:find(plpath.sep, 1, true) then
      exepath = nil
      local envpath = os.getenv('PATH')
      if envpath then
        local paths = stringer.split(envpath, ':')
        for _, pathprefix in ipairs(paths) do
          local trypath = plpath.join(pathprefix, exe)
          if plpath.isfile(trypath) then
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
    local outfd, outwfd = unistd.pipe()
    local errfd, errwfd = unistd.pipe()
    local pid, errmsg = unistd.fork()
    if pid == 0 then
      unistd.close(outfd) unistd.close(errfd)
      unistd.dup2(outwfd, unistd.STDOUT_FILENO) unistd.dup2(errwfd, unistd.STDERR_FILENO)
      local _, err = unistd.exec(exepath, args)
      -- this is reached only when it fails
      io.stderr:write(err)
      unistd._exit(127)
    end
    unistd.close(outwfd)
    unistd.close(errwfd)
    local ssout = {}
    local sserr = {}
    while true do
      local r = unistd.read(outfd, 8192)
      if not r or #r == 0 then break end
      table.insert(ssout, r)
    end
    while true do
      local r = unistd.read(errfd, 8192)
      if not r or #r == 0  then break end
      table.insert(sserr, r)
    end
    local _, reason, status = wait(pid)
    local ok = (reason == 'exited') and status == 0
    unistd.close(outfd) unistd.close(errfd)
    local sout = table.concat(ssout)
    local serr = table.concat(sserr)
    return ok, status, sout, serr
  end
end)

local function pl_pexec(exe, args)
  local command = exe
  if args and #args > 0 then
    local strargs = tabler(args):imap(plutil.quote_arg):concat(' '):value()
    command = command .. ' ' .. strargs
  end
  return plutil.executeex(command)
end

local pexec = hasposix and posix_pexec or pl_pexec

--luacov:enable

local function convert_args(exe, args)
  if not args then
    args = pegger.split_execargs(exe)
    exe = args[1]
    table.remove(args, 1)
  end
  return exe, args
end

function executor.exec(exe, args)
  exe, args = convert_args(exe, args)
  local success, status, sout, serr = pexec(exe, args)
  if sout then
    io.stdout:write(sout)
    io.stdout:flush()
  end
  if serr then
    io.stderr:write(serr)
    io.stderr:flush()
  end
  if status ~= 0 then success = false end
  return success, status
end

function executor.execex(exe, args)
  exe, args = convert_args(exe, args)
  return pexec(exe, args)
end

return executor
