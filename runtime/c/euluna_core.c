#include "euluna_core.h"

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
    euluna_stdout_write_boolean((bool)a.value);
  } else if(a.type == &euluna_type_int) {
    fprintf(stdout, "%ti", (intptr_t)a.value);
  } else if(a.type == &euluna_type_int8) {
    fprintf(stdout, "%hhi", (int8_t)a.value);
  } else if(a.type == &euluna_type_int16) {
    fprintf(stdout, "%hi", (int16_t)a.value);
  } else if(a.type == &euluna_type_int32) {
    fprintf(stdout, "%i", (int32_t)a.value);
  } else if(a.type == &euluna_type_int64) {
    fprintf(stdout, "%li", (int64_t)a.value);
  } else if(a.type == &euluna_type_uint) {
    fprintf(stdout, "%tu", (uintptr_t)a.value);
  } else if(a.type == &euluna_type_uint8) {
    fprintf(stdout, "%hhu", (uint8_t)a.value);
  } else if(a.type == &euluna_type_uint16) {
    fprintf(stdout, "%hu", (uint16_t)a.value);
  } else if(a.type == &euluna_type_uint32) {
    fprintf(stdout, "%u", (uint32_t)a.value);
  } else if(a.type == &euluna_type_uint64) {
    fprintf(stdout, "%lu", (uint64_t)a.value);
  } else if(a.type == &euluna_type_float32) {
    fprintf(stdout, "%f", (float)a.value);
  } else if(a.type == &euluna_type_float64) {
    fprintf(stdout, "%lf", (double)a.value);
  } else if(a.type == &euluna_type_char) {
    fprintf(stdout, "%c", (char)a.value);
  } else if(a.type == &euluna_type_pointer) {
    fprintf(stdout, "%p", (void*)a.value);
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

void euluna_panic(const char *message) {
  fputs(message, stderr);
  fflush(stderr);
  exit(-1);
  EULUNA_UNREACHABLE;
}
