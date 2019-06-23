---
layout: default
title: Overview
permalink: /overview/
toc: true
categories: sidenav
order: 2
---

{% raw %}

# Overview

This is a quick overview of the language features using many examples.
Most of Nelua syntax and semantics
is similar to Lua, thus if you know Lua you probably know Nelua too, however Nelua have many
additions to code with types, to make more performant code and to metaprogram.
This overview try to focus more on those features.

--------------------------------------------------------------------------------
## Hello world

Simple hello world program, just like in Lua:

```nelua
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

--------------------------------------------------------------------------------
## Variables

Variables are declared or defined like in lua, but optionally
you can specify it's type when declaring:

```nelua
local a = nil -- of deduced type 'any', initialized to nil
local b = false -- of deduced type 'boolean', initialized to false
local d = 1 --  of type 'integer', initialized to 1
local e: integer = 1 --  of type 'integer', initialized to 1
```

Nelua takes advantages of types to make checks and optimizations at compile time.

### Type deduction

When a variable has no specified type on its declaration, the type is automatically deduced
and resolved at compile time:

```nelua
local a -- type will be deduced and scope end
a = 1
a = 2
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
-- a is deduced to be of type 'any', because it could hold an 'integer' or a 'boolean'
```

### Zero initialization

Variables declared but not defined are always initialized to zeros automatically,
this prevents undefined behaviours:

```nelua
local a -- variable of deduced type 'any', initialized to 'nil'
local b: integer -- variable of type 'integer', initialized to 0
```

This can be optionally be disabled (for optimization reasons) using **pragmas**.

### Auto variables

Variables declared as auto have it's type deduced early using only the type of it's first assignment.

```nelua
local a: auto = 1 -- a is deduced to be of type 'integer'

-- this would trigger a compile error:
-- a = false
```

Auto variables are more useful when used in **lazy functions**.

### Compconst variables

Compconst variables have its value known at compile time:

```nelua
local a: compconst = 1 + 2 -- constant variable of value '3' evaluated and known at compile time
```

The compiler takes advantages of constants to make optimizations, constants are also useful
for using as compile time parameters in **lazy functions**.

### Const variables

Const variables can be assigned at runtime however it cannot mutate.

```nelua
local x = 1
local a: const = x -- constant variable of value '3' evaluated and known at compile time
-- doing "a = 2" would throw a compile time error

local function f(x: const integer)
  -- cannot assign 'x' here because it's const
end
```


--------------------------------------------------------------------------------
## Control flow

### If

If statement is just like in Lua.

```nelua
if a == 1 then
  print 'is one'
elseif a ~= 2 then
  print 'is not two'
else
  print 'else'
end
```

### Switch

Switch statement is similar to C switches:

```nelua
switch a
case 1 then
  print 'is 1'
case 2, 3 then
  print 'is 2 or 3'
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
end
do
  local a = 1 -- can declare variable named a again
end
```

They are also useful to create arbitrary scopes for **defer** statement.

### Goto

Gotos are useful to get out of nested loops and jump between codes:

```nelua
local haserr = true
if haserr then
  goto getout -- get out of the loop
end
print 'hello'
::getout::
print 'world'
-- outputs only 'world'
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

--------------------------------------------------------------------------------
## Looping

### While

While are just like in Lua:

```nelua
local a = 1
while a < 42 do
  a = a + 1
end
```

### Repeat

Repeat is also like in Lua:

```nelua
repeat
  a = a - 1
until a == 0
```

Note that variables declarated inside repeat scope are visible on it's condition expression.

### For

Numeric for are like in Lua, meaning they are inclusive for the first and the last
element:

```nelua
for i = 0, 5 do
  -- i is deduced to 'integer'
  print(i) -- outputs 0 1 2 3 4 5
end
```

Numeric for loops always evaluate it's begin, end and step expressions only once. The iterate
variable type is automatically deduced using the for expressions.

#### Exclusive
An extesion to for is available to do exclusive for loops, they work using
comparison operators `~=` `<=` `>=` `<` `>`:

```nelua
for i = 0,<5 do
  print(i) -- outputs 0 1 2 3 4
end
```

#### Stepped
The last parameter in for syntax is the step, it's counter is always incremented
with `i = i + step`, by default step is always 1, with negative steps reverse for is possible:

```nelua
for i = 5,0,-1 do
  print(i) -- outputs 5 4 3 2 1
end
```

#### Iterated

```nelua
local a = {'a', 'b', 'c'}
for i,v in ipairs(a) do
  print(i, v)
end
-- outputs 1 a 2 b 3 c
```

