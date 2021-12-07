---
layout: docs
title: Overview
permalink: /overview/
categories: docs toc
order: 3
---

{% raw %}

This is a quick overview of the language features that are currently implemented by the examples.
{: .lead}

All of the features and examples presented here should work with the latest Nelua version.
{: .callout.callout-info}

## A note for Lua users

Most of Nelua's syntax and semantics
are similar to Lua, so if you know Lua, you probably know Nelua. However, Nelua has many
additions, such as type notations, to make code more efficient and to allow metaprogramming.
This overview will try to focus on those additions.

There is no interpreter or VM, all of the code is converted directly into native machine code.
This means you can expect better efficiency than Lua. However, this also means that Nelua **cannot load
code generated at runtime**. The user is encouraged to generate code at compile-time
using the preprocessor.

Although copying Lua syntax and semantics with minor changes is a goal of Nelua, not all Lua
features are implemented yet. Most of the dynamic parts, such as tables and handling dynamic types
at runtime, are not implemented yet. So at the moment, using
records instead of tables and using type notations is required.
{: .callout.callout-warning}

## A note for C users

Nelua tries to expose most of C's features without overhead, so expect
to get near-C performance when coding in the C style; that is, using
type notations, manual memory management, pointers, and records (structs).

The semantics are not exactly the same as C semantics, but they are close. There are slight differences
(like initializing to zero by default) to minimize undefined behaviors and
other differences to maintain consistency with Lua semantics (like integer division rounding towards negative infinity).
However, there are ways to use C semantics when needed.

The preprocessor is much more powerful than C's preprocessor
because it is part of the compiler which runs in Lua.
This means you can interact with the compiler during parsing. The preprocessor should
be used for code specialization, making generic code, and avoiding code duplication.

Nelua compiles everything into a single readable C file.
If you know C, it is recommended that you read the generated C code
to learn more about exactly how the compiler works and what code it outputs.

## Hello world

A simple *hello world* program is just the same as in Lua:

```lua
print 'Hello world!'
```

## Comments

Comments are just like Lua:

```nelua
-- one line comment
--[[
  multi-line comment
]]
--[=[
  multi line comment. `=` can be placed multiple times
  in case you have `[[` `]]` tokens inside the comment.
  it will always match its corresponding token
]=]
```

## Variables

Variables are declared and defined like in Lua, but you may optionally
specify a type:

```nelua
local b = false -- of deduced type 'boolean', initialized to false
local s = 'test' -- of deduced type 'string', initialized to 'test'
local one = 1 --  of type 'integer', initialized to 1
local pi: number = 3.14 --  local pi: number = 3.14 --  of type 'number', initialized to 3.14
print(b,s,one,pi) -- outputs: false test 1 3.14
```

The compiler takes advantage of types for compile-time and runtime checks,
as well as to generate **efficient code** to handle the **specific type used**.
{:.alert.alert-info}

### Type deduction

When a variable has no specified type on its declaration, the type is automatically deduced
and resolved at compile-time:

```nelua
local a -- type will be deduced at scope end
a = 1
a = 2
print(a) -- outputs: 2
-- end of scope, compiler deduced 'a' to be of type 'integer'
```

The compiler does the best it can to deduce the type for you. In most situations
it should work, but in some corner cases you may want to explicitly set a type for a variable.
{:.alert.alert-info}

In the case of different types being assigned to the same variable,
the compiler deduces the variable type to be the `any` type,
a type that can hold anything at runtime.
However support for `any` type is not fully implemented yet,
thus you will get a compile error.
In the future with proper support for any type usual Lua
code with dynamic typing will be compatible with Nelua.
{:.alert.alert-warning}

### Zero initialization

Variables declared but not defined early are always initialized to zeros by default:

```nelua
local b: boolean -- variable of type 'boolean', initialized to 'false'
local i: integer -- variable of type 'integer', initialized to 0
print(b, i) -- outputs: false 0
```

Nelua encourages the Zero Is Initialization (ZII) idiom
and it's used in all of its standard libraries.
The language does not have constructor or destructors (RAII)
in favor of this idiom.

