
#ifndef EULUNA_CORE_H
#define EULUNA_CORE_H

#include <stdbool.h>
#include <stdint.h>

/* defines */
#ifdef __GNUC__
#define EULUNA_UNREACHABLE  __builtin_unreachable()
#else
#define EULUNA_UNREACHABLE
#endif
#define EULUNA_NORETURN     __attribute__((noreturn))
#define EULUNA_LIKELY(x)    __builtin_expect(x, 1)
#define EULUNA_UNLIKELY(x)  __builtin_expect(x, 0)

/* basic types */
typedef struct euluna_type_t {
  char *name;
} euluna_type_t;

typedef struct euluna_any_t {
    euluna_type_t *type;
    uint64_t value;
} euluna_any_t;

typedef struct euluna_string_t {
    uintptr_t len;
    uintptr_t res;
    char data[];
} euluna_string_t;

/* runtime types */
extern euluna_type_t euluna_type_uint;
extern euluna_type_t euluna_type_uint8;
extern euluna_type_t euluna_type_uint16;
extern euluna_type_t euluna_type_uint32;
extern euluna_type_t euluna_type_uint64;
extern euluna_type_t euluna_type_int;
extern euluna_type_t euluna_type_int8;
extern euluna_type_t euluna_type_int16;
extern euluna_type_t euluna_type_int32;
extern euluna_type_t euluna_type_int64;
extern euluna_type_t euluna_type_float32;
extern euluna_type_t euluna_type_float64;
extern euluna_type_t euluna_type_boolean;
extern euluna_type_t euluna_type_string;
extern euluna_type_t euluna_type_char;
extern euluna_type_t euluna_type_pointer;

/* static builtins */
void euluna_stdout_write_string(const euluna_string_t* s);
void euluna_stdout_write_boolean(const bool b);
void euluna_stdout_write_any(const euluna_any_t a);
void euluna_stdout_write_newline();
void euluna_stdout_write(const char *message);
void euluna_stdout_write_format(char *format, ...);
void euluna_panic(const char* message) EULUNA_NORETURN;

/* inlined builtins */
static inline void euluna_check_type(euluna_type_t* a, euluna_type_t* b) {
  if(EULUNA_UNLIKELY(a != b)) {
    euluna_panic("type check fail");
    EULUNA_UNREACHABLE;
  }
}
static inline intptr_t euluna_cast_any_int(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_int);
  return (intptr_t)a.value;
}
static inline int8_t euluna_cast_any_int8(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_int8);
  return (int8_t)a.value;
}
static inline int16_t euluna_cast_any_int16(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_int16);
  return (int16_t)a.value;
}
static inline int32_t euluna_cast_any_int32(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_int32);
  return (int32_t)a.value;
}
static inline int64_t euluna_cast_any_int64(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_int64);
  return (int64_t)a.value;
}
static inline uintptr_t euluna_cast_any_uint(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_uint);
  return (uintptr_t)a.value;
}
static inline uint8_t euluna_cast_any_uint8(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_uint8);
  return (uint8_t)a.value;
}
static inline uint16_t euluna_cast_any_uint16(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_uint16);
  return (uint16_t)a.value;
}
static inline uint32_t euluna_cast_any_uint32(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_uint32);
  return (uint32_t)a.value;
}
static inline uint64_t euluna_cast_any_uint64(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_uint64);
  return (uint64_t)a.value;
}
static inline float euluna_cast_any_float32(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_float32);
  return (float)a.value;
}
static inline double euluna_cast_any_float64(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_float64);
  return (double)a.value;
}
static inline bool euluna_cast_any_boolean(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_boolean);
  return (bool)a.value;
}
static inline euluna_string_t* euluna_cast_any_string(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_string);
  return (euluna_string_t*)a.value;
}
static inline char euluna_cast_any_char(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_char);
  return (char)a.value;
}
static inline void* euluna_cast_any_pointer(const euluna_any_t a) {
  euluna_check_type(a.type, &euluna_type_pointer);
  return (void*)a.value;
}

#endif
