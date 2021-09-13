#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <string.h>

#include <lua.h>
#include <lauxlib.h>

/* Base 58 */

#define BASE58_ENCODE_MAXLEN 256
#define BASE58_DECODE_MAXLEN 360

static const int8_t b58digits_map[] = {
  -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
  -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
  -1,-1,-1,-1,-1,-1,-1,-1, -1,-1,-1,-1,-1,-1,-1,-1,
  -1, 0, 1, 2, 3, 4, 5, 6,  7, 8,-1,-1,-1,-1,-1,-1,
  -1, 9,10,11,12,13,14,15, 16,-1,17,18,19,20,21,-1,
  22,23,24,25,26,27,28,29, 30,31,32,-1,-1,-1,-1,-1,
  -1,33,34,35,36,37,38,39, 40,41,42,43,-1,44,45,46,
  47,48,49,50,51,52,53,54, 55,56,57,-1,-1,-1,-1,-1,
};
static const char b58digits_ordered[] = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

static bool base58_encode(char *b58, size_t *b58sz, const char *data, size_t binsz)
{
  const uint8_t *bin = (const uint8_t*)data;
  int carry;
  int32_t i, j, high, zcount = 0;
  size_t size;

  while (zcount < (int32_t)binsz && !bin[zcount])
    ++zcount;

  size = (binsz - zcount) * 138 / 100 + 1;
  uint8_t buf[BASE58_DECODE_MAXLEN];
  memset(buf, 0, size);

  for (i = zcount, high = (int32_t)size - 1; i < (int32_t)binsz; ++i, high = j)
  {
    for (carry = bin[i], j = size - 1; (j > high) || carry; --j)
    {
      carry += 256 * buf[j];
      buf[j] = carry % 58;
      carry /= 58;
    }
  }

  for (j = 0; j < (int32_t)size && !buf[j]; ++j);

  if (*b58sz <= zcount + size - j)    {
    /* with the added size limit on encoded string, */
    /* this should never happen -- XXXXX remove the test? */
    *b58sz = zcount + size - j + 1;
    return false;
  }

  if (zcount)
    memset(b58, '1', zcount);
  for (i = zcount; j < (int32_t)size; ++i, ++j)
    b58[i] = b58digits_ordered[buf[j]];
  b58[i] = '\0';
  *b58sz = i + 1;

  return true;
}


static bool base58_decode(char *bin, size_t *binszp, const char *b58, size_t b58sz)
{
  size_t binsz = *binszp;
  const unsigned char *b58u = (const unsigned char*)b58;
  unsigned char *binu = (unsigned char*)bin;
  size_t outisz = BASE58_DECODE_MAXLEN / 4;
  uint32_t outi[BASE58_DECODE_MAXLEN / 4];
  uint64_t t;
  uint32_t c;
  size_t i, j;
  uint8_t bytesleft = binsz % 4;
  uint32_t zeromask = bytesleft ? (0xffffffff << (bytesleft * 8)) : 0;
  unsigned zerocount = 0;

  if (!b58sz)
    b58sz = strlen(b58);

  memset(outi, 0, outisz * sizeof(*outi));

  /* Leading zeros, just count */
  for (i = 0; i < b58sz && b58u[i] == '1'; ++i)
    ++zerocount;

  for ( ; i < b58sz; ++i)
  {
    if (b58u[i] & 0x80)
      /* High-bit set on invalid digit */
      return false;
    if (b58digits_map[b58u[i]] == -1)
      /* Invalid base58 digit */
      return false;
    c = (unsigned)b58digits_map[b58u[i]];
    for (j = outisz; j--; )
    {
      t = ((uint64_t)outi[j]) * 58 + c;
      c = (t & 0x3f00000000) >> 32;
      outi[j] = t & 0xffffffff;
    }
    if (c)
      /* Output number too big (carry to the next int32) */
      return false;
    if (outi[0] & zeromask)
      /* Output number too big (last int32 filled too far) */
      return false;
  }

  j = 0;
  switch (bytesleft) {
    case 3:
      *(binu++) = (outi[0] &   0xff0000) >> 16;
    /* fallthrough */
    case 2:
      *(binu++) = (outi[0] &     0xff00) >>  8;
    /* fallthrough */
    case 1:
      *(binu++) = (outi[0] &       0xff);
      ++j;
    /* fallthrough */
    default:
      break;
  }

  for (; j < outisz; ++j)
  {
    *(binu++) = (outi[j] >> 0x18) & 0xff;
    *(binu++) = (outi[j] >> 0x10) & 0xff;
    *(binu++) = (outi[j] >>    8) & 0xff;
    *(binu++) = (outi[j] >>    0) & 0xff;
  }

  /* Count canonical base58 byte count */
  binu = (unsigned char*)bin;
  for (i = 0; i < binsz; ++i)
  {
    if (binu[i])
      break;
    --*binszp;
  }
  *binszp += zerocount;

  return true;
}

