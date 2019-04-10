#ifndef EULUNA_CORE_H
#define EULUNA_CORE_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdarg.h>
#include <string.h>

/* defines */
#define EULUNA_NORETURN     __attribute__((noreturn))
#define EULUNA_LIKELY(x)    __builtin_expect(x, 1)
#define EULUNA_UNLIKELY(x)  __builtin_expect(x, 0)
#define EULUNA_UNUSED(x)    (void)(x)

/* basic types */
typedef struct euluna_type_t {
  char *name;
} euluna_type_t;

typedef struct euluna_string_t {
  uintptr_t len;
  uintptr_t res;
  char data[];
} euluna_string_t;

typedef struct euluna_any_t {
  euluna_type_t *type;
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
    euluna_string_t* s;
    char c;
    void* p;
  } value;
} euluna_any_t;

/* runtime types */
extern euluna_type_t euluna_type_int;
extern euluna_type_t euluna_type_int8;
extern euluna_type_t euluna_type_int16;
extern euluna_type_t euluna_type_int32;
extern euluna_type_t euluna_type_int64;
extern euluna_type_t euluna_type_uint;
extern euluna_type_t euluna_type_uint8;
extern euluna_type_t euluna_type_uint16;
extern euluna_type_t euluna_type_uint32;
extern euluna_type_t euluna_type_uint64;
extern euluna_type_t euluna_type_float32;
extern euluna_type_t euluna_type_float64;
extern euluna_type_t euluna_type_boolean;
extern euluna_type_t euluna_type_string;
extern euluna_type_t euluna_type_char;
extern euluna_type_t euluna_type_pointer;

/* static builtins */
/* {% if context.builtins['stdout_write'] then %} */
void euluna_stdout_write_string(const euluna_string_t* s);
void euluna_stdout_write_boolean(const bool b);
void euluna_stdout_write_any(const euluna_any_t a);
void euluna_stdout_write_newline();
void euluna_stdout_write(const char *message);
void euluna_stdout_write_format(char *format, ...);
/* {% end %} */

void euluna_panic(const char* message) EULUNA_NORETURN;
/* {% if context.builtins['assert'] then %} */
static inline void euluna_assert(bool cond) {
  if(EULUNA_UNLIKELY(!cond))
    euluna_panic("assertion failed!");
}
/* {% end %} */
/* {% if context.builtins['assert_message'] then %} */
static inline void euluna_assert_message(bool cond, const euluna_string_t* s) {
  if(EULUNA_UNLIKELY(!cond))
    euluna_panic(s->data);
}
/* {% end %} */

/* inlined builtins */
static inline void euluna_check_type(euluna_type_t* a, euluna_type_t* b) {
  if(EULUNA_UNLIKELY(a != b)) {
    euluna_panic("type check fail");
  }
}

static inline intptr_t euluna_cast_any_int(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_int);
  return a.value.i;
}
static inline int8_t euluna_cast_any_int8(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_int8);
  return a.value.i8;
}
static inline int16_t euluna_cast_any_int16(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_int16);
  return a.value.i16;
}
static inline int32_t euluna_cast_any_int32(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_int32);
  return a.value.i32;
}
static inline int64_t euluna_cast_any_int64(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_int64);
  return a.value.i64;
}
static inline uintptr_t euluna_cast_any_uint(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_uint);
  return a.value.u;
}
static inline uint8_t euluna_cast_any_uint8(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_uint8);
  return a.value.u8;
}
static inline uint16_t euluna_cast_any_uint16(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_uint16);
  return a.value.u16;
}
static inline uint32_t euluna_cast_any_uint32(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_uint32);
  return a.value.u32;
}
static inline uint64_t euluna_cast_any_uint64(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_uint64);
  return a.value.u64;
}
static inline float euluna_cast_any_float32(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_float32);
  return a.value.f32;
}
static inline double euluna_cast_any_float64(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_float64);
  return a.value.f64;
}
static inline bool euluna_cast_any_boolean(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_boolean);
  return a.value.b;
}
static inline euluna_string_t* euluna_cast_any_string(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_string);
  return a.value.s;
}
static inline char euluna_cast_any_char(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_char);
  return a.value.c;
}
static inline void* euluna_cast_any_pointer(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_pointer);
  return a.value.p;
}

#endif
