local tabler = require 'nelua.utils.tabler'

local cdefs = {}

cdefs.primitive_typenames = {
  nlisize       = {'intptr_t', '<stdint.h>'},
  nlint8        = {'int8_t', '<stdint.h>'},
  nlint16       = {'int16_t', '<stdint.h>'},
  nlint32       = {'int32_t', '<stdint.h>'},
  nlint64       = {'int64_t', '<stdint.h>'},
  nlint128      = '__int128',
  nlusize       = {'uintptr_t', '<stdint.h>'},
  nluint8       = {'uint8_t', '<stdint.h>'},
  nluint16      = {'uint16_t', '<stdint.h>'},
  nluint32      = {'uint32_t', '<stdint.h>'},
  nluint64      = {'uint64_t', '<stdint.h>'},
  nluint128     = 'unsigned __int128',
  nlfloat32     = 'float',
  nlfloat64     = 'double',
  nlfloat128    = '__float128',
  nlboolean     = {'bool', '<stdbool.h>'},
  nlcstring     = 'char*',
  nlpointer     = 'void*',
  nlnilptr      = 'void*',
  nlvoid        = 'void',
  -- C types
  nlcvalist     = {'va_list', '<stdarg.h>'},
  nlcvarargs    = '...',
  nlcchar       = 'char',
  nlcschar      = 'signed char',
  nlcshort      = 'short',
  nlcint        = 'int',
  nlclong       = 'long',
  nlclonglong   = 'long long',
  nlcptrdiff    = {'ptrdiff_t', '<stddef.h>'},
  nlcuchar      = 'unsigned char',
  nlcushort     = 'unsigned short',
  nlcuint       = 'unsigned int',
  nlculong      = 'unsigned long',
  nlculonglong  = 'unsigned long long',
  nlcsize       = {'size_t', '<stddef.h>'},
  nlclongdouble = 'long double',
  nlcclock_t    = {'clock_t', '<time.h>'},
  nlctime_t     = {'time_t', '<time.h>'},
  nlcwchar_t    = {'wchar_t', '<stddef.h>'},
}

cdefs.builtins_headers = {
  -- stddef.h
  NULL = '<stddef.h>',
  -- stdbool.h
  ["false"] = '<stdbool.h>',
  ["true"] = '<stdbool.h>',
  -- stdio.h
  fwrite = '<stdio.h>',
  fputs = '<stdio.h>',
  fprintf = '<stdio.h>', snprintf = '<stdio.h>',
  fflush = '<stdio.h>',
  stderr = '<stdio.h>', stdout = '<stdio.h>',
  -- stdlib.h
  abort = '<stdlib.h>',
  exit = '<stdlib.h>',
  -- string.h
  strlen = '<string.h>',
  memcmp = '<string.h>',
  -- math.h
  fmod = '<math.h>', fmodf = '<math.h>', fmodl = '<math.h>', fmodq = '<quadmath.h>',
  floor = '<math.h>', floorf = '<math.h>', floorl = '<math.h>', floorq = '<quadmath.h>',
  trunc = '<math.h>', truncf = '<math.h>', truncl = '<math.h>', truncq = '<quadmath.h>',
  pow = '<math.h>', powf = '<math.h>', powl = '<math.h>', powq = '<quadmath.h>',
  quadmath_snprintf = '<quadmath.h>',
}

local compilers_flags = {}
cdefs.compilers_flags = compilers_flags

