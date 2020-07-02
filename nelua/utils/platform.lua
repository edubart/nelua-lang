local platform = {}

-- the directory separator character for the current platform
platform.dir_separator = _G.package.config:sub(1,1)

-- boolean flag this is a Windows platform
platform.is_windows = platform.dir_separator == '\\'

return platform
