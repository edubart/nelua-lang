---
layout: docs
title: C libraries
permalink: /clibraries/
categories: docs toc
toc: true
order: 5
---

Nelua provides bindings for common C functions according to the C11 specification.
This is a list of all imported C libraries.
{: .lead}

To use a C library, use `require 'C.stdlib'`{:.language-nelua} for example.
{: .callout.callout-info}

Nelua encourages you to use it's standard libraries instead of the C APIs,
these are provided just as convenience for interoperating with C libraries.
{:.alert.alert-info}

## C.arg

Library importing C's main `argc` and `argv`.

### C.argc

```nelua
global C.argc: cint
```



### C.argv

```nelua
global C.argv: *[0]cstring
```



---
## C.ctype

Library importing symbols from `<ctype.h>` header according to C11 spec.

For a complete documentation about the functions,
see [C ctype documentation](https://www.cplusplus.com/reference/cctype/).

### C.isalnum

```nelua
function C.isalnum(x: cint): cint
```



### C.isalpha

```nelua
function C.isalpha(x: cint): cint
```



### C.islower

```nelua
function C.islower(x: cint): cint
```



### C.isupper

```nelua
function C.isupper(x: cint): cint
```



### C.isdigit

```nelua
function C.isdigit(x: cint): cint
```



### C.isxdigit

```nelua
function C.isxdigit(x: cint): cint
```



### C.iscntrl

```nelua
function C.iscntrl(x: cint): cint
```



### C.isgraph

```nelua
function C.isgraph(x: cint): cint
```



### C.isspace

```nelua
function C.isspace(x: cint): cint
```



### C.isblank

```nelua
function C.isblank(x: cint): cint
```



### C.isprint

```nelua
function C.isprint(x: cint): cint
```



### C.ispunct

```nelua
function C.ispunct(x: cint): cint
```



### C.tolower

```nelua
function C.tolower(c: cint): cint
```



### C.toupper

```nelua
function C.toupper(c: cint): cint
```



---
## C.errno

Library that imports symbols from the `<errno.h>` header according to C11 specifications.

For a complete documentation about the functions,
see [C errno documentation](https://www.cplusplus.com/reference/cerrno/).

### C.errno

```nelua
global C.errno: cint
```



### C.EDOM

```nelua
global C.EDOM: cint
```



### C.EILSEQ

```nelua
global C.EILSEQ: cint
```



### C.ERANGE

```nelua
global C.ERANGE: cint
```



---
## C.locale

Library that imports symbols from the `<locale.h>` header according to C11 specifications.

For a complete documentation about the functions,
see [C locale documentation](https://www.cplusplus.com/reference/clocale/).

### C.lconv

```nelua
global C.lconv: type = @record{
  decimal_point: cstring,
  thousands_sep: cstring,
  grouping: cstring,
  int_curr_symbol: cstring,
  currency_symbol: cstring,
  mon_decimal_point: cstring,
  mon_thousands_sep: cstring,
  mon_grouping: cstring,
  positive_sign: cstring,
  negative_sign: cstring,
  int_frac_digits: cchar,
  frac_digits: cchar,
  p_cs_precedes: cchar,
  p_sep_by_space: cchar,
  n_cs_precedes: cchar,
  n_sep_by_space: cchar,
  p_sign_posn: cchar,
  n_sign_posn: cchar,
  int_p_cs_precedes: cchar,
  int_p_sep_by_space: cchar,
  int_n_cs_precedes: cchar,
  int_n_sep_by_space: cchar,
  int_p_sign_posn: cchar,
  int_n_sign_posn: cchar
}
```



### C.setlocale

```nelua
function C.setlocale(category: cint, locale: cstring): cstring
```



### C.localeconv

```nelua
function C.localeconv(): *C.lconv
```



### C.LC_ALL

```nelua
global C.LC_ALL: cint
```



### C.LC_COLLATE

```nelua
global C.LC_COLLATE: cint
```



### C.LC_CTYPE

```nelua
global C.LC_CTYPE: cint
```



### C.LC_MONETARY

```nelua
global C.LC_MONETARY: cint
```



### C.LC_NUMERIC

```nelua
global C.LC_NUMERIC: cint
```



### C.LC_TIME

```nelua
global C.LC_TIME: cint
```



---
## C.math

Library that imports symbols from the `<math.h>` header according to C11 specifications.

For a complete documentation about the functions,
see [C math documentation](https://www.cplusplus.com/reference/cmath/).

### C.fabs

```nelua
function C.fabs(x: float64): float64
```



### C.fabsf

```nelua
function C.fabsf(x: float32): float32
```



### C.fabsl

```nelua
function C.fabsl(x: clongdouble): clongdouble
```



### C.fmod

```nelua
function C.fmod(x: float64, y: float64): float64
```



### C.fmodf

```nelua
function C.fmodf(x: float32, y: float32): float32
```



### C.fmodl

```nelua
function C.fmodl(x: clongdouble, y: clongdouble): clongdouble
```



### C.remainder

```nelua
function C.remainder(x: float64, y: float64): float64
```



### C.remainderf

```nelua
function C.remainderf(x: float32, y: float32): float32
```



### C.remainderl

```nelua
function C.remainderl(x: clongdouble, y: clongdouble): clongdouble
```



### C.remquo

```nelua
function C.remquo(x: float64, y: float64, quo: *cint): float64
```



### C.remquof

```nelua
function C.remquof(x: float32, y: float32, quo: *cint): float32
```



### C.remquol

```nelua
function C.remquol(x: clongdouble, y: clongdouble, quo: *cint): clongdouble
```



### C.fma

```nelua
function C.fma(x: float64, y: float64, z: float64): float64
```



### C.fmaf

```nelua
function C.fmaf(x: float32, y: float32, z: float32): float32
```



### C.fmal

```nelua
function C.fmal(x: clongdouble, y: clongdouble, z: clongdouble): clongdouble
```



### C.fmax

```nelua
function C.fmax(x: float64, y: float64): float64
```



### C.fmaxf

```nelua
function C.fmaxf(x: float32, y: float32): float32
```



### C.fmaxl

```nelua
function C.fmaxl(x: clongdouble, y: clongdouble): clongdouble
```



### C.fmin

```nelua
function C.fmin(x: float64, y: float64): float64
```



### C.fminf

```nelua
function C.fminf(x: float32, y: float32): float32
```



### C.fminl

```nelua
function C.fminl(x: clongdouble, y: clongdouble): clongdouble
```



### C.fdim

```nelua
function C.fdim(x: float64, y: float64): float64
```



### C.fdimf

```nelua
function C.fdimf(x: float32, y: float32): float32
```



### C.fdiml

```nelua
function C.fdiml(x: clongdouble, y: clongdouble): clongdouble
```



### C.nan

```nelua
function C.nan(tagb: cstring): float64
```



### C.nanf

```nelua
function C.nanf(tagb: cstring): float32
```



### C.nanl

```nelua
function C.nanl(tagb: cstring): clongdouble
```



### C.exp

```nelua
function C.exp(x: float64): float64
```



### C.expf

```nelua
function C.expf(x: float32): float32
```



### C.expl

```nelua
function C.expl(x: clongdouble): clongdouble
```



### C.exp2

```nelua
function C.exp2(x: float64): float64
```



### C.exp2f

```nelua
function C.exp2f(x: float32): float32
```



### C.exp2l

```nelua
function C.exp2l(x: clongdouble): clongdouble
```



### C.expm1

```nelua
function C.expm1(x: float64): float64
```



### C.expm1f

```nelua
function C.expm1f(x: float32): float32
```



### C.expm1l

```nelua
function C.expm1l(x: clongdouble): clongdouble
```



### C.log

```nelua
function C.log(x: float64): float64
```



### C.logf

```nelua
function C.logf(x: float32): float32
```



### C.logl

```nelua
function C.logl(x: clongdouble): clongdouble
```



### C.log10

```nelua
function C.log10(x: float64): float64
```



### C.log10f

```nelua
function C.log10f(x: float32): float32
```



### C.log10l

```nelua
function C.log10l(x: clongdouble): clongdouble
```



### C.log1p

```nelua
function C.log1p(x: float64): float64
```



### C.log1pf

```nelua
function C.log1pf(x: float32): float32
```



### C.log1pl

```nelua
function C.log1pl(x: clongdouble): clongdouble
```



### C.log2

```nelua
function C.log2(x: float64): float64
```



### C.log2f

```nelua
function C.log2f(x: float32): float32
```



### C.log2l

```nelua
function C.log2l(x: clongdouble): clongdouble
```



### C.logb

```nelua
function C.logb(x: float64): float64
```



### C.logbf

```nelua
function C.logbf(x: float32): float32
```



### C.logbl

```nelua
function C.logbl(x: clongdouble): clongdouble
```



### C.pow

```nelua
function C.pow(x: float64, y: float64): float64
```



### C.powf

```nelua
function C.powf(x: float32, y: float32): float32
```



### C.powl

```nelua
function C.powl(x: clongdouble, y: clongdouble): clongdouble
```



### C.sqrt

```nelua
function C.sqrt(x: float64): float64
```



### C.sqrtf

```nelua
function C.sqrtf(x: float32): float32
```



### C.sqrtl

```nelua
function C.sqrtl(x: clongdouble): clongdouble
```



### C.cbrt

```nelua
function C.cbrt(x: float64): float64
```



### C.cbrtf

```nelua
function C.cbrtf(x: float32): float32
```



### C.cbrtl

```nelua
function C.cbrtl(x: clongdouble): clongdouble
```



### C.hypot

```nelua
function C.hypot(x: float64, y: float64): float64
```



### C.hypotf

```nelua
function C.hypotf(x: float32, y: float32): float32
```



### C.hypotl

```nelua
function C.hypotl(x: clongdouble, y: clongdouble): clongdouble
```



### C.cos

```nelua
function C.cos(x: float64): float64
```



### C.cosf

```nelua
function C.cosf(x: float32): float32
```



### C.cosl

```nelua
function C.cosl(x: clongdouble): clongdouble
```



### C.sin

```nelua
function C.sin(x: float64): float64
```



### C.sinf

```nelua
function C.sinf(x: float32): float32
```



### C.sinl

```nelua
function C.sinl(x: clongdouble): clongdouble
```



### C.tan

```nelua
function C.tan(x: float64): float64
```



### C.tanf

```nelua
function C.tanf(x: float32): float32
```



### C.tanl

```nelua
function C.tanl(x: clongdouble): clongdouble
```



### C.acos

```nelua
function C.acos(x: float64): float64
```



### C.acosf

```nelua
function C.acosf(x: float32): float32
```



### C.acosl

```nelua
function C.acosl(x: clongdouble): clongdouble
```



### C.asin

```nelua
function C.asin(x: float64): float64
```



### C.asinf

```nelua
function C.asinf(x: float32): float32
```



### C.asinl

```nelua
function C.asinl(x: clongdouble): clongdouble
```



### C.atan

```nelua
function C.atan(x: float64): float64
```



### C.atanf

```nelua
function C.atanf(x: float32): float32
```



### C.atanl

```nelua
function C.atanl(x: clongdouble): clongdouble
```



### C.atan2

```nelua
function C.atan2(y: float64, x: float64): float64
```



### C.atan2f

```nelua
function C.atan2f(y: float32, x: float32): float32
```



### C.atan2l

```nelua
function C.atan2l(y: clongdouble, x: clongdouble): clongdouble
```



### C.cosh

```nelua
function C.cosh(x: float64): float64
```



### C.coshf

```nelua
function C.coshf(x: float32): float32
```



### C.coshl

```nelua
function C.coshl(x: clongdouble): clongdouble
```



### C.sinh

```nelua
function C.sinh(x: float64): float64
```



### C.sinhf

```nelua
function C.sinhf(x: float32): float32
```



### C.sinhl

```nelua
function C.sinhl(x: clongdouble): clongdouble
```



### C.tanh

```nelua
function C.tanh(x: float64): float64
```



### C.tanhf

```nelua
function C.tanhf(x: float32): float32
```



### C.tanhl

```nelua
function C.tanhl(x: clongdouble): clongdouble
```



### C.acosh

```nelua
function C.acosh(x: float64): float64
```



### C.acoshf

```nelua
function C.acoshf(x: float32): float32
```



### C.acoshl

```nelua
function C.acoshl(x: clongdouble): clongdouble
```



### C.asinh

```nelua
function C.asinh(x: float64): float64
```



### C.asinhf

```nelua
function C.asinhf(x: float32): float32
```



### C.asinhl

```nelua
function C.asinhl(x: clongdouble): clongdouble
```



### C.atanh

```nelua
function C.atanh(x: float64): float64
```



### C.atanhf

```nelua
function C.atanhf(x: float32): float32
```



### C.atanhl

```nelua
function C.atanhl(x: clongdouble): clongdouble
```



### C.erf

```nelua
function C.erf(x: float64): float64
```



### C.erff

```nelua
function C.erff(x: float32): float32
```



### C.erfl

```nelua
function C.erfl(x: clongdouble): clongdouble
```



### C.erfc

```nelua
function C.erfc(x: float64): float64
```



### C.erfcf

```nelua
function C.erfcf(x: float32): float32
```



### C.erfcl

```nelua
function C.erfcl(x: clongdouble): clongdouble
```



### C.tgamma

```nelua
function C.tgamma(x: float64): float64
```



### C.tgammaf

```nelua
function C.tgammaf(x: float32): float32
```



### C.tgammal

```nelua
function C.tgammal(x: clongdouble): clongdouble
```



### C.lgamma

```nelua
function C.lgamma(x: float64): float64
```



### C.lgammaf

```nelua
function C.lgammaf(x: float32): float32
```



### C.lgammal

```nelua
function C.lgammal(x: clongdouble): clongdouble
```



### C.ceil

```nelua
function C.ceil(x: float64): float64
```



### C.ceilf

```nelua
function C.ceilf(x: float32): float32
```



### C.ceill

```nelua
function C.ceill(x: clongdouble): clongdouble
```



### C.floor

```nelua
function C.floor(x: float64): float64
```



### C.floorf

```nelua
function C.floorf(x: float32): float32
```



### C.floorl

```nelua
function C.floorl(x: clongdouble): clongdouble
```



### C.trunc

```nelua
function C.trunc(x: float64): float64
```



### C.truncf

```nelua
function C.truncf(x: float32): float32
```



### C.truncl

```nelua
function C.truncl(x: clongdouble): clongdouble
```



### C.round

```nelua
function C.round(x: float64): float64
```



### C.roundf

```nelua
function C.roundf(x: float32): float32
```



### C.roundl

```nelua
function C.roundl(x: clongdouble): clongdouble
```



### C.lround

```nelua
function C.lround(x: float64): clong
```



### C.lroundf

```nelua
function C.lroundf(x: float32): clong
```



### C.lroundl

```nelua
function C.lroundl(x: clongdouble): clong
```



### C.llround

```nelua
function C.llround(x: float64): clonglong
```



### C.llroundf

```nelua
function C.llroundf(x: float32): clonglong
```



### C.llroundl

```nelua
function C.llroundl(x: clongdouble): clonglong
```



### C.rint

```nelua
function C.rint(x: float64): float64
```



### C.rintf

```nelua
function C.rintf(x: float32): float32
```



### C.rintl

```nelua
function C.rintl(x: clongdouble): clongdouble
```



### C.lrint

```nelua
function C.lrint(x: float64): clong
```



### C.lrintf

```nelua
function C.lrintf(x: float32): clong
```



### C.lrintl

```nelua
function C.lrintl(x: clongdouble): clong
```



### C.llrint

```nelua
function C.llrint(x: float64): clonglong
```



### C.llrintf

```nelua
function C.llrintf(x: float32): clonglong
```



### C.llrintl

```nelua
function C.llrintl(x: clongdouble): clonglong
```



### C.nearbyint

```nelua
function C.nearbyint(x: float64): float64
```



### C.nearbyintf

```nelua
function C.nearbyintf(x: float32): float32
```



### C.nearbyintl

```nelua
function C.nearbyintl(x: clongdouble): clongdouble
```



### C.frexp

```nelua
function C.frexp(x: float64, exponent: *cint): float64
```



### C.frexpf

```nelua
function C.frexpf(x: float32, exponent: *cint): float32
```



### C.frexpl

```nelua
function C.frexpl(x: clongdouble, exponent: *cint): clongdouble
```



### C.ldexp

```nelua
function C.ldexp(x: float64, exponent: cint): float64
```



### C.ldexpf

```nelua
function C.ldexpf(x: float32, exponent: cint): float32
```



### C.ldexpl

```nelua
function C.ldexpl(x: clongdouble, exponent: cint): clongdouble
```



### C.modf

```nelua
function C.modf(x: float64, iptr: *float64): float64
```



### C.modff

```nelua
function C.modff(x: float32, iptr: *float32): float32
```



### C.modfl

```nelua
function C.modfl(x: clongdouble, iptr: *clongdouble): clongdouble
```



### C.scalbln

```nelua
function C.scalbln(x: float64, n: clong): float64
```



### C.scalblnf

```nelua
function C.scalblnf(x: float32, n: clong): float32
```



### C.scalblnl

```nelua
function C.scalblnl(x: clongdouble, n: clong): clongdouble
```



### C.scalbn

```nelua
function C.scalbn(x: float64, n: cint): float64
```



### C.scalbnf

```nelua
function C.scalbnf(x: float32, n: cint): float32
```



### C.scalbnl

```nelua
function C.scalbnl(x: clongdouble, n: cint): clongdouble
```



### C.ilogb

```nelua
function C.ilogb(x: float64): cint
```



### C.ilogbf

```nelua
function C.ilogbf(x: float32): cint
```



### C.ilogbl

```nelua
function C.ilogbl(x: clongdouble): cint
```



### C.nextafter

```nelua
function C.nextafter(x: float64, y: float64): float64
```



### C.nextafterf

```nelua
function C.nextafterf(x: float32, y: float32): float32
```



### C.nextafterl

```nelua
function C.nextafterl(x: clongdouble, y: clongdouble): clongdouble
```



### C.nexttoward

```nelua
function C.nexttoward(x: float64, y: clongdouble): float64
```



### C.nexttowardf

```nelua
function C.nexttowardf(x: float32, y: clongdouble): float32
```



### C.nexttowardl

```nelua
function C.nexttowardl(x: clongdouble, y: clongdouble): clongdouble
```



### C.copysign

```nelua
function C.copysign(x: float64, y: float64): float64
```



### C.copysignf

```nelua
function C.copysignf(x: float32, y: float32): float32
```



### C.copysignl

```nelua
function C.copysignl(x: clongdouble, y: clongdouble): clongdouble
```



### C.fpclassify

```nelua
function C.fpclassify(x: float64): cint
```



### C.fpclassifyf

```nelua
function C.fpclassifyf(x: float32): cint
```



### C.fpclassifyl

```nelua
function C.fpclassifyl(x: clongdouble): cint
```



### C.isfinite

```nelua
function C.isfinite(x: float64): cint
```



### C.isfinitef

```nelua
function C.isfinitef(x: float32): cint
```



### C.isfinitel

```nelua
function C.isfinitel(x: clongdouble): cint
```



### C.isinf

```nelua
function C.isinf(x: float64): cint
```



### C.isinff

```nelua
function C.isinff(x: float32): cint
```



### C.isinfl

```nelua
function C.isinfl(x: clongdouble): cint
```



### C.isnan

```nelua
function C.isnan(x: float64): cint
```



### C.isnanf

```nelua
function C.isnanf(x: float32): cint
```



### C.isnanl

```nelua
function C.isnanl(x: clongdouble): cint
```



### C.isnormal

```nelua
function C.isnormal(x: float64): cint
```



### C.isnormalf

```nelua
function C.isnormalf(x: float32): cint
```



### C.isnormall

```nelua
function C.isnormall(x: clongdouble): cint
```



### C.signbit

```nelua
function C.signbit(x: float64): cint
```



### C.signbitf

```nelua
function C.signbitf(x: float32): cint
```



### C.signbitl

```nelua
function C.signbitl(x: clongdouble): cint
```



### C.isgreater

```nelua
function C.isgreater(x: float64, y: float64): cint
```



### C.isgreaterf

```nelua
function C.isgreaterf(x: float32, y: float32): cint
```



### C.isgreaterl

```nelua
function C.isgreaterl(x: clongdouble, y: clongdouble): cint
```



### C.isgreaterequal

```nelua
function C.isgreaterequal(x: float64, y: float64): cint
```



### C.isgreaterequalf

```nelua
function C.isgreaterequalf(x: float32, y: float32): cint
```



### C.isgreaterequall

```nelua
function C.isgreaterequall(x: clongdouble, y: clongdouble): cint
```



### C.isless

```nelua
function C.isless(x: float64, y: float64): cint
```



### C.islessf

```nelua
function C.islessf(x: float32, y: float32): cint
```



### C.islessl

```nelua
function C.islessl(x: clongdouble, y: clongdouble): cint
```



### C.islessequal

```nelua
function C.islessequal(x: float64, y: float64): cint
```



### C.islessequalf

```nelua
function C.islessequalf(x: float32, y: float32): cint
```



### C.islessequall

```nelua
function C.islessequall(x: clongdouble, y: clongdouble): cint
```



### C.islessgreater

```nelua
function C.islessgreater(x: float64, y: float64): cint
```



### C.islessgreaterf

```nelua
function C.islessgreaterf(x: float32, y: float32): cint
```



### C.islessgreaterl

```nelua
function C.islessgreaterl(x: clongdouble, y: clongdouble): cint
```



### C.isunordered

```nelua
function C.isunordered(x: float64, y: float64): cint
```



### C.isunorderedf

```nelua
function C.isunorderedf(x: float32, y: float32): cint
```



### C.isunorderedl

```nelua
function C.isunorderedl(x: clongdouble, y: clongdouble): cint
```



### C.HUGE_VALF

```nelua
global C.HUGE_VALF: float32
```



### C.HUGE_VAL

```nelua
global C.HUGE_VAL: float64
```



### C.HUGE_VALL

```nelua
global C.HUGE_VALL: clongdouble
```



### C.INFINITY

```nelua
global C.INFINITY: cfloat
```



### C.NAN

```nelua
global C.NAN: cfloat
```



### C.FP_FAST_FMAF

```nelua
global C.FP_FAST_FMAF: float32
```



### C.FP_FAST_FMA

```nelua
global C.FP_FAST_FMA: float64
```



### C.FP_FAST_FMAL

```nelua
global C.FP_FAST_FMAL: clongdouble
```



### C.FP_ILOGB0

```nelua
global C.FP_ILOGB0: cint
```



### C.FP_ILOGBNAN

```nelua
global C.FP_ILOGBNAN: cint
```



### C.math_errhandling

```nelua
global C.math_errhandling: cint
```



### C.MATH_ERRNO

```nelua
global C.MATH_ERRNO: cint
```



### C.MATH_ERREXCEPT

```nelua
global C.MATH_ERREXCEPT: cint
```



### C.FP_NORMAL

```nelua
global C.FP_NORMAL: cint
```



### C.FP_SUBNORMAL

```nelua
global C.FP_SUBNORMAL: cint
```



### C.FP_ZERO

```nelua
global C.FP_ZERO: cint
```



### C.FP_INFINITE

```nelua
global C.FP_INFINITE: cint
```



### C.FP_NAN

```nelua
global C.FP_NAN: cint
```



---
## C.signal

Library that imports symbols from the `<signal.h>` header according to C11 specifications.

For a complete documentation about the functions,
see [C signal documentation](https://www.cplusplus.com/reference/csignal/).

### C.signal

```nelua
function C.signal(sig: cint, handler: function(cint)): function(cint): void
```



### C.raise

```nelua
function C.raise(sig: cint): cint
```



### C.SIG_DFL

```nelua
global C.SIG_DFL: function(cint): void
```



### C.SIG_IGN

```nelua
global C.SIG_IGN: function(cint): void
```



### C.SIG_ERR

```nelua
global C.SIG_ERR: function(cint): void
```



### C.SIGTERM

```nelua
global C.SIGTERM: cint
```



### C.SIGSEGV

```nelua
global C.SIGSEGV: cint
```



### C.SIGINT

```nelua
global C.SIGINT: cint
```



### C.SIGILL

```nelua
global C.SIGILL: cint
```



### C.SIGABRT

```nelua
global C.SIGABRT: cint
```



### C.SIGFPE

```nelua
global C.SIGFPE: cint
```



---
## C.stdarg

Library that imports symbols from the `<stdarg.h>` header according to C11 specifications.

For a complete documentation about the functions,
see [C stdarg documentation](https://www.cplusplus.com/reference/cstdarg/).

### C.va_start

```nelua
function C.va_start(ap: cvalist, paramN: auto): void
```



### C.va_end

```nelua
function C.va_end(ap: cvalist): void
```



### C.va_arg

```nelua
function C.va_arg(ap: *cvalist, T: type): auto
```



---
## C.stdio

Library that imports symbols from the `<stdio.h>` header according to C11 specifications.

For a complete documentation about the functions,
see [C stdio documentation](https://www.cplusplus.com/reference/cstdio/).

### C.FILE

```nelua
global C.FILE: type = @record{}
```



### C.fpos_t

```nelua
global C.fpos_t: type = @record{}
```



### C.remove

```nelua
function C.remove(filename: cstring): cint
```



### C.rename

```nelua
function C.rename(old: cstring, new: cstring): cint
```



### C.tmpfile

```nelua
function C.tmpfile(): *C.FILE
```



### C.tmpnam

```nelua
function C.tmpnam(s: cstring): cstring
```



### C.fclose

```nelua
function C.fclose(stream: *C.FILE): cint
```



### C.fflush

```nelua
function C.fflush(stream: *C.FILE): cint
```



### C.fopen

```nelua
function C.fopen(filename: cstring, modes: cstring): *C.FILE
```



### C.freopen

```nelua
function C.freopen(filename: cstring, modes: cstring, stream: *C.FILE): *C.FILE
```



### C.setbuf

```nelua
function C.setbuf(stream: *C.FILE, buf: cstring): void
```



### C.setvbuf

```nelua
function C.setvbuf(stream: *C.FILE, buf: cstring, modes: cint, n: csize): cint
```



### C.scanf

```nelua
function C.scanf(format: cstring, ...: cvarargs): cint
```



### C.fscanf

```nelua
function C.fscanf(stream: *C.FILE, format: cstring, ...: cvarargs): cint
```



### C.sscanf

```nelua
function C.sscanf(s: cstring, format: cstring, ...: cvarargs): cint
```



### C.vscanf

```nelua
function C.vscanf(format: cstring, arg: cvalist): cint
```



### C.vfscanf

```nelua
function C.vfscanf(stream: *C.FILE, format: cstring, arg: cvalist): cint
```



### C.vsscanf

```nelua
function C.vsscanf(s: cstring, format: cstring, arg: cvalist): cint
```



### C.printf

```nelua
function C.printf(format: cstring, ...: cvarargs): cint
```



### C.fprintf

```nelua
function C.fprintf(stream: *C.FILE, format: cstring, ...: cvarargs): cint
```



### C.sprintf

```nelua
function C.sprintf(s: cstring, format: cstring, ...: cvarargs): cint
```



### C.snprintf

```nelua
function C.snprintf(s: cstring, maxlen: csize, format: cstring, ...: cvarargs): cint
```



### C.vprintf

```nelua
function C.vprintf(format: cstring, arg: cvalist): cint
```



### C.vfprintf

```nelua
function C.vfprintf(stream: *C.FILE, format: cstring, arg: cvalist): cint
```



### C.vsprintf

```nelua
function C.vsprintf(s: cstring, format: cstring, arg: cvalist): cint
```



### C.vsnprintf

```nelua
function C.vsnprintf(s: cstring, maxlen: csize, format: cstring, arg: cvalist): cint
```



### C.getc

```nelua
function C.getc(stream: *C.FILE): cint
```



### C.putc

```nelua
function C.putc(c: cint, stream: *C.FILE): cint
```



### C.getchar

```nelua
function C.getchar(): cint
```



### C.putchar

```nelua
function C.putchar(c: cint): cint
```



### C.fgetc

```nelua
function C.fgetc(stream: *C.FILE): cint
```



### C.fputc

```nelua
function C.fputc(c: cint, stream: *C.FILE): cint
```



### C.fgets

```nelua
function C.fgets(s: cstring, n: cint, stream: *C.FILE): cstring
```



### C.fputs

```nelua
function C.fputs(s: cstring, stream: *C.FILE): cint
```



### C.gets

```nelua
function C.gets(s: cstring): cstring
```



### C.puts

```nelua
function C.puts(s: cstring): cint
```



### C.ungetc

```nelua
function C.ungetc(c: cint, stream: *C.FILE): cint
```



### C.fread

```nelua
function C.fread(ptr: pointer, size: csize, n: csize, stream: *C.FILE): csize
```



### C.fwrite

```nelua
function C.fwrite(ptr: pointer, size: csize, n: csize, sream: pointer): csize
```



### C.fgetpos

```nelua
function C.fgetpos(stream: *C.FILE, pos: *C.fpos_t): cint
```



### C.fsetpos

```nelua
function C.fsetpos(stream: *C.FILE, pos: *C.fpos_t): cint
```



### C.fseek

```nelua
function C.fseek(stream: *C.FILE, off: clong, whence: cint): cint
```



### C.ftell

```nelua
function C.ftell(stream: *C.FILE): clong
```



### C.rewind

```nelua
function C.rewind(stream: *C.FILE): void
```



### C.clearerr

```nelua
function C.clearerr(stream: *C.FILE): void
```



### C.feof

```nelua
function C.feof(stream: *C.FILE): cint
```



### C.ferror

```nelua
function C.ferror(stream: *C.FILE): cint
```



### C.perror

```nelua
function C.perror(s: cstring): void
```



### C.stdin

```nelua
global C.stdin: *C.FILE
```



### C.stdout

```nelua
global C.stdout: *C.FILE
```



### C.stderr

```nelua
global C.stderr: *C.FILE
```



### C.EOF

```nelua
global C.EOF: cint
```



### C.BUFSIZ

```nelua
global C.BUFSIZ: cint
```



### C.FOPEN_MAX

```nelua
global C.FOPEN_MAX: cint
```



### C.FILENAME_MAX

```nelua
global C.FILENAME_MAX: cint
```



### C._IOFBF

```nelua
global C._IOFBF: cint
```



### C._IOLBF

```nelua
global C._IOLBF: cint
```



### C._IONBF

```nelua
global C._IONBF: cint
```



### C.SEEK_SET

```nelua
global C.SEEK_SET: cint
```



### C.SEEK_CUR

```nelua
global C.SEEK_CUR: cint
```



### C.SEEK_END

```nelua
global C.SEEK_END: cint
```



### C.TMP_MAX

```nelua
global C.TMP_MAX: cint
```



### C.L_tmpnam

```nelua
global C.L_tmpnam: cint
```



---
## C.stdlib

Library that imports symbols from the `<stdlib.h>` header according to C11 specifications.

For a complete documentation about the functions,
see [C stdlib documentation](https://www.cplusplus.com/reference/cstdlib/).

### C.div_t

```nelua
global C.div_t: type = @record{quot: cint, rem: cint}
```



### C.ldiv_t

```nelua
global C.ldiv_t: type = @record{quot: cint, rem: cint}
```



### C.lldiv_t

```nelua
global C.lldiv_t: type = @record{quot: cint, rem: cint}
```



### C.malloc

```nelua
function C.malloc(size: csize): pointer
```



### C.calloc

```nelua
function C.calloc(nmemb: csize, size: csize): pointer
```



### C.realloc

```nelua
function C.realloc(ptr: pointer, size: csize): pointer
```



### C.free

```nelua
function C.free(ptr: pointer): void
```



### C.aligned_alloc

```nelua
function C.aligned_alloc(alignment: csize, size: csize): pointer
```



### C.abort

```nelua
function C.abort(): void
```



### C.exit

```nelua
function C.exit(status: cint): void
```



### C.quick_exit

```nelua
function C.quick_exit(status: cint): void
```



### C._Exit

```nelua
function C._Exit(status: cint): void
```



### C.atexit

```nelua
function C.atexit(func: pointer): cint
```



### C.at_quick_exit

```nelua
function C.at_quick_exit(func: pointer): cint
```



### C.system

```nelua
function C.system(command: cstring): cint
```



### C.getenv

```nelua
function C.getenv(name: cstring): cstring
```



### C.bsearch

```nelua
function C.bsearch(key: pointer, base: pointer, nmemb: csize, size: csize, compar: function(pointer, pointer): cint): pointer
```



### C.qsort

```nelua
function C.qsort(base: pointer, nmemb: csize, size: csize, compar: function(pointer, pointer): cint): void
```



### C.rand

```nelua
function C.rand(): cint
```



### C.srand

```nelua
function C.srand(seed: cuint): void
```



### C.atof

```nelua
function C.atof(nptr: cstring): float64
```



### C.atoi

```nelua
function C.atoi(nptr: cstring): cint
```



### C.atol

```nelua
function C.atol(nptr: cstring): clong
```



### C.atoll

```nelua
function C.atoll(nptr: cstring): clonglong
```



### C.strtof

```nelua
function C.strtof(nptr: cstring, endptr: *cstring): float32
```



### C.strtod

```nelua
function C.strtod(nptr: cstring, endptr: *cstring): float64
```



### C.strtold

```nelua
function C.strtold(nptr: cstring, endptr: *cstring): clongdouble
```



### C.strtol

```nelua
function C.strtol(nptr: cstring, endptr: *cstring, base: cint): clong
```



### C.strtoll

```nelua
function C.strtoll(nptr: cstring, endptr: *cstring, base: cint): clonglong
```



### C.strtoul

```nelua
function C.strtoul(nptr: cstring, endptr: *cstring, base: cint): culong
```



### C.strtoull

```nelua
function C.strtoull(nptr: cstring, endptr: *cstring, base: cint): culonglong
```



### C.abs

```nelua
function C.abs(x: cint): cint
```



### C.labs

```nelua
function C.labs(x: clong): clong
```



### C.llabs

```nelua
function C.llabs(x: clonglong): clonglong
```



### C.div

```nelua
function C.div(numer: cint, denom: cint): C.div_t
```



### C.ldiv

```nelua
function C.ldiv(numer: clong, denom: clong): C.ldiv_t
```



### C.lldiv

```nelua
function C.lldiv(numer: clonglong, denom: clonglong): C.lldiv_t
```



### C.EXIT_SUCCESS

```nelua
global C.EXIT_SUCCESS: cint
```



### C.EXIT_FAILURE

```nelua
global C.EXIT_FAILURE: cint
```



### C.RAND_MAX

```nelua
global C.RAND_MAX: cint
```



---
## C.string

Library that imports symbols from the `<string.h>` header according to C11 specifications.

For a complete documentation about the functions,
see [C string documentation](https://www.cplusplus.com/reference/cstring/).

### C.memcpy

```nelua
function C.memcpy(dest: pointer, src: pointer, n: csize): pointer
```



### C.memmove

```nelua
function C.memmove(dest: pointer, src: pointer, n: csize): pointer
```



### C.memccpy

```nelua
function C.memccpy(dest: pointer, src: pointer, c: cint, n: csize): pointer
```



### C.memset

```nelua
function C.memset(s: pointer, c: cint, n: csize): pointer
```



### C.memcmp

```nelua
function C.memcmp(s1: pointer, s2: pointer, n: csize): cint
```



### C.memchr

```nelua
function C.memchr(s: pointer, c: cint, n: csize): pointer
```



### C.strcpy

```nelua
function C.strcpy(dest: cstring, src: cstring): cstring
```



### C.strncpy

```nelua
function C.strncpy(dest: cstring, src: cstring, n: csize): cstring
```



### C.strcat

```nelua
function C.strcat(dest: cstring, src: cstring): cstring
```



### C.strncat

```nelua
function C.strncat(dest: cstring, src: cstring, n: csize): cstring
```



### C.strcmp

```nelua
function C.strcmp(s1: cstring, s2: cstring): cint
```



### C.strncmp

```nelua
function C.strncmp(s1: cstring, s2: cstring, n: csize): cint
```



### C.strcoll

```nelua
function C.strcoll(s1: cstring, s2: cstring): cint
```



### C.strxfrm

```nelua
function C.strxfrm(dest: cstring, src: cstring, n: csize): csize
```



### C.strchr

```nelua
function C.strchr(s: cstring, c: cint): cstring
```



### C.strrchr

```nelua
function C.strrchr(s: cstring, c: cint): cstring
```



### C.strcspn

```nelua
function C.strcspn(s: cstring, reject: cstring): csize
```



### C.strspn

```nelua
function C.strspn(s: cstring, accept: cstring): csize
```



### C.strpbrk

```nelua
function C.strpbrk(s: cstring, accept: cstring): cstring
```



### C.strstr

```nelua
function C.strstr(haystack: cstring, needle: cstring): cstring
```



### C.strlen

```nelua
function C.strlen(s: cstring): csize
```



### C.strerror

```nelua
function C.strerror(errnum: cint): cstring
```



---
## C.time

Library that imports symbols from the `<time.h>` header according to C11 specifications.

For a complete documentation about the functions,
see [C time documentation](https://www.cplusplus.com/reference/ctime/).

### C.clock_t

```nelua
global C.clock_t: type
```



### C.time_t

```nelua
global C.time_t: type
```



### C.tm

```nelua
global C.tm: type = @record{
  tm_sec: cint,
  tm_min: cint,
  tm_hour: cint,
  tm_mday: cint,
  tm_mon: cint,
  tm_year: cint,
  tm_wday: cint,
  tm_yday: cint,
  tm_isdst: cint
}
```



### C.timespec

```nelua
global C.timespec: type = @record{
  tv_sec: C.time_t,
  tv_nsec: clong
}
```



### C.clock

```nelua
function C.clock(): C.clock_t
```



### C.difftime

```nelua
function C.difftime(time1: C.time_t, time0: C.time_t): float64
```



### C.mktime

```nelua
function C.mktime(tp: *C.tm): C.time_t
```



### C.strftime

```nelua
function C.strftime(s: cstring, maxsize: csize, format: cstring, tp: *C.tm): csize
```



### C.time

```nelua
function C.time(timer: *C.time_t): C.time_t
```



### C.asctime

```nelua
function C.asctime(tp: *C.tm): cstring
```



### C.ctime

```nelua
function C.ctime(timer: *C.time_t): cstring
```



### C.gmtime

```nelua
function C.gmtime(timer: *C.time_t): *C.tm
```



### C.localtime

```nelua
function C.localtime(timer: *C.time_t): *C.tm
```



### C.timespec_get

```nelua
function C.timespec_get(ts: *C.timespec, base: cint): cint
```



### C.CLOCKS_PER_SEC

```nelua
global C.CLOCKS_PER_SEC: C.clock_t
```



### C.TIME_UTC

```nelua
global C.TIME_UTC: cint
```



---
## C.threads

Library that imports symbols from the `<threads.h>` header according to C11 specifications.

For a complete documentation about the functions,
see [C11 threads documentation](https://en.cppreference.com/w/c/thread).

### C.tss_dtor_t

```nelua
global C.tss_dtor_t: type = @function(pointer): void
```



### C.thrd_start_t

```nelua
global C.thrd_start_t: type = @function(pointer): cint
```



### C.tss_t

```nelua
global C.tss_t: type = @record{}
```



### C.thrd_t

```nelua
global C.thrd_t: type = @record{}
```



### C.once_flag

```nelua
global C.once_flag: type = @record{}
```



### C.mtx_t

```nelua
global C.mtx_t: type = @record{}
```



### C.cnd_t

```nelua
global C.cnd_t: type = @record{}
```



### C.thrd_create

```nelua
function C.thrd_create(thr: *C.thrd_t, func: C.thrd_start_t, arg: pointer): cint
```



### C.thrd_equal

```nelua
function C.thrd_equal(lhs: C.thrd_t, rhs: C.thrd_t): cint
```



### C.thrd_current

```nelua
function C.thrd_current(): C.thrd_t
```



### C.thrd_sleep

```nelua
function C.thrd_sleep(time_point: *C.timespec, remaining: *C.timespec): cint
```



### C.thrd_exit

```nelua
function C.thrd_exit(res: cint)
```



### C.thrd_detach

```nelua
function C.thrd_detach(thr: C.thrd_t): cint
```



### C.thrd_join

```nelua
function C.thrd_join(thr: C.thrd_t, res: *cint): cint
```



### C.thrd_yield

```nelua
function C.thrd_yield()
```



### C.mtx_init

```nelua
function C.mtx_init(mutex: *C.mtx_t, type: cint): cint
```



### C.mtx_lock

```nelua
function C.mtx_lock(mutex: *C.mtx_t): cint
```



### C.mtx_timedlock

```nelua
function C.mtx_timedlock(mutex: *C.mtx_t, time_point: *C.timespec): cint
```



### C.mtx_trylock

```nelua
function C.mtx_trylock(mutex: *C.mtx_t): cint
```



### C.mtx_unlock

```nelua
function C.mtx_unlock(mutex: *C.mtx_t): cint
```



### C.mtx_destroy

```nelua
function C.mtx_destroy(mutex: *C.mtx_t): void
```



### C.call_once

```nelua
function C.call_once(flag: *C.once_flag, func: function(): void)
```



### C.cnd_init

```nelua
function C.cnd_init(cond: *C.cnd_t): cint
```



### C.cnd_signal

```nelua
function C.cnd_signal(cond: *C.cnd_t): cint
```



### C.cnd_broadcast

```nelua
function C.cnd_broadcast(cond: *C.cnd_t): cint
```



### C.cnd_wait

```nelua
function C.cnd_wait(cond: *C.cnd_t, mutex: *C.mtx_t): cint
```



### C.cnd_timedwait

```nelua
function C.cnd_timedwait(cond: *C.cnd_t, mutex: *C.mtx_t, time_point: *C.timespec): cint
```



### C.cnd_destroy

```nelua
function C.cnd_destroy(COND: *C.cnd_t)
```



### C.tss_create

```nelua
function C.tss_create(tss_id: *C.tss_t, destructor: C.tss_dtor_t): cint
```



### C.tss_get

```nelua
function C.tss_get(tss_id: C.tss_t): pointer
```



### C.tss_set

```nelua
function C.tss_set(tss_id: C.tss_t, val: pointer): cint
```



### C.tss_delete

```nelua
function C.tss_delete(tss_id: C.tss_t)
```



### C.thrd_success

```nelua
global C.thrd_success: cint
```



### C.thrd_busy

```nelua
global C.thrd_busy: cint
```



### C.thrd_error

```nelua
global C.thrd_error: cint
```



### C.thrd_nomem

```nelua
global C.thrd_nomem: cint
```



### C.thrd_timedout

```nelua
global C.thrd_timedout: cint
```



### C.mtx_plain

```nelua
global C.mtx_plain: cint
```



### C.mtx_recursive

```nelua
global C.mtx_recursive: cint
```



### C.mtx_timed

```nelua
global C.mtx_timed: cint
```



---
## C.stdatomic

Library that imports symbols from the `<stdatomic.h>` header according to C11 specifications.

For a complete documentation about the functions,
see [C11 threads documentation](https://en.cppreference.com/w/c/atomic).

### C.memory_order

```nelua
global C.memory_order: type = @cint
```

Memory ordering constraints.

### C.memory_order_relaxed

```nelua
global C.memory_order_relaxed: C.memory_order
```



### C.memory_order_consume

```nelua
global C.memory_order_consume: C.memory_order
```



### C.memory_order_acquire

```nelua
global C.memory_order_acquire: C.memory_order
```



### C.memory_order_release

```nelua
global C.memory_order_release: C.memory_order
```



### C.memory_order_acq_rel

```nelua
global C.memory_order_acq_rel: C.memory_order
```



### C.memory_order_seq_cst

```nelua
global C.memory_order_seq_cst: C.memory_order
```



### C.atomic_flag

```nelua
global C.atomic_flag: type = @record{__val: boolean}
```

Lock-free atomic boolean flag.

### C.kill_dependency

```nelua
function C.kill_dependency(y: is_atomicable): #[y.type]#
```

Breaks a dependency chain for `memory_order_consume`.

### C.atomic_flag_test_and_set

```nelua
function C.atomic_flag_test_and_set(object: *C.atomic_flag <volatile>): boolean
```

Sets an atomic_flag to `true` and returns the old value (uses `memory_order_seq_cst` order).

### C.atomic_flag_test_and_set_explicit

```nelua
function C.atomic_flag_test_and_set_explicit(object: *C.atomic_flag <volatile>, order: C.memory_order): boolean
```

Sets an atomic_flag to `true` and returns the old value.

### C.atomic_flag_clear

```nelua
function C.atomic_flag_clear(object: *C.atomic_flag <volatile>): void
```

Sets an C.atomic_flag to `false` (uses `memory_order_seq_cst` order).

### C.atomic_flag_clear_explicit

```nelua
function C.atomic_flag_clear_explicit(object: *C.atomic_flag <volatile>, order: C.memory_order): void
```

Sets an C.atomic_flag to `false`.

### C.atomic_init

```nelua
function C.atomic_init(obj: is_atomicable_ptr <volatile>, value: is_atomicable): void
```

Initializes an existing atomic object.

### C.atomic_is_lock_free

```nelua
function C.atomic_is_lock_free(obj: is_atomicable_ptr <const,volatile>): boolean
```

Indicates whether the atomic object is lock-free.

### C.atomic_store

```nelua
function C.atomic_store(object: is_atomicable_ptr <volatile>, desired: is_atomicable): void
```

Stores a value in an atomic object (uses `memory_order_seq_cst` order).

### C.atomic_store_explicit

```nelua
function C.atomic_store_explicit(object: is_atomicable_ptr <volatile>, desired: is_atomicable, order: C.memory_order): void
```

Stores a value in an atomic object.

### C.atomic_load

```nelua
function C.atomic_load(object: is_atomicable_ptr <volatile>): #[object.type.subtype]#
```

Reads a value from an atomic object (uses `memory_order_seq_cst` order).

### C.atomic_load_explicit

```nelua
function C.atomic_load_explicit(object: is_atomicable_ptr <volatile>, order: C.memory_order): #[object.type.subtype]#
```

Reads a value from an atomic object.

### C.atomic_exchange

```nelua
function C.atomic_exchange(object: is_atomicable_ptr <volatile>, desired: is_atomicable): #[object.type.subtype]#
```

Swaps a value with the value of an atomic object (uses `memory_order_seq_cst` order).

### C.atomic_exchange_explicit

```nelua
function C.atomic_exchange_explicit(object: is_atomicable_ptr <volatile>, desired: is_atomicable, order: C.memory_order): #[object.type.subtype]#
```

Swaps a value with the value of an atomic object.

### C.atomic_compare_exchange_strong

```nelua
function C.atomic_compare_exchange_strong(object: is_atomicable_ptr <volatile>, expected: is_atomicable_ptr, desired: is_atomicable): boolean
```



### C.atomic_compare_exchange_strong_explicit

```nelua
function C.atomic_compare_exchange_strong_explicit(object: is_atomicable_ptr <volatile>, expected: is_atomicable_ptr, desired: is_atomicable, success: C.memory_order, failure: C.memory_order): boolean
```



### C.atomic_compare_exchange_weak

```nelua
function C.atomic_compare_exchange_weak(object: is_atomicable_ptr <volatile>, expected: is_atomicable_ptr, desired: is_atomicable): boolean
```



### C.atomic_compare_exchange_weak_explicit

```nelua
function C.atomic_compare_exchange_weak_explicit(object: is_atomicable_ptr <volatile>, expected: is_atomicable_ptr, desired: is_atomicable, success: C.memory_order, failure: C.memory_order): boolean
```



### C.atomic_fetch_add

```nelua
function C.atomic_fetch_add(object: is_atomicable_ptr <volatile>, arg: is_atomicable): #[object.type.subtype]#
```



### C.atomic_fetch_add_explicit

```nelua
function C.atomic_fetch_add_explicit(object: is_atomicable_ptr <volatile>, arg: is_atomicable, order: C.memory_order): #[object.type.subtype]#
```



### C.atomic_fetch_sub

```nelua
function C.atomic_fetch_sub(object: is_atomicable_ptr <volatile>, arg: is_atomicable): #[object.type.subtype]#
```



### C.atomic_fetch_sub_explicit

```nelua
function C.atomic_fetch_sub_explicit(object: is_atomicable_ptr <volatile>, arg: is_atomicable, order: C.memory_order): #[object.type.subtype]#
```



### C.atomic_fetch_or

```nelua
function C.atomic_fetch_or(object: is_atomicable_ptr <volatile>, arg: is_atomicable): #[object.type.subtype]#
```



### C.atomic_fetch_or_explicit

```nelua
function C.atomic_fetch_or_explicit(object: is_atomicable_ptr <volatile>, arg: is_atomicable, order: C.memory_order): #[object.type.subtype]#
```



### C.atomic_fetch_and

```nelua
function C.atomic_fetch_and(object: is_atomicable_ptr <volatile>, arg: is_atomicable): #[object.type.subtype]#
```



### C.atomic_fetch_and_explicit

```nelua
function C.atomic_fetch_and_explicit(object: is_atomicable_ptr <volatile>, arg: is_atomicable, order: C.memory_order): #[object.type.subtype]#
```



### C.atomic_thread_fence

```nelua
function C.atomic_thread_fence(order: C.memory_order): void
```

Generic memory order-dependent fence synchronization primitive.

### C.atomic_signal_fence

```nelua
function C.atomic_signal_fence(order: C.memory_order): void
```

Fence between a thread and a signal handler executed in the same thread.

### C.ATOMIC_BOOL_LOCK_FREE

```nelua
global C.ATOMIC_BOOL_LOCK_FREE: cint
```



### C.ATOMIC_CHAR_LOCK_FREE

```nelua
global C.ATOMIC_CHAR_LOCK_FREE: cint
```



### C.ATOMIC_CHAR16_T_LOCK_FREE

```nelua
global C.ATOMIC_CHAR16_T_LOCK_FREE: cint
```



### C.ATOMIC_CHAR32_T_LOCK_FREE

```nelua
global C.ATOMIC_CHAR32_T_LOCK_FREE: cint
```



### C.ATOMIC_WCHAR_T_LOCK_FREE

```nelua
global C.ATOMIC_WCHAR_T_LOCK_FREE: cint
```



### C.ATOMIC_SHORT_LOCK_FREE

```nelua
global C.ATOMIC_SHORT_LOCK_FREE: cint
```



### C.ATOMIC_INT_LOCK_FREE

```nelua
global C.ATOMIC_INT_LOCK_FREE: cint
```



### C.ATOMIC_LONG_LOCK_FREE

```nelua
global C.ATOMIC_LONG_LOCK_FREE: cint
```



### C.ATOMIC_LLONG_LOCK_FREE

```nelua
global C.ATOMIC_LLONG_LOCK_FREE: cint
```



### C.ATOMIC_POINTER_LOCK_FREE

```nelua
global C.ATOMIC_POINTER_LOCK_FREE: cint
```



### C.ATOMIC_FLAG_INIT

```nelua
global C.ATOMIC_FLAG_INIT: C.atomic_flag
```

Initializes a new atomic flag.

---
