#ifndef EULUNA_COMPILER
#include "euluna_core.h"
#endif

#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>

/* runtime types */
euluna_type_t euluna_type_uint = {"uint"};
euluna_type_t euluna_type_uint8 = {"uint8"};
euluna_type_t euluna_type_uint16 = {"uint16"};
euluna_type_t euluna_type_uint32 = {"uint32"};
euluna_type_t euluna_type_uint64 = {"uint64"};
euluna_type_t euluna_type_int = {"int"};
euluna_type_t euluna_type_int8 = {"int8"};
euluna_type_t euluna_type_int16 = {"int16"};
euluna_type_t euluna_type_int32 = {"int32"};
euluna_type_t euluna_type_int64 = {"int64"};
euluna_type_t euluna_type_float32 = {"float32"};
euluna_type_t euluna_type_float64 = {"float64"};
euluna_type_t euluna_type_boolean = {"boolean"};
euluna_type_t euluna_type_string = {"string"};
euluna_type_t euluna_type_char = {"char"};
euluna_type_t euluna_type_pointer = {"pointer"};

/* static builtins */
/* {% if context.builtins['stdout_write'] then %} */
void euluna_stdout_write_string(const euluna_string_t* s) {
  fwrite(s->data, s->len, 1, stdout);
}

void euluna_stdout_write_boolean(const bool b) {
  if(b)
    fwrite("true", 4, 1, stdout);
  else
    fwrite("false", 5, 1, stdout);
}

void euluna_stdout_write_any(const euluna_any_t a) {
  if(a.type == &euluna_type_boolean) {
    euluna_stdout_write_boolean(a.value.b);
  } else if(a.type == &euluna_type_int) {
    fprintf(stdout, "%ti", a.value.i);
  } else if(a.type == &euluna_type_int8) {
    fprintf(stdout, "%hhi", a.value.i8);
  } else if(a.type == &euluna_type_int16) {
    fprintf(stdout, "%hi", a.value.i16);
  } else if(a.type == &euluna_type_int32) {
    fprintf(stdout, "%i", a.value.i32);
  } else if(a.type == &euluna_type_int64) {
    fprintf(stdout, "%li", a.value.i64);
  } else if(a.type == &euluna_type_uint) {
    fprintf(stdout, "%tu", a.value.u);
  } else if(a.type == &euluna_type_uint8) {
    fprintf(stdout, "%hhu", a.value.u8);
  } else if(a.type == &euluna_type_uint16) {
    fprintf(stdout, "%hu", a.value.u16);
  } else if(a.type == &euluna_type_uint32) {
    fprintf(stdout, "%u", a.value.u32);
  } else if(a.type == &euluna_type_uint64) {
    fprintf(stdout, "%lu", a.value.u64);
  } else if(a.type == &euluna_type_float32) {
    fprintf(stdout, "%f", a.value.f32);
  } else if(a.type == &euluna_type_float64) {
    fprintf(stdout, "%lf", a.value.f64);
  } else if(a.type == &euluna_type_char) {
    fprintf(stdout, "%c", a.value.c);
  } else if(a.type == &euluna_type_pointer) {
    fprintf(stdout, "%p", a.value.p);
  } else {
    euluna_panic("invalid type for euluna_fwrite_any");
    EULUNA_UNREACHABLE;
  }
}

void euluna_stdout_write(const char *message) {
  fputs(message, stdout);
}

void euluna_stdout_write_format(char *format, ...)
{
  va_list args;
  va_start(args, format);
  vfprintf(stdout, format, args);
  va_end(args);
}

void euluna_stdout_write_newline() {
  fwrite("\n", 1, 1, stdout);
  fflush(stdout);
}
/* {% end %} */

void euluna_panic(const char *message) {
  fputs(message, stderr);
  fflush(stderr);
  exit(-1);
  EULUNA_UNREACHABLE;
}
