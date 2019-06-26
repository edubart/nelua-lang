local typedefs = require 'nelua.typedefs'
local types = require 'nelua.types'
local primtypes = typedefs.primtypes

local symdefs = {}

symdefs.nilptr = primtypes.Nilptr
symdefs.assert = primtypes.any
symdefs.error = types.FunctionType(nil, {primtypes.string})
symdefs.print = primtypes.any
symdefs.type = types.FunctionType(nil, {primtypes.any}, {primtypes.string})

--symdefs.assert = types.FunctionType(nil, {primtypes.boolean, primtypes.auto})
--symdefs.print = types.FunctionType(nil, {primtypes.varargs})

return symdefs
