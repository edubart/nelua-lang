---
layout: docs
title: Overview
permalink: /overview/
categories: docs toc
order: 3
---

{% raw %}

This is a quick overview of the language features that are currently implemented by examples.
{: .lead}

All the features and examples presented here should work with the latest Nelua, for
features not implemented yet see the [draft](/draft/).
{: .callout.callout-info}

## A note for Lua users

Most of Nelua syntax and semantics
are similar to Lua, thus if you know Lua you probably know Nelua too. However Nelua have many
additions to code with type notations, to make more efficient code and to meta program.
This overview try to focus more on those features.

There is no interpreter or VM, all the code is converted directly into native machine code,
thus expect better efficiency than Lua. However this means that Nelua can't load
code generated at runtime, the user is encouraged to generate code at compile-time
using the preprocessor.

Although copying Lua code with minor changes is a goal of Nelua, not all Lua
features are implemented yet. Mostly the dynamic part such as tables and handling dynamic types
at runtime is not implemented yet, thus at the moment is best to try Nelua using
records instead of tables and type notations in function definitions.
Visit [this](/diffs/) page for the full list of available features.
{: .callout.callout-warning}

## A note for C users

Nelua tries to expose most of C features without overhead, thus expect
to get near C performance when coding in the C style, that is, using
type notations, manual memory management, pointers and records (structs).

The semantics are not exactly as C semantics but close. There are slight differences
to minimize undefined behaviors (like initialize to zero by default) and
other ones to keep Lua semantics (like integer division rounds towards minus infinity).
However there are ways to get C semantics for each case when needed.

The preprocessor is much more powerful than C preprocessor,
because it's actually the compiler running in Lua,
thus you can interact with the compiler while parsing. The preprocessor should
be used for making generic code, code specialization and avoiding code duplication.

Nelua generates everything compiled into a single readable C file,
if you know C is recommended to read the generated C code sometimes
to learn more what exactly the compiler outputs.

## Hello world

Simple hello world program is just like in Lua:

```lua
print 'Hello world!'
```

## Comments

Comments are just like in Lua:

```nelua
-- one line comment
--[[
  multi-line comment
]]
--[=[
  multi line comment, `=` can be placed multiple times
  in case if you have `[[` `]]` tokens inside, it will
  always match it's corresponding token
]=]
```

## Variables

Variables are declared or defined like in Lua, but optionally
you can specify it's type when declaring:

```nelua
local a = nil -- of deduced type 'any', initialized to nil
local b = false -- of deduced type 'boolean', initialized to false
local s = 'test' -- of deduced type 'string', initialized to 'test'
local one = 1 --  of type 'integer', initialized to 1
local pi: number = 3.14 --  of type 'number', initialized to 1
print(a,b,s,one,pi) -- outputs: nil false test 1 3.1400000
```

The compiler takes advantages of types to make compile-time checks, runtime checks
and generate **efficient code** for that **specific type**.
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

The compiler does it best it can to deduce the type for you, in most situations
it should work, but in some corner cases you may want to explicitly set a type for a variable.
{:.alert.alert-info}

### Type collision

In case of different types being assigned to a same variable,
then the compiler deduces the variable type
to the `any` type, a type that can hold anything an runtime, this makes Nelua code compatible with lua values semantics:

```nelua
local a -- a type will be deduced
a = 2
a = false
print(a) -- outputs: false
-- a is deduced to be of type 'any', because it could hold an 'integer' or a 'boolean'
```

The **any type is poorly supported** at the moment, so please at the moment **avoid this situation**, that is, avoid making the compiler deduce types collisions that would be deduced to the `any` type. Usually you don't want use any types anyway, as they are less efficient. Collision between different numeric types are fine,
the compiler always resolves to the largest appropriate number type.
{:.alert.alert-warning}

### Zero initialization

Variables declared but not defined early are always initialized to zeros by default,
this prevents undefined behaviors:

```nelua
local a -- variable of deduced type 'any', initialized to 'nil'
local i: integer -- variable of type 'integer', initialized to 0
print(a, i) --outputs: nil 0
```