-- Generic CC
compilers_flags.cc = {
  cflags_base = "",
  cflags_sanitize = "",
  cflags_devel = "",
  cflags_debug = "",
  cflags_release = "-O2 -DNDEBUG",
  cflags_maximum_performance = "-O3 -DNDEBUG",
  cflags_shared_lib = "-shared",
  cflags_assembly = "-S",
  cflags_object = "-c",
  cmd_compile = '$(cc) "$(cfile)" $(cflags) -o "$(binfile)"',
  cmd_info = '$(cc) -E "$(cfile)" $(cflags)',
  cmd_defines = '$(cc) -E -dM $(cflags) "$(cfile)"',
  ext = '.c',
}
-- GCC
compilers_flags.gcc = tabler.copyupdate(compilers_flags.cc, {
  cflags_base = "-fwrapv -fno-strict-aliasing",
  cflags_sanitize = "-Wall -Wextra -fsanitize=address,undefined",
  cflags_devel = "-g",
  cflags_debug = "-fsanitize-undefined-trap-on-error -ggdb",
  cflags_release = "-O2 -DNDEBUG",
  cflags_maximum_performance = "-Ofast -march=native -DNDEBUG -fno-plt -flto=auto",
  cflags_shared_lib = "-shared -fPIC",
  cflags_shared_lib_windows_msc = '-shared',
  cflags_shared_lib_windows_gcc = '-shared -Wl,--out-implib,"$(binfile).a"',
  cflags_assembly = "-S -fverbose-asm -g0",
  cmd_compile = '$(cc) -x c "$(cfile)" -x none $(cflags) -o "$(binfile)"',
  cmd_info = '$(cc) -E -x c "$(cfile)" -x none $(cflags)',
  cmd_defines = '$(cc) -E -dM -x c "$(cfile)" -x none $(cflags)',
})
-- Emscripten CC
compilers_flags.emcc = tabler.copyupdate(compilers_flags.gcc, {
  cflags_release = "-Oz -DNDEBUG",
  cflags_maximum_performance = "-O3 -ffast-math -DNDEBUG -fno-plt -flto",
})
-- Clang
compilers_flags.clang = tabler.copyupdate(compilers_flags.gcc, {
  cmd_compile = '$(cc) -x c "$(cfile)" -x none -Wno-unused-command-line-argument $(cflags) -o "$(binfile)"',
  cmd_info = '$(cc) -E -x c "$(cfile)" -x none -Wno-unused-command-line-argument $(cflags)',
  cmd_defines = '$(cc) -E -dM -x c "$(cfile)" -x none -Wno-unused-command-line-argument $(cflags)',
})
-- TCC
compilers_flags.tcc = tabler.copyupdate(compilers_flags.cc, {
  cflags_base = "-w",
  cflags_devel = "-g",
  cflags_debug = "-g",
})
-- C2M
compilers_flags.c2m = tabler.copyupdate(compilers_flags.cc, {
  cflags_base = "-w",
  cflags_shared_lib = "-c",
})
-- GCC (C++)
compilers_flags['g++'] = tabler.copyupdate(compilers_flags.gcc, {
  cmd_compile = '$(cc) -x c++ "$(cfile)" -x none $(cflags) -o "$(binfile)"',
  cmd_info = '$(cc) -E -x c++ "$(cfile)" -x none $(cflags)',
  cmd_defines = '$(cc) -E -dM -x c++ "$(cfile)" -x none $(cflags)',
  ext = '.cpp',
})
-- Clang (C++)
compilers_flags['clang++'] = tabler.copyupdate(compilers_flags['g++'], {
  cmd_compile = '$(cc) -x c++ "$(cfile)" -x none -Wno-unused-command-line-argument $(cflags) -o "$(binfile)"',
  cmd_info = '$(cc) -E -x c++ "$(cfile)" -x none -Wno-unused-command-line-argument $(cflags)',
  cmd_defines = '$(cc) -E -dM -x c++ "$(cfile)" -x none -Wno-unused-command-line-argument $(cflags)',
})
-- NVCC (CUDA C++)
compilers_flags['nvcc'] = tabler.copyupdate(compilers_flags.gcc, {
  cflags_base = "",
  cmd_compile = '$(cc) -x cu "$(cfile)" $(cflags) -o "$(binfile)"',
  cmd_info = '$(cc) -E -x cu "$(cfile)" $(cflags)',
  cmd_defines = '$(cc) -E -dM -x cu "$(cfile)" $(cflags)',
  ext = '.cu',
})
-- Zig CC
compilers_flags['zig cc'] = compilers_flags.clang