Zero initialization can be **optionally disabled** using the `<noinit>` [annotation](#annotations).
Although not advised, one could do this for micro optimization purposes.
{:.alert.alert-info}

### Auto variables

A variable declared as `auto` has its type deduced early based only on the type of its first assignment:

```nelua
local a: auto = 1 -- a is deduced to be of type 'integer'

-- uncommenting the following will trigger the compile error:
--   constant value `1.0` is fractional which is invalid for the type 'int64'
--a = 1.0

print(a) -- outputs: 1
```

Auto variables were not intended to be used in variable declarations
like in the example above, because in most cases you can omit the type
and the compiler will automatically deduce it.
This can be used, however, if you want the compiler to deduce early.
The `auto` type was mainly created to be used with [polymorphic functions](#polymorphic-functions).
{:.alert.alert-warning}

### Compile-time variables

Compile-time variables have their values known at compile-time:

```nelua
local a <comptime> = 1 + 2 -- constant variable of value '3' evaluated and known at compile-time
print(a) -- outputs: 3
```

The compiler takes advantage of compile-time variables to generate
**efficient code**,
because compile-time variables can be processed at compile-time.
Compile-time variables are also useful
as compile-time parameters in [polymorphic functions](#polymorphic-functions).
{:.alert.alert-info}

### Const variables

Const variables can be assigned once at runtime, however, they cannot mutate:

```nelua
local x <const> = 1
local a <const> = x
print(a) -- outputs: 1

-- uncommenting the following will trigger the compile error:
--   error: cannot assign a constant variable
--a = 2
```

The const annotation can also be used for function arguments.

The use of `<const>` annotation is mostly for aesthetic
purposes. Its usage does not affect efficiency.
{:.alert.alert-info}

### Multiple variables assignment

Multiple variables can be assigned in a single statement:

```nelua
local a, b = 1, 2
print(a, b) -- outputs: 1 2
b, a = a, b -- swap values
print(a, b) -- outputs: 2 1
```

Temporary variables are used in a multiple assignment, so
the values can be safely swapped.
{:.alert.alert-info}

## Symbols

Symbols are named identifiers for functions, types, and variables.

### Local symbol

Local symbols are only visible in the current and inner scopes:

```nelua
do
  local a = 1
  do
    print(a) -- outputs: 1
  end
end
-- uncommenting this would trigger a compiler error because `a` is not visible:
-- a = 1
```

### Global symbol

Global symbols are visible in other source files. They can only be declared in the top scope:

```nelua
global global_a = 1
global function global_f()
  return 'f'
end
```

If the above is saved into a file in the same directory as `globals.nelua`, then we can run:

```nelua
require 'globals'
print(global_a) -- outputs: 1
print(global_f()) -- outputs: f
```

Unlike Lua, to declare a global variable you **must explicitly use** the
`global` keyword.
{:.alert.alert-info}

<!---
### Symbols with special characters

A symbol identifier, that is, the symbol name, can contain UTF-8 special characters:

```nelua
local π = 3.14
print(π) -- outputs 3.14
```
-->

## Control flow

Nelua provides the same control flow mechanisms as Lua, plus some additional
ones to make low level programming easier, like `switch`, `defer`, and `continue` statements.

### If

If statements work just like in Lua:

```nelua
local a = 1 -- change this to 2 or 3 to trigger other ifs
if a == 1 then
  print 'is one'
elseif a == 2 then
  print 'is two'
else
  print('not one or two')
end
```

### Switch

The switch statement is similar to C:

```nelua
local a = 1 -- change this to 2 or 3 to trigger other ifs
switch a
case 1 then
  print 'is 1'
case 2, 3 then
  print 'is 2 or 3'
else
  print 'else'
end
```

The case expression can only contain **integral** numbers known at **compile-time**.
The compiler can generate more optimized code when using a switch
instead of using many if statements for integers.
{:.alert.alert-info}

Note that, unlike C, there is no need to use "break" on each case statement,
this is done automatically.
{:.alert.alert-info}

### Do

Do blocks are useful for creating arbitrary scopes to avoid collision of
variable names:

```nelua
do
  local a = 0
  print(a) -- outputs: 0
end
do
  local a = 1 -- can declare variable named a again
  print(a) -- outputs: 1
end
```

### Defer

The defer statement is useful for executing code upon scope termination.

```nelua
do
  defer
    print 'world'
  end
  print 'hello'
end
-- outputs 'hello' then 'world'
```

Defer is meant to be used for **releasing resources** in a deterministic manner **on scope termination**.
The syntax and functionality is inspired by the similar statement in the Go language.
It is guaranteed to be executed in reverse order before any `return`, `break` or `continue` statement.
{:.alert.alert-info}

### Goto

Gotos are useful to get out of nested loops and jump between lines:

```nelua
local haserr = true
if haserr then
  goto getout -- get out of the loop
end
print 'success'
::getout::
print 'fail'
-- outputs only 'fail'
```

### While

While is just like in Lua:

```nelua
local a = 1
while a <= 5 do
  print(a) -- outputs 1 2 3 4 5
  a = a + 1
end
```

### Repeat

Repeat also functions as in Lua:

```nelua
local a = 0
repeat
  a = a + 1
  print(a) -- outputs 1 2 3 4 5
  local stop = a == 5
until stop
```

Note that, like Lua, a variable declared inside a `repeat` scope **is visible** inside its condition expression.
{:.alert.alert-info}

### Numeric For

Numeric for is like in Lua, meaning it is inclusive of the first and the last
elements:

```nelua
for i = 0,5 do
  -- i is deduced to 'integer'
  print(i) -- outputs 0 1 2 3 4 5
end
```

Like in Lua, numeric for loops always evaluate the begin, end, and step expressions **just once**. The iterate
variable type is automatically deduced using the begin and end expressions only.
{:.alert.alert-info}

#### Exclusive For

The exclusive for is available to create exclusive for loops. They work using
comparison operators `~=` `<=` `>=` `<` `>`:

```nelua
for i=0,<5 do
  print(i) -- outputs 0 1 2 3 4
end
```

#### Stepped For

The last parameter in for syntax is the step. Its counter is always incremented
with `i = i + step`. By default the step is always 1. When using negative steps, a reverse for loop is possible:

```nelua
for i=5,0,-1 do
  print(i) -- outputs 5 4 3 2 1 0
end
```

### For In

Like in Lua, you can iterate values using an iterator function:

```nelua
require 'iterators'

local a: [4]string = {"a","b","c","d"}
for i,v in ipairs(a) do
  print(i,v) -- outputs: 0 a, 1 b, 2 c, 3 d
end
```

Nelua provides some basic iterator functions that works on most containers,
check the [iterators module documentation](https://nelua.io/libraries/#iterators)
for more of them.
{:.alert.alert-info}

### Continue

The continue statement is used to skip to the next iteration of a loop:

```nelua
for i=1,10 do
  if i<=5 then
    continue
  end
  print(i) -- outputs: 6 7 8 9 10
end
```

### Break

The break statement is used to immediately exit a loop:

```nelua
for i=1,10 do
  if i>5 then
    break
  end
  print(i) -- outputs: 1 2 3 4 5
end
```

### Do expression

Sometimes is useful to create an expression with statements on its own
in the middle of another expression, this is possible with the
`(do end)` syntax:

```nelua
local i = 2
local s = (do
  local res: string
  if i == 1 then
    res = 'one'
  elseif i == 2 then
    res = 'two'
  else
    res = 'other'
  end
  in res -- injects final expression result
end)
print(s) -- outputs: two
```

This construct is used internally by the compiler to implement other features,
thus the motivation behind this was not really the syntax (it can be verbose),
but the meta programming possibilities that such feature offers.
{:.alert.alert-info}

## Primitive types

Primitives types are the basic types built into the compiler.

### Boolean

```nelua
local a: boolean -- variable of type 'boolean' initialized to 'false'
local b = false
local c = true
print(a,b,c) -- outputs: false false true
```

The `boolean` is defined as a `bool` in the generated C code.

### Number

Number literals are defined like in Lua:

```nelua
local dec = 1234 -- variable of type 'integer'
local bin = 0b1010 -- variable of type 'uint8', set from binary number
local hex = 0xff -- variable of type 'integer', set from hexadecimal number
local char = 'A'_u8 -- variable of type 'uint8' set from ASCII character
local exp = 1.2e-100 -- variable of type 'number' set using scientific notation
local frac = 1.41 -- variable of type 'number'
print(dec,bin,hex,char,exp,frac)

local pi = 0x1.921FB54442D18p+1 -- hexadecimal with fractional and exponent
print(pi) -- outputs: 3.1415926535898
```

The `integer` is the default type for integral literals without suffix.
The `number` is the default type for fractional literals without suffix.

You can use type suffixes to force a type for a numeric literal:

```nelua
local a = 1234_u32 -- variable of type 'int32'
local b = 1_f32 -- variable of type 'float32'
local c = -1_isize -- variable of type `isize`
print(a,b,c) --outputs: 1234 1.0 -1
```

The following table shows Nelua primitive numeric types and their related types in C:

| Type              | C Type              | Suffixes            |
|-------------------|---------------------|---------------------|
| `integer`         | `int64_t`           | `_i` `_integer`     |
| `uinteger`        | `uint64_t`          | `_u` `_uinteger`    |
| `number`          | `double`            | `_n` `_number`      |
| `byte`            | `uint8_t`           | `_b` `_byte`        |
| `isize`           | `intptr_t`          | `_is` `_isize`      |
| `int8`            | `int8_t`            | `_i8` `_int8`       |
| `int16`           | `int16_t`           | `_i16` `_int16`     |
| `int32`           | `int32_t`           | `_i32` `_int32`     |
| `int64`           | `int64_t`           | `_i64` `_int64`     |
| `int128`*         | `__int128`          | `_i128` `_int128`   |
| `usize`           | `uintptr_t`         | `_us` `_usize`      |
| `uint8`           | `uint8_t`           | `_u8` `_uint8`      |
| `uint16`          | `uint16_t`          | `_u16` `_uint16`    |
| `uint32`          | `uint32_t`          | `_u32` `_uint32`    |
| `uint64`          | `uint64_t`          | `_u64` `_uint64`    |
| `uint128`*        | `unsigned __int128` | `_u128` `_uint128`  |
| `float32`         | `float`             | `_f32` `_float32`   |
| `float64`         | `double`            | `_f64` `_float64`   |
| `float128`*       | `__float128`        | `_f128` `_float128` |
{: .table.table-bordered.table-striped.table-sm}

*\* Only supported by some C compilers and architectures.*
{:.text-muted}

The types `isize` and `usize` are usually 32 bits wide on 32-bit systems,
and 64 bits wide on 64-bit systems.

When you need an integer value you **should use** `integer`
unless you have a specific reason to use a sized or unsigned integer type.
The `integer`, `uinteger` and `number` **are intended to be configurable**. By default
they are 64 bits for all architectures, but this can be customized by the user at compile-time
via the preprocessor when needed.
{:.alert.alert-info}

### String

String points to an immutable contiguous sequence of characters.

```nelua
local str1: string -- empty string
local str2 = "string 2" -- variable of type 'string'
local str3: string = 'string 3' -- also a 'string'
local str4 = [[
multi
line
string
]]
print(str1, str2, str3) -- outputs: "" "string 2" "string 3"
print(str4) -- outputs the multi line string
```

Internally string just holds a pointer to a buffer and a size.
It's buffer is null terminated ('\0') by default to have more compatibility with C.

Like in Lua, `string` **is immutable**.
If the programmer wants a mutable string, he should use the [stringbuilder module](https://nelua.io/libraries/#stringbuilder).
{:.alert.alert-info}

#### String escape sequence

Strings literals defined between quotes can have escape sequences
following same rules as in Lua:

```nelua
local ctr = "\n\t\r\a\b\v\f" -- escape control characters
local utf = "\u{03C0}" -- escape UTF-8 code
local hex = "\x41" -- escape hexadecimal byte
local dec = "\65" -- escape decimal byte
local multiline1 = "my\z
                    text1" -- trim spaces and newlines after '\z'
local multiline2 = "my\
text2" -- escape new lines after '\' to '\n'
print(utf, hex, dec, multiline1) -- outputs: π A A mytext1
print(multiline2) -- outputs "my" and "text2" on a new line
```

### Array

An array is a list with a size that is fixed and known at compile-time:

```nelua
local a: [4]integer = {1,2,3,4}
print(a[0], a[1], a[2], a[3]) -- outputs: 1 2 3 4

local b: [4]integer
print(b[0], b[1], b[2], b[3]) -- outputs: 0 0 0 0
local len = #b -- get the length of the array, should be 4
print(len) -- outputs: 4
```

When passing an array to a function as an argument, it is **passed by value**.
This means the array is copied. This can incur some performance overhead.
Thus when calling functions, you may want to pass arrays by reference
using the [reference operator](#dereferencing-and-referencing) when appropriate.
{:.alert.alert-warning}

#### Array with inferred size

When declaring and initializing an array the size on the type notation can be optionally omitted as a syntax sugar:

```nelua
local a: []integer = {1,2,3,4} -- array size will be 4
print(#a) -- outputs: 4
```

Do not confuse this syntax with dynamic arrays,
the array size will still be fixed and determined at compile time.
{:.alert.alert-warning}

#### Multidimensional array

An array can also be multidimensional:

```nelua
local m: [2][2]number = {
  {1.0, 2.0},
  {3.0, 4.0}
}
print(m[0][0], m[0][1]) -- outputs: 1.0 2.0
print(m[1][0], m[1][1]) -- outputs: 3.0 4.0
```

### Enum

Enums are used to list constant values in sequential order:

```nelua
local Weeks = @enum{
  Sunday = 0,
  Monday,
  Tuesday,
  Wednesday,
  Thursday,
  Friday,
  Saturday
}
print(Weeks.Sunday) -- outputs: 0

local a: Weeks = Weeks.Monday
print(a) -- outputs: 1
```

The programmer must always initialize the first enum value. This choice
was made to makes the code more clear when reading.
{:.alert.alert-info}

### Record

Records store variables in a block of memory:

```nelua
local Person = @record{
  name: string,
  age: integer
}

-- typed initialization
local a: Person = {name = "Mark", age = 20}
print(a.name, a.age)

-- casting initialization
local b = (@Person){name = "Paul", age = 21}
print(b.name, b.age)

-- ordered fields initialization
local c = (@Person){"Eric", 21}
print(c.name, c.age)

-- late initialization
local d: Person
d.name = "John"
d.age  = 22
print(d.name, d.age)
```

Records are directly translated to C structs.
{:.alert.alert-info}

### Union

Union store multiple variables in a shared memory block:

```nelua
local IntOrFloat = @union{
  i: int64,
  f: float64,
}
local u: IntOrFloat = {i=1}
print(u.i) -- outputs: 1
u.f = 1
print(u.f) -- outputs: 1.0f
print(u.i) -- outputs some garbage integer
```

You are responsible for saving the current stored type in the union somewhere
else to know what current field is valid for reading, otherwise
you can read garbage data. Unions are directly translated to C unions.
{:.alert.alert-info}

### Pointer

A pointer points to a region in memory of a specific type:

```nelua
local n = nilptr -- a generic pointer, initialized to nilptr
local p: pointer -- a generic pointer to anything, initialized to nilptr
local i: *integer -- pointer to an integer
```

Pointers are directly translated to C raw pointers.
Unlike C, pointer arithmetic is disallowed.
To do pointer arithmetic you must explicitly cast to and from integers.
{:.alert.alert-info}

#### Unbounded Array

An array with size 0 is an unbounded array,
that is, an array with unknown size at compile time:

```nelua
local a: [4]integer = {1,2,3,4}

-- unbounded array only makes sense when used with pointer
local a_ptr: *[0]integer
a_ptr = &a -- takes the reference of 'a'
print(a_ptr[1])
```

An unbounded array is useful for indexing pointers, because unlike
C, you cannot index a pointer unless it is a pointer
to an unbounded array.
{:.alert.alert-info}

Unbounded arrays are **unsafe**, because bounds checking is
not possible at compile time or runtime. Use the [span](#span)
to have bounds checking.
{:.alert.alert-warning}

### Function type

The function type, mostly used to store callbacks, is a pointer to a function:

```nelua
local function add_impl(x: integer, y: integer): integer
  return x + y
end

local function double_add_impl(x: integer, y: integer): integer
  return 2*(x + y)
end

local add: function(x: integer, y: integer): integer
add = add_impl
print(add(1,2)) -- outputs 3
add = double_add_impl
print(add(1,2)) -- outputs 6
```

The function type is just a pointer, thus can be converted to/from generic pointers
with explicit casts.
{:.alert.alert-info}

### Span

Span, also known as "fat pointers" or "slices" in other languages,
are pointers to a block of contiguous elements of which the size is known at runtime:

```nelua
require 'span'
local arr = (@[4]integer) {1,2,3,4}
local s: span(integer) = &arr
print(s[0], s[1]) -- outputs: 1 2
print(#s) -- outputs 4
```

The advantage of using a span instead of a pointer is that spans generate runtime
checks for out of bounds access, so oftentimes code using span is **safer**.
The runtime checks can be disabled in release builds.
{:.alert.alert-info}

### Niltype

The niltype is the type of `nil`.

The niltype is not useful by itself, it is only useful when using with unions to create the
optional type or for detecting `nil` arguments in [polymorphic functions](#polymorphic-functions).
{:.alert.alert-info}

### Void

The void type is used internally for the generic pointer,
that is, `*void` and `pointer` types are all equivalent.

The void type can also be used explicitly mark that a function has no return:

```nelua
local function myprint(): void
  print 'hello'
end
myprint() -- outputs: hello
```

The compiler can automatic deduce function return types thus this is usually not needed.

### The "type" type

The `type` type is the type of a symbol that refers to a type.
Symbols with this type are used at compile-time only. They are useful for aliasing types:

```nelua
local MyInt: type = @integer -- a symbol of type 'type' holding the type 'integer'
local a: MyInt -- variable of type 'MyInt' (actually an 'integer')
print(a) -- outputs: 0
```

In the middle of statements the `@` token is required to precede a type expression.
This token signals to the compiler that a type expression comes after it.
{:.alert.alert-info}

#### Size of a type

You can use the operator `#` to get the size of any type in bytes:

```nelua
local Vec2 = @record{x: int32, y: int32}
print(#Vec2) -- outputs: 8
```

### Implicit type conversion

Some types can be implicitly converted. For example, any scalar type can be
converted to any other scalar type:

```nelua
local i: integer = 1
local u: uinteger = i
print(u) -- outputs: 1
```

Implicit conversion generates **runtime checks** for **loss of precision**
in the conversion. If this happens the application crashes with a narrow casting error.
The runtime checks can be disabled in release builds.
{:.alert.alert-warning}

### Explicit type conversion

The expression `(@type)(variable)` is used to explicitly convert a
variable to another type.

```nelua
local i = 1
local f = (@number)(i) -- convert 'i' to the type 'number'
print(i, f) -- outputs: 1 1.0
```

If a type is aliased to a symbol then
it is possible to convert variables by calling the symbol:

```nelua
local MyNumber = @number
local i = 1
local f = MyNumber(i) -- convert 'i' to the type 'number'
print(i, f) -- outputs: 1 1.0
```

Unlike implicit conversion, explicit conversions skip runtime checks:

```nelua
local ni: integer = -1
-- the following would crash with "narrow casting from int64 to uint64 failed"
--local nu: uinteger = ni

local nu: uinteger = (@uinteger)(ni) -- explicit cast works, no checks are done
print(nu) -- outputs: 18446744073709551615
```

## Operators

Unary and binary operators are provided for creating expressions:

```nelua
print(2 ^ 2) -- pow, outputs: 4.0
print(5 // 2) -- integer division, outputs: 2
print(5 / 2) -- float division, outputs: 2.5
```

All Lua operators are provided:

| Name | Syntax | Operation |
|---|---|---|---|
| or     | `a or b`{:.language-nelua}   | conditional or                            |
| and    | `a and b`{:.language-nelua}  | conditional and                           |
| lt     | `a < b`{:.language-nelua}    | less than                                 |
| gt     | `a > b`{:.language-nelua}    | greater than                              |
| le     | `a <= b`{:.language-nelua}   | less or equal than                        |
| ge     | `a >= b`{:.language-nelua}   | greater or equal than                     |
| ne     | `a ~= b`{:.language-nelua}   | not equal                                 |
| eq     | `a == b`{:.language-nelua}   | equal                                     |
| bor    | `a | b`{:.language-nelua}    | bitwise OR                                |
| band   | `a & b`{:.language-nelua}    | bitwise AND                               |
| bxor   | `a ~ b`{:.language-nelua}    | bitwise XOR                               |
| shl    | `a << b`{:.language-nelua}   | bitwise logical left shift                |
| shr    | `a >> b`{:.language-nelua}   | bitwise logical right shift               |
| asr    | `a >>> b`{:.language-nelua}  | bitwise arithmetic right shift            |
| bnot   | `~a`{:.language-nelua}       | bitwise NOT                               |
| concat | `a .. b`{:.language-nelua}   | concatenation                             |
| add    | `a + b`{:.language-nelua}    | arithmetic add                            |
| sub    | `a - b`{:.language-nelua}    | arithmetic subtract                       |
| mul    | `a * b`{:.language-nelua}    | arithmetic multiply                       |
| div    | `a / b`{:.language-nelua}    | arithmetic division                       |
| idiv   | `a // b`{:.language-nelua}   | arithmetic floor division                 |
| tdiv   | `a /// b`{:.language-nelua}  | arithmetic truncate division              |
| mod    | `a % b`{:.language-nelua}    | arithmetic floor division remainder       |
| tmod   | `a %%% b`{:.language-nelua}  | arithmetic truncate division remainder    |
| pow    | `a ^ b`{:.language-nelua}    | arithmetic exponentiation                 |
| unm    | `-a`{:.language-nelua}       | arithmetic negation                       |
| not    | `not a`{:.language-nelua}    | boolean negation                          |
| len    | `#a`{:.language-nelua}       | length                                    |
| deref  | `$a`{:.language-nelua}       | pointer dereference                       |
| ref    | `&a`{:.language-nelua}       | memory reference                          |
{: .table.table-bordered.table-striped.table-sm}

All the operators follow Lua semantics, i.e.:
* `/` and `^` promotes numbers to floats.
* `//` and `%` rounds the quotient towards minus infinity.
* `<<` and `>>` are logical shifts and you can do negative or large shifts.
* `and`, `or`, `not`, `==`, `~=` can be used between any variable type.
* Integer overflows wrap around.

These additional operators are not available in Lua,
they are used for low-level programming and follow C semantics:
* `///` and `%%%` rounds the quotient towards zero (like C division and modulo on integers).
* `>>>` arithmetic right shift (like C right shift on signed integers).
* `$` dereference a pointer (like C dereference).
* `&` reference a memory (like C reference).

## Functions

Functions are declared as in Lua,
but arguments and returns can have their types explicitly specified:

```nelua
local function add(a: integer, b: integer): integer
  return a + b
end
print(add(1, 2)) -- outputs 3
```

### Return type inference

The return type can be automatically deduced when not specified:

```nelua
local function add(a: integer, b: integer)
  return a + b -- return is of deduced type 'integer'
end
print(add(1, 2)) -- outputs 3
```

### Recursive calls

Functions can call themselves recursively:

```nelua
local function fib(n: integer): integer
  if n < 2 then return n end
  return fib(n - 2) + fib(n - 1)
end
print(fib(10)) -- outputs: 55
```

Function that do recursive calls must **explicitly set the return type**,
i.e, the compiler cannot deduce the return type.
{:.alert.alert-warning}

### Multiple returns

Functions can have multiple return values as in Lua:

```nelua
local function get_multiple()
  return false, 1
end

local a, b = get_multiple()
-- a is of type 'boolean' with value 'false'
-- b is of type 'integer' with value '1'
print(a,b) -- outputs: false 1
```

Multiple returns can optionally be explicitly typed:

```nelua
local function get_multiple(): (boolean, integer)
  return false, 1
end

local a, b = get_multiple()
print(a,b) -- outputs: false 1
```

Multiple returns are efficient and packed into C structs in the code generator.
{:.alert.alert-info}

### Anonymous functions

A function can be declared without a name as an expression, this
kind of function is called anonymous function:

```nelua
local function g(x: integer, f: function(x: integer): integer)
  return f(x)
end

local y = g(1, function(x: integer): integer
  return 2*x
end)

print(y) -- outputs: 2
```

Unlike Lua an anonymous function cannot be a closure, that is,
it cannot use variables declared in upper scopes unless the top most scope.
{:.alert.alert-warning}

### Nested functions

A function can be declared inside another function:

```nelua
local function f()
  local function g()
    return 'hello from g'
  end
  return g()
end

print(f()) -- outputs: hello from g
```

The function will be visible only in inner scopes.
{:.alert.alert-info}

Unlike Lua a nested function cannot be a closure, that is,
it cannot use variables declared in upper scopes unless the top most scope.
{:.alert.alert-warning}

### Top scope closures

Functions declared in the top scope work as top scope closures.
They have access to all local variables declared beforehand:

```nelua
local counter = 1 -- 'a' lives in the heap because it's on the top scope
local function increment() -- a top scope closure
  -- counter is an upvalue for this function, we can access and modify it
  counter = counter + 1
end
print(counter) -- outputs 1
increment()
print(counter) -- outputs 2
```

Unlike Lua,
when declaring functions in the top scope, the compiler takes advantage of the fact that
top scope variables are always accessible in the program's static storage memory
to create lightweight closures without
needing to hold an upvalue reference or to use a garbage collector.
Therefore they are very lightweight and do not incur costs like a closure nested in a function would.
{:.alert.alert-info}

### Variable number of arguments

A function can have variable number arguments:

```nelua
local function f(...: varargs)
  print(...)
end
f(1, true) -- outputs: 1 true

local function sum(...: varargs)
  local s: integer
  ## for i=1,select('#', ...) do -- iterate over all arguments
    s = s + #[select(i, ...)]# -- select argument at index `i`
  ## end
  return s
end
print(sum(1, 2, 3)) -- outputs: 6
```

Functions with variable number of arguments will be polymorphic (see below).

The preprocessor is used to specialize the function at compile time.
One specialization occur for every different number of arguments or argument types,
thus there are no branching or costs at runtime when making functions
with variable number of arguments.
{:.alert.alert-info}

### Polymorphic functions

Polymorphic functions, or poly functions in short in the sources,
are functions which contain arguments whose proprieties can
only be known when calling the function at compile time.
They are defined and processed later when calling it for the first time.
They are used to specialize the function for different arguments types:

```nelua
local function add(a: auto, b: auto)
  return a + b
end

local a = add(1,2)
-- call to 'add', a function 'add(a: integer, b: integer): integer' is defined
print(a) -- outputs: 3
local b = add(1.0, 2.0)
-- call to 'add' with different types, function 'add(a: number, b: number): number' is defined
print(b) -- outputs: 3.0
```

In the above, the `auto` type is used as a generic placeholder to replace the function argument
with the incoming call type. This makes it possible to create a generic function for multiple types.

Polymorphic functions are memoized, that is, only defined once for each kind of specialization.
{:.alert.alert-info}

Later we will show how polymorphic functions are more useful when used in combination with the [preprocessor](#preprocessing-polymorphic-functions).
{: .callout.callout-info}

### Record functions

A record type can have functions defined for it. This makes it possible to
create functions that are to be used only within the record:

```nelua
local Vec2 = @record{x: number, y: number}

function Vec2.create(x: integer, y: integer): Vec2
  return (@Vec2){x, y}
end

local v = Vec2.create(1,2)
print(v.x, v.y) -- outputs: 1.0 2.0
```

### Record methods

A method is function defined for record that takes a reference to the record
as its first argument. This first argument is visible as `self` inside the method.
For defining or calling a method the colon token `:` must be used, just like in Lua.

```nelua
local Rect = @record{x: number, y: number, w: number, h: number}

function Rect:translate(x: number, y: number)
  -- 'self' here is of the type '*Rect'
  self.x = self.x + x
  self.y = self.y + y
end

function Rect:area()
  -- 'self' here is of the type '*Rect'
  return self.w * self.h
end

local v = Rect{0,0,2,3}
v:translate(2,2)
print(v.x, v.y) -- outputs: 2.0 2.0
print(v:area()) -- outputs: 6.0
```

When calling methods on records, the compiler automatically takes care
to [automatically reference or dereference](#automatic-referencing-and-dereferencing)
the object being called.
{:.alert.alert-info}

### Record metamethods

Some special methods using the `__` prefix are used by the compiler to define behaviors
on certain operations with the record type.
They are called metamethods and are similar to Lua metamethods:

```nelua
require 'math'

local Vec2 = @record{x: number, y: number}

-- Called on the binary operator '+'
function Vec2.__add(a: Vec2, b: Vec2)
  return (@Vec2){a.x+b.x, a.y+b.y}
end

-- Called on the unary operator '#'
function Vec2:__len()
  return math.sqrt(self.x*self.x + self.y*self.y)
end

local a: Vec2 = {1, 2}
local b: Vec2 = {3, 4}
local c = a + b -- calls the __add metamethod
print(c.x, c.y) -- outputs: 4.0 6.0
local len = #c -- calls the __len metamethod
print(len) -- outputs: 7.211102550928
```

Complete list of metamethods that can be defined for records:

| Name | Syntax | Kind | Operation |
|---|---|---|---|
| `__lt`           | `a < b`{:.language-nelua}   | binary   | less than                              |
| `__le`           | `a <= b`{:.language-nelua}  | binary   | less or equal than                     |
| `__eq`           | `a == b`{:.language-nelua}  | binary   | equal                                  |
| `__bor`          | `a | b`{:.language-nelua}   | binary   | bitwise or                             |
| `__band`         | `a & b`{:.language-nelua}   | binary   | bitwise and                            |
| `__bxor`         | `a ~ b`{:.language-nelua}   | binary   | bitwise xor                            |
| `__shl`          | `a << b`{:.language-nelua}  | binary   | bitwise logical left shift             |
| `__shr`          | `a >> b`{:.language-nelua}  | binary   | bitwise logical right shift            |
| `__asr`          | `a >>> b`{:.language-nelua} | binary   | bitwise arithmetic right shift         |
| `__bnot`         | `~a`{:.language-nelua}      | unary    | bitwise not                            |
| `__concat`       | `a .. b`{:.language-nelua}  | binary   | concatenation                          |
| `__add`          | `a + b`{:.language-nelua}   | binary   | arithmetic add                         |
| `__sub`          | `a - b`{:.language-nelua}   | binary   | arithmetic subtract                    |
| `__mul`          | `a * b`{:.language-nelua}   | binary   | arithmetic multiply                    |
| `__div`          | `a / b`{:.language-nelua}   | binary   | arithmetic division                    |
| `__idiv`         | `a // b`{:.language-nelua}  | binary   | arithmetic floor division              |
| `__tdiv`         | `a /// b`{:.language-nelua} | binary   | arithmetic truncate division           |
| `__mod`          | `a % b`{:.language-nelua}   | binary   | arithmetic floor division remainder    |
| `__tmod`         | `a %%% b`{:.language-nelua} | binary   | arithmetic truncate division remainder |
| `__pow`          | `a ^ b`{:.language-nelua}   | binary   | arithmetic exponentiation              |
| `__unm`          | `-a`{:.language-nelua}      | unary    | arithmetic negation                    |
| `__len`          | `#a`{:.language-nelua}      | unary    | length                                 |
| `__index`        | `a[b]`{:.language-nelua}    | indexing | array index                            |
| `__atindex`      | `a[b]`{:.language-nelua}    | indexing | array index via reference              |
| `__tostring`     | tostring(a)                 | cast     | explicit/implicit cast to string       |
| `__convert`      |                             | cast     | implicit cast from anything            |
| `__gc`           |                             | gc       | called when collected by the GC        |
| `__close`        |                             | close    | called when `<close>` variables goes out of scope |
| `__next`         | next(a)                     | iterator | used by `next`                         |
| `__mnext`        | mnext(a)                    | iterator | used by `mnext`                        |
| `__pairs`        | pairs(a)                    | iterator | used by `pairs`                        |
| `__mpairs`       | mpairs(a)                   | iterator | used by `mpairs`                       |
{: .table.table-bordered.table-striped.table-sm}

### Record globals

Sometimes it is useful to declare a global variable inside a record type,
using the record as a "namespace":

```nelua
global Globals = @record{} -- record used just for name spacing
global Globals.AppName: string
Globals.AppName = "My App"
print(Globals.AppName) -- outputs: My App
```

Record globals can be used to encapsulate modules,
like tables are used to make modules in Lua.
{:.alert.alert-info}

### Calls with nested records

You can define and later initialize complex records structures in a Lua-like style:

```nelua
local WindowConfig = @record{
  title: string,
  pos: record{
    x: integer,
    y: integer
  },
  size: record{
    x: integer,
    y: integer
  }
}
local function create_window(config: WindowConfig)
  print(config.title, config.pos.x, config.pos.y)
end

-- the compiler knows that the argument should be parsed as WindowConfig
-- notice that 'size' field is not set, so its initialized to zeros
create_window({title="hi", pos={x=1, y=2}})
```

## Memory management

By default Nelua uses a garbage collector to allocate and deallocate memory on its own.
However, it can be disabled with the pragma `nogc` via the command line using `-P nogc`
or in the sources:

```nelua
## pragmas.nogc = true -- tells the compiler that we don't want to use the GC
require 'string' -- the string class will be implemented without GC code
local str = tostring(1) -- tostring needs to allocates a new string
print(str) -- outputs: 1
## if pragmas.nogc then -- the GC is disabled, must manually deallocate memory
str:destroy() -- deallocates the string
## end
print(str) -- the string was destroyed and is now empty, outputs nothing
```

Notice that when disabling the garbage collector the coding style is
different from the usual Lua style, since you now need to **think of each allocation
and deallocation**, including strings, otherwise memory in your application will leak.
Thus it is best to leave the GC enabled when you need rapid prototyping.
{:.alert.alert-warning}

Disable the GC if you want to control the memory on your own for performance reasons,
if you know how to deal with memory management and don't mind the additional cognitive load
when coding.
{:.alert.alert-info}

### Allocating memory

Nelua provides many allocators to assist in managing memory.
The most important one is the `allocators.default`.

```nelua
require 'string'
require 'memory'

-- this will actually require 'allocators.gc' because GC is enabled
require 'allocators.default'

local Person = @record{name: string, age: integer}
local p: *Person = default_allocator:new(@Person)
p.name = "John"
p.age = 20
print(p.name, p.age)
p = nilptr
-- we don't need to deallocate, the GC will do this on its own when needed!
```

The `default_allocator` is an alias to `gc_allocator` or `general_allocator`
depending if the GC is enabled or not.

When the GC is enabled, you must **always allocate memory that contains pointers using**
`gc_allocator` (or `default_allocator`) instead of any other allocator,
because it marks the allocated memory region for scanning for references.
{:.alert.alert-warning}

### Allocating memory manually

For doing manual memory management, you can use the general purpose allocator,
which is based on the system's `malloc` and `free` functions:

```nelua
## pragmas.nogc = true -- disables the GC
require 'string'
require 'memory'
require 'allocators.general'

local Person = @record{name: string, age: integer}
local p: *Person = general_allocator:new(@Person) -- allocate the appropriate size for Person
p.name = tostring("John") -- another allocation here
p.age = 20
print(p.name, p.age)
p.name:destroy() -- free the string allocation
general_allocator:delete(p) -- free the Person allocation
p = nilptr
```

### Dereferencing and referencing

The operator `&` is used to get a reference to a variable,
and the operator `$` is used to access the reference.

```nelua
local a = 1
local ap = &a -- ap is a pointer to a
$ap = 2
print(a) -- outputs: 2
a = 3
print($ap) -- outputs: 3
print(ap) -- outputs memory address of a
```

### Automatic referencing and dereferencing

The compiler can perform automatic referencing or dereferencing for records and arrays ***only on function calls**:

```nelua
local Person = @record{name: string, age: integer}

local function print_info_byref(p: *Person)
  print(p.name, p.age)
end
local function print_info_bycopy(p: Person)
  print(p.name, p.age)
end

local p: Person = {"John", 20}
print_info_byref(p) -- the referencing with `&` is implicit here
local pref: *Person = &p
print_info_bycopy(pref) -- the dereferencing with `$` is implicit here
```

For instance, the above code is equivalent to:

```nelua
local Person = @record{name: string, age: integer}

local function print_info_byref(p: *Person)
  print(p.name, p.age)
end
local function print_info_bycopy(p: Person)
  print(p.name, p.age)
end

local p: Person = {"John", 20}
print_info_byref(&p)
local pref: *Person = &p
print_info_bycopy($pref)
```

The above example is not very useful by itself,
but permits auto referencing when doing method calls:

```nelua
local Person = @record{name: string, age: integer}

-- note that this function only accept pointers
function Person.print_info(self: *Person)
  print(self.name, self.age)
end

local p: Person = {"John", 20}
p:print_info() -- perform auto referencing of 'p' when calling here
Person.print_info(p) -- equivalent, also performs auto referencing
```

The automatic referencing and dereferencing mechanism allows the use
of unary operators, binary operators, function calls, or method calls
by value or by reference, for records or arrays.
{:.alert.alert-info}

## Meta programming

The language offers advanced features for metaprogramming by having a full Lua preprocessor
at compile time that can generate and manipulate code when compiling.

### Preprocessor

At compile time a Lua preprocessor is available to render arbitrary code.
It works similarly to templates in the web development world, because it emits
code written between its statements.

Lines beginning with `##` and between `##[[ ]]` are Lua code evaluated by the preprocessor:

```nelua
local a = 0
## for i = 1,4 do
  a = a + 1 -- unroll this line 4 times
## end
print(a) -- outputs 4

##[[
local something = false
if something then
]]
  print('hello') -- prints hello when compiling with "something" defined
##[[ end ]]
```

For instance, the above code compiles exactly as:

```nelua
local a = 0
a = a + 1
a = a + 1
a = a + 1
a = a + 1
print(a)
```

Using the Lua preprocessor, you can generate arbitrary code at compile-time.

### Emitting AST nodes (statements)

It is possible to manually emit AST nodes for statements while preprocessing:

```nelua
##[[
-- create a macro that injects a custom node when called
local function print_macro(str)
  local node = aster.Call{{aster.String{"hello"}}, aster.Id{"print"}}
  -- inject the node where this macro is being called from
  inject_astnode(node)
end
]]

## print_macro('hello')
```

The above code compiles exactly as:

```nelua
print('hello')
```

For a complete list
of AST shapes that can be created using the `aster` module read the [AST definitions file](https://github.com/edubart/nelua-lang/blob/master/lualib/nelua/astdefs.lua) or the
[syntax definitions spec file](https://github.com/edubart/nelua-lang/blob/master/spec/syntaxdefs_spec.lua)
for examples.
{:.alert.alert-info}

### Emitting AST nodes (expressions)

It is possible to manually emit AST nodes for expressions while preprocessing:

```nelua
local a = #[aster.Number{1}]#
print(a) -- outputs: 1
```

The above code compiles exactly as:

```nelua
local a = 1
print(a) -- outputs: 1
```

### Expression replacement

For placing values generated by the preprocessor you can use `#[ ]#`:

```nelua
local deg2rad = #[math.pi/180.0]#
local hello = #['hello' .. 'world']#
local mybool = #[false]#
print(deg2rad, hello, mybool) -- outputs: 0.017453 helloworld false
```

The above code compiles exactly as:

```nelua
local deg2rad = 0.017453292519943
local hello = 'helloworld'
local mybool = false
print(deg2rad, hello, mybool)
```

### Name replacement

For placing identifier names generated by the preprocessor you can use `#| |#`:

```nelua
local #|'my' .. 'var'|# = 1
print(myvar) -- outputs: 1

local function foo1() print 'foo' end
#|'foo' .. 1|#() -- outputs: foo

local Weekends = @enum{ Friday=0, Saturday, Sunday }
print(Weekends.#|'S'..string.lower('UNDAY')|#)
```

The above code compiles exactly as:

```nelua
local myvar = 1
print(myvar)

local function foo1() print 'foo' end
foo1()

local Weekends = @enum{ Friday=0, Saturday, Sunday }
print(Weekends.Sunday)
```

### Preprocessor templated macros

A macros can be created by declaring a function in the preprocessor with its body
containing normal code:

```nelua
## function increment(a, amount)
  -- 'a' in the preprocessor context is a symbol, we need to use its name
  -- 'amount' in the preprocessor context is a lua number
  #|a.name|# = #|a.name|# + #[amount]#
## end
local x = 0
## increment(x, 4)
print(x)
```

The above code compile exactly as:

```nelua
local x = 0
x = x + 4
print(x)
```

### Statement replacement macros

A preprocessor function can be called as if it were a runtime function
in the middle of a block,
it will serve as replacement macro for statements:

```nelua
## local function mul(res, a, b)
  #[res]# = #[a]# * #[b]#
## end

local a, b = 2, 3
local res = 0
#[mul]#(res, a, b)
print(res) -- outputs: 6
```

The above code compiles exactly as:

```nelua
local a, b = 2, 3
local res = 0
res = a * b
print(res) -- outputs: 6
```

### Expression replacement macros

A preprocessor function using `in` statement
can be called as if it were a runtime function
in the middle of a statement,
it will serve as replacement macro for an expression:

```nelua
## local function mul(a, b)
  in #[a]# * #[b]#
## end

local a, b = 2, 3
local res = #[mul]#(a, b)
print(res) -- outputs: 6
```

The above code compiles exactly as:

```nelua
local a, b = 2, 3
local res = a * b
print(res) -- outputs: 6
```

### Preprocessor macros emitting AST nodes

Creating macros using the template rendering mechanism
in the previous example is handy, but has limitations
and is not flexible enough for all cases. For example,
suppose you want to create an arbitrarily sized array. In this
case you will need to manually emit AST nodes:

```nelua
##[[
-- Create a fixed array initializing to 1,2,3,4...n
local function create_sequence(attr_or_type, n)
  local type
  if traits.is_type(attr_or_type) then -- already a type
    type = attr_or_type
  elseif traits.is_attr(attr_or_type) then -- get a type from a symbol
    type = attr_or_type.value
  end
  -- check if the inputs are valid, in case of wrong input
  static_assert(traits.is_type(type), 'expected a type or a symbol to a type')
  static_assert(traits.is_number(n) and n > 0, 'expected n > 0')
  -- create the InitList ASTNode, it's used for any braces {} expression
  local initlist = aster.InitList{pattr = {
    -- hint the compiler what type this braces should be evaluated
    desiredtype = types.ArrayType(type, n)}
  }
  -- fill expressions
  for i=1,n do
    -- convert any Lua value to the proper ASTNode
    initlist[i] = aster.value(i)
  end
  return initlist
end
]]

local a = #[create_sequence(integer, 10)]#
```

The above code compiles exactly as:

```nelua
local a = (@[10]integer){1,2,3,4,5,6,7,8,9,10}
```

### Code blocks as arguments to preprocessor functions

Blocks of code can be passed to macros by surrounding them inside a function:

```nelua
##[[
function unroll(count, block)
  for i=1,count do
    block()
  end
end
]]

local counter = 1
## unroll(4, function()
  print(counter) -- outputs: 1 2 3 4
  counter = counter + 1
## end)
```

The above code compiles exactly as:

```nelua
local counter = 1
print(counter)
counter = counter + 1
print(counter)
counter = counter + 1
print(counter)
counter = counter + 1
print(counter)
counter = counter + 1
```

### Generic code via the preprocessor

Using macros it is possible to create generic code:

```nelua
## function Point(PointT, T)
  local #|PointT|# = @record{x: #|T|#, y: #|T|#}
  function #|PointT|#:squaredlength()
    return self.x*self.x + self.y*self.y
  end
## end

## Point('PointFloat', 'float64')
## Point('PointInt', 'int64')

local pa: PointFloat = {x=1,y=2}
print(pa:squaredlength()) -- outputs: 5.0

local pb: PointInt = {x=1,y=2}
print(pb:squaredlength()) -- outputs: 5
```

### Preprocessing on the fly

While the compiler is processing you can view what the compiler already knows
to generate arbitrary code:

```nelua
local Weekends = @enum{ Friday=0, Saturday, Sunda }
## for i,field in ipairs(Weekends.value.fields) do
  print(#[field.name .. ' ' .. tostring(field.value)]#)
## end
```

The above code compiles exactly as:

```nelua
local Weekends = @enum{ Friday=0, Saturday, Sunday }
print 'Friday 0'
print 'Saturday 1'
print 'Sunday 2'
```

You can even manipulate what has already been processed:

```nelua
local Person = @record{name: string}
## Person.value:add_field('age', primtypes.integer) -- add field 'age' to 'Person'
local p: Person = {name='Joe', age=21}
print(p.age) -- outputs '21'
```

The above code compiles exactly as:

```nelua
local Person = @record{name: string, age: integer}
local p: Person = {name='Joe', age=21}
print(p.age) -- outputs '21'
```

The compiler is implemented and runs using Lua, and the preprocessor
is actually a Lua function that the compiler is running, so it is even possible to modify
or inject code into the compiler itself on the fly.

### Preprocessing polymorphic functions

Polymorphic functions can be specialized at compile time
when used in combination with the preprocessor:

```nelua
local function pow(x: auto, n: integer)
## static_assert(x.type.is_scalar, 'cannot pow variable of type "%s"', x.type)
## if x.type.is_integral then
  -- x is an integral type (any unsigned/signed integer)
  local r: #[x.type]# = 1
  for i=1,n do
    r = r * x
  end
  return r
## elseif x.type.is_float then
  -- x is a floating point type
  return x ^ n
## end
end

local a = pow(2, 2) -- use specialized implementation for integers
local b = pow(2.0, 2) -- use pow implementation for floats
print(a,b) -- outputs: 4 4.0

-- uncommenting the following will trigger the compile error:
--   error: cannot pow variable of type "string"
--pow('a', 2)
```

### Preprocessor code blocks

Arbitrary Lua code can be put inside preprocessor code blocks. Their syntax
starts with `##[[` or `##[=[` (any number of `=` tokens you want between the
brackets) and ends with `]]` or `]=]` (matching the number of `=` tokens previously used):

```nelua
-- this is a preprocessor code block
##[[
function my_compiletime_function(str)
  print(str) -- print at compile time
end
]]

-- call the function defined in the block above
## my_compiletime_function('hello from preprocessor')
```

As shown in the last line, functions defined inside of the preprocessor code
blocks can be evaluated arbitrarily from any part of the code, at any point,
using `##`.

Although said block was defined for a single module, it will be available for all
modules required afterwards, because declarations default to the global scope in Lua.
If you would like to avoid polluting other module's
preprocessor environments, declare its functions as `local`.

### Preprocessor function modularity

Suppose you want to use the same preprocessor function from multiple Nelua
modules. As explained in the [preprocessor code blocks](#preprocessor-code-blocks) section,
one idea is to
declare everything in that block as global so that everything would also be available in
the preprocessor evaluation of other modules.

For example, in `module_A.nelua`:

```nelua
##[[
-- this function is declared as global, so it'll be available on module_B.nelua
function foo()
  print "bar"
end
]]
```

Then, in `module_B.nelua`:

```nelua
require 'module_A'
-- even though foo is not declared in this file, since it's global, it'll be available here
## foo()
```

Although this seems harmless, it can get messy if you define a function with
the same name in different modules. It also means you're relying on global
scope semantics from the preprocessor, which might be unpredictable or brittle
due to evaluation order.

Fortunately, there's a more modular approach for code reuse which does not rely
on global scope. Simply create a standalone Lua module and require it on all
Nelua modules where you want to use it.

The previous example would be refactored as follows:

1\. Create a `foo.lua` (or any name you want) file and paste your code there:

```nelua
local function bar()
  print "bar"
end

return { bar = bar }
```

2\. Then, in any source codes that uses that module:

```nelua
## local foo = require "foo"

## foo.bar()
```

Aside from modularity, this has the benefit of your preprocessor code being
simply Lua code which can leverage all of your editor's tooling and configuration,
such as a code formatter, syntax highlighter, completions, etc.

If the Lua module is not in the same directory where the compiler is running from, then `require`
will fail to find it. To solve this
you can set your system's `LUA_PATH` environment variable to a pattern which matches that directory,
for example, executing `export LUA_PATH="/myprojects/mymodules/?.lua"`{:.language-bash} in your terminal (notice the `?.lua` at the end).
{:.alert.alert-info}

### Preprocessor utilities

The preprocessor comes with some pre-defined functions to assist metaprogramming.

#### static_error

Used to throw compile-time errors:

```nelua
##[[
-- check the current Lua version in the preprocessor
if _VERSION ~= 'Lua 5.4' then
  static_error('not using Lua 5.4, got %s', _VERSION)
end
]]
```

#### static_assert

Used to throw compile-time assertions:

```nelua
-- check the current Lua version in the preprocessor
## static_assert(_VERSION == 'Lua 5.4', 'not using Lua 5.4, got %s', _VERSION)
```

## Generics

A generic is a special type created using a preprocessor function
that is evaluated at compile time to generate a specialized type based
on compile-time arguments. To do this the `generalize` macro is used.
It is hard to explain in words, so take a look at this full example:

```nelua
-- Define a generic type for creating a specialized FixedStackArray
## local make_FixedStackArray = generalize(function(T, maxsize)
  -- alias compile-time parameters visible in the preprocessor to local symbols
  local T = #[T]#
  local MaxSize <comptime> = #[maxsize]#

  -- Define a record using T and MaxSize compile-time parameters.
  local FixedStackArrayT = @record{
    data: [MaxSize]T,
    size: isize
  }

  -- Push a value into the stack array.
  function FixedStackArrayT:push(v: T)
    if self.size >= MaxSize then error('stack overflow') end
    self.data[self.size] = v
    self.size = self.size + 1
  end

  -- Pop a value from the stack array.
  function FixedStackArrayT:pop(): T
    if self.size == 0 then error('stack underflow') end
    self.size = self.size - 1
    return self.data[self.size]
  end

  -- Return the length of the stack array.
  function FixedStackArrayT:__len(): isize
    return self.size
  end

  -- return the new defined type to the compiler
  ## return FixedStackArrayT
## end)

-- define FixedStackArray generic type in the scope
local FixedStackArray: type = #[make_FixedStackArray]#

do -- test with 'integer' type
  local v: FixedStackArray(integer, 3)

  -- push elements
  v:push(1)
  v:push(2)
  v:push(3)
  -- uncommenting would trigger a stack overflow error:
  -- v:push(4)

  -- check the stack array length
  assert(#v == 3)

  -- pop elements checking the values
  assert(v:pop() == 3)
  assert(v:pop() == 2)
  assert(v:pop() == 1)
  -- uncommenting would trigger a stack underflow error:
  -- v:pop()
end

do -- test with 'number' type
  local v: FixedStackArray(number, 3)

  -- push elements
  v:push(1.5)
  v:push(2.5)
  v:push(3.5)
  -- uncommenting would trigger a stack overflow error:
  -- v:push(4.5)

  -- check the stack array length
  assert(#v == 3)

  -- pop elements checking the values
  assert(v:pop() == 3.5)
  assert(v:pop() == 2.5)
  assert(v:pop() == 1.5)
  -- uncommenting would trigger a stack underflow error:
  -- v:pop()
end
```

Generics are powerful for **specializing efficient code at compile time**
based on different compile-time arguments. They are used in many places in the
standard library to, for example, create the
[vector](https://github.com/edubart/nelua-lang/blob/master/lib/vector.nelua)
[sequence](https://github.com/edubart/nelua-lang/blob/master/lib/sequence.nelua)
and [span](https://github.com/edubart/nelua-lang/blob/master/lib/span.nelua)
classes. Generics are similar to C++ templates.
{:.alert.alert-info}

Generics are **memoized**, that is, they are evaluated and defined just once for the
same compile-time arguments.
{:.alert.alert-info}

## Concepts

Concepts are a powerful system used to specialize [polymorphic functions](#polymorphic-functions)
with efficiency at compile-time.

An argument of a polymorphic function can
use the special concept type defined by a
preprocessor function that, when evaluated at compile time,
decides whether the incoming variable type matches the concept requirements.

To create a concept, use the preprocessor function `concept`:

```nelua
local an_scalar = #[concept(function(attr)
  -- the first argument of the concept function is an Attr,
  -- attr are stores different attributes for the incoming symbol, variable or node,
  -- we want to check if the incoming attr type matches the concept
  if attr.type.is_scalar then
    -- the attr is an arithmetic type (can add, subtract, etc)
    return true
  end
  -- the attr type does not match this concept
  return false
end)]#

local function add(x: an_scalar, y: an_scalar)
  return x + y
end

print(add(1, 2)) -- outputs 3

-- uncommenting the following will trigger the compile error:
--   type 'boolean' could not match concept 'an_scalar'
-- add(1, true)
```

When the concepts of a function are matched for the first time,
a specialized function is defined just for those incoming types,
thus the compiler generates different functions in C code for each different match.
This means that the code is specialized
for each type and is handled efficiently because the code does
not need to do runtime type branching (the type branching is only done at compile time).

The property `type.is_scalar` is used here to check the incoming type.
All the properties defined by the compiler to check the incoming types can be
[seen here](https://github.com/edubart/nelua-lang/blob/master/lualib/nelua/types.lua#L44).
{:.alert.alert-info}

### Specializing with concepts

A concept can match multiple types, thus it is possible to specialize
a polymorphic function further using a concept:

```nelua
require 'string'

local an_scalar_or_string = #[concept(function(attr)
  if attr.type.is_stringy then
    -- we accept strings
    return true
  elseif attr.type.is_scalar then
    -- we accept scalars
    return true
  end
  return false
end)]#

local function add(x: an_scalar_or_string,
                   y: an_scalar_or_string)
  ## if x.type.is_stringy and y.type.is_stringy then
    return x .. y
  ## else
    return x + y
  ## end
end

-- add will be specialized for scalar types
print(add(1, 2)) -- outputs 3
-- add will be specialized for string types
print(add('1', '2')) -- outputs 12
```

The compiler only defines new different specialized functions as needed,
i.e. specialized functions for different argument types are memoized.

### Specializing concepts for records

Sometimes you may want to check whether a record matches a concept.
To do this you can set a field on its type to later check in the concept,
plus you can use it in the preprocessor to assist in specializing code:

```nelua
local Vec2 = @record{x: number, y: number}
-- Vec2 is an attr of the "type" type, Vec2.value is it's holded type
-- we set here is_Vec2 at compile-time to use later for checking whether a attr is a Vec2
## Vec2.value.is_Vec2 = true

local Vec2_or_scalar_concept = #[concept(function(attr)
  -- match in case of scalar or Vec2
  return attr.type.is_scalar or attr.type.is_Vec2
end)]#

-- we use a concepts on the metamethod __add to allow adding Vec2 with numbers
function Vec2.__add(a: Vec2_or_scalar_concept, b: Vec2_or_scalar_concept)
  -- specialize the function at compile-time based on the argument type
  ## if a.type.is_Vec2 and b.type.is_Vec2 then
    return (@Vec2){a.x + b.x, a.y + b.y}
  ## elseif a.type.is_Vec2 then
    return (@Vec2){a.x + b, a.y + b}
  ## elseif b.type.is_Vec2  then
    return (@Vec2){a + b.x, a + b.y}
  ## end
end

local a: Vec2 = {1, 2}
local v: Vec2
v = a + 1 -- Vec2 + scalar
print(v.x, v.y) -- outputs: 2 3
v = 1 + a -- scalar + Vec2
print(v.x, v.y) -- outputs: 2 3
v = a + a -- Vec2 + Vec2
print(v.x, v.y) -- outputs: 2 4
```

### Concepts with logic

You can put some logic in your concept to check for any kind of proprieties
that the incoming `attr` should satisfy, and to return compile-time errors
explaining why the concept didn't match:

```nelua
-- Concept to check whether a type is indexable.
local indexable_concept = #[concept(function(attr)
  local type = attr.type
  if type.is_pointer then -- accept pointer to containers
    type = type.subtype
  end
  -- we accept arrays
  if type.is_array then
    return true
  end
  -- we expect a record
  if not type.is_record then
    return false, 'the container is not a record'
  end
  -- the record must have a __index metamethod
  if not type.metafields.__index then
    return false, 'the container must have the __index metamethod'
  end
  -- the record must have a __len metamethod
  if not type.metafields.__len then
    return false, 'the container must have the __len metamethod'
  end
  -- concept matched all the imposed requirements
  return true
end)]#

-- Sum all elements of any container with index beginning at 0.
local function sum_container(container: indexable_concept)
  local v: integer = 0
  for i=0,<#container do
    v = v + container[i]
  end
  return v
end

-- We create our customized array type.
local MyArray = @record{data: [10]integer}
function MyArray:__index(i: integer)
  return self.data[i]
end
function MyArray:__len()
  return #self.data
end

local a: [10]integer = {1,2,3,4,5,6,7,8,9,10}
local b: MyArray = {data = a}

-- sum_container can be called with 'a' because it matches the concept
-- we pass as reference using & here to avoid an unnecessary copy
print(sum_container(&a)) -- outputs: 55

-- sum_container can also be called with 'b' because it matches the concept
-- we pass as reference using & here to avoid an unnecessary copy
print(sum_container(&b)) -- outputs: 55
```

### Concept that infers to another type

Sometimes is useful to infer a concept to a different type
from the incoming `attr`. For example, suppose you want to specialize a function
that optionally accepts any kind of scalar, but you really want it to be implemented
as an number:

```nelua
local facultative_number_concept = #[concept(function(attr)
  if attr.type.is_niltype then
    -- niltype is the type when the argument is missing or when we use 'nil'
    -- we accept it because the number is facultative
    return true
  end
  -- instead of returning true, we return the desired type to be implemented,
  -- the compiler will take care to implicit cast the incoming attr to the desired type,
  -- or throw an error if not possible,
  -- here we want to force the function using this concept to implement as a 'number'
  return primtypes.number
end)]#

local function get_number(x: facultative_number_concept)
  ## if x.type.is_niltype then
    return 0.0
  ## else
    return x
  ## end
end

print(get_number(nil)) -- prints 0.0
print(get_number(2)) -- prints 2.0
```

### Facultative concept

Facultative concepts are commonly used, thus there is
a shortcut for creating them. For instance, the previous code is equivalent to this:

```nelua
local function get_number(x: facultative(number))
  ## if x.type.is_niltype then
    return 0
  ## else
    return x
  ## end
end

print(get_number(nil)) -- prints 0
print(get_number(2)) -- prints 2
```

Use this when you want to specialize optional arguments at compile-time
without any runtime costs.

### Overload concept

Using concepts to overload functions for different incoming types
at compile time is a common use, so there is also a shortcut for creating overload concepts:

```nelua
local function foo(x: overload(integer,string,niltype))
  ## if x.type.is_integral then
    print('got integer ', x)
  ## elseif x.type.is_string then
    print('got string ', x)
  ## else
    print('got nothing')
  ## end
end

foo(2) -- outputs: got integer 2
foo('hello') -- outputs: got string hello
foo(nil) -- outputs: got nothing
```

Use this when you want to specialize different argument types at compile time
without runtime costs.

## Annotations

Annotations are used to prompt the compiler to behave differently during code
generation.

### Function annotations

```nelua
local function sum(a: integer, b: integer) <inline> -- C inline function
  return a + b
end
print(sum(1,2)) -- outputs: 3
```

### Variable annotations

```nelua
local a: integer <noinit>-- don't initialize variable to zero
a = 0 -- manually initialize to zero
print(a) -- outputs: 0

local b <volatile> = 1 -- C volatile variable
print(b) -- outputs: 1
```

## C interoperability

Nelua provides many utilities to interoperate with C code.

### Importing C functions

To import a C function you must use the `<cimport>` annotation:

```nelua
-- import "puts" from C library
local function puts(s: cstring <const>): cint <cimport>
  -- cannot have any code here, because this function is imported
end

puts('hello') -- outputs: hello
```

The above code generates exactly this C code:

```c
/* ------------------------------ DECLARATIONS ------------------------------ */
int puts(const char* s);
static int nelua_main(int argc, char** argv);
/* ------------------------------ DEFINITIONS ------------------------------- */
int nelua_main(int argc, char** argv) {
  puts("hello");
  return 0;
}
```

Notice that the `puts` function is **declared automatically**,
i.e., there is no need to include the header that declares the function.
{:.alert.alert-info}

### Importing C functions declared in headers

Sometimes you need to import a C function that is declared
in a C header, specially if it is declared as a macro:

```nelua
-- `nodecl` is used because this function doesn't need to be declared by Nelua,
-- as it will be declared in <stdio.h> header
-- `cinclude` is used to make the compiler include the header when using the function
local function puts(s: cstring <const>): cint <cimport, nodecl, cinclude '<stdio.h>'>
end

puts('hello') -- outputs: hello
```

The above code generates exactly this C code:

```c
#include <stdio.h>
/* ------------------------------ DECLARATIONS ------------------------------ */
static int nelua_main(int argc, char** argv);
/* ------------------------------ DEFINITIONS ------------------------------- */
int nelua_main(int argc, char** argv) {
  puts("hello");
  return 0;
}
```

Notice that the `nodecl` is needed when importing any C function
that is declared in a C header, otherwise the function will have duplicate declarations.
{:.alert.alert-info}

### Including C files with defines

Sometimes you need to include a C file while defining something before the include:

```nelua
-- link SDL2 library
## linklib 'SDL2'
-- define SDL_MAIN_HANDLED before including SDL2
## cdefine 'SDL_MAIN_HANDLED'
-- include SDL2 header
## cinclude '<SDL2/SDL.h>'

-- import some constants defined in SDL2 header
local SDL_INIT_VIDEO: uint32 <cimport, nodecl>

-- import functions defined in SDL2 header
local function SDL_Init(flags: uint32): int32 <cimport, nodecl> end
local function SDL_Quit() <cimport, nodecl> end

SDL_Init(SDL_INIT_VIDEO)
SDL_Quit()
```

### Importing C functions using a different name

The `<cimport>` annotation uses the same name as its symbol name,
but it is possible to import the function under a different name:

```nelua
-- we pass the C function name as a parameter for `cimport`
local function c_puts(s: cstring): cint <cimport 'puts', nodecl, cinclude '<stdio.h>'>
end

c_puts('hello') -- outputs: hello
```

### Linking a C library

When importing a function from a C library you also need to link the library,
to do this use the `linklib` function in the preprocessor:

```nelua
-- link the SDL2 library when compiling
## linklib 'SDL2'

local function SDL_GetPlatform(): cstring <cimport> end

print(SDL_GetPlatform()) -- outputs your platform name (Linux, Windows, ...)
```

Notice that we didn't need to include the SDL header in the above example,
we could, but we let Nelua declare the function.
{:.alert.alert-info}

### Passing C flags

It is possible to add custom C flags when compiling via the preprocessor:

```nelua
##[[
if FAST then -- release build
  cflags '-Ofast' -- C compiler flags
  ldflags '-s' -- link flags
else -- debug build
  cflags '-Og'
end
]]
```

If we run the above example with `nelua -DFAST example.nelua`
the C compiler will compile with the cflags `-Ofast` otherwise `-Og`.

### Emitting raw C code

Sometimes to do low level things in C, or to avoid Nelua's default semantics,
you may want to emit raw C code:

```nelua
local function do_stuff()
  -- make sure `<stdio.h>` is included
  ## cinclude '<stdio.h>'

  -- emits in the directives section of the generated C file
  ## cinclude [[#define HELLO_MESSAGE "hello from C"]]

  -- emits in the declarations section of the generated C file
  ## cemitdecl [[static const char* get_hello_message();]]

  -- emits in the definitions section of the generated C file
  ## cemitdefn [[const char* get_hello_message() { return HELLO_MESSAGE; }]]

  -- emits inside this function in the generated C file
  ##[==[ cemit [[
    printf("%s\n", get_hello_message());
  ]] ]==]
end

do_stuff()
```

Nelua can emit C code in 4 different sections:
* In the **directives** section with `cinclude`, this is where C include and defines are emitted.
* In the **declarations** section with `cemitdecl`, this is  where functions and variables names are declared.
* In the **definitions** section with `cemitdefn`, this is where functions are defined.
* In the current scope with `cemit`, this emits in the current scope context, and
local variables should be accessible.
{:.alert.alert-info}

### Exporting named C functions

You can use Nelua to create C libraries. When doing this,
you may want to fix the name of the generated C function and export it:

```nelua
-- `cexport` marks this function to be exported
-- `codename` fix the generated C code name
local function foo() <cexport, codename 'mylib_foo'>
  return 1
end
```

The above code generates exactly this C code:

```c
/* ------------------------------ DECLARATIONS ------------------------------ */
extern int64_t mylib_foo();
/* ------------------------------ DEFINITIONS ------------------------------- */
int64_t mylib_foo() {
  return 1;
}
```

### C primitives

For importing C functions, additional primitive types are provided for compatibility:

| Type              | C Type               | Suffixes         |
|-------------------|----------------------|------------------|
| `cshort`          | `short`              | `_cshort`        |
| `cint`            | `int`                | `_cint`          |
| `clong`           | `long`               | `_clong`         |
| `clonglong`       | `long long`          | `_clonglong`     |
| `cptrdiff`        | `ptrdiff_t`          | `_cptrdiff`      |
| `cchar`           | `char`               | `_cchar`         |
| `cschar`          | `signed char`        | `_cschar`        |
| `cuchar`          | `unsigned char`      | `_cuchar`        |
| `cushort`         | `unsigned short`     | `_cushort`       |
| `cuint`           | `unsigned int`       | `_cuint`         |
| `culong`          | `unsigned long`      | `_culong`        |
| `culonglong`      | `unsigned long long` | `_culonglong`    |
| `csize`           | `size_t`             | `_csize`         |
| `clongdouble`     | `long double`        | `_clongdouble`   |
| `cstring`         | `char*`              | `_cstring`       |
{: .table.table-bordered.table-striped.table-sm}

Use these types for **importing C functions only**. For normal
code, use the other Nelua primitive types.
{:.alert.alert-info}

{% endraw %}

*[closure]: Closure is function that capture variables from parent scopes.
*[upvalue]: A variable captured from inside a scope above the closure.
*[integral]: A whole number, a number that has no fractional part.
*[GC]: Garbage Collector

<a href="/libraries/" class="btn btn-outline-primary btn-lg float-right">Libraries >></a>
