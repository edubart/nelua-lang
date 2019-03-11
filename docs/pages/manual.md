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

Additional keywords:
```
var let const
continue
typedef
enum struct
```

## Variables

There are many types of variables:

* **var** is a mutable variable
* **local** is an alias to mutable variable
* **let** is an immutable variable
* **ref** is a referente to a variable
* **const** is an immutable variable and it's expression is evoluated at compile time

## Primitives types

| Type  | C++ Type  | Suffixes  |
|---|---|---|
| `boolean` `bool` | `bool` | |
| `integer` `int` | `long` | `_i` `_integer` |
| `uinteger` `uint` | `unsigned long` | `_u` `_uinteger` |
| `number` | `double` | `_number` |
| `uint64` | `uint64_t` | `_u64` `_uint64` |
| `uint32` | `uint32_t` | `_u32` `_uint32` |
| `uint16` | `uint16_t` | `_u16` `_uint16` |
| `uint8` `byte` | `uint8_t` | `_u8` `_uint8` |
| `int64` | `int64_t` | `_i64` `_int64` |
| `int32` | `int32_t` | `_i32` `_int32` |
| `int16` | `int16_t` | `_i16` `_int16` |
| `int8` | `int8_t` | `_i8` `_int8` |
| `float64` | `double` | `_f64` `_float64` |
| `float32` | `float` | `_f32` `_float32` |
| `isize` | `std::ptrdiff_t` | `_isize` |
| `usize` | `std::size_t` | `_usize` |
| `char` | `char` | `_c` `_char` |

table
struct
any
variant
optional
tuple
function
enum
