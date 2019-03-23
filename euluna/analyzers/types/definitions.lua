local typedefs = {}

typedefs.NUM_LITERALS = {
  _integer    = 'integer',
  _number     = 'number',
  _b          = 'byte',     _byte       = 'byte',
  _c          = 'char',     _char       = 'char',
  _i          = 'int',      _int        = 'int',
  _i8         = 'int8',     _int8       = 'int8',
  _i16        = 'int16',    _int16      = 'int16',
  _i32        = 'int32',    _int32      = 'int32',
  _i64        = 'int64',    _int64      = 'int64',
  _u          = 'uint',     _uint       = 'uint',
  _u8         = 'uint',     _uint8      = 'uint',
  _u16        = 'uint',     _uint16     = 'uint',
  _u32        = 'uint',     _uint32     = 'uint',
  _u64        = 'uint',     _uint64     = 'uint',
  _f32        = 'float32',  _float32    = 'float32',
  _f64        = 'float64',  _float64    = 'float64',
  _pointer    = 'pointer',
}

typedefs.NUM_DEF_TYPES = {
  int = 'int',
  dec = 'number',
  exp = 'number',
  hex = 'uint',
  bin = 'uint'
}

return typedefs