-- Code to detect target features.
cdefs.target_info_code = [[
/* OS */
#if !defined(_WIN32) && (defined(__unix__) || defined(__unix) || (defined(__APPLE__) && defined(__MACH__)))
  is_unix = true;
#endif
#if !defined(_WIN32) && (defined(__unix__) || defined(__unix) || \
                        (defined(__APPLE__) && defined(__MACH__)) || \
                        defined(__HAIKU__))
  is_posix = true;
#endif
#if defined(__linux__) || defined(__linux)
  is_linux = true;
#endif
#if defined(__gnu_linux__)
  is_gnu_linux = true;
#endif
#if defined(_WIN32)
  is_win32 = true;
  is_windows = true;
#endif
#if defined(_WIN64)
  is_win64 = true;
#endif
#if defined(__WINNT__) || defined(__WINNT)
  is_winnt = true;
#endif
#if defined(__DOS__) || defined(__DOS) || defined(_DOS)
  is_dos = true;
#endif
#if defined(__MSDOS__) || defined(__MSDOS)
  is_msdos = true;
#endif
#if defined(__APPLE__)
  is_apple = true;
  #include <TargetConditionals.h>
  #if defined(TARGET_OS_EMBEDDED)
    is_apple_embedded = true;
  #endif
  #if defined(TARGET_OS_IOS)
    is_ios = true;
  #endif
  #if defined(TARGET_OS_MAC)
    is_macos = true;
  #endif
  #if defined(TARGET_OS_MACCATALYST)
    is_catalyst = true;
    is_ios = true;
  #endif
  #if defined(TARGET_OS_IPHONE)
    is_iphone = true;
  #endif
  #if defined(TARGET_OS_TV)
    is_tvos = true;
  #endif
  #if defined(TARGET_OS_NANO) || defined(TARGET_OS_WATCH)
    is_watchos = true;
  #endif
  #if defined(TARGET_IPHONE_SIMULATOR) || defined(TARGET_OS_SIMULATOR)
    is_iphone_sim = true;
  #endif
  #if defined(TARGET_OS_BRIDGE)
    is_bridgeos = true;
  #endif
#endif
#if defined(__ANDROID__) || defined(ANDROID)
  is_android = true;
#endif
#if defined(__MACH__)
  is_mach = true;
#endif
#if defined(__hpux)
  is_hpux = true;
#endif
#if defined(__sgi__) || defined(__sgi)
  is_irix = true;
#endif
#if defined(__TIZEN__)
  is_tizen = true;
#endif
#if defined(__BLACKBERRY10__) || defined(__BB10__)
  is_bb10 = true;
  is_blackberry = true;
  is_qnx = true;
  is_qnxnto = true;
#endif
#if defined(__PLAYBOOK__)
  is_playbook = true;
  is_blackberry = true;
  is_qnx = true;
  is_qnxnto = true;
#endif
#if defined(__QNX__)
  is_qnx = true;
  is_blackberry = true;
#endif
#if defined(__QNXNTO__)
  is_qnx = true;
  is_qnxnto = true;
  is_blackberry = true;
#endif
#if defined(__WEBOS__)
  is_webos = true;
#endif
#if defined(__native_client__)
  is_nacl = true;
#endif
#if defined(WINAPI_FAMILY)
  #if (WINAPI_FAMILY == WINAPI_FAMILY_APP)
    is_uwp = true;
  #endif
  #if (WINAPI_FAMILY == WINAPI_FAMILY_PHONE_APP)
    is_windows_phone = true;
  #endif
#endif
#if defined(__GAMEBOY__)
  is_gameboy = true;
#endif
#if defined(__gba__) || defined(__GBA__)
  is_gba = true;
#endif
#if defined(__NDS__) || defined(_NDS)
  is_nds = true;
#endif
#if defined(__3DS__) || defined(_3DS)
  is_3ds = true;
#endif
#if defined(__SWITCH__) || defined(_SWITCH) || defined(__NX__)
  is_switch = true;
#endif
#if defined(__GAMECUBE__)
  is_gamecube = true;
#endif
#if defined(__WII__) || defined(_WII)
  is_wii = true;
#endif
#if defined(__WIIU__)
  is_wiiu = true;
#endif
#if defined(__PSX__) || defined(_PSX)
  is_ps1 = true;
#endif
#if defined(__PS2__) || defined(_PS2) || defined(__PLAYSTATION2__) || defined(SN_TARGET_PS2)
  is_ps2 = true;
#endif
#if defined(__PS3__) || defined(_PS3) || defined(SN_TARGET_PS3)
  is_ps3 = true;
#endif
#if defined(__PS4__) || defined(_PS4) || defined(__ORBIS__)
  is_ps4 = true;
#endif
#if defined(__PS5__) || defined(_PS5)
  is_ps5 = true;
#endif
#if defined(__PSP__) || defined(_PSP)
  is_psp = true;
#endif
#if defined(__VITA__) || defined(_PSVITA)
  is_psvita = true;
#endif
#if defined(__XBOX__) || defined(_XBOX)
  is_xbox = true;
#endif
#if defined(_X360) || defined(_XBOX360) || defined(__XBOX360__)
  is_xbox360 = true;
  is_xbox = true;
#endif
#if defined(_XBOXONE) || (defined(_XBOX_ONE) && defined(_TITLE)) || defined(_DURANGO)
  is_xbox_one = true;
  is_xbox = true;
#endif
#if defined(__BEOS__)
  is_beos = true;
#endif
#if defined(__HAIKU__)
  is_haiku = true;
  is_beos = true;
#endif
#if defined(__FreeBSD__)
  is_freebsd = true;
  is_bsd = true;
#endif
#if defined(__DragonFly__)
  is_dragonfly = true;
  is_bsd = true;
#endif
#if defined(__NetBSD__)
  is_netbsd = true;
  is_bsd = true;
#endif
#if defined(__OpenBSD__)
  is_openbsd = true;
  is_bsd = true;
#endif
#if defined(__bsdi__)
  is_bsd = true;
#endif
#if defined(__sun) && defined(__SVR4)
  is_solaris = true;
#endif

/* Compilers */
#if defined(__VERSION__)
  version = __VERSION__;
#endif
#if defined(__clang__)
  is_clang = true;
  clang_major = __clang_major__;
  clang_minor = __clang_minor__;
  clang_patchlevel = __clang_patchlevel__;
#endif
#if defined(__GNUC__)
  is_gcc = true;
  gnuc = __GNUC__;
  gnuc_minor = __GNUC_MINOR__;
  gnuc_patchlevel = __GNUC_PATCHLEVEL__;
#endif
#if defined(__MINGW64__) || defined(__MINGW32__)
  is_mingw = true;
#endif
#if defined(__CYGWIN__)
  is_cygwin = true;
#endif
#if defined(_MSC_VER)
  is_msc = true;
  msc_ver = _MSC_VER;
  msc_full_ver = _MSC_FULL_VER;
#endif
#if defined(__TINYC__)
  is_tcc = true;
  tinyc = __TINYC__;
#endif
#if defined(__EMSCRIPTEN__)
  is_emscripten = true;
  emscripten_major = __EMSCRIPTEN_major__;
  emscripten_minor = __EMSCRIPTEN_minor__;
  emscripten_tiny = __EMSCRIPTEN_tiny__;
#endif
#if defined(__MIRC__)
  is_mirc = true;
#endif
#if defined(__COMPCERT__)
  is_ccomp = true;
#endif
#if defined(__DJGPP__)
  is_djgpp = true;
#endif

/* Architectures */
#if defined(__wasm__) || defined(__wasm)
  is_wasm = true;
#endif
#if defined(__wasi__)
  is_wasi = true;
#endif
#if defined(__asmjs__)
  is_asmjs = true;
#endif
#if defined(__x86_64__) || defined(__x86_64) || \
    defined(__amd64__) || defined(__amd64) || \
    defined(_M_X64) || defined(_M_AMD64)
  is_x86_64 = true;
#endif
#if defined(__i386__) || defined(_M_X86)
  is_x86_32 = true;
#endif
#if defined(__arm__) || defined(_M_ARM)
  is_arm = true;
#endif
#if defined(__aarch64__) || defined(_M_ARM64)
  is_arm64 = true;
#endif
#if defined(__riscv)
  is_riscv = true;
#endif
#if defined(__AVR__) || defined(__AVR)
  is_avr = true;
#endif
#if defined(__powerpc__)
  is_powerpc = true;
#endif
#if defined(__mips__)
  is_mips = true;
#endif
#if defined(__sparc__)
  is_sparc = true;
#endif
#if defined(__s390__)
  is_s390 = true;
#endif
#if defined(__s390x__)
  is_s390x = true;
#endif

/* C standard */
#if defined(__STDC__)
  stdc = true;
#endif
#if __STDC_HOSTED__ > 0
  stdc_hosted = true;
#endif
#if defined(__STDC_VERSION__)
  is_c = true;
  stdc_version = __STDC_VERSION__;
#endif
#if __STDC_VERSION__ >= 201112L
  is_c11 = true;
#endif
#if defined(__STDC_NO_THREADS__)
  stdc_no_threads = true;
#endif
#if defined(__STDC_NO_ATOMICS__)
  stdc_no_atomics = true;
#endif
#if defined(__STDC_NO_COMPLEX__)
  stdc_no_complex = true;
#endif
#if defined(__STDC_NO_VLA__)
  stdc_no_vla = true;
#endif
#if defined(__cplusplus)
  is_cpp = true;
  cplusplus = __cplusplus;
#endif
#if __cplusplus >= 201103L
  is_cpp11 = true;
#endif
#if __cplusplus >= 202002L
  is_cpp20 = true;
#endif
#if __STDC_VERSION__ >= 201112L && !(defined(__STDC_NO_THREADS__) || \
                                     defined(__APPLE__) || \
                                     defined(__WIN32) || \
                                     defined(__HAIKU__))
  has_c11_threads = true;