Zero initialization can be **optionally disabled** using the `<noinit>` [annotation](#annotations),
although not advised, usually one would do this only for micro optimization purposes.
{:.alert.alert-info}

### Auto variables

Variables declared as `auto` have its type deduced early based only in the type of its first assignment:

```nelua
local a: auto = 1 -- a is deduced to be of type 'integer'

-- uncommenting the following will trigger the compile error:
--   error: in variable assignment: no viable type conversion from `boolean` to `int64`
--a = false

print(a) -- outputs: 1
```

Auto variables were not intended to be used in variable declarations
like in the example above, because usually you can omit the type
and the compiler will automatically deduce already,
unless you want the compiler to deduce early.
The `auto` type was really created to be used with [polymorphic functions](#polymorphic-functions).
{:.alert.alert-warning}

### Compile time variables

Comptime variables have its value known at compile-time:

```nelua
local a <comptime> = 1 + 2 -- constant variable of value '3' evaluated and known at compile-time
```

The compiler takes advantages of compile-time variables to generate
**efficient code**,
because compile-time variables can be processed at compile-time.
Compile time variables are also useful
for using as compile-time parameters in [polymorphic functions](#polymorphic-functions).
{:.alert.alert-info}

### Const variables

Const variables can be assigned once at runtime however they cannot mutate:

```nelua
local x <const> = 1
local a <const> = x
print(a) -- outputs: 1

-- uncommenting the following will trigger the compile error:
--   error: cannot assign a constant variable
--a = 2
```

Const annotation can also be used for function arguments.

The use of `<const>` annotation is mostly for aesthetic
purposes, it's usage does not change efficiency.
{:.alert.alert-info}

## Symbols

Symbols are named identifiers for functions, types or variables.

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

Global symbols are visible in other source files, they can only be declared in the top scope:

```nelua
global global_a = 1
global function global_f()
end
```

If the above is saved into a file in the same directory as `globals.nelua`, then we can run:

```nelua
require 'globals'
print(global_a) -- outputs: 1
print(global_f()) -- outputs: f
```

Unlike Lua, to declare a global variable you **must explicitly** use the
`global` keyword.
{:.alert.alert-info}

### Symbols with special characters

A symbol identifier, that is, the symbol name, can contain UTF-8 special characters:

```nelua
local π = 3.14
print(π) -- outputs 3.14
```

## Control flow

Nelua provides the same control flow mechanism from Lua, plus some additional
ones to make low level coding easier, like `switch`, `defer` and `continue` statements.

### If

If statement is just like in Lua:

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

Switch statement is similar to C switches:

```nelua
local a = 1 -- change this to 2 or 3 to trigger other ifs
switch a do
case 1 then
  print 'is 1'
case 2, 3 then
  print 'is 2 or 3'
else
  print 'else'
end
```

The case expression can only contain **integral** numbers known at **compile-time**. The
compiler can generate more optimized code when using a switch instead of many ifs for integers.
{:.alert.alert-info}

### Do

Do blocks are useful to create arbitrary scopes to avoid collision of
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

Defer statement is useful for executing code at scope termination.

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
It's guaranteed to be executed in reverse order before any `return`, `break` or `continue` statement.
{:.alert.alert-info}

### Goto

Gotos are useful to get out of nested loops and jump between codes:

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

Repeat is also like in Lua:

```nelua
local a = 0
repeat
  a = a + 1
  print(a) -- outputs 1 2 3 4 5
  local stop = a == 5
until stop
```

Note that like Lua, a variable declared inside `repeat` scope **is visible** inside it's condition expression.
{:.alert.alert-info}

### Numeric For

Numeric for are like in Lua, meaning they are inclusive for the first and the last
element:

```nelua
for i = 0,5 do
  -- i is deduced to 'integer'
  print(i) -- outputs 0 1 2 3 4 5
end
```

Like in Lua, numeric for loops always evaluate it's begin, end and step expressions **only once**. The iterate
variable type is automatically deduced using the begin and end expressions only.
{:.alert.alert-info}

#### Exclusive For
An exclusive for is available to do exclusive for loops, they work using
comparison operators `~=` `<=` `>=` `<` `>`:

```nelua
for i=0,<5 do
  print(i) -- outputs 0 1 2 3 4
end
```

#### Stepped For
The last parameter in for syntax is the step, it's counter is always incremented
with `i = i + step`, by default step is always 1, when using negative steps reverse for is possible:

```nelua
for i=5,0,-1 do
  print(i) -- outputs 5 4 3 2 1
end
```

### Continue
Continue statement is used to skip a loop to it's next iteration:

```nelua
for i=1,10 do
  if i<=5 then
    continue
  end
  print(i) -- outputs: 6 7 8 9 10
end
```

### Break
Break statement is used to break a loop:

```nelua
for i=1,10 do
  if i>5 then
    break
  end
  print(i) -- outputs: 1 2 3 4 5
end
```

## Primitive types

Primitives types are all the basic types builtin in the compiler.

### Boolean

```nelua
local a: boolean -- variable of type 'boolean' initialized to 'false'
local b = false
local c = true
print(a,b,c) -- outputs: false false true
```

The `boolean` is defined as `bool` in C code.

### Numbers

Number literals are defined similar as in Lua:

```nelua
local a = 1234 -- variable of type 'integer'
local b = 0xff -- variable of type 'integer'
local c = 3.14159 -- variable of type 'number'
local d: integer
print(a,b,c,d) -- outputs: 1234 255 3.141590 0
```

The `integer` is the default type for integral literals without suffix.
The `number` is the default type for fractional literals without suffix.

You can use type suffixes to force a type for a numeric literal:

```nelua
local a = 1234_u32 -- variable of type 'int32'
local b = 1_f32 -- variable of type 'float32'
print(a,b) --outputs: 1234 1.000000
```

The following table shows Nelua primitive numeric types and is related type in C:

| Type              | C Type          | Suffixes            |
|-------------------|-----------------|---------------------|
| `integer`         | `int64_t`       | `_i` `_integer`     |
| `uinteger`        | `unt64_t`       | `_u` `_uinteger`    |
| `number`          | `double`        | `_n` `_number`      |
| `byte`            | `uint8_t`       | `_b` `_byte`        |
| `isize`           | `intptr_t`      | `_is` `_isize`      |
| `int8`            | `int8_t`        | `_i8` `_int8`       |
| `int16`           | `int16_t`       | `_i16` `_int16`     |
| `int32`           | `int32_t`       | `_i32` `_int32`     |
| `int64`           | `int64_t`       | `_i64` `_int64`     |
| `usize`           | `uintptr_t`     | `_us` `_usize`      |
| `uint8`           | `uint8_t`       | `_u8` `_uint8`      |
| `uint16`          | `uint16_t`      | `_u16` `_uint16`    |
| `uint32`          | `uint32_t`      | `_u32` `_uint32`    |
| `uint64`          | `uint64_t`      | `_u64` `_uint64`    |
| `float32`         | `float`         | `_f32` `_float32`   |
| `float64`         | `double`        | `_f64` `_float64`   |
{: .table.table-bordered.table-striped.table-sm}

The types `isize` and `usize` types are usually 32 bits wide on 32-bit systems,
and 64 bits wide on 64-bit systems.

When you need an integer value you **should use** `integer`
unless you have a specific reason to use a sized or unsigned integer type.
The `integer`, `uinteger` and `number` **are intended to be configurable**, by default
they are 64 bits for all architectures, but this can be customized by the user at compile-time
via the preprocessor when needed.
{:.alert.alert-info}

### Strings

There are two types of strings, the `string` used for strings allocated at runtime,
and `stringview` used for strings literals defined at compile-time and as views
of runtime strings too.

```nelua
-- to use the 'string' type we must import from the standard library
require 'string'

local mystr: string -- empty string
local str1: string = 'my string' -- variable of type 'string'
local str2 = "static stringview" -- variable of type 'stringview'
local str3: stringview = 'stringview two' -- also a 'stringview'
print(str1, str2, str3) -- outputs: "my string" "static stringview" "stringview two"
```

The major difference of `stringview` and `string` is that `stringview` doesn't
manage the string memory, i.e. it doesn't allocates or deallocate strings.
The `string` type is usually allocated at runtime and it frees the string memory
once it reference count reaches 0. When the garbage collector is disabled
the `stringview` uses weak references, thus
any `stringview` pointing to a `string` is invalidated once the related `string` is freed.
Both types can be converted from one to another.

Like in Lua, `string` **is immutable**, this make the semantics similar to Lua.
If the programmer wants a mutable string he can always implement his own string class.
{:.alert.alert-info}

### Array

Array is a list with where its size is fixed and known at compile-time:

```nelua
local a: array(integer, 4) = {1,2,3,4}
print(a[0], a[1], a[2], a[3]) -- outputs: 1 2 3 4

local b: [4]integer -- "[4]integer" is syntax sugar for "array(integer, 4)"
print(b[0], b[1], b[2], b[3]) -- outputs: 0 0 0 0
local len = #b -- get the length of the array, should be 4
print(len) -- outputs: 4
```

When passing an array to a function as an argument, it is **passed by value**,
this means the array is copied and can incur in some performance overhead.
Thus when calling functions you mostly want to pass arrays by reference
using the [reference operator](#dereferencing-and-referencing) when appropriate.
{:.alert.alert-warning}

### Enum

Enums are used to list constant values in sequential order:

```nelua
local Weeks = @enum {
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

The programmer must always initialize the first enum value, this choice
was made to makes the code more clear when reading.
{:.alert.alert-info}

### Any

Any is a special type that can store any type at runtime:

```nelua
local a: any = 2 -- variable of type 'any', holding type 'integer' at runtime
print(a) -- outputs 2
a = false -- now holds the type 'boolean' at runtime
print(a) -- outputs false
```

The `any` type makes Nelua semantics compatible to Lua, you can use it to make untyped code
just like in Lua, however know that you pays the price in
performance, as operations on `any` types generate lots of branches at runtime,
thus **less efficient code**.
{:.alert.alert-info}

The **any type is poorly supported** at the moment, so please at the moment **avoid using it**.
Usually you don't want use any types anyway, as they require runtime branching, thus less efficient.
{:.alert.alert-warning}

### Record

Record store variables in a block of memory:

```nelua
local Person = @record {
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

Records are straight translated to C structs.
{:.alert.alert-info}

### Pointer

A pointer points to a region in memory of a specific type:

```nelua
local n = nilptr -- a generic pointer, initialized to nilptr
local p: pointer --a generic pointer to anything, initialized to nilptr
local i: pointer(integer) -- pointer to an integer

-- syntax sugar
local i: *integer
```

Pointers are straight translated to C raw pointers.
Unlikely C pointer arithmetic is disallowed,
to do pointer arithmetic you must explicitly cast to and from integers.
{:.alert.alert-info}

#### Unbounded Array

An an array with size 0 is an unbounded array,
that is, an array with unknown size at compile time:

```nelua
local a: array(integer, 4) = {1,2,3,4}

-- unbounded array only makes sense when used with pointer
local a_ptr: pointer(array(integer, 0))
a_ptr = &a -- takes the reference of 'a'
print(a_ptr[1])
```

Unbounded array is useful to index pointers, because unlikely
C you cannot index pointers unless it's a pointer
of an unbounded array.
{:.alert.alert-info}

Unbounded arrays are **unsafe**, because bounds checking is
not possible at compile-time or runtime, prefer the [span](#span)
to have bounds checking.
{:.alert.alert-warning}

### Function type

The function type, mostly used to store callbacks, is the type of a function:

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

The function type is just a pointer, thus can be converted to/from generic pointers.
{:.alert.alert-info}

### Span

Span, also known as "fat pointers" or "slices" in other languages,
are pointers to a block of contiguous elements which size is known at runtime:

```nelua
require 'span'
local arr = (@[4]integer) {1,2,3,4}
local s: span(integer) = &arr
print(s[0], s[1]) -- outputs: 1 2
print(#s) -- outputs 4
```

The advantage of using a span instead of a pointer it that spans generates runtime
checks for out of bounds access, thus usually a code using a span is **more safe**.
The runtime checks can be disabled in release builds.
{:.alert.alert-info}

### Niltype

The niltype is the type of `nil`.

Niltype type is not useful by itself, it's only useful when using with unions to create the
optional type or for detecting `nil` arguments in [polymorphic functions](#polymorphic-functions).
{:.alert.alert-info}

### The "type" type

The `type` type is the type of a symbol that refers to a type.
Symbols with this type is used at compile-time only, they are useful for aliasing types:

```nelua
local MyInt: type = @integer -- a symbol of type 'type' holding the type 'integer'
local a: MyInt -- variable of type 'MyInt' (actually an 'integer')
print(a) -- outputs: 0
```

In the middle of statements the `@` token is required to precede a type expression,
this token signs the compiler that a type expression is expect after it.
{:.alert.alert-info}

#### Size of a type

You can use the operator `#` to get a size in bytes of any type:

```nelua
local Vec2 = @record{x: integer, y: integer}
print(#Vec2) -- outputs: 8
```

### Implicit type conversion

Some types can be implicit converted, for example any arithmetic type can be
converted to any other arithmetic type:

```nelua
local i: integer = 1
local u: uinteger = i
print(u) -- outputs: 1
```

Implicit conversion generates **runtime checks** for **loss of precision**
in the conversion, if this happens the application crashes with a narrow casting error.
The runtime checks can be disabled in release builds.
{:.alert.alert-warning}

### Explicit type conversion

The expression `(@type)(variable)` is used to explicitly convert a
variable to another type.

```nelua
local i = 1
local f = (@number)(i) -- convert 'i' to the type 'number'
print(i, f) -- outputs: 1 1.000000
```

If a type is aliased to a symbol then
is also possible to convert variables by calling the symbol:

```nelua
local MyNumber = @number
local i = 1
local f = MyNumber(i) -- convert 'i' to the type 'number'
print(i, f) -- outputs: 1 1.000000
```

Unlikely implicit conversion, explicit conversions skip runtime checks:

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
print(2 ^ 2) -- pow, outputs: 4.000000
print(5 // 2) -- integer division, outputs: 2
print(5 / 2) -- float division, outputs: 2.500000
```

All Lua operators are provided:

| Name | Syntax | Kind | Operation |
|---|---|---|---|
| or       | `a or b`{:.language-nelua}      | binary   | conditional or            |
| and      | `a and b`{:.language-nelua}     | binary   | conditional and           |
| lt       | `a < b`{:.language-nelua}       | binary   | less than                 |
| gt       | `a > b`{:.language-nelua}       | binary   | greater than              |
| le       | `a <= b`{:.language-nelua}      | binary   | less or equal than        |
| ge       | `a >= b`{:.language-nelua}      | binary   | greater or equal than     |
| ne       | `a ~= b`{:.language-nelua}      | binary   | not equal                 |
| eq       | `a == b`{:.language-nelua}      | binary   | equal                     |
| bor      | `a | b`{:.language-nelua}       | binary   | bitwise or                |
| band     | `a & b`{:.language-nelua}       | binary   | bitwise and               |
| bxor     | `a ~ b`{:.language-nelua}       | binary   | bitwise xor               |
| shl      | `a << b`{:.language-nelua}      | binary   | bitwise left shift        |
| shr      | `a >> b`{:.language-nelua}      | binary   | bitwise right shift       |
| bnot     | `~a`{:.language-nelua}          | unary    | bitwise not               |
| concat   | `a .. b`{:.language-nelua}      | binary   | concatenation             |
| add      | `a + b`{:.language-nelua}       | binary   | arithmetic add            |
| sub      | `a - b`{:.language-nelua}       | binary   | arithmetic subtract       |
| mul      | `a * b`{:.language-nelua}       | binary   | arithmetic multiply       |
| unm      | `-a`{:.language-nelua}          | unary    | arithmetic negation       |
| mod      | `a % b`{:.language-nelua}       | binary   | arithmetic modulo         |
| pow      | `a ^ b`{:.language-nelua}       | binary   | arithmetic exponentiation |
| div      | `a / b`{:.language-nelua}       | binary   | arithmetic division       |
| idiv     | `a // b`{:.language-nelua}      | binary   | arithmetic floor division |
| not      | `not a`{:.language-nelua}       | unary    | boolean negation          |
| len      | `#a`{:.language-nelua}          | unary    | length                    |
| deref    | `$a`{:.language-nelua}          | unary    | pointer dereference       |
| ref      | `&a`{:.language-nelua}          | unary    | memory reference          |
{: .table.table-bordered.table-striped.table-sm}

All the operators follows Lua semantics, i.e.:
* `%` and `//` rounds the quotient towards minus infinity.
* `/` and `^` promotes numbers to floats.
* Integer overflows wrap around.
* Bitwise shifts are defined for negative and large shifts.
* `and`, `or`, `not`, `==`, `~=` can be used on any variable type.

The only additional operators over Lua are `$` and `&`, used for working with pointers.
{:.alert.alert-info}

## Functions

Functions are declared like in Lua,
but arguments and returns can have the type explicitly specified:

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

### Argument type inference

When not specifying a type for an argument, the compiler assumes that the argument
is of the `any` type:

```nelua
local function get(a)
  -- a is of type 'any'
  return a -- return is of deduced type 'any'
end
print(get(1)) -- outputs: 1
```

In contrast with variable declaration,
when the type is omitted from a function argument there is no
automatic deducing of the argument type, instead it's assumed the argument must
be of the `any` type, this makes Nelua semantics more compatible with Lua semantics.
{:.alert.alert-info}

At the moment avoid doing this and you must **explicty set types for functions arguments**,
due to the poor support for `any` type yet. Omitting the type for the return type is fine,
because the compiler can deduce it.
{:.alert.alert-warning}

### Recursive calls

Functions can call itself recursively:

```nelua
local function fib(n: integer): integer
  if n < 2 then return n end
  return fib(n - 2) + fib(n - 1)
end
print(fib(10)) -- outputs: 55
```

Function that does recursive calls itself must **explicit set the return type**,
i.e, the compiler cannot deduce the return type.
{:.alert.alert-warning}

### Multiple returns

Functions can have multiple returns like in Lua:

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

### Top scope closures

Functions declared in the top scope works as top scope closure,
they have access to all local variables declared before it:

```nelua
local counter = 1 -- 'a' lives in the heap because it's on the top scope
local function increment() -- foo is a top scope closure
  -- counter is an upvalue for this function, we can access and modify it
  counter = counter + 1
end
print(counter) -- outputs 1
increment()
print(counter) -- outputs 2
```

Unlikely Lua,
when declaring functions in the top scope the compiler takes advantages of the fact that
top scope variables is always accessible in the program static storage memory
to create lightweight closures without
needing to hold a upvalue reference or use a garbage collector,
thus they are very lightweight and does not incur costs like a closure nested in a function.
{:.alert.alert-info}

### Polymorphic functions

Polymorphic functions, or in short poly functions in the sources,
are functions which contains arguments that proprieties can
only be known when calling the function at compile-time.
They are defined and processed lately when calling it for the first time.
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
print(b) -- outputs: 3.000000
```

In the above, the `auto` type is used as a generic placeholder to replace the function argument
by the incoming call type, this makes possible to make a generic function for multiple types.

Polymorphic functions are memoized, that is, only defined once for each kind of specialization.
{:.alert.alert-info}

Later we will show how polymorphic functions are more useful when used in combination with the [preprocessor](#preprocessing-polymorphic-functions).
{: .callout.callout-info}

### Record functions

A record type can have functions defined for it, this makes useful to
organize functions that are to be used just within the record:

```nelua
local Vec2 = @record{x: number, y: number}

function Vec2.create(x: integer, y: integer): Vec2
  return (@Vec2){x, y}
end

local v = Vec2.create(1,2)
print(v.x, v.y) -- outputs: 1 2
```

### Record methods

A method is function defined for record that takes a reference to the record type
as its first argument, this first argument is visible as `self` inside the method.
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
print(v.x, v.y) -- outputs 2 2
print(v:area()) -- outputs 6
```

When calling methods on records, the compiler automatically takes care
to [automatically reference or dereference](#automatic-referencing-and-dereferencing)
the object being called.
{:.alert.alert-info}

### Record metamethods

Some special methods using the `__` prefix are used by the compiler to defines behaviors
on certain operations with the record type,
they are called metamethods and are similar to the Lua metamethods:

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
print(c.x, c.y) -- outputs: 4 6
local len = #c -- calls the __len metamethod
print(len) -- outputs: 7.2
```

Complete list of the metamethods that can be defined for records:

| Name | Syntax | Kind | Operation |
|---|---|---|---|
| `__lt`            | `a < b`{:.language-nelua}  | binary   | less than                   |
| `__le`            | `a <= b`{:.language-nelua} | binary   | less or equal than          |
| `__eq`            | `a == b`{:.language-nelua} | binary   | equal                       |
| `__bor`           | `a | b`{:.language-nelua}  | binary   | bitwise or                  |
| `__band`          | `a & b`{:.language-nelua}  | binary   | bitwise and                 |
| `__bxor`          | `a ~ b`{:.language-nelua}  | binary   | bitwise xor                 |
| `__shl`           | `a << b`{:.language-nelua} | binary   | bitwise left shift          |
| `__shr`           | `a >> b`{:.language-nelua} | binary   | bitwise right shift         |
| `__bnot`          | `~a`{:.language-nelua}     | unary    | bitwise not                 |
| `__concat`        | `a .. b`{:.language-nelua} | binary   | concatenation               |
| `__add`           | `a + b`{:.language-nelua}  | binary   | arithmetic add              |
| `__sub`           | `a - b`{:.language-nelua}  | binary   | arithmetic subtract         |
| `__mul`           | `a * b`{:.language-nelua}  | binary   | arithmetic multiply         |
| `__unm`           | `-a`{:.language-nelua}     | unary    | arithmetic negation         |
| `__mod`           | `a % b`{:.language-nelua}  | binary   | arithmetic modulo           |
| `__pow`           | `a ^ b`{:.language-nelua}  | binary   | arithmetic exponentiation   |
| `__div`           | `a / b`{:.language-nelua}  | binary   | arithmetic division         |
| `__idiv`          | `a // b`{:.language-nelua} | binary   | arithmetic floor division   |
| `__len`           | `#a`{:.language-nelua}     | unary    | length                      |
| `__index`         | `a[b]`{:.language-nelua}   | indexing | array index                 |
| `__atindex`       | `a[b]`{:.language-nelua}   | indexing | array index via reference   |
| `__tocstring`     |                            | cast     | implicit cast to cstring    |
| `__tostring`      |                            | cast     | implicit cast to string     |
| `__tostringview`  |                            | cast     | implicit cast to stringview |
| `__convert`       |                            | cast     | implicit cast from anything |
{: .table.table-bordered.table-striped.table-sm}

### Record globals

Sometimes is useful to declare a global variable inside a record type,
using the record as a "namespace":

```nelua
global Globals = @record{} -- record used just for name spacing
global Globals.AppName: stringview
Globals.AppName = "My App"
print(Globals.AppName) -- outputs: My App
```

Record globals can be used to encapsulate modules,
like tables are used to make modules in Lua.
{:.alert.alert-info}

### Calls with nested records

You can define and later initialize complex records structures in a Lua like style:

```nelua
local WindowConfig = @record{
  title: stringview,
  pos: record {
    x: integer,
    y: integer
  },
  size: record {
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
However it can be disabled with the pragma `nogc` via the command line using `-P nogc`
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
different from Lua usual style, because now you need to **think of each allocation
and deallocation**, including for strings, otherwise memory in your application will leak,
thus is best to leave the GC enabled when you need rapid prototyping.
{:.alert.alert-warning}

Disable the GC if you want to control the memory on your own for performance reasons,
know how to deal with memory management and don't mind the additional cognitive load
when coding without automatic memory management.
{:.alert.alert-info}

### Allocating memory with the GC

Nelua provides many allocators to assist managing memory.
The most important ones are the `allocators.general` and `allocators.gc`.

When using the GC you should allocated using the `gc_allocator`:
```nelua
require 'string'
require 'memory'
require 'allocators.gc'

local Person = @record{name: string, age: integer}
local p: *Person = gc_allocator:new(@Person)
p.name = "John"
p.age = 20
print(p.name, p.age)
p = nilptr
-- we don't need to deallocate, the GC will do this on its own when needed!
```

When the GC is enabled, you must **always allocate memory that contains pointers using**
`gc_allocator` instead of other allocators,
because it marks the allocated memory region for scanning for references.
{:.alert.alert-warning}

### Allocating memory manually

For doing manual memory management you can use the general purpose allocator,
that is based on the system's `malloc` and `free` functions:

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

The operator `&` is used to get a reference a variable,
and the operator `$` is used to access the reference.

```nelua
local a = 1
local ap = &a -- ap is a pointer to a
$ap = 2
print(a) -- outputs 2
a = 3
print($ap) -- outputs 3
```

### Automatic referencing and dereferencing

The compiler can perform automatic referencing or dereferencing for records or arrays:

```nelua
local Person = @record{name: stringview, age: integer}
local p: Person = {"John", 20}
local p_ref: *Person = p -- the referencing with `&` is implicit here
local p_copy: Person = p_ref -- the dereferencing with `$` is implicit here
```

For instance, the above code is equivalent to:

```nelua
local Person = @record{name: stringview, age: integer}
local p: Person = {"John", 20}
local p_ref: *Person = &p
local p_copy: Person = $p_ref
```

The above example is not much useful by itself,
but permits auto referencing when doing method calls:

```nelua
local Person = @record{name: stringview, age: integer}

-- note that this function only accept pointers
function Person.print_info(self: *Person)
  print(self.name, self.age)
end

local p: Person = {"John", 20}
p:print_info() -- perform auto referencing of 'p' when calling here
Person.print_info(p) -- equivalent, also performs auto referencing
```

The automatic referencing and dereferencing mechanism allows to use
any unary operator, binary operator, function call or method call
by value or by reference, for records or arrays.
{:.alert.alert-info}

## Meta programming

The language offers advanced features for meta programming by having a full Lua preprocessor
at compile-time that can generate and manipulate code when compiling.

### Preprocessor

At compile-time a Lua preprocessor is available to render arbitrary code,
it works similar to templates in the web development world because they emit
code between it's statements.

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

For instance the above code compile exactly as:

```nelua
local a = 0
a = a + 1
a = a + 1
a = a + 1
a = a + 1
print(a)
```

Using the lua preprocessor you can generate complex codes at compile-time.

### Emitting AST nodes (statements)

It's possible to manually emit AST node for statements while preprocessing:

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

The above code compile exactly as:

```nelua
print('hello')
```

For a complete list
of AST shapes that can be created using the `aster` module read the [AST definitions file](https://github.com/edubart/nelua-lang/blob/master/nelua/astdefs.lua) or the
[syntax definitions spec file](https://github.com/edubart/nelua-lang/blob/master/spec/02-syntaxdefs_spec.lua)
for many examples.
{:.alert.alert-info}

### Emitting AST nodes (expressions)

It's possible to manually emit AST node for expressions while preprocessing:

```nelua
local a = #[aster.Number{'dec','1'}]#
print(a) -- outputs: 1
```

The above code compile exactly as:

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

The above code compile exactly as:

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

local Weekends = @enum { Friday=0, Saturday, Sunday }
print(Weekends.#|'S'..string.lower('UNDAY')|#)
```

The above code compile exactly as:

```nelua
local myvar = 1
print(myvar)

local function foo1() print 'foo' end
foo1()

local Weekends = @enum { Friday=0, Saturday, Sunday }
print(Weekends.Sunday)
```

### Preprocessor templated macros

Macros can be created by declaring functions in the preprocessor with its body
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

### Preprocessor macros emitting AST nodes

Creating macros using the template rendering mechanism
in the previously example is handy but have limitations
and is not flexible enough for all cases. For example,
suppose you want to create an arbitrary length array, in this
case you will need to manually emit AST node:

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
  -- check if the inputs are valid, in case wrong input
  static_assert(traits.is_type(type), 'expected a type or a symbol to a type')
  static_assert(traits.is_number(n) and n > 0, 'expected n > 0')
  -- create list of expression
  local exprs = {}
  for i=1,n do
    -- aster.value convert any Lua value to the proper ASTNode
    exprs[i] = aster.value(i)
  end
  -- create the Table ASTNode, it's used for any braces {} expression
  return aster.Table{exprs, pattr = {
    -- hint the compiler what type this braces should be evaluated
    desiredtype = types.ArrayType(type, #exprs)}
  }
end
]]

local a = #[create_sequence(integer, 10)]#
```

The above code compile exactly as:

```nelua
local a = (@[10]integer){1,2,3,4,5,6,7,8,9,10}
```

### Code blocks as arguments to preprocessor functions

Block of codes can be passed to macros by surrounding it inside a function:

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

The above code compile exactly as:

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

Using macros its possible to create generic code:

```nelua
## function Point(PointT, T)
  local #|PointT|# = @record { x: #|T|#, y: #|T|# }
  function #|PointT|#:squaredlength()
    return self.x*self.x + self.y*self.y
  end
## end

## Point('PointFloat', 'float64')
## Point('PointInt', 'int64')

local pa: PointFloat = {x=1,y=2}
print(pa:squaredlength()) -- outputs: 5

local pb: PointInt = {x=1,y=2}
print(pb:squaredlength()) -- outputs: 5.000000
```

### Preprocessing on the fly

While the compiler is processing you can view what the compiler already knows
to generate arbitrary code:

```nelua
local Weekends = @enum { Friday=0, Saturday, Sunda }
## for i,field in ipairs(Weekends.value.fields) do
  print(#[field.name .. ' ' .. tostring(field.value)]#)
## end
```

The above code compile exactly as:

```nelua
local Weekends = @enum { Friday=0, Saturday, Sunday }
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

The above code compile exactly as:

```nelua
local Person = @record{name: string, age: integer}
local p: Person = {name='Joe', age=21}
print(p.age) -- outputs '21'
```

The compiler is implemented and runs using Lua and the preprocess
is actually a lua function that the compiler is running, thus it's possible to even modify
or inject code to the compiler itself on the fly.

### Preprocessing polymorphic functions

Polymorphic functions can be specialized at compile-time
when used in combination with the preprocessor:

```nelua
local function pow(x: auto, n: integer)
## static_assert(x.type.is_arithmetic, 'cannot pow variable of type "%s"', x.type)
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
print(a,b) -- outputs: 4 4.000000

-- uncommenting the following will trigger the compile error:
--   error: cannot pow variable of type "string"
--pow('a', 2)
```

### Preprocessor code blocks

Arbitrary Lua code can be put inside preprocessor code blocks. Their syntax
starts with `##[[` or `##[=[` (any number of `=` tokens you want between the
brackets) and ends with `]]` or `]=]` (matching the number of `=` tokens previously used):

```nelua
-- this is an preprocessor code block
##[[
function my_compiletime_function(str)
  print(str) -- print at compile-time
end
]]

-- call the function defined in the block above
## my_compiletime_function('hello from preprocessor')
```

As shown in the last line, functions defined inside of the preprocessor code
blocks can be evaluated arbitrarily from any part of the code, at any point,
using `##`.

Although said block was defined for a single module it will be available for all
modules required after them, because declarations default to the global scope in Lua.
If you'd like to avoid polluting other module's
preprocessor environments then declare its functions as `local`.

### Preprocessor function modularity

Suppose you want to use the same preprocessor function from multiple Nelua
modules. As explained in the [preprocessor code blocks](#preprocessor-code-blocks) section,
one idea is to
declare everything in that block as global, thus it would also be available in
preprocessor evaluation from other modules.

For example, on `module_A.nelua`:

```nelua
##[[
-- this function is declared as global, so it'll be available on module_B.nelua
function foo()
  print "bar"
end
]]
```

Then, on `module_B.nelua`:

```nelua
require 'module_A'
-- even though foo is not declared in this file, since it's global, it'll be available here
## foo()
```

Although this seems harmless, it can get messy if you define a function with
the same name on different modules. It also means you're relying on global
scope semantics from the preprocessor, which might be unpredictable or brittle
due to evaluation order.

Fortunately, there's a more modular approach for code reuse which does not rely
on global scope. Simply create a standalone Lua module and require it on all
Nelua modules you would want to use it.

The previous example would be refactored as follows:

1\. Create a `foo.lua` (or any name you want) file and paste your code there:

```lua
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
simply Lua code which can leverage all your editor's tooling and configuration,
such as a code formatter, syntax highlighter, completions, etc.

If the Lua module is not in the same directory where the compiler is running from, then `require`
will fail to find it, to solve this
you can set `LUA_PATH` system's environment variable to a pattern which matches that directory,
for example doing `export LUA_PATH="/myprojects/mymodules/?.lua"`{:.language-bash} in your terminal (notice the `?.lua` at the end).
{:.alert.alert-info}

### Preprocessor utilities

The preprocessor comes with some pre-defined functions to assist meta programming.

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
that is evaluated at compile-time to generate a specialized type based
on compile-time arguments, to do this the `generalize` macro is used.
It's hard to explain in words, lets view a full example:

```nelua
-- Define a generic type for creating a specialized FixedStackArray
## local make_FixedStackArray = generalize(function(T, maxsize)
  -- alias compile-time parameters visible in the preprocessor to local symbols
  local T = #[T]#
  local MaxSize <comptime> = #[maxsize]#

  -- Define a record using T and MaxSize compile-time parameters.
  local FixedStackArrayT = @record {
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

Generics are powerful to **specialize efficient code at compile-time**
based on different compile-time arguments, they are used in many places in the
standard library for example to create
[vector](https://github.com/edubart/nelua-lang/blob/master/lib/vector.nelua)
[sequence](https://github.com/edubart/nelua-lang/blob/master/lib/sequence.nelua)
and [span](https://github.com/edubart/nelua-lang/blob/master/lib/span.nelua)
classes. Generics is similar to C++ templates.
{:.alert.alert-info}

Generics are **memoized**, that is, they are evaluated and defined just once for the
same compile-time arguments.
{:.alert.alert-info}

## Concepts

Concepts is a powerful system used to specialize [polymorphic functions](#polymorphic-functions)
with efficiency at compile-time.

An argument of a polymorphic function can
use the special concept type defined by a
preprocessor function that when evaluated at compile-time
decides whether if the incoming variable type matches the concept requirements.

To create a concept use preprocessor function `concept`:

```nelua
local an_arithmetic = #[concept(function(attr)
  -- the first argument of the concept function is an Attr,
  -- attr are stores different attributes for the incoming symbol, variable or node,
  -- we want to check if the incoming attr type matches the concept
  if attr.type.is_arithmetic then
    -- the attr is an arithmetic type (can add, subtract, etc)
    return true
  end
  -- the attr type does not match this concept
  return false
end)]#

local function add(x: an_arithmetic, y: an_arithmetic)
  return x + y
end

print(add(1, 2)) -- outputs 3

-- uncommenting the following will trigger the compile error:
--   type 'boolean' could not match concept 'an_arithmetic'
-- add(1, true)
```

When the concepts of a function is matched for the first time,
a specialized function is defined just for that incoming types,
thus the compiler generates different functions in C code for each different match,
this means that the code is specialized
for each type and handled efficiently because the code does
not need to do runtime type branching, the type branching is only done at compile-time.

The property `type.is_arithmetic` is used here to check the incoming type,
all the properties defined by the compiler to check the incoming types can be
[seen here](https://github.com/edubart/nelua-lang/blob/master/nelua/types.lua#L44).
{:.alert.alert-info}

### Specializing with concepts

A concept can match multiple types, thus is possible to specialize
further a polymorphic function using a concept:

```nelua
require 'string'

local an_arithmetic_or_string = #[concept(function(attr)
  if attr.type.is_stringy then
    -- we accept strings
    return true
  elseif attr.type.is_arithmetic then
    -- we accept arithmetics
    return true
  end
  return false
end)]#

local function add(x: an_arithmetic_or_string,
                   y: an_arithmetic_or_string)
  ## if x.type.is_stringy and y.type.is_stringy then
    return x .. y
  ## else
    return x + y
  ## end
end

-- add will be specialized for arithmetic types
print(add(1, 2)) -- outputs 3
-- add will be specialized for string types
print(add('1', '2')) -- outputs 12
```

The compiler only defines new different specialized functions as needed,
i.e. specialized functions for different argument types are memoized.

### Specializing concepts for records

Sometimes you want to check weather a record matches a concept,
to do this you can set a field on its type to later check in the concept
plus you can also use in the preprocessor to assist specializing code:

```nelua
local Vec2 = @record{x: number, y: number}
-- Vec2 is an attr of the "type" type, Vec2.value is it's holded type
-- we set here is_Vec2 at compile-time to use later for checking whether a attr is a Vec2
## Vec2.value.is_Vec2 = true

local Vec2_or_arithmetic_concept = #[concept(function(attr)
  -- match in case of arithmetic or Vec2
  return attr.type.is_arithmetic or attr.type.is_Vec2
end)]#

-- we use a concepts on the metamethod __add to allow adding Vec2 with numbers
function Vec2.__add(a: Vec2_or_arithmetic_concept, b: Vec2_or_arithmetic_concept)
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
v = a + 1 -- Vec2 + arithmetic
print(v.x, v.y) -- outputs: 2 3
v = 1 + a -- arithmetic + Vec2
print(v.x, v.y) -- outputs: 2 3
v = a + a -- Vec2 + Vec2
print(v.x, v.y) -- outputs: 2 4
```

### Concepts with logic

You can put some logic in your concept, to check for any kind of proprieties
that the incoming `attr` should satisfy, and return compile-time errors
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
local MyArray = @record {data: [10]integer}
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
from the incoming `attr`, for example suppose you want to specialize a function
that optionally accepts any kind of arithmetic, but you really want it to be implemented
as an number:

```nelua
local optional_number_concept = #[concept(function(attr)
  if attr.type.is_niltype then
    -- niltype is the type when the argument is missing or when we use 'nil'
    -- we accept it because the number is optional
    return true
  end
  -- instead of returning true, we return the desired type to be implemented,
  -- the compiler will take care to implicit cast the incoming attr to the desired type,
  -- or throw an error if not possible,
  -- here we want to force the function using this concept to implement as a 'number'
  return primtypes.number
end)]#

local function get_number(x: optional_number_concept)
  ## if x.type.is_niltype then
    return 0
  ## else
    return x
  ## end
end

print(get_number(nil)) -- prints 0
print(get_number(2)) -- prints 2
```

### Optional concept

Optional concept are common to use, thus there is
a shortcut for creating them, for instance this the previous code is equivalent to:

```nelua
local function get_number(x: #[optional_concept(number)]#)
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
at compile-time is a common use, so there is also a shortcut for creating overload concepts:

```nelua
local function foo(x: #[overload_concept{integer,stringview,niltype}]#)
  ## if x.type.is_integral then
    print('got integer ', x)
  ## elseif x.type.is_stringview then
    print('got string ', x)
  ## else
    print('got nothing')
  ## end
end

foo(2) -- outputs: got integer 2
foo('hello') -- outputs: got string hello
foo(nil) -- outputs: got nothing
```

Use this when you want to specialize different argument types at compile-time
without runtime costs.

## Annotations

Annotations are used to inform the compiler different behaviors in the code
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
/* DECLARATIONS */
int puts(const char* s);
static char __strlit1[6] = "hello";
/* DEFINITIONS */
int nelua_main() {
  puts(__strlit1);
  return 0;
}
```

Notice that the `puts` functions is **declared automatically**,
i.e., there is no need to include the header that declares the function.
{:.alert.alert-info}

### Importing C functions declared in headers

Sometimes you need to import a C function that is declared
in a C header, specially if its declared as a macro:

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
/* DECLARATIONS */
#include <stdio.h>
static char __strlit1[6] = "hello";
/* DEFINITIONS */
int nelua_main() {
  puts(__strlit1);
  return 0;
}
```

Notice that the `nodecl` is needed when importing any C function
that is declared in a C header, otherwise the function will have duplicate declarations.
{:.alert.alert-info}

### Including C files with defines

Sometimes you need to include a C file but defining something before the include:

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

The `<cimport>` annotation uses the same name of its symbol name,
but it's possible import using a different name:

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

It's possible to add custom C flags when compiling via the preprocessor:

```nelua
##[[
if FAST then -- release build
  cflags '-Ofast' -- C  compiler flags
  ldflags '-s' -- linker flags
else -- debug build
  cflags '-Og'
end
]]
```

If we run the above example with `nelua -DFAST example.nelua`
the C compiler will compile with the cflags `-Ofast` otherwise `-Og`.

### Emitting raw C code

Sometimes to do low level stuff in C, or skip Nelua default semantics,
you may want to emit raw C code:

```nelua
local function do_stuff()
  -- emits in the declarations section of the generated C file
  ## cemitdecl '#include <stdio.h>'

  -- emits inside this function in the generated C file
  ##[==[ cemit([[
    const char *msg = "hello from C\n";
    printf(msg);
  ]])]==]
end

do_stuff()
```

Nelua can emit C code in 3 different sections, in the global **declarations**
section using `cemitdecl`, in the global **definitions** section using `cemitdef`
or the **current scope** section using `cemit`. Usually you
want to use `cemit`.
{:.alert.alert-info}


### Exporting named C functions

You can use Nelua to create C libraries, when doing this
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
/* DECLARATIONS */
extern int64_t mylib_foo();
/* DEFINITIONS */
int64_t mylib_foo() {
  return 1;
}
```

### C primitives

For importing C functions, additional compatibility primitive types are provided:

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
{: .table.table-bordered.table-striped.table-sm}

Use this types for **importing C functions only**, for doing usual
code prefer the other Nelua primitive types.
{:.alert.alert-info}

{% endraw %}

*[closure]: Closure are functions that captures variables from its parent scope.
*[upvalue]: A variable captured from in a scope above the closure.
*[integral]: A whole number, numbers that has not fractional part.
*[GC]: Garbage Collector

<a href="/libraries/" class="btn btn-outline-primary btn-lg float-right">Libraries >></a>
