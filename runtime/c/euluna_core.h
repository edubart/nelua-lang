#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include <string.h>
{% if context.has_math then %}
#include <math.h>
{% end %}
#define EULUNA_NORETURN     __attribute__((noreturn))
#define EULUNA_NOINLINE     __attribute__((noinline))
#define EULUNA_LIKELY(x)    __builtin_expect(x, 1)
#define EULUNA_UNLIKELY(x)  __builtin_expect(x, 0)
#define EULUNA_UNUSED(x)    (void)(x)
{% if context.has_type then %}
typedef struct euluna_type {
  char* name;
} euluna_type;
{% end %}
typedef struct euluna_string_object {
  intptr_t len;
  intptr_t res;
  char data[];
} euluna_string_object;
typedef euluna_string_object* euluna_string;
{% if context.has_any then %}
typedef struct euluna_any {
  euluna_type *type;
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
} euluna_any;
{% end %}
{% if context.has_type then %}
extern euluna_type euluna_isize_type;
extern euluna_type euluna_int8_type;
extern euluna_type euluna_int16_type;
extern euluna_type euluna_int32_type;
extern euluna_type euluna_int64_type;
extern euluna_type euluna_usize_type;
extern euluna_type euluna_uint8_type;
extern euluna_type euluna_uint16_type;
extern euluna_type euluna_uint32_type;
extern euluna_type euluna_uint64_type;
extern euluna_type euluna_float32_type;
extern euluna_type euluna_float64_type;
extern euluna_type euluna_boolean_type;
extern euluna_type euluna_string_type;
extern euluna_type euluna_pointer_type;
{% end %}
{% if context.builtins['stdout_write'] then %}
void euluna_stdout_write_string(const euluna_string s);
void euluna_stdout_write_boolean(const bool b);
{% if context.has_any then %}
void euluna_stdout_write_any(const euluna_any a);
{% end %}
void euluna_stdout_write_newline();
void euluna_stdout_write(const char *message);
void euluna_stdout_write_format(char *format, ...);
{% end %}
void euluna_panic(const char* message) EULUNA_NORETURN;
{% if context.builtins['assert'] then %}
static inline void euluna_assert(bool cond) {
  if(EULUNA_UNLIKELY(!cond))
    euluna_panic("assertion failed!");
}
{% end %}
{% if context.builtins['assert_message'] then %}
static inline void euluna_assert_message(bool cond, const euluna_string s) {
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
static inline intptr_t euluna_isize_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_isize_type);
  return a.value.i;
}
static inline int8_t euluna_int8_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_int8_type);
  return a.value.i8;
}
static inline int16_t euluna_int16_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_int16_type);
  return a.value.i16;
}
static inline int32_t euluna_int32_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_int32_type);
  return a.value.i32;
}
static inline int64_t euluna_int64_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_int64_type);
  return a.value.i64;
}
static inline uintptr_t euluna_usize_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_usize_type);
  return a.value.u;
}
static inline uint8_t euluna_uint8_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_uint8_type);
  return a.value.u8;
}
static inline uint16_t euluna_uint16_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_uint16_type);
  return a.value.u16;
}
static inline uint32_t euluna_uint32_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_uint32_type);
  return a.value.u32;
}
static inline uint64_t euluna_uint64_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_uint64_type);
  return a.value.u64;
}
static inline float euluna_float32_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_float32_type);
  return a.value.f32;
}
static inline double euluna_float64_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_float64_type);
  return a.value.f64;
}
static inline bool euluna_boolean_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_boolean_type);
  return a.value.b;
}
static inline euluna_string euluna_string_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_string_type);
  return a.value.s;
}
static inline void* euluna_pointer_any_cast(const euluna_any a) {
  euluna_check_type(a.type, &euluna_pointer_type);
  return a.value.p;
}
static inline bool euluna_any_to_boolean(const euluna_any a) {
  if(a.type == &euluna_boolean_type)
    return a.value.b;
  else if(a.type == &euluna_pointer_type)
    return a.value.p != NULL;
  else if(a.type == NULL)
    return false;
  return true;
}
{% end %}
