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

Although copying Lua code with minor changes is a goal of Nelua, not all Lua
features are implemented yet. Mostly the dynamic part such as tables and dynamic typing
are not implemented yet, thus at the moment is best to try Nelua using type notations.

There is no interpreter or VM, all the code is converted directly into native machine code,
thus expect better efficiency than Lua. However this means that Nelua can't load
code generated at runtime, the user is encouraged to generate code at compile time
using the preprocessor.

## A note for C users

Nelua tries to expose most of C features without overhead, thus expect
to get near C performance when coding in the C style, that is using
type notations, manual memory management, pointers, records (structs).

The semantics are not exactly as C semantics but close. There are slight differences
to minimize undefined behaviors (like initialize to zero by default) and
other ones to keep Lua semantics (like integer division rounds towards minus infinity).
However there are ways to get C semantics for each case when needed.

The preprocessor is much more powerful than C preprocessor,
because it's actually the compiler running in Lua,
thus you can interact with the compiler while parsing. The preprocessor should
be used for making generic code and avoiding code duplication.

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

Variables are declared or defined like in lua, but optionally
you can specify it's type when declaring:

```nelua
local a = nil -- of deduced type 'any', initialized to nil
local b = false -- of deduced type 'boolean', initialized to false
local s = 'test' -- of deduced type 'string', initialized to 'test'
local one = 1 --  of type 'integer', initialized to 1
local pi: number = 3.14 --  of type 'number', initialized to 1
print(a,b,s,one,pi) -- outputs: nil false test 1 3.1400000
```

Nelua takes advantages of types to make checks and optimizations at compile time.

### Type deduction

When a variable has no specified type on its declaration, the type is automatically deduced
and resolved at compile time:

```nelua
local a -- type will be deduced and scope end
a = 1
a = 2
print(a) -- outputs: 2
-- end of scope, compiler deduced 'a' to be of type 'integer'
```

### Type collision

In case of different types being assigned to a same variable,
then the compiler deduces the variable type
to the type `any` (a type that can hold anything an runtime), this makes nelua code compatible with lua values semantics:

```nelua
local a -- a type will be deduced
a = 2
a = false
print(a) -- outputs: false
-- a is deduced to be of type 'any', because it could hold an 'integer' or a 'boolean'
```

### Zero initialization

Variables declared but not defined are always initialized to zeros automatically,
this prevents undefined behaviors:

```nelua
local a -- variable of deduced type 'any', initialized to 'nil'
local i: integer -- variable of type 'integer', initialized to 0
print(a, i) --outputs: nil 0
```

This can be optionally be disabled (for optimization reasons) using **annotations**.

### Auto variables

Variables declared as auto have it's type deduced early using only the type of it's first assignment.

```nelua
local a: auto = 1 -- a is deduced to be of type 'integer'

-- uncommenting the following will trigger the compile error:
--   error: in variable assignment: no viable type conversion from `boolean` to `int64`
--a = false

print(a) -- outputs: 1
```