/* Blake2b */

/* Blake2b context.  Do not rely on its contents or its size, they */
/* may change without notice. */
typedef struct {
  uint64_t hash[8];
  uint64_t input_offset[2];
  uint64_t input[16];
  size_t   input_idx;
  size_t   hash_size;
} blake2b_ctx;

static void blake2b_init(blake2b_ctx *ctx, size_t hash_size,
             const uint8_t      *key, size_t key_size);

static void blake2b_update(blake2b_ctx *ctx,
               const uint8_t *message, size_t message_size);

static void blake2b_final(blake2b_ctx *ctx, uint8_t *hash);

static uint64_t load64_le(const uint8_t s[8])
{
  return (uint64_t)s[0]
    | ((uint64_t)s[1] <<  8)
    | ((uint64_t)s[2] << 16)
    | ((uint64_t)s[3] << 24)
    | ((uint64_t)s[4] << 32)
    | ((uint64_t)s[5] << 40)
    | ((uint64_t)s[6] << 48)
    | ((uint64_t)s[7] << 56);
}

static void store64_le(uint8_t out[8], uint64_t in)
{
  out[0] =  in        & 0xff;
  out[1] = (in >>  8) & 0xff;
  out[2] = (in >> 16) & 0xff;
  out[3] = (in >> 24) & 0xff;
  out[4] = (in >> 32) & 0xff;
  out[5] = (in >> 40) & 0xff;
  out[6] = (in >> 48) & 0xff;
  out[7] = (in >> 56) & 0xff;
}

static uint64_t rotr64(uint64_t x, uint64_t n) { return (x >> n) ^ (x << (64 - n)); }

/* Blake2b (taken from the reference implentation in RFC 7693) */

static const uint64_t iv[8] = {
  0x6a09e667f3bcc908, 0xbb67ae8584caa73b,
  0x3c6ef372fe94f82b, 0xa54ff53a5f1d36f1,
  0x510e527fade682d1, 0x9b05688c2b3e6c1f,
  0x1f83d9abfb41bd6b, 0x5be0cd19137e2179,
};

/* increment the input offset */
static void blake2b_incr(blake2b_ctx *ctx)
{
  uint64_t   *x = ctx->input_offset;
  size_t y = ctx->input_idx;
  x[0] += y;
  if (x[0] < y) {
    x[1]++;
  }
}

static void blake2b_set_input(blake2b_ctx *ctx, uint8_t input)
{
  size_t word = ctx->input_idx / 8;
  size_t byte = ctx->input_idx % 8;
  ctx->input[word] |= (uint64_t)input << (byte * 8);
  ctx->input_idx++;
}