Iterators are useful to create more complex for loops:

```nelua
local function multiples_countdown(s, e)
  return function(e, i)
    repeat
      i = i - 1
      if i < e then return nil end
    until i % 2 == 0
    return i
  end, e, s+2
end

for i,b in multiples_countdown(10, 0) do
  print(i) -- outputs 10 8 6 4 2 0
end
```

### Continue
Continue statement is used to skip a for loop to it's next iteration.

```nelua
for i=1,10 do
  if i<=5 do
    continue
  end
  print(i)
end
-- outputs: 6 7 8 9 10
```

### Break
Break statement is used to break a for loop.

```nelua
for i=1,10 do
  if i>5 do
    break
  end
  print(i)
end
-- outputs: 1 2 3 4 5
```

--------------------------------------------------------------------------------
## Primitive types

### Boolean

```nelua
local a: boolean -- variable of type 'boolean' initialized to 'false'
local b = false
local c = true
```

They are defined as `bool` in C code.

### Numbers

Number literals are defined similar as in Lua:

```nelua
local a = 1234 -- variable of type 'integer'
local b = 0x123 -- variable of type 'integer'
local c = 1234.56 -- variable of type 'number'
```

The `integer` is the default type for integral literals with no suffix.
The `number` is the default type for fractional literals with no suffix.

You can use type suffixes to force a type for a numeric literal:

```nelua
local a = 1234_u32 -- variable of type 'int32'
local b = 1_f32 -- variable of type 'float32'
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

The types `isize` and `usize` types are usually 32 wide bits on 32-bit systems,
and 64 bits wide on 64-bit systems. When you need an integer value you should use `integer`
unless you have a specific reason to use a sized or unsigned integer type.

### String

Strings are just like in Lua:

```nelua
local s1 = "hello world" -- string
local s2 = 'hello world' -- also a string
```

Like in lua strings are immutable, this make the semantics similar to lua and
allows the compiler to use deferred reference counting instead of garbage collector
for managing strings memory improving the application performance. If the programmer want's
a mutable string he can always implement his own string object.


### Function

Functions can be stored inside variables like in lua:

```nelua
local f1: function<(a: integer, b: integer): boolean, boolean>
local f2 = function(args) end

-- syntax sugar
local f3: (integer, integer) -> (boolean, boolean)
function f4(args) end
```

### Table

Tables are just like Lua tables:

```nelua
local t1 = {} -- empty table
local t2: table -- empty table
local t3 = {x = 1, y = 2} -- simple table
local t4 = {1 , 2} -- simple table
local t5 = {a = 1, [2] = "a", 1} -- complex table
```

Tables triggers usage of the garbage collector.

### The "type" type

The "type" type is also a type, they can be stored in variables (actually symbols).
Variables with this type is used at compile time only, they are useful for aliasing types:

```nelua
local MyInt: type = @integer -- a symbol of type 'type' holding the type 'integer'
local a: MyInt -- varible of type 'MyInt' (actually a 'integer')

local CallbackType = @function<()>
local callback: CallbackType
```

The '@' symbol is required to infer types in expressions.

### Type conversion

Type expressions (and also symbols) can be called to explicitly convert a
variable to a new compatible type.

```nelua
local i = 1
local f = @number(i) -- convert 'i' to the type 'number'
```

### Array

Array is a fixed size array known at compile time:

```nelua
local a1: array<integer, 4> = {1,2,3,4}
local a2: array<integer, 4>

-- syntax sugar
local a3: integer[4] = {1,2,3,4}
local a4 = @integer[4] {1,2,3,4}
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

local a: Weeks = @Weeks.Sunday
print(Weeks.Sunday) -- outputs 1
print(tostring(Weeks.Sunday)) -- outputs Sunday
```

The programmer must always initialize the first enum value, this choice
was made to makes the code more clear when reading.

### Any

Any is a special type tha can store any type at runtime:

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

local a: Person
a.name = "John"
a.age  = 20
print(a.age)

-- record initialization
local b = @Person {name = 1, age = 2}
print(b.age)
```

Records can also be used as tuples:

```nelua
local a: record{integer, integer}
a = {1,2}
a[1] = 0
```

### Union

Union can store multiple types at the same block of memory:

```nelua
local u: union<integer,string> -- variable of type union, initialized to its first type 'integer'
print(u) -- outputs 0
u = 'string' -- u now holds a string
print(u) -- outputs 'string'
```

