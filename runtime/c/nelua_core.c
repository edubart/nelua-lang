#include <stdio.h>
#include <stdlib.h>
{% if context.has_type then %}
nelua_type nelua_usize_type = {"usize"};
nelua_type nelua_uint8_type = {"uint8"};
nelua_type nelua_uint16_type = {"uint16"};
nelua_type nelua_uint32_type = {"uint32"};
nelua_type nelua_uint64_type = {"uint64"};
nelua_type nelua_isize_type = {"isize"};
nelua_type nelua_int8_type = {"int8"};
nelua_type nelua_int16_type = {"int16"};
nelua_type nelua_int32_type = {"int32"};
nelua_type nelua_int64_type = {"int64"};
nelua_type nelua_float32_type = {"float32"};
nelua_type nelua_float64_type = {"float64"};
nelua_type nelua_boolean_type = {"boolean"};
nelua_type nelua_string_type = {"string"};
nelua_type nelua_pointer_type = {"pointer"};
{% end %}
{% if context.builtins['stdout_write'] then %}
{% if context.has_string then %}
void nelua_stdout_write_string(const nelua_string s) {
  fwrite(s->data, s->len, 1, stdout);
}
{% end %}
void nelua_stdout_write_boolean(const bool b) {
  if(b)
    fwrite("true", 4, 1, stdout);
  else
    fwrite("false", 5, 1, stdout);
}
{% if context.has_any then %}
void nelua_stdout_write_any(const nelua_any a) {
  if(a.type == &nelua_boolean_type) {
    nelua_stdout_write_boolean(a.value.b);
  } else if(a.type == &nelua_isize_type) {
    fprintf(stdout, "%ti", a.value.i);
  } else if(a.type == &nelua_int8_type) {
    fprintf(stdout, "%hhi", a.value.i8);
  } else if(a.type == &nelua_int16_type) {
    fprintf(stdout, "%hi", a.value.i16);
  } else if(a.type == &nelua_int32_type) {
    fprintf(stdout, "%i", a.value.i32);
  } else if(a.type == &nelua_int64_type) {
    fprintf(stdout, "%li", a.value.i64);
  } else if(a.type == &nelua_usize_type) {
    fprintf(stdout, "%tu", a.value.u);
  } else if(a.type == &nelua_uint8_type) {
    fprintf(stdout, "%hhu", a.value.u8);
  } else if(a.type == &nelua_uint16_type) {
    fprintf(stdout, "%hu", a.value.u16);
  } else if(a.type == &nelua_uint32_type) {
    fprintf(stdout, "%u", a.value.u32);
  } else if(a.type == &nelua_uint64_type) {
    fprintf(stdout, "%lu", a.value.u64);
  } else if(a.type == &nelua_float32_type) {
    fprintf(stdout, "%f", a.value.f32);
  } else if(a.type == &nelua_float64_type) {
    fprintf(stdout, "%lf", a.value.f64);
  } else if(a.type == &nelua_pointer_type) {
    fprintf(stdout, "%p", a.value.p);
  } else {
    nelua_panic("invalid type for nelua_fwrite_any");
  }
}
{% end %}
void nelua_stdout_write(const char *message) {
  fputs(message, stdout);
}
void nelua_stdout_write_format(char *format, ...) {
  va_list args;
  va_start(args, format);
  vfprintf(stdout, format, args);
  va_end(args);
}
void nelua_stdout_write_newline() {
  fwrite("\n", 1, 1, stdout);
  fflush(stdout);
}
{% end %}
void nelua_panic(const char *message) {
  fputs(message, stderr);
  fputs("\n", stderr);
  fflush(stderr);
  exit(-1);
}