static void blake2b_compress(blake2b_ctx *ctx, int is_last_block)
{
  static const uint8_t sigma[12][16] = {
    {  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15 },
    { 14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3 },
    { 11,  8, 12,  0,  5,  2, 15, 13, 10, 14,  3,  6,  7,  1,  9,  4 },
    {  7,  9,  3,  1, 13, 12, 11, 14,  2,  6,  5, 10,  4,  0, 15,  8 },
    {  9,  0,  5,  7,  2,  4, 10, 15, 14,  1, 11, 12,  6,  8,  3, 13 },
    {  2, 12,  6, 10,  0, 11,  8,  3,  4, 13,  7,  5, 15, 14,  1,  9 },
    { 12,  5,  1, 15, 14, 13,  4, 10,  0,  7,  6,  3,  9,  2,  8, 11 },
    { 13, 11,  7, 14, 12,  1,  3,  9,  5,  0, 15,  4,  8,  6,  2, 10 },
    {  6, 15, 14,  9, 11,  3,  0,  8, 12,  2, 13,  7,  1,  4, 10,  5 },
    { 10,  2,  8,  4,  7,  6,  1,  5, 15, 11,  9, 14,  3, 12, 13,  0 },
    {  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15 },
    { 14, 10,  4,  8,  9, 15, 13,  6,  1, 12,  0,  2, 11,  7,  5,  3 },
  };

  /* init work vector */
  uint64_t v[16];
  size_t i;
  for (i = 0; i < 8; i++) {
    v[i  ] = ctx->hash[i];
    v[i+8] = iv[i];
  }
  v[12] ^= ctx->input_offset[0];
  v[13] ^= ctx->input_offset[1];
  if (is_last_block) {
    v[14] = ~v[14];
  }

  /* mangle work vector */
  uint64_t *input = ctx->input;
  for (i = 0; i < 12; i++) {
#define BLAKE2_G(v, a, b, c, d, x, y)                       \
    v[a] += v[b] + x;  v[d] = rotr64(v[d] ^ v[a], 32);  \
    v[c] += v[d];      v[b] = rotr64(v[b] ^ v[c], 24);  \
    v[a] += v[b] + y;  v[d] = rotr64(v[d] ^ v[a], 16);  \
    v[c] += v[d];      v[b] = rotr64(v[b] ^ v[c], 63);  \

    BLAKE2_G(v, 0, 4,  8, 12, input[sigma[i][ 0]], input[sigma[i][ 1]]);
    BLAKE2_G(v, 1, 5,  9, 13, input[sigma[i][ 2]], input[sigma[i][ 3]]);
    BLAKE2_G(v, 2, 6, 10, 14, input[sigma[i][ 4]], input[sigma[i][ 5]]);
    BLAKE2_G(v, 3, 7, 11, 15, input[sigma[i][ 6]], input[sigma[i][ 7]]);
    BLAKE2_G(v, 0, 5, 10, 15, input[sigma[i][ 8]], input[sigma[i][ 9]]);
    BLAKE2_G(v, 1, 6, 11, 12, input[sigma[i][10]], input[sigma[i][11]]);
    BLAKE2_G(v, 2, 7,  8, 13, input[sigma[i][12]], input[sigma[i][13]]);
    BLAKE2_G(v, 3, 4,  9, 14, input[sigma[i][14]], input[sigma[i][15]]);
  }
  /* update hash */
  for (i = 0; i < 8; i++) {
    ctx->hash[i] ^= v[i] ^ v[i+8];
  }
}

static void blake2b_reset_input(blake2b_ctx *ctx)
{
  size_t i;
  for(i = 0; i < 16; i++) {
    ctx->input[i] = 0;
  }
  ctx->input_idx = 0;
}

static void blake2b_end_block(blake2b_ctx *ctx)
{
  if (ctx->input_idx == 128) {  /* If buffer is full, */
    blake2b_incr(ctx);        /* update the input offset */
    blake2b_compress(ctx, 0); /* and compress the (not last) block */
    blake2b_reset_input(ctx);
  }
}

void blake2b_init(blake2b_ctx *ctx, size_t hash_size,
          const uint8_t           *key, size_t key_size)
{
  size_t i;
  /* initial hash */
  for (i = 0; i < 8; i++) {
    ctx->hash[i] = iv[i];
  }
  ctx->hash[0] ^= 0x01010000 ^ (key_size << 8) ^ hash_size;

  ctx->input_offset[0] = 0;         /* begining of the input, no offset */
  ctx->input_offset[1] = 0;         /* begining of the input, no offset */
  ctx->input_idx       = 0;         /* buffer is empty */
  ctx->hash_size       = hash_size; /* remember the hash size we want */
  blake2b_reset_input(ctx);         /* clear the input buffer */

  /* if there is a key, the first block is that key */
  if (key_size > 0) {
    blake2b_update(ctx, key, key_size);
    ctx->input_idx = 128;
  }
}

void blake2b_update(blake2b_ctx *ctx,
               const uint8_t *message, size_t message_size)
{
  /* Align ourselves with 8 byte words */
  while (ctx->input_idx % 8 != 0 && message_size > 0) {
    blake2b_set_input(ctx, *message);
    message++;
    message_size--;
  }

  /* Process the input 8 bytes at a time */
  size_t nb_words  = message_size / 8;
  size_t remainder = message_size % 8;
  size_t i;
  for (i = 0; i < nb_words; i++) {
    blake2b_end_block(ctx);
    ctx->input[ctx->input_idx / 8] = load64_le(message);
    message        += 8;
    ctx->input_idx += 8;
  }

  /* Load the remainder */
  if (remainder != 0) {
    blake2b_end_block(ctx);
  }
  for (i = 0; i < remainder; i++) {
    blake2b_set_input(ctx, message[i]);
  }
}