#endif
#if (__STDC_VERSION__ >= 201112L || __cplusplus >= 202002L) && !defined(__STDC_NO_ATOMICS__)
  has_c11_atomics = true;
#endif

/* Primitive sizes */
#if defined(__CHAR_BIT__)
  char_bit = __CHAR_BIT__;
#endif
#if defined(__SIZEOF_DOUBLE__)
  sizeof_double = __SIZEOF_DOUBLE__;
#endif
#if defined(__SIZEOF_FLOAT__)
  sizeof_float = __SIZEOF_FLOAT__;
#endif
#if defined(__SIZEOF_INT__)
  sizeof_int = __SIZEOF_INT__;
#endif
#if defined(__SIZEOF_LONG_DOUBLE__)
  sizeof_long_double = __SIZEOF_LONG_DOUBLE__;
#endif
#if defined(__SIZEOF_LONG_LONG__)
  sizeof_long_long = __SIZEOF_LONG_LONG__;
#endif
#if defined(__SIZEOF_LONG__)
  sizeof_long = __SIZEOF_LONG__;
#endif
#if defined(__SIZEOF_POINTER__)
  sizeof_pointer = __SIZEOF_POINTER__;
#endif
#if defined(__SIZEOF_PTRDIFF_T__)
  sizeof_ptrdiff_t = __SIZEOF_PTRDIFF_T__;
