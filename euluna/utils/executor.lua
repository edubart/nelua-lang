local plutil = require 'pl.utils'
local tabler = require 'euluna.utils.tabler'

local executor = {}

function executor.build_command(command, args)
  if args and #args > 0 then
    local strargs = tabler(args)
      :imap(function(a) return plutil.quote_arg(a) end)
      :concat(' '):value()
    return command .. ' ' .. strargs
  end
  return command
end

function executor.exec(command)
  local success, status, sout, serr = plutil.executeex(command)
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

function executor.execex(command, binary)
  return plutil.executeex(command, binary)
end

return executor
