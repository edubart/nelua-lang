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

return luadefs
