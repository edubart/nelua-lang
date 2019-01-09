
local tasker = {}

local tasks = {}
tasker.tasks = tasks

function tasker.task(name, desc, func)
  tasks[name] = {desc = desc, func = func}
end

function tasker.run(default_task)
  local taskname = arg[1]
  if taskname then
    table.remove(arg, 1)
    if tasks[taskname] then
      return tasks[taskname].func(arg)
    else
      print('Invalid task, see help')
      return false
    end
  elseif default_task and tasks[default_task] then
    return tasks[default_task].func(arg)
  else
    print('No default task found to be done')
    return false
  end
end

return tasker