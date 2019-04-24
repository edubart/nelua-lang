---
layout: default
title: Manual
permalink: /manual/
toc: true
categories: sidenav
order: 4
---

# Manual

## Functions

By default variables are locally visible only in their scope and sub scopes.


## Modules

By default modules functions and variables are exported unless declared local.

## Keywords

All Lua keywords:
```
and       break     do        else      elseif    end
false     for       function  goto      if        in
local     nil       not       or        repeat    return
then      true      until     while
```

Additional keywords used in extensions:
```
switch case
continue
```

## Operators

| Name | Syntax | Type | Operation |
|---|---|---|---|
| or       | `a or b`      | binary   | conditional or           |
| and      | `a and b`     | binary   | conditional and          |
| lt       | `a < b`       | binary   | less than                |
| ne       | `a ~= b`      | binary   | not equal                |
| gt       | `a > b`       | binary   | greater than             |
| le       | `a <= b`      | binary   | less or equal than       |
| ge       | `a >= b`      | binary   | greater or equal than    |
| eq       | `a == b`      | binary   | equal                    |
| bor      | `a | b`       | binary   | bitwise or               |
| band     | `a & b`       | binary   | bitwise and              |
| bxor     | `a ~ b`       | binary   | bitwise xor              |
| shl      | `a << b`      | binary   | bitwise sguft right      |
| shr      | `a >> b`      | binary   | bitwise shift left       |
| concat   | `a .. b`      | binary   | concatenation operator   |
| add      | `a + b`       | binary   | numeric add              |
| sub      | `a - b`       | binary   | numeric subtract         |
| mul      | `a * b`       | binary   | numeric multiply         |
| div      | `a / b`       | binary   | numeric division         |
| idiv     | `a // b`      | binary   | integer division         |
| mod      | `a % b`       | binary   | numeric modulo           |
| imod     | `a %% b`      | binary   | integer modulo           |
| not      | `not a`       | unary    | boolean negation         |
| len      | `#a`          | unary    | length operator          |
| neg      | `-a`          | unary    | numeric negation         |
| bnot     | `~a`          | unary    | bitwise not              |
| tostring | `$a`          | unary    | stringification operator |
| ref      | `&a`          | unary    | reference operator       |
| deref    | `*a`          | unary    | dereference operator     |
| pow      | `a ^ b`       | unary    | numeric pow              |

## Other symbols used in the language syntax

| Symbol| Syntax | Usage |
|---|---|---|
| `[]`  | array index |
| `{}`  | listing |
| `()`  | surrounding |
| `<>`  | inner type definition |
| `:`   | method access |
| `.`   | field index |
| `...` | varargs |
| `,`   | separator |
| `;`   | line separator |
| `""`  | string quoting |
| `''`  | alternative string quoting |
| `;`   | statement separator |
| `@`   | type inference |
| `::`  | label definition |
| `--`  | comment |
| `{: :}` | pragma |



## Variables mutabilities

* **var** is a mutable variable
* **var&** is a reference to a mutable variable
* **var&&** is a mutable rvalue
* **val** is an immutable variable
* **val&** is a reference to a immutable variable
* **const** is an immutable variable and it's expression is evaluated at compile time

## Primitives types

| Type              | C Type          | Suffixes            |
|-------------------|-----------------|---------------------|
| `integer`         | `int64_t`       | `_i` `_integer`     |
| `uinteger`        | `unt64_t`       | `_u` `_uinteger`    |
| `number`          | `double`        | `_n` `_number`      |
| `byte`            | `uint8_t`       | `_b` `_byte`        |
| `isize`           | `intptr_t`      | `_is` `_int`        |
| `int8`            | `int8_t`        | `_i8` `_int8`       |
| `int16`           | `int16_t`       | `_i16` `_int16`     |
| `int32`           | `int32_t`       | `_i32` `_int32`     |
| `int64`           | `int64_t`       | `_i64` `_int64`     |
| `usize`           | `uintptr_t`     | `_us` `_uint`       |
| `uint8`           | `uint8_t`       | `_u8` `_uint8`      |
| `uint16`          | `uint16_t`      | `_u16` `_uint16`    |
| `uint32`          | `uint32_t`      | `_u32` `_uint32`    |
| `uint64`          | `uint64_t`      | `_u64` `_uint64`    |
| `float32`         | `float`         | `_f32` `_float32`   |
| `float64`         | `double`        | `_f64` `_float64`   |
| `pointer`         | `void*`         | `_pointer`          |
| `boolean`         | `bool`          |                     |

The types `isize` and `usize` types are usually 32 wide bits on 32-bit systems,
and 64 bits wide on 64-bit systems. When you need an integer value you should use `integer`
unless you have a specific reason to use a sized or unsigned integer type.

The `integer` is the default type for integral literals with no suffix.
The `number` is the default type for fractional literals with no suffix.

Additional types for C compatibility are also provided:

| Type              | C Type               | Suffixes         |
|-------------------|----------------------|------------------|
| `cschar`          | `char`               | `_cschar`        |
| `cshort`          | `signed char`        | `_cshort`        |
| `cint`            | `short`              | `_cint`          |
| `clong`           | `int`                | `_clong`         |
| `clonglong`       | `long`               | `_clonglong`     |
| `cptrdiff`        | `long long`          | `_cptrdiff`      |
| `cchar`           | `ptrdiff_t`          | `_cchar`         |
| `cuchar`          | `unsigned char`      | `_cuchar`        |
| `cushort`         | `unsigned short`     | `_cushort`       |
| `cuint`           | `unsigned int`       | `_cuint`         |
| `culong`          | `unsigned long`      | `_culong`        |
| `culonglong`      | `unsigned long long` | `_culonglong`    |
| `csize`           | `size_t`             | `_csize`         |
| `clongdouble`     | `long double`        | `_clongdouble`   |
| `cdouble`         | `double`             | `_cdouble`       |
| `cfloat`          | `float`              | `_cfloat_`       |
| `cstring`         | `char*`              | `_cstring`       |

## Primitives values

`false`
`true`
`nil`
`nilptr`
