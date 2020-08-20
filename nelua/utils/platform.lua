-- Platform module
--
-- Platform module defines platform specific values.

local platform = {}

-- The separator for directories on the platform.
-- Usually '/' on Linux and '\' on Windows.
platform.dir_separator = _G.package.config:sub(1,1)

-- Boolean flag to if we are running on Windows
platform.is_windows = platform.dir_separator == '\\'

-- The separator for the PATH environment variable on the platform.
-- Usually ':' on Linux and ';' on Windows.
platform.path_separator = platform.is_windows and ';' or ':'

return platform
