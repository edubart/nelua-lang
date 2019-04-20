#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include <string.h>
#define EULUNA_NORETURN     __attribute__((noreturn))
#define EULUNA_NOINLINE     __attribute__((noinline))
#define EULUNA_LIKELY(x)    __builtin_expect(x, 1)
#define EULUNA_UNLIKELY(x)  __builtin_expect(x, 0)
#define EULUNA_UNUSED(x)    (void)(x)
typedef intptr_t      euluna_int;
typedef int8_t        euluna_int8;
typedef int16_t       euluna_int16;
typedef int32_t       euluna_int32;
typedef int64_t       euluna_int64;
typedef uintptr_t     euluna_uint;
typedef uint8_t       euluna_uint8;
typedef uint16_t      euluna_uint16;
typedef uint32_t      euluna_uint32;
typedef uint64_t      euluna_uint64;
typedef float         euluna_float32;
typedef double        euluna_float64;
typedef bool          euluna_boolean;
typedef char          euluna_char;
typedef char*         euluna_cstring;
typedef void*         euluna_pointer;
{% if context.has_type then %}
typedef struct euluna_type {
  euluna_cstring name;
} euluna_type;
{% end %}
typedef struct euluna_string_object {
  euluna_int len;
  euluna_int res;
  euluna_char data[];
} euluna_string_object;
typedef euluna_string_object* euluna_string;
{% if context.has_any then %}
typedef struct euluna_any {
  euluna_type *type;
  union {
    euluna_int i;
    euluna_int8 i8;
    euluna_int16 i16;
    euluna_int32 i32;
    euluna_int64 i64;
    euluna_uint u;
    euluna_uint8 u8;
    euluna_uint16 u16;
    euluna_uint32 u32;
    euluna_uint64 u64;
    euluna_float32 f32;
    euluna_float64 f64;
    euluna_boolean b;
    euluna_string s;
    euluna_char c;
    euluna_pointer p;
  } value;
} euluna_any;
{% end %}
{% if context.has_type then %}
extern euluna_type euluna_int_type;
extern euluna_type euluna_int8_type;
extern euluna_type euluna_int16_type;
extern euluna_type euluna_int32_type;
extern euluna_type euluna_int64_type;
extern euluna_type euluna_uint_type;
extern euluna_type euluna_uint8_type;
extern euluna_type euluna_uint16_type;
extern euluna_type euluna_uint32_type;
extern euluna_type euluna_uint64_type;
extern euluna_type euluna_float32_type;
extern euluna_type euluna_float64_type;
extern euluna_type euluna_boolean_type;
extern euluna_type euluna_string_type;
extern euluna_type euluna_char_type;
extern euluna_type euluna_pointer_type;
{% end %}
{% if context.builtins['stdout_write'] then %}
void euluna_stdout_write_string(const euluna_string s);
void euluna_stdout_write_boolean(const euluna_boolean b);
{% if context.has_any then %}
void euluna_stdout_write_any(const euluna_any a);
{% end %}
void euluna_stdout_write_newline();
void euluna_stdout_write(const char *message);
void euluna_stdout_write_format(char *format, ...);
{% end %}
void euluna_panic(const char* message) EULUNA_NORETURN;
{% if context.builtins['assert'] then %}
static inline void euluna_assert(euluna_boolean cond) {
  if(EULUNA_UNLIKELY(!cond))
    euluna_panic("assertion failed!");
}
{% end %}
{% if context.builtins['assert_message'] then %}
static inline void euluna_assert_message(euluna_boolean cond, const euluna_string s) {
  if(EULUNA_UNLIKELY(!cond))
    euluna_panic(s->data);
}
{% end %}
{% if context.has_type then %}
static inline void euluna_check_type(euluna_type* a, euluna_type* b) {
  if(EULUNA_UNLIKELY(a != b)) {
    euluna_panic("type check fail");
  }
}
{% end %}
{% if context.has_any then %}
static inline euluna_int euluna_int_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_int_type);
  return a.value.i;
}
static inline euluna_int8 euluna_int8_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_int8_type);
  return a.value.i8;
}
static inline euluna_int16 euluna_int16_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_int16_type);
  return a.value.i16;
}
static inline euluna_int32 euluna_int32_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_int32_type);
  return a.value.i32;
}
static inline euluna_int64 euluna_int64_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_int64_type);
  return a.value.i64;
}
static inline euluna_uint euluna_uint_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_uint_type);
  return a.value.u;
}
static inline euluna_uint8 euluna_uint8_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_uint8_type);
  return a.value.u8;
}
static inline euluna_uint16 euluna_uint16_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_uint16_type);
  return a.value.u16;
}
static inline euluna_uint32 euluna_uint32_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_uint32_type);
  return a.value.u32;
}
static inline euluna_uint64 euluna_uint64_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_uint64_type);
  return a.value.u64;
}
static inline euluna_float32 euluna_float32_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_float32_type);
  return a.value.f32;
}
static inline euluna_float64 euluna_float64_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_float64_type);
  return a.value.f64;
}
static inline euluna_boolean euluna_boolean_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_boolean_type);
  return a.value.b;
}
static inline euluna_string euluna_string_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_string_type);
  return a.value.s;
}
static inline char euluna_char_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_char_type);
  return a.value.c;
}
static inline void* euluna_pointer_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_pointer_type);
  return a.value.p;
}
{% end %}
