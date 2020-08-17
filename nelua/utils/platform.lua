-- Platform module
--
-- Define some platform specific values that is used in the compiler.

local platform = {}

-- The directory separator character for the platform.
platform.dir_separator = _G.package.config:sub(1,1)

-- Boolean flag to if we are running on Windows
platform.is_windows = platform.dir_separator == '\\'

return platform