Auto variables are more useful when used in [polymorphic functions](#polymorphic-functions).

### Comptime variables

Comptime variables have its value known at compile time:

```nelua
local a <comptime> = 1 + 2 -- constant variable of value '3' evaluated and known at compile time
```

The compiler takes advantages of constants to make optimizations, constants are also useful
for using as compile time parameters in [polymorphic functions](#polymorphic-functions).

### Const variables

Const variables can be assigned at runtime however it cannot mutate.

```nelua
local x <const> = 1
local a <const> = x
print(a) -- outputs: 1

-- uncommenting the following will trigger the compile error:
--   error: cannot assign a constant variable
--a = 2
```

Const annotation can also be used for function arguments.

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
-- this would trigger a compiler error because `a` is not visible:
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

## Control flow

### If

If statement is just like in Lua.

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
switch a
case 1 then
  print 'is 1'
case 2 then
  print 'is 2'
else
  print 'else'
end
```

The case expression can only contain integral expressions known at compile time. The
compiler can generate more optimized code when using a switch instead of an if for integers.

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

Defer is meant to be used for releasing resources in a deterministic manner on scope termination.
The syntax and functionality is inspired by the similar statement in the Go language.
It's guaranteed to be executed before any "return", "break" or "continue".

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

Note that variables declared inside repeat scope are visible on it's condition expression.

### Numeric For

Numeric for are like in Lua, meaning they are inclusive for the first and the last
element:

```nelua
for i = 0,5 do
  -- i is deduced to 'integer'
  print(i) -- outputs 0 1 2 3 4 5
end
```

Numeric for loops always evaluate it's begin, end and step expressions only once. The iterate
variable type is automatically deduced using the begin and end expressions.

#### Exclusive
An exclusive for is available to do exclusive for loops, they work using
comparison operators `~=` `<=` `>=` `<` `>`:

```nelua
for i=0,<5 do
  print(i) -- outputs 0 1 2 3 4
end
```

#### Stepped
The last parameter in for syntax is the step, it's counter is always incremented
with `i = i + step`, by default step is always 1, when using negative steps reverse for is possible:

```nelua
for i=5,0,-1 do
  print(i) -- outputs 5 4 3 2 1
end
```

### Continue
Continue statement is used to skip a for loop to it's next iteration.

```nelua
for i=1,10 do
  if i<=5 then
    continue
  end
  print(i) -- outputs: 6 7 8 9 10
end
```

### Break
Break statement is used to break a for loop.

```nelua
for i=1,10 do
  if i>5 then
    break
  end
  print(i) -- outputs: 1 2 3 4 5
end
```

## Primitive types

### Boolean

```nelua
local a: boolean -- variable of type 'boolean' initialized to 'false'
local b = false
local c = true
print(a,b,c) -- outputs: false false true
```

They are defined as `bool` in C code.

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

The types `isize` and `usize` types are usually 32 wide bits on 32-bit systems,
and 64 bits wide on 64-bit systems. When you need an integer value you should use `integer`
unless you have a specific reason to use a sized or unsigned integer type.
The `integer`, `uinteger` and `number` are intended to be configurable. By default
they are 64 bits for all architectures, but this can be changed at compile time
using the preprocessor if needed.

### Strings

There are two types of strings, the `string` used for strings allocated at runtime,
and `stringview` used for strings literals defined at compile time and as views
of runtime strings too.

```nelua
-- to use the 'string' type we must import from the standard library
require 'string'

local mystr: string -- empty string
local str1: string = 'my string' -- variable of type 'string'
local str2 = "static stringview" -- variable of type 'stringview'
local str3: stringview = 'stringview two' -- also a 'stringview'
print(str1, str2, str3) -- outputs: "" "string one" "string two"
```

Like in Lua, strings are immutable, this make the semantics similar to Lua.
If the programmer wants a mutable string he can always implement his own string class.

The major difference of `stringview` and `string` is that `stringview` doesn't
manage the string memory, i.e. it doesn't allocates or free strings.
The `string` type is usually allocated at runtime and it frees the string memory
once it reference count reaches 0. When the garbage collector is disabled
the `stringview` uses weak references, thus
any `stringview` pointing to a `string` is invalidated once the related `string` is freed.
Both types can be converted from one to another.

### Array

Array is a list with where its size is fixed and known at compile time:

```nelua
local a: array(integer, 4) = {1,2,3,4}
print(a[0], a[1], a[2], a[3]) -- outputs: 1 2 3 4

local b: integer[4] -- "integer[4]" is syntax sugar for "array(integer, 4)"
print(b[0], b[1], b[2], b[3]) -- outputs: 0 0 0 0
```

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

### Any

Any is a special type that can store any type at runtime:

```nelua
local a: any = 2 -- variable of type 'any', holding type 'integer' at runtime
print(a) -- outputs 2
a = false -- now holds the type 'boolean' at runtime
print(a) -- outputs false
```

This type makes Nelua semantics compatible to Lua, you can use it to make untyped code
just like in Lua, however the programmer should know that he pays the price in
performance, as operations on `any` types generate lots of branches at runtime,
thus less efficient code.

### Record

Record store variables in a block of memory (like C structs):

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

### Pointer

Pointer is like in C, points to a region in memory of a specific type:

```nelua
local n = nilptr -- a generic pointer, initialized to nilptr
local p: pointer --a generic pointer to anything, initialized to nilptr
local i: pointer(integer) -- pointer to an integer

-- syntax sugar
local i: integer*
```

### Span

Span are pointers to a block of contiguous elements which size is known at runtime.

```nelua
require 'span'
local arr = (@integer[4]) {1,2,3,4}
local s: span(integer) = &arr
print(s[0], s[1]) -- outputs: 1 2
print(#s) -- outputs 4
```

### Niltype

Niltype type is not useful by itself, it's only useful when using with unions to create the
optional type or for detecting nil arguments in [polymorphic functions](#polymorphic-functions).

### The "type" type

The "type" type is also a type, they can be stored in variables (actually symbols).
Symbols with this type is used at compile time only, they are useful for aliasing types:

```nelua
local MyInt: type = @integer -- a symbol of type 'type' holding the type 'integer'
local a: MyInt -- variable of type 'MyInt' (actually an 'integer')
print(a) -- outputs: 0
```

The '@' symbol is required to infer types expressions.

### Explicit type conversion

The expression `(@type)(variable)` can be called to explicitly convert a
variable to a new type.

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

### Implicit type conversion

Some types can be implicit converted, for example any arithmetic type can be
converted to any other arithmetic type:

```nelua
local i: integer = 1
local u: uinteger = i
print(u) -- outputs: 1
```

When implicit conversion is used the compiler checks if there is no loss
in the conversion at runtime,
if that happens the application crashes with a narrow casting error.
These checks can be avoided by doing explicit casting:

```nelua
local ni: integer = -1
-- the following would crash with "narrow casting from int64 to uint64 failed"
--local nu: uinteger = ni

local nu: uinteger = (@uinteger)(ni) -- explicit cast works, no checks are done
print(nu) -- outputs: 18446744073709551615
```

## Operators

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

The operators follows Lua semantics, for example, `%` and `//`
rounds the quotient towards minus infinity (different from C).

The only additional operators are `$` and `&`, used for working with pointers.

```nelua
print(2 ^ 2) -- pow, outputs: 4.000000
print(5 // 2) -- integer division, outputs: 2
print(5 / 2) -- float division, outputs: 2.500000
```

## Functions

Functions are declared like in lua:

```nelua
local function get(a)
  -- a is of type 'any'
  return a -- return is of deduced type 'any'
end
print(get(1)) -- outputs: 1
```

The function arguments can have the type specified and its return type will be automatically deduced:

```nelua
local function add(a: integer, b: integer)
  return a + b -- return is of deduced type 'integer'
end
print(add(1, 2)) -- outputs 3
```

In contrast with variable declaration when the type is omitted from a function argument there is no
automatic detection of the argument type, instead it's assumed the argument must
be of the `any` type, this makes Nelua semantics more compatible with Lua semantics.

### Return type inference

The function return type can also be specified:

```nelua
local function add(a: integer, b: integer): integer
  return a + b -- return is of deduced type 'integer'
end
print(add(1, 2)) -- outputs 3
```

### Recursive calls

Functions can call itself recursively:

```nelua
local function fib(n: integer): integer
  if n < 2 then return n end
  return fib(n - 2) + fib(n - 1)
end
print(fib(10)) -- outputs: 55
```

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

### Top scope closures

When declaring functions in the top scope the compiler takes advantages of the fact that
top scope variables is always accessible in the heap to create lightweight closures without
needing to hold upvalues references or use a garbage collector,
thus they are more lightweight than a closure nested in a function.

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

### Polymorphic functions

Polymorphic functions, or in short poly functions in the sources,
are functions which contains arguments that proprieties can
only be known when calling the function at compile time.
They are defined and processed lately when calling it for the first time.
The are used to specialize the function different arguments types.
They are memoized (only defined once for each kind of specialization).

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

Later we will show how polymorphic functions are more useful when used in combination with the **preprocessor**.

### Record functions

A record type can have functions defined for it, this makes useful to
organize functions that are to be used just with that type.

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
  self.x = self.x + x
  self.y = self.y + y
end

function Rect:area()
  return self.w * self.h
end

local v = Rect{0,0,2,3}
v:translate(2,2)
print(v.x, v.y) -- outputs 2 2
print(v:area()) -- outputs 6
```

### Record metamethods

Some special methods using the `__` prefix are used by the compiler to defines behaviors
on certain operations with the record type,
they are called metamethods and are similar to the Lua metamethods.

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
| `__tostring'`     |                            | cast     | implicit cast to string     |
| `__tostringview'` |                            | cast     | implicit cast to stringview |
| `__cinvert'`      |                            | cast     | implicit cast to anything   |
{: .table.table-bordered.table-striped.table-sm}

## Memory management

By default Nelua uses a garbage collector to allocate and deallocate memory on its own.
However it can be disabled with the pragma `nogc` via the command line or in the sources:

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

Notice that when disabling the garbage collector the coding style may
be different from Lua usual style, because now you need to think of each allocation
and dellocation, including for strings, otherwise memory in your application will leak,
thus is best to leave the GC enabled when you need rapid prototyping.
Disable the GC if you want to control the memory on your own for performance reasons,
know how to deal with memory management and don't mind the additional cognitive load
when coding without automatic memory management.

### Allocating memory

Nelua provides many allocators to assist managing memory.
The most important ones are the `allocators.general` and `allocators.gc`.

If you are using the GC, you must always use the `allocators.gc`, because
it marks the allocated memory region for scanning for references:
```nelua
require 'string'
require 'memory'
require 'allocators.gc'

local Person = @record{name: string, age: integer}
local p: Person* = general_allocator:new(@Person)
p.name = "John"
p.age = 20
print(p.name, p.age)
p = nilptr
-- we don't need to deallocate, the GC will do this on its own when needed!
```

If you are doing manual memory management you can use the general purpose allocator,
that is based on the system's `malloc` and `free` functions:

```nelua
## pragmas.nogc = true -- disables the GC
require 'string'
require 'memory'
require 'allocators.general'

local Person = @record{name: string, age: integer}
local p: Person* = general_allocator:new(@Person) -- allocate the appropriate size for Person
p.name = tostring("John") -- another allocation here
p.age = 20
print(p.name, p.age)
p.name:destroy() -- free the string allocation
general_allocator:delete(p) -- free the Person allocation
p = nilptr
```

### Dereferencing and referencing

The operator '&' is used to get a reference a variable,
and the operator '$' is used to access the reference.

```nelua
local a = 1
local ap = &a -- ap is a pointer to a
$ap = 2
print(a) -- outputs 2
a = 3
print($ap) -- outputs 3
```

## Meta programming

The language offers advanced features for meta programming by having a full Lua preprocessor
at compile time that can generate and manipulate code when compiling.

### Preprocessor

At compile time a Lua preprocessor is available to render arbitrary code,
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

Using the lua preprocessor you can generate complex codes at compile time.

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
local hello = 'hello world'
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
local a = (@integer[10]){1,2,3,4,5,6,7,8,9,10}
```

### Preprocessor code blocks

Arbitrary Lua code can be put inside preprocessor code blocks. Their syntax
starts with `##[[` or `##[=[` (any number of `=` tokens you want between the
brackets) and ends with `]]` or `]=]` (matching the number of `=` tokens previously used):

```nelua
-- this is an preprocessor code block
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

### Generic code

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
local Person = @record{name: string}
local p: Person = {name='Joe', age: integer}
print(p.age) -- outputs '21'
```

The compiler is implemented and runs using Lua and the preprocess
is actually a lua function that the compiler is running, thus it's possible to even modify
or inject code to the compiler itself on the fly.

### Preprocessor utilities

The preprocessor comes with some pre-defined functions to assist meta programming.

#### static_error

Used to throw compile time errors:

```nelua
##[[
-- check the current Lua version in the preprocessor
if _VERSION ~= 'Lua 5.4' then
  static_error('not using Lua 5.4, got %s', _VERSION)
end
]]
```

#### static_assert

Used to throw compile time assertions:

```nelua
-- check the current Lua version in the preprocessor
## static_assert(_VERSION == 'Lua 5.4', 'not using Lua 5.4, got %s', _VERSION)
```

### Preprocessing polymorphic functions

Polymorphic functions can make compile time dynamic functions
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

## Concepts

Concepts is a powerful system used to specialize [polymorphic functions](#polymorphic-functions)
with efficiency at compile time.

An argument of a polymorphic function can
use the special concept type defined by a
preprocessor function that when evaluated at compile time
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

print(add(1 ,2)) -- outputs 3

-- uncommenting the following will trigger the compile error:
--   type 'boolean' could not match concept 'an_arithmetic_or_string'
-- add(1,true)
```

When the concepts of a function is matched for the first time,
a specialized function is defined just for that incoming types,
thus the compiler generates different functions in C code for each different match,
this means that the code is specialized
for each type and handled efficiently because the runtime code does
not need to do any runtime check, the type checking is only done at compile time.

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

Some times you want to check weather a record matches a concept,
to do this you can set a field on its type to later check in the concept
plus you can also use in the preprocessor to assist specializing code:

```nelua
local vec2 = @record{x: number, y: number}
-- vec2 is a attr of the "type" type, vec2.value is it's holded type
-- we set here is_vec2 at compile time to use later for checking whether a attr is a vec2
## vec2.value.is_vec2 = true

local vec2_or_arithmetic_concept = #[concept(function(attr)
  -- match in case of arithmetic or vec2
  return attr.type.is_arithmetic or attr.type.is_vec2
end)]#

-- we use a concepts on the metamethod __add to allow adding vec2 with numbers
function vec2.__add(a: vec2_or_arithmetic_concept, b: vec2_or_arithmetic_concept)
  -- specialize the function at compile time based on the argument type
  ## if a.type.is_vec2 and b.type.is_vec2 then
    return (@vec2){a.x + b.x, a.y + b.y}
  ## elseif a.type.is_vec2 then
    return (@vec2){a.x + b, a.y + b}
  ## elseif b.type.is_vec2  then
    return (@vec2){a + b.x, a + b.y}
  ## end
end

local a: vec2 = {1, 2}
local v: vec2
v = a + 1 -- vec2 + arithmetic
print(v.x, v.y) -- outputs: 2 3
v = 1 + a -- arithmetic + vec2
print(v.x, v.y) -- outputs: 2 3
v = a + a -- vec2 + vec2
print(v.x, v.y) -- outputs: 2 4
```

### Concepts with logic

You can put some logic in your concept, to check for any kind of proprieties
that the incoming `attr` should satisfy, and return compile time errors
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
local MyArray = @record {data: integer[10]}
function MyArray:__index(i: integer)
  return self.data[i]
end
function MyArray:__len()
  return #self.data
end

local a: integer[10] = {1,2,3,4,5,6,7,8,9,10}
local b: MyArray = {data = a}

-- sum_container can be called with 'a' because it matches the concept
-- we pass as reference using & here to avoid an unnecessary copy
print(sum_container(&a)) -- outputs: 55

-- sum_container can also be called with 'b' because it matches the concept
-- we pass as reference using & here to avoid an unnecessary copy
print(sum_container(&b)) -- outputs: 55
```

### Concept that infers to another type

Some times is useful to infer a concept to a different type
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
print(get_number(2)) -- prints 0
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
print(get_number(2)) -- prints 0
```

Use this when you want to specialize optional arguments at compile time
without any runtime costs.

### Overload concept

Using concepts to overload functions for different incoming types
at compile time is a common use, so there is also a shortcut for creating overload concepts:

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

Use this when you want to specialize different argument typesat compile time
without any runtime costs.

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

## Mixing C code

Nelua can import C functions from C headers:

```nelua
-- `cimport` informs the compiler the function name from C that should be imported
-- `cinclude` informs the compiler which C header its declared
-- `nodecl` informs the compiler that it doesn't need to declare it (C header already declares)
local function malloc(size: usize): pointer <cimport'malloc',cinclude'<stdlib.h>',nodecl> end
local function memset(s: pointer, c: int32, n: usize): pointer <cimport'memset',cinclude'<string.h>',nodecl> end
local function free(ptr: pointer) <cimport'free',cinclude'<stdlib.h>',nodecl> end

local a = (@int64[10]*)(malloc(10 * 8))
memset(a, 0, 10*8)
assert(a[0] == 0)
a[0] = 1
assert(a[0] == 1)
free(a)
```

This allows to use existing C libraries in Nelua code.

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

{% endraw %}

<a href="/manual/" class="btn btn-outline-primary btn-lg float-right">Manual >></a>
