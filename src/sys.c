#define _POSIX_C_SOURCE 200112L

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#ifndef _MSC_VER
  #include <unistd.h>
#endif

#if defined(_WIN32)
  #define WIN32_LEAN_AND_MEAN
  #include <windows.h>
#else
  #include <errno.h>
  #include <string.h>
  #if defined (_POSIX_TIMERS) && _POSIX_TIMERS > 0
  #ifdef _POSIX_MONOTONIC_CLOCK
    #define HAVE_CLOCK_GETTIME
    #include <time.h>
  #else
    #warning "A nanosecond resolution monotonic clock is not available;"
    #warning "falling back to microsecond gettimeofday()"
    #include <sys/time.h>
  #endif
  #elif defined(__APPLE__)
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

static const struct luaL_Reg sys_reg[] = {
  {"nanotime", sys_nanotime},
  {"isatty", sys_isatty},
  {NULL, NULL}
};

LUA_API int luaopen_sys(lua_State *L){
  luaL_newlib(L, sys_reg);
  return 1;
}