Unions are slightly different from C union, because it has an `uint8` internally that holds
the current type pointer at runtime, thus the union size will have at least the
size of the largest type plus the size of `uint8`. Unions cannot hold more than 256 different types.

### Nilable

Nil type is not useful by itself, it's only useful when using with unions to create the
optional type as shown bellow.

### Optional

Optional type is actually a union of a `nilable` and any other type, it
is used to declare a variable that may hold or not a variable:

```nelua
local a: union<nilable,string> -- variable that may hold a string, initialized to 'nil'
assert(a == nil)
assert(not a)
print(a) -- outputs 'nil'
a = 'hi'
print(a) -- outputs 'hi'

-- syntax sugar for union union<nilable,string>
local v: string?
```

Optional types are useful for passing or returning variables that maybe set or not:

```nelua
local function foo(a: integer?): integer?
  if not a then
    return nil
  end
  return a + 1
end

local a = inc(1)
print(a) -- outputs '1'
local b = inc(nil)
print(b) -- outputs 'nil'
```

### Pointer

Pointer is like in C, points to a region in memory of a specific type:

```nelua
local n = nilptr -- a generic pointer, initialized to nilptr
local p: pointer --a generic pointer to anything, initialized to nilptr
local i: pointer<integer> -- pointer to an integer

-- syntax sugar
local i: integer*
```

### Range

Ranges are used to specifying ranges for slices.

```nelua
local r = 1:10
local r: range<integer>
```

### Slice

Slices are pointers to a block of contiguous elements at runtime.

```nelua
local arr = @integer[4] {1,2,3,4}
local str = 'hello world'
print(arr[1:2]) -- outputs '1 2'
print(arr[2:]) -- outputs '2 3 4'
print(arr[:3]) -- outputs '1 2 3'
print(arr[:]) -- outputs '1 2 3 4'
print(str[1:5]) -- outputs 'hello'

local a: array_slice<integer> = arr[1:2]
local a: string_slice = 'hello world'[1:2]
```

### Void

Void type is more used internally and it's only used to specify that a function returns nothing:

```nelua
local function f(): void end
```

### Block

Block variables are used to encapsulate arbritary code inside a variable at compile time,
when the block variable is called the compiler replaces the call code with the block code:

```nelua
local a: block = do
  print 'hello'
end -- a is of type 'block'
a() -- compiler injects the block code here, prints 'hello world'
```

But block variables are not functions, think of block variables as a code replacement tool.
Later will be shown how them are more useful to do *metaprogramming*.

--------------------------------------------------------------------------------
## Operators

All Lua operators are provided:

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
| div      | `a / b`       | binary   | float division           |
| idiv     | `a // b`      | binary   | integer division         |
| mod      | `a % b`       | binary   | numeric modulo           |
| pow      | `a ^ b`       | binary   | numeric pow              |
| not      | `not a`       | unary    | boolean negation         |
| len      | `#a`          | unary    | length operator          |
| neg      | `-a`          | unary    | numeric negation         |
| bnot     | `~a`          | unary    | bitwise not              |
| deref    | `$a`          | unary    | dereference              |
| ref      | `&a`          | unary    | reference                |

The only additional operators are `$` and `&`, used for working with pointers.

```nelua
print(2 ^ 2) -- pow, outputs 4
print(5 // 2) -- integer division, outputs 2
print(5 / 2) -- float division, outputs 2.5
```

--------------------------------------------------------------------------------
## Functions

Functions are declared like in lua:

```nelua
-- untyped function, 'n' argument and return value is of the type 'any'
local function fib(n)
  if n < 2 then return n end
  return fib(n - 2) + fib(n - 1)
end
```

They can be recursive as shown above. It's arguments can have an optionally specified type:

```nelua
-- typed function, 'n' argument and return value is of the type 'integer'
local function fib(n: integer): integer
  if n < 2 then return n end
  return fib(n - 2) + fib(n - 1)
end
```

In contrast with variable declaration when the type is omitted from an argument there is no
automatic detection of the argument type, instead it's assumed the argument must
be of the `any` type, this makes Nelua semantics compatible with Lua semantics.


### Return type inference

Function return type is automatically detected:

```nelua
local function add(a: integer, b: integer)
  return a + b
end

local a = add(1,2) -- a will be of type 'integer'
```

### Multiple returns

Functions can have multiple returns like in Lua:

```nelua
local function get_multiple()
  return false, 1
end

local a, b = get_multiple()
-- a is of type 'integer' with value 'false'
-- b is of type 'boolean' with value '1'
```

