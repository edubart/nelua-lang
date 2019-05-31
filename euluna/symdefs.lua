local typedefs = require 'euluna.typedefs'
--local types = require 'euluna.types'
local primtypes = typedefs.primtypes

local symdefs = {}

symdefs.nilptr = primtypes.Nilptr
symdefs.assert = primtypes.any
symdefs.print = primtypes.any

--symdefs.assert = types.FunctionType(nil, {primtypes.boolean, primtypes.auto})
--symdefs.print = types.FunctionType(nil, {primtypes.varargs})

return symdefs
