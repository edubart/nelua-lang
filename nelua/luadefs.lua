local luabuiltins = require 'nelua.luabuiltins'
local luadefs = {}

luadefs.unary_ops = {
  ['not'] = 'not ',
  ['neg'] = '-',
  ['bnot'] = '~',
  ['len'] = '#',
}

luadefs.binary_ops = {
  ['or'] = 'or',
  ['and'] = 'and',
  ['ne'] = '~=',
  ['eq'] = '==',
  ['le'] = '<=',
  ['ge'] = '>=',
  ['lt'] = '<',
  ['gt'] = '>',
  ['bor'] = '|',
  ['bxor'] = '~',
  ['band'] = '&',
  ['shl'] = '<<',
  ['shr'] = '>>',
  ['add'] = '+',
  ['sub'] = '-',
  ['mul'] = '*',
  ['div'] = '/',
  ['idiv'] = '//',
  ['mod'] = '%',
  ['pow'] = '^',
  ['concat'] = '..',
}

luadefs.lua51_unary_ops = {
  ['bnot']  = { func = 'bit.bnot', builtin = 'bit '},
}

luadefs.lua51_binary_ops = {
  ['idiv']  = { func = luabuiltins.idiv },
  ['pow']   = { func = 'math.pow' },
  ['bor']   = { func = 'bit.bor', builtin = 'bit' },
  ['band']  = { func = 'bit.band', builtin = 'bit' },
  ['bxor']  = { func = 'bit.bxor', builtin = 'bit' },
  ['shl']   = { func = 'bit.lshift', builtin = 'bit' },
  ['shr']   = { func = 'bit.rshift', builtin = 'bit' }
}

return luadefs