The returns can optionally be explicitly typed:

```nelua
local function get_multiple(): boolean, integer
  return false, 1
end
```

### Closures

Closure are functions declared inside another function
that captures variables from the upper scope, by default they
capture values by shared references using the garbage collector,
this choice was made to make Nelua code compatible with lua semantics:

```nelua
local function main()
  local a = 1 -- a is promoted to a heap variable internally because it's captured by a closure
  local function foo()
    -- captured 'a' garbage collected reference
    a = 2
  end
  foo()
  print(a)
end
main()  -- outputs 2
```

To make the above possible the compiler promote any captured variable to heap variables and
adds references of them to the garbage collector, however we can explicitly specify to capture the variable by its stack reference:

```nelua
-- capture all value by garbage collected copies
local function main()
  local a = 1
  local function foo[&a]()
    -- captured 'a' by stack reference
    a = 2
  end
  foo()
  print(a) -- outputs 2
end
main()
```

The advantage of capturing by its stack reference is that the closure becomes much more lightweight
because we don't need to promote to heap variables or use the garbage collector, but the disadvantage is that the function can not be called outside is parent scope, making this more unsafe and is responsability of the programmer to make sure this doesn't happen otherwise would cause an undefined behaviour and potentially a crash.

### Top scope closures

Because any top scope variable lives in the heap, top scope closures environment is always
visible and the compiler takes advantages this to not use the garbage collector, thus they
they are more lightweight.

```nelua
local a = 1 -- 'a' lives in the heap already because it's on the top scope
local function foo() -- foo is a top scope closure
  -- captured 'a' by reference
  a = 2
end
print(a) -- outputs 2
```

--------------------------------------------------------------------------------
## Memory management

### Dereferencing and referencing

The operator '&' is used to get a reference a variable,
and the operator '$' is used to access the reference.

```nelua
local a = 1
local aptr = &a -- aptr is a pointer to a
$aptr = 2
print(a) -- outputs 2
a = 3
print($aptr) -- outputs 3
```

--------------------------------------------------------------------------------
## Lazy functions

Lazy functions are functions which contains arguments that it's proprieties can
only be known when calling the function, they are processed and defined lazily (lately, on demand)
at each call. They are memoized (only defined once for each kind of arguments).

```nelua
local function add(a: auto, b: auto)
  return a + b
end

local a = add(1,2)
-- call to 'add', a function 'add(a: integer, b: integer): integer' is defined
local b = add(1.0, 2.0)
-- call to 'add' with another types, function 'add(a: number, b: number): number' is defined
```

In the above, the `auto` type is used as a generic placeholder to replace the function argument
by the incoming call type, this makes possible to make a generic function for multiple types.

Later we will show how lazy functions are a lot more useful when used in combination with the **preprocessor**.

### Variable arguments

Variable arguments functions can be implemented as lazy functions, the syntax is like in Lua
using the `...`, and can be used to forward to another variable argument function:

```nelua
local function printproxy(a, ...)
  print(a, ...)
end
print(1,2,3) -- outputs 1 2 3
```

On each call a different types call a real function will be implemented.

The arguments can be accessed individually using the `select` builtin directive (like in Lua):

```nelua
local function printfirsttwo(...)
  local a = select(1, ...)
  local b = select(2, ...)
  local n = select('#', ...)
  print(a, b, n)
end
printfirsttwo('a','b') -- outputs "a b 2"
```

It can be combined with multiple return functions:

```nelua
local function gettwo()
  return 1, 2
end
local function printall(...)
  print(...)
end
printall(getwo()) -- outputs "1 2"
```

### Generics

Generics can be achieved with lazy functions:

```nelua
local function Point(T: type)
  local PointT = @struct{ x: T, y: T }
  function PointT:length(a: T): T
    return math.sqrt(self.x ^ @T(2), self.y ^ @T(2))
  end
  return PointT
end

local PointFloat32 = Point(float32)
local b: PointFloat32
```

--------------------------------------------------------------------------------
## Meta programming

The language offers advanced features for metaprogramming by having a full lua processor
at compile time that can generate and manipulate code when compiling.

### Preprocessor

At compile time a Lua preprocessor is available to render arbitrary code,
it works similiar to templates in the web development world because they emit
code between it's statements.

Lines beginning with `##` and between `[##[ ]##]` are Lua code evaluated by the processor:


