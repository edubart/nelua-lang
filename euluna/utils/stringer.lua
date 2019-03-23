local stringx = require 'pl.stringx'
local sha1 = require 'sha1'.sha1

local stringer = {}

stringer.sha1 = sha1
stringer.split = stringx.split
stringer.rstrip = stringx.rstrip

return stringer