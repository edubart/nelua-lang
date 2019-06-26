#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
{% if context.has_math then %}
#include <math.h>
{% end %}
#define Nelua_NORETURN     __attribute__((noreturn))
#define Nelua_NOINLINE     __attribute__((noinline))
#define Nelua_LIKELY(x)    __builtin_expect(x, 1)
#define Nelua_UNLIKELY(x)  __builtin_expect(x, 0)
#define Nelua_UNUSED(x)    (void)(x)
{% if context.has_type then %}
typedef struct nelua_type {
  char* name;
} nelua_type;
{% end %}
{% if context.has_string then %}
typedef struct nelua_string_object {
  intptr_t len;
  intptr_t res;
  char data[];
} nelua_string_object;
typedef nelua_string_object* nelua_string;
static void nelua_panic_string(const nelua_string s) Nelua_NORETURN;
static inline bool nelua_string_eq(const nelua_string a, const nelua_string b) {
  return a->len == b->len && memcmp(a->data, b->data, a->len) == 0;
}
static inline bool nelua_string_ne(const nelua_string a, const nelua_string b) {
  return !nelua_string_eq(a, b);
}
{% if context.builtins['cstring2string'] then %}
static nelua_string nelua_cstring2string(const char *s);
{% end %}
{% end %}
{% if context.has_any then %}
typedef struct nelua_any {
  nelua_type *type;
  union {
    intptr_t i;
    int8_t i8;
    int16_t i16;
    int32_t i32;
    int64_t i64;
    uintptr_t u;
    uint8_t u8;
    uint16_t u16;
    uint32_t u32;
    uint64_t u64;
    float f32;
    double f64;
    bool b;
    char* s;
    void* p;
    char cc;
    signed char csc;
    short cs;
    int ci;
    long cl;
    long long cll;
    ptrdiff_t cpd;
    unsigned char cuc;
    unsigned short cus;
    unsigned int cui;
    unsigned long cul;
    unsigned long long cull;
    size_t csz;
  } value;
} nelua_any;
{% end %}
{% if context.has_type then %}
extern nelua_type nelua_isize_type;
extern nelua_type nelua_int8_type;
extern nelua_type nelua_int16_type;
extern nelua_type nelua_int32_type;
extern nelua_type nelua_int64_type;
extern nelua_type nelua_usize_type;
extern nelua_type nelua_uint8_type;
extern nelua_type nelua_uint16_type;
extern nelua_type nelua_uint32_type;
extern nelua_type nelua_uint64_type;
extern nelua_type nelua_float32_type;
extern nelua_type nelua_float64_type;
extern nelua_type nelua_boolean_type;
extern nelua_type nelua_string_type;
extern nelua_type nelua_pointer_type;
{% end %}
{% if context.builtins['stdout_write'] then %}
{% if context.has_string then %}
static void nelua_stdout_write_string(const nelua_string s);
{% end %}
static void nelua_stdout_write_boolean(const bool b);
{% if context.has_any then %}
static void nelua_stdout_write_any(const nelua_any a);
{% end %}
static void nelua_stdout_write_newline();
static void nelua_stdout_write(const char *message);
static void nelua_stdout_write_format(char *format, ...);
{% end %}
static void nelua_panic_cstring(const char* s) Nelua_NORETURN;
{% if context.builtins['assert'] then %}
static inline void nelua_assert(bool cond) {
  if(Nelua_UNLIKELY(!cond))
    nelua_panic_cstring("assertion failed!");
}
{% end %}
{% if context.builtins['assert_message'] then %}
static inline void nelua_assert_string(bool cond, const nelua_string s) {
  if(Nelua_UNLIKELY(!cond))
    nelua_panic_cstring(s->data);
}
{% end %}
static inline void nelua_assert_cstring(bool cond, const char* s) {
  if(Nelua_UNLIKELY(!cond))
    nelua_panic_cstring(s);
}
{% if context.has_type then %}
static inline void nelua_check_type(nelua_type* a, nelua_type* b) {
  if(Nelua_UNLIKELY(a != b)) {
    nelua_panic_cstring("type check fail");
  }
}
{% end %}
{% if context.has_any then %}
static inline intptr_t nelua_isize_any_cast(const nelua_any a) {
  nelua_check_type(a.type, &nelua_isize_type);
  return a.value.i;
}
static inline int8_t nelua_int8_any_cast(const nelua_any a) {
  nelua_check_type(a.type, &nelua_int8_type);
  return a.value.i8;
}
static inline int16_t nelua_int16_any_cast(const nelua_any a) {
  nelua_check_type(a.type, &nelua_int16_type);
  return a.value.i16;
}
static inline int32_t nelua_int32_any_cast(const nelua_any a) {
  nelua_check_type(a.type, &nelua_int32_type);
  return a.value.i32;
}
static inline int64_t nelua_int64_any_cast(const nelua_any a) {
  nelua_check_type(a.type, &nelua_int64_type);
  return a.value.i64;
}
static inline uintptr_t nelua_usize_any_cast(const nelua_any a) {
  nelua_check_type(a.type, &nelua_usize_type);
  return a.value.u;
}
static inline uint8_t nelua_uint8_any_cast(const nelua_any a) {
  nelua_check_type(a.type, &nelua_uint8_type);
  return a.value.u8;
}
static inline uint16_t nelua_uint16_any_cast(const nelua_any a) {
  nelua_check_type(a.type, &nelua_uint16_type);
  return a.value.u16;
}
static inline uint32_t nelua_uint32_any_cast(const nelua_any a) {
  nelua_check_type(a.type, &nelua_uint32_type);
  return a.value.u32;
}
static inline uint64_t nelua_uint64_any_cast(const nelua_any a) {
  nelua_check_type(a.type, &nelua_uint64_type);
  return a.value.u64;
}
static inline float nelua_float32_any_cast(const nelua_any a) {
  nelua_check_type(a.type, &nelua_float32_type);
  return a.value.f32;
}
static inline double nelua_float64_any_cast(const nelua_any a) {
  nelua_check_type(a.type, &nelua_float64_type);
  return a.value.f64;
}
static inline bool nelua_boolean_any_cast(const nelua_any a) {
  nelua_check_type(a.type, &nelua_boolean_type);
  return a.value.b;
}
static inline nelua_string nelua_string_any_cast(const nelua_any a) {
  nelua_check_type(a.type, &nelua_string_type);
  return a.value.s;
}
static inline void* nelua_pointer_any_cast(const nelua_any a) {
  nelua_check_type(a.type, &nelua_pointer_type);
  return a.value.p;
}
static inline bool nelua_any_to_boolean(const nelua_any a) {
  if(a.type == &nelua_boolean_type)
    return a.value.b;
  else if(a.type == &nelua_pointer_type)
    return a.value.p != NULL;
  else if(a.type == NULL)
    return false;
  return true;
}
{% end %}
{% if context.builtins['type_strings'] then %}
static const struct { uintptr_t len, res; char data[4]; } nelua_typestr_nil = {3,3,"nil"};
static const struct { uintptr_t len, res; char data[5]; } nelua_typestr_type = {4,4,"type"};
static const struct { uintptr_t len, res; char data[7]; } nelua_typestr_string = {6,6,"string"};
static const struct { uintptr_t len, res; char data[7]; } nelua_typestr_number = {6,6,"number"};
static const struct { uintptr_t len, res; char data[7]; } nelua_typestr_record = {6,6,"record"};
static const struct { uintptr_t len, res; char data[8]; } nelua_typestr_boolean = {7,7,"boolean"};
static const struct { uintptr_t len, res; char data[8]; } nelua_typestr_integer = {7,7,"integer"};
static const struct { uintptr_t len, res; char data[8]; } nelua_typestr_pointer = {7,7,"pointer"};
static const struct { uintptr_t len, res; char data[9]; } nelua_typestr_function = {8,8,"function"};
{% end %}