void blake2b_final(blake2b_ctx *ctx, uint8_t *hash)
{
  blake2b_incr(ctx);        /* update the input offset */
  blake2b_compress(ctx, 1); /* compress the last block */
  size_t nb_words  = ctx->hash_size / 8;
  size_t i;
  for (i = 0; i < nb_words; i++) {
    store64_le(hash + i*8, ctx->hash[i]);
  }
  for (i = nb_words * 8; i < ctx->hash_size; i++) {
    hash[i] = (ctx->hash[i / 8] >> (8 * (i % 8))) & 0xff;
  }
}

static void blake2b(uint8_t       *hash   , size_t hash_size,
       const uint8_t *key    , size_t key_size,
       const uint8_t *message, size_t message_size)
{
  blake2b_ctx ctx;
  blake2b_init(&ctx, hash_size, key, key_size);
  blake2b_update(&ctx, message, message_size);
  blake2b_final(&ctx, hash);
}

/* hasher *********************************************************************/

/* compability with lua 5.1 */
#if LUA_VERSION_NUM >= 502
#define new_lib(L, l) (luaL_newlib(L, l))
#else
#define new_lib(L, l) (lua_newtable(L), luaL_register(L, NULL, l))
#endif

static int lblake2b(lua_State *L) {
  /* compute the hash of a string */
  /* lua api:  blake2b(m [, digln [, key]]) return digest */
  /* m: the string to be hashed */
  /* digln: the optional length of the digest to be computed */
  /* (between 1 and 64) - default value is 64 */
  /* key: an optional secret key, allowing blake2b to work as a MAC */
  /*    (if provided, key length must be between 1 and 64) */
  /*    default is no key */
  /* digest: the blake2b hash as a string (string length is digln, */
  /* so default hash is a 64-byte string) */
  size_t mln;
  size_t keyln = 0;
  const char *m = luaL_checklstring(L, 1, &mln);
  int digln = luaL_optinteger(L, 2, 64);
  const char *key = luaL_optlstring(L, 3, NULL, &keyln);
  if(keyln > 64)
  luaL_error(L, "bad key size");
  if(digln < 1 || digln > 64)
  luaL_error(L, "bad digest size");
  char digest[64];
  blake2b(
  (uint8_t*)digest, digln,
  (const uint8_t*)key, keyln,
  (const uint8_t*)m, mln);
  lua_pushlstring(L, digest, digln);
  return 1;
}

static int lbase58_encode(lua_State *L) {
  /* lua api:  b58encode(str) => encoded | (nil, error msg) */
  /* prereq:  #str <= 256  (defined as BASE58_ENCODE_MAXLEN) */
  size_t bln, eln;
  char buf[BASE58_DECODE_MAXLEN];   /* buffer to receive encoded string */
  const char *b = luaL_checklstring(L,1,&bln);
  if (bln == 0) { /* empty string special case (not ok with b58enc) */
    lua_pushliteral(L, "");
    return 1;
  } else if (bln > BASE58_ENCODE_MAXLEN) {
    luaL_error(L, "string too long");
  }
  eln = BASE58_DECODE_MAXLEN; /* eln must be set to buffer size before calling b58enc */
  bool r = base58_encode(buf, &eln, b, bln);
  if(!r)
    luaL_error(L, "base58 encode error");
  eln = eln - 1;  /* b58enc add \0 at the end of the encode string */
  lua_pushlstring(L, buf, eln);
  return 1;
}

static int lbase58_decode(lua_State *L) {
  /* lua api: b58decode(encstr) => str | (nil, error msg) */
  size_t bln, eln;
  char buf[BASE58_DECODE_MAXLEN];   /* buffer to receive decoded string */
  const char *e = luaL_checklstring(L,1,&eln); /* encoded data */
  if (eln == 0) { /* empty string special case */
    lua_pushliteral(L, "");
    return 1;
  } else if (eln > BASE58_DECODE_MAXLEN) {
    lua_pushnil(L);
    lua_pushfstring(L, "string too long");
    return 2;
  }
  bln = BASE58_DECODE_MAXLEN;
  bool r = base58_decode(buf, &bln, e, eln);
  if (!r) {
    lua_pushnil(L);
    lua_pushfstring(L, "b58decode error");
    return 2;
  }
  /* base58_decode returns its result at the end of buf!!! */
  lua_pushlstring(L, buf + BASE58_DECODE_MAXLEN - bln, bln);
  return 1;
}

static const luaL_Reg hasherlib[] = {
  { "blake2b",  lblake2b },
  { "base58encode", lbase58_encode },
  { "base58decode", lbase58_decode },
  { NULL,   NULL  }
};

LUAMOD_API int luaopen_hasher(lua_State *L)
{
  new_lib(L, hasherlib);
  return 1;
}
