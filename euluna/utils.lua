local utils = {}

function utils.assertf(cond, str, ...)
  return assert(cond, string.format(str, ...))
end

return utils