#endif
#if defined(__SIZEOF_WCHAR_T__)
  sizeof_wchar_t = __SIZEOF_WCHAR_T__;
#endif
#if defined(__SIZEOF_SHORT__)
  sizeof_short = __SIZEOF_SHORT__;
#endif
#if defined(__SIZEOF_SIZE_T__)
  sizeof_size_t = __SIZEOF_SIZE_T__;
#endif
#if defined(__SIZEOF_FLOAT128__)
  sizeof_float128 = __SIZEOF_FLOAT128__;
  has_float128 = true;
#endif
#if defined(__SIZEOF_INT128__)
  sizeof_int128 = __SIZEOF_INT128__;
  has_int128 = true;
#endif

/* Float */
#if defined(__FLT_DECIMAL_DIG__)
  flt_decimal_dig = __FLT_DECIMAL_DIG__;
  flt_dig = __FLT_DIG__;
  flt_mant_dig = __FLT_MANT_DIG__;
#endif
#if defined(__DBL_DECIMAL_DIG__)
  dbl_decimal_dig = __DBL_DECIMAL_DIG__;
  dbl_dig = __DBL_DIG__;
  dbl_mant_dig = __DBL_MANT_DIG__;
#endif
#if defined(__DBL_DECIMAL_DIG__)
  ldbl_decimal_dig = __DBL_DECIMAL_DIG__;
  ldbl_dig = __LDBL_DIG__;
  ldbl_mant_dig = __LDBL_MANT_DIG__;
#endif
#if defined(__FLT128_DECIMAL_DIG__)
  flt128_decimal_dig = __FLT128_DECIMAL_DIG__;
  flt128_dig = __FLT128_DIG__;
  flt128_mant_dig = __FLT128_MANT_DIG__;
#endif

/* Features */
#if defined(__LP64__) || defined(__ILP64__) || defined(__LLP64__)
  is_64 = true;
#endif
#if defined(__LP32__) || defined(__ILP32__) || defined(__LLP32__)
  is_32 = true;
#endif
#if defined(__ELF__)
  is_elf = true;
#endif
#if defined(__OPTIMIZE__)
  is_optimize = true;
#endif
#if defined(__BYTE_ORDER__) && defined(__ORDER_LITTLE_ENDIAN__)
  #if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
    is_little_endian = true;
  #else
    is_big_endian = true;
  #endif
#endif
#if defined(__STDC_VERSION__) && !defined(__cplusplus) && \
    (defined(__GNUC__) || defined(__TINYC__) || defined(__MIRC__)) && \
    !defined(__PGIC__)
  is_empty_supported = true;
#endif

/* Alignment */
#if defined(__BIGGEST_ALIGNMENT__)
  biggest_alignment = __BIGGEST_ALIGNMENT__;
#endif
#if defined(__wasm__)
  alignof_long_long = 8;
  alignof_double = 8;
  alignof_long_double = 8;
  #define ALIGN_DETECTED
#elif defined(__LP32__) || defined(__ILP32__) || defined(__LLP32__)
  #if defined(_WIN32) || defined(__CYGWIN__)
    alignof_long_long = 8;
    alignof_double = 8;
    alignof_long_double = 4;
  #else
    alignof_long_long = 4;
    alignof_double = 4;
    alignof_long_double = 4;
  #endif
  #define ALIGN_DETECTED
#endif
#ifndef ALIGN_DETECTED
  #if defined(__SIZEOF_LONG_LONG__)
    alignof_long_long = __SIZEOF_LONG_LONG__;
  #endif
  #if defined(__SIZEOF_DOUBLE__)
    alignof_double = __SIZEOF_DOUBLE__;
  #endif
  #if __SIZEOF_LONG_DOUBLE__ >= 16
    alignof_long_double = 16;
  #elif __SIZEOF_LONG_DOUBLE__ >= 8
    alignof_long_double = 8;
  #elif __SIZEOF_LONG_DOUBLE__ >= 4
    alignof_long_double = 4;
  #endif
#endif
]]

