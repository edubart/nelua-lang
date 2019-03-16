local utils = {}

function utils.assertf(cond, str, ...)
  return assert(cond, not cond and string.format(str, ...))
end

return utils
