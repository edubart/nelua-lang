local luadefs = {}

luadefs.UNARY_OPS = {
  ['not'] = 'not ',
  ['neg'] = '-',
  ['bnot'] = '~',
  ['len'] = '#',
}

luadefs.BINARY_OPS = {
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

return luadefs