cdefs.include_hooks = {
  ["@unistd.h"] = [[
/* Include basic POSIX constants and APIs */
#if !defined(_WIN32) && (defined(__unix__) || defined(__unix) || \
                        (defined(__APPLE__) && defined(__MACH__)) || \
                        defined(__HAIKU__))
  #include <unistd.h>
#endif
]],
  ["@windows.h"] = [[
/* Include Windows APIs. */
#ifdef _WIN32
  #ifndef WIN32_LEAN_AND_MEAN
    #define WIN32_LEAN_AND_MEAN
  #endif
  #ifndef _WIN32_WINNT
    #define _WIN32_WINNT 0x600
  #endif
  #include <windows.h>
#endif
]],
}
cdefs.reserverd_keywords = {
  -- C syntax keywords
  ['auto'] = true,
  ['break'] = true,
  ['case'] = true,
  ['char'] = true,
  ['const'] = true,
  ['continue'] = true,
  ['default'] = true,
  ['do'] = true,
  ['double'] = true,
  ['else'] = true,
  ['enum'] = true,
  ['extern'] = true,
  ['float'] = true,
  ['for'] = true,
  ['goto'] = true,
  ['if'] = true,
  ['int'] = true,
  ['long'] = true,
  ['register'] = true,
  ['return'] = true,
  ['short'] = true,
  ['signed'] = true,
  ['sizeof'] = true,
  ['static'] = true,
  ['struct'] = true,
  ['switch'] = true,
  ['typedef'] = true,
  ['union'] = true,
  ['unsigned'] = true,
  ['void'] = true,
  ['volatile'] = true,
  ['while'] = true,
  ['inline'] = true,
  ['restrict'] = true,

  -- C11
  ['_Bool'] = true,
  ['_Complex'] = true,
  ['_Imaginary'] = true,
  ['_Thread_local'] = true,
  ['_Atomic'] = true,
  ['_Alignas'] = true,
  ['_Alignof'] = true,
  ['_Noreturn'] = true,
  ['_Static_assert'] = true,

  -- C extensions
  ['asm'] = true,
  ['fortran'] = true,

  -- C aliases
  ['alignas'] = true,
  ['alignof'] = true,
  ['offsetof'] = true,
  ['complex'] = true,
  ['imaginary'] = true,
  ['noreturn'] = true,
  ['static_assert'] = true,
  ['thread_local'] = true,
  ['NULL'] = true,

  -- C stdbool.h
  ['bool'] = true,
  ['true'] = true,
  ['false'] = true,

  -- C stdarg.h
  ['va_start'] = true,
  ['va_arg'] = true,
  ['va_copy'] = true,
  ['va_end'] = true,
  ['va_list'] = true,

  -- C iso646.h
  ['and'] = true,
  ['and_eq'] = true,
  ['bitand'] = true,
  ['bitor'] = true,
  ['compl'] = true,
  ['not'] = true,
  ['not_eq'] = true,
  ['or'] = true,
  ['or_eq'] = true,
  ['xor'] = true,
  ['xor_eq'] = true,

  -- Common C platform defines
  ['linux'] = true,
  ['unix'] = true,
  ['WIN32'] = true,
  ['WIN64'] = true,
  ['WINNT'] = true,

  -- Common C APIs
  ['FILE'] = true,
  ['NAN'] = true,
  ['EOF'] = true,
  ['INFINITY'] = true,
  ['BUFSIZ'] = true,
  ['alloca'] = true,
  ['errno'] = true,
  ['stderr'] = true,
  ['stdin'] = true,
  ['stdout'] = true,
  ['assert'] = true,
}

cdefs.template = [[
/* ------------------------------ DIRECTIVES -------------------------------- */
$(directives)
/* ------------------------------ DECLARATIONS ------------------------------ */
$(declarations)
/* ------------------------------ DEFINITIONS ------------------------------- */
$(definitions)
]]

function cdefs.quotename(name)
  if cdefs.reserverd_keywords[name] then
    return name .. '_'
  end
  return name
end

return cdefs