```nelua
local a = 0
## for i = 1,4 do
  a = a + 1 -- unroll this line 4 times
## end
print(a) -- outputs 4

[##[
local something = false
if something then
]##]
  print('hello') -- prints hello when compiling with "something" defined
[##[ end ]##]
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

### Emitting AST nodes

It's also possible to emit new AST node while preprocessing:

```nelua
local a = #[aster.Number{'dec','1'}]
```

The above code compile exactly as:

```nelua
local a = 1
```

### Expression replacement

For placing values generated by the processor you should use `#[ ]`:

```nelua
local deg2rad = #[math.pi/180.0]
local hello = #['hello ' .. 'world']
local mybool = #[false]
```

The above code compile exactly as:

```nelua
local deg2rad = 0.017453292519943
local hello = 'hello world'
local mybool = false
```

### Name replacement

For placing identifier names generated by the processor you should use `#( )`:

```nelua
local #('my' .. 'var') = 1
local function foo1() print 'foo' end
#('foo' .. 1)() -- outputs 'foo'
```

The above code compile exactly as:

```nelua
local myvar = 1
local function foo1() print 'foo' end
foo1()
```

### Processing on the fly

While the compiler is processing you can view what the compiler already knows
to generate code:

```nelua
local Weekends = @enum { Friday=0, Saturday, Sunda }
## for i,field in ipairs(symbols.Weekends.attr.holdedtype.fields) do
  print(#[field.name .. ' ' .. tostring(field.value)])
## end
```

The above code compile exactly as:

```nelua
local Weekends = @enum { Friday=0, Saturday, Sunday }
print 'Friday 0'
print 'Saturday 1'
print 'Sunday 2'
```

You can even manipulate what is already been processed:

```nelua
local Weekends = @enum { Friday=0, Saturday, Sunda }
-- fix the third field name to 'Sunday'
## symbols.Weekends.attr.holdedtype.fields[3].name = 'Sunday'
print(Weekends.Sunday) -- outputs 2
```

The above code compile exactly as:

```nelua
local Weekends = @enum { Friday=0, Saturday, Sunday }
print(Weekends.Sunday)
```

As the compiler is implemented and runs using Lua, and the preprocess
is actually a lua function that the compiler is running, thus it's possible to even modify
or inject code to the compiler itself on the fly.

### Preprocessing lazy functions

Lazy functions can make compile time dynamic functions when used in combination with
the preprocessor:

```nelua
function pow(x: auto, n: compconst integer)
  ## symbols.x.attr.type:is_integral() then
    -- x is an integral type (any unsigned/signed integer)
    local r: #[symbols.x.attr.type] = 1
    ## for i=1,symbols.n.attr.value do
      r = r * x
    ## end
    return r
  ## elseif symbols.x.attr.type:is_float() then
    -- x is a floating point type
    return x ^ n
  [##[ else
    -- invalid type, raise an error at compile time
    symbols.x.node:raisef('cannot pow variable of type "%s"', tostring(symbols.x.attr.type))
  end ]##]
end

pow(2, 2) -- use specialized implementation for integers
pow(2.0, 2) -- use pow implementation for floats
pow('a', 2) -- throws an error at compile time because of invalid type
```

### Lazy functions with blocks

Blocks can be passed to lazy functions, in this case the entire function code will be always
inlined in the call placement.

```nelua
local function unroll(count: compconst integer, body: block)
  ## for i=1,symbols.count.attr.value do
    body()
  ## end
end

local a = 0
unroll(4, do a = a + 1 end) -- inline "a = a + 1" for times
print(a) -- outputs 4
```

--------------------------------------------------------------------------------
## Pragmas

Pragmas are used to inform the compiler different behaviours in the code
generation.

### Global pragmas

Global pragmas begins with `!!` followed by it's name and parameters.

```nelua
!!cinclude '<stdio.h>' -- include a C header
!!linklib "SDL" -- link SDL library
```

### Function pragmas

```nelua
function sum(a, b) !inline -- inline function
  return a + b
end
```

### Variable pragmas

```nelua
local a: integer !noinit-- don't initialize variable to zeros
local a !volatile = 1 -- C volatile variable
```

--------------------------------------------------------------------------------
## Mixing C code

Nelua can import C functions from C headers:

```nelua
local function malloc(size: usize): pointer !cimport('malloc','<stdlib.h>') end
local function memset(s: pointer, c: int32, n: usize): pointer !cimport('memset','<stdlib.h>') end
local function free(ptr: pointer) !cimport('free','<stdlib.h>') end
local a = @int64[10]*(malloc(10 * 8))
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

{% endraw %}
