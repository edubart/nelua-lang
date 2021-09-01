#define _POSIX_C_SOURCE 200112L

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <string.h>
#include <stdlib.h>

#ifndef _MSC_VER
  #include <unistd.h>
#else
  #include <io.h>
#endif

#if defined(_WIN32)
  #define WIN32_LEAN_AND_MEAN
  #include <windows.h>
#else
  #include <errno.h>
  #if defined (_POSIX_TIMERS) && _POSIX_TIMERS > 0
    #ifdef _POSIX_MONOTONIC_CLOCK
      #define HAVE_CLOCK_GETTIME
      #include <time.h>
    #else
      #warning "A nanosecond resolution monotonic clock is not available;"
      #warning "falling back to microsecond gettimeofday()"
      #include <sys/time.h>
    #endif
  #elif defined(__APPLE__) || defined(__MSDOS__)
    #include <sys/time.h>
  #endif
#endif

#if defined(_WIN32)

static int sys_nanotime(lua_State *L) {
  /* See http://msdn.microsoft.com/en-us/library/windows/desktop/dn553408(v=vs.85).aspx */
  LARGE_INTEGER timer;
  LARGE_INTEGER freq;
  static double multiplier;
  static int init = 1;

  /* Though bool, guaranteed to not return an error after WinXP,
    and the alternatives have fairly crappy resolution.
    However, if you're on XP, you've got bigger problems than timing.
  */
  (void) QueryPerformanceCounter(&timer);
  if(init){
    QueryPerformanceFrequency(&freq);
    multiplier = 1.0 / (double)freq.QuadPart;
    init = 0;
  }
  lua_pushnumber(L, (lua_Number)(timer.QuadPart * multiplier));
  return 1;
}

# else

static int sys_nanotime(lua_State *L) {
#ifdef HAVE_CLOCK_GETTIME
  /** From man clock_gettime(2)
     CLOCK_MONOTONIC
      Clock  that  cannot  be  set and represents monotonic time since
      some unspecified starting point.  This clock is not affected by
      discontinuous jumps in the system time (e.g., if the system
      administrator manually changes the clock), but is affected by the
      incremental  adjustments  performed by adjtime(3) and NTP.

     CLOCK_MONOTONIC_COARSE (since Linux 2.6.32; Linux-specific)
        A faster but less precise version of CLOCK_MONOTONIC.
        Use when you need very fast, but not fine-grained timestamps.

     CLOCK_MONOTONIC_RAW (since Linux 2.6.28; Linux-specific)
        Similar to CLOCK_MONOTONIC, but provides access to a raw
        hardware-based time that is not subject to NTP adjustments or the
        incremental adjustments performed by adjtime(3).
  */
  struct timespec t_info;
  const double multiplier = 1.0 / 1e9;

  if (clock_gettime(CLOCK_MONOTONIC, &t_info) != 0) {
    return luaL_error(L, "clock_gettime() failed:%s", strerror(errno));
  }
  lua_pushnumber(
    L,
    (lua_Number)t_info.tv_sec + (t_info.tv_nsec * multiplier)
  );
  return 1;
#else
  struct timeval t_info;
  if (gettimeofday(&t_info, NULL) < 0) {
    return luaL_error(L, "gettimeofday() failed!:%s", strerror(errno));
  };
  lua_pushnumber(L, (lua_Number)t_info.tv_sec + t_info.tv_usec / 1.e6);
  return 1;
#endif
}

#endif

static int sys_isatty(lua_State *L) {
  FILE **fp = (FILE **) luaL_checkudata(L, 1, LUA_FILEHANDLE);
  lua_pushboolean(L, isatty(fileno(*fp)));
  return 1;
}

#if defined(_MSC_VER) && defined(_M_X64)
  #include <intrin.h>
  #define SYS_RDTSC
#elif defined(__GNUC__) && defined(__x86_64__)
  #if defined(__has_include)
    #if __has_include(<x86intrin.h>)
      #include <x86intrin.h>
      #define SYS_RDTSC
    #endif
  #endif
#endif

#ifdef SYS_RDTSC
static int sys_rdtsc(lua_State *L) {
  lua_pushinteger(L, (lua_Integer)__rdtsc());
  return 1;
}
static int sys_rdtscp(lua_State *L) {
  unsigned int aux;
  lua_pushinteger(L, (lua_Integer)__rdtscp(&aux));
  return 1;
}
#endif

int sys_setenv(lua_State* L) {
  const char* name = luaL_checkstring(L, 1);
  const char* value = luaL_optstring(L, 2, NULL);
  int ok = 0;
#if defined(_WIN32)
  void* ud;
  lua_Alloc allocf = lua_getallocf(L, &ud);
  size_t len = strlen(name) + (value ? strlen(value) : 0) + 2; /* 1 for '\0', 1 for =. */
  char* var = (char*)allocf(ud, NULL, 0, len);
  if (var) {
    if (value) {
      snprintf(var, len, "%s=%s", name, value);
    } else {
      snprintf(var, len, "%s=", name);
    }
    /*
    _putenv was chosen over SetEnvironmentVariable because variables set
    with the latter seem to be invisible to getenv() calls and Lua uses
    these in the 'os' module.
    */
    ok = _putenv(var) == 0;
    allocf(ud, var, len, 0);
  }
#else
  if (value) {
    ok = setenv(name, value, 1) == 0;
  } else {
    ok = unsetenv(name) == 0;
  }
#endif
  lua_pushboolean(L, ok);
  return 1;
}

static const struct luaL_Reg sys_reg[] = {
  {"nanotime", sys_nanotime},
  {"isatty", sys_isatty},
  {"setenv", sys_setenv},
#ifdef SYS_RDTSC
  {"rdtsc", sys_rdtsc},
  {"rdtscp", sys_rdtscp},
#endif
  {NULL, NULL}
};

LUA_API int luaopen_sys(lua_State *L){
  luaL_newlib(L, sys_reg);
  return 1;
}
