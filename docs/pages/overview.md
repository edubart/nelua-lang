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

Quick overview of the language features using many examples.

--------------------------------------------------------------------------------
## Hello world
Simple hello world program:
```euluna
print 'Hello world!'
```

## Comments
Comments are just like in Lua:
```euluna
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

There are many types of variables:

```euluna
local l = 0 -- variable of type integer, type automatically deduced
local a = 2 -- variable of type integer, type automatically deduced
local b: integer -- variable of type integer, initialized to zero by default
local c: integer = 1 -- variable of type integer, initialized
local d: var integer = 1 -- var variable
local e: var& = a -- mutable reference to variable a
local f: val = a -- immutable variable a
local f: val& = a -- mutable reference to variable a
local g = nil -- variable of type any
local h: any -- variable of type any
local i: any = 2 -- variable of type any holding an integer 2
```

Variables are initialized to zero values.

### Constants
Constant are evaluated at compile time.

```euluna
local h: const = 1 + 2 -- constant variable evaluated at compile time
```

--------------------------------------------------------------------------------
## Functions
Function arguments can be explicitly typed or automatically deduced:

```euluna
-- n type automatically deduced
function fib(n)
  if n < 2 then return n end
  return fib(n - 2) + fib(n - 1)
end

-- typed function
function fib(n: integer): integer
  if n < 2 then return n end
  return fib(n - 2) + fib(n - 1)
end
```

### Parameters

```euluna
function foo(a: var integer,
             b: var& integer,
             c: integer,
             d: val integer,
             e: val& integer)
  print(a,b,c,d,e)
  -- `d` and `e` are a read only variables and assignment on it is not allowed
  a = 2
  b = 3
  c = 4
end

local a, b, c, d, e = 0, 0, 0, 0, 0
foo(a ,b, c, d, e)
print(a, b, c, d, e) -- outputs 2 3 4 0 0
```

By default function parameters are `var` unless changed.

### Rvalues

```euluna
function foo(a: var&& integer)
  a = 1
  print(a)
end

local a = 1
-- cannot call foo(a), because a is a lvalue
foo(0)
```

### Closures

Closure are functions declared inside another function
that captures variables in the scope, by default they
capture values by shared references using the garbage collector
(this choice was made to make it work similar to lua closures),
but can they be captured by stack reference, or garbage collected copy.


```euluna
-- capture all value by reference
function main1()
  local a = 1
  local function foo()
    -- captured a by shared reference
    a = 2
  end
  foo()
  print(a)
end
main1()  -- outputs 2

-- capture all values by copy
function main2()
  local a = 1
  local function foo[=a]()
    -- captured a by copy
    a = 2
  end
  foo()
  print(a) -- outputs 1
end
main2()

function main3()
  local a = 0
  local b = 0
  local c = 0
  local function foo[=a, &b, c]()
    a = 1
    b = 2
    c = 3
  end
  foo()
  print(a, b, c) -- outputs 0 2 3
end
main3()
```

### Varargs

```euluna
function printproxy(a, ...)
  print(a, ...)
end
print(1,2,3) -- outputs 1 2 3
```

--------------------------------------------------------------------------------
## Types

### Primitives types

Value types are similar to C with some changes:

```euluna
local b = true -- boolean
local i = 1234 -- integer
local h = 0x123 -- hexadecimal integer
local u = 1234_u64 -- unsigned integer of 64 bits
local f = 1234.56_f -- float
local d = 1234.56 -- double
local c = 'a'_c -- character
local s1 = "hello world" -- string
local s2 = 'hello world' -- string
local p: integer* = nil -- pointer to integer type
```

### Function

```euluna
local f: function<(a: integer, b: integer): boolean, boolean>
local f = function(args) end

-- syntax sugar
local f: (integer, integer) -> (boolean, boolean)
function f(args) end
```

### Type inference
To infer types for arbitrary values the `@` operator can be used.

```euluna
local a = @integer(1) -- a is an integer with value 1
local p = @integer*() -- p is a pointer to an integer initialized to zeros
```

### Static Arrays

```euluna
local a: @array<integer, 4> = {1,2,3,4}
local a: array<integer, 4>

-- syntax sugar
local a: integer[4] = {1,2,3,4}
local a = @integer[4] {1,2,3,4}
```

### Tables

Similar to lua tables.

```euluna
local t1 = {} -- empty table
local t2: table -- empty table
local t3 = {x = 1, y = 2} -- simple table
local t4 = {1 , 2} -- simple table
local t5 = {a = 1, [2] = "a", 1} -- complex table
```

### Enum

Enums are used to list constant values in sequential order, if no
initial value is specified, the first value initiates at 1.

```euluna
local Weeks = @enum {
  Sunday,
  Monday,
  Tuesday,
  Wednesday,
  Thursday,
  Friday,
  Saturday
}

local a: Weeks = @Weeks.Sunday
print(@Weeks.Sunday) -- outputs 1
print(tostring(@Weeks.Sunday)) -- outputs Sunday

```

### Any

Any can store any type.

```euluna
local a: any
```

### Struct

```euluna
local Person = @record {
  name: string,
  age: integer
}

local a: Person
a.name = "John"
a.age  = 20
print(a.age)

-- constructor
local b = @Person {name = 1, age = 2}
print(b.age)
```

Can also be used as tuples

```euluna
local a: record{integer, integer}
a = {1,2}
a[1] = 0
```

### Union

Union can store multiple types.

```euluna
local u: union<integer,string>
```

### Nilable

Nilable types are not useful by itself, they are only useful when using with unions.

```euluna
local v: union<string,nilable>

-- syntax sugar for union union{string,nilable}
local v: integer?
```

### Pointer

Pointer to one or many elements.

```euluna
local p: pointer --a generic pointer to anything
local i: pointer<integer> -- pointer to an integer

-- syntax sugar
local i: integer*
```

### Range

Ranges are used to specifying ranges for slices.

```euluna
local r = 1:10
local r: range<integer>
```

### Slice

Slices are pointers to a known number of elements at runtime.

```euluna
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

### Type

The "type" type is also a type. Useful for aliasing types.

```euluna
local myint: type = integer
local MyPair = @struct{myint, myint}
```

### Type Conversion

```euluna
local i = 1
local f = @float32(i)
```

There is no automatic type conversion.


--------------------------------------------------------------------------------
## Flow control

### If

If statement is just like in Lua.

```euluna
if a == 1 then
  print 'is one'
elseif a ~= 2 then
  print 'is not two'
else
  print 'else'
end
```

### Switch

Switch statement is like C++ switch, however you don't need and should not
use breaks:

```euluna
switch a
case 1 then
  print 'is 1'
case 2, 3 then
  print 'is 2 or 3'
else
  print 'else'
end
```

### Do
Do blocks are useful to create arbitrary scopes to avoid collision of
variable names, also useful to use in combination with defer statement:

```euluna
do
  local a = 0
end
do
  local a = 1 -- can declare variable named a again
end
```

### Goto
Gotos are useful to get out of nested loops and jump between codes:

```euluna
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

```euluna
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

Just like in Lua.

```euluna
local a = 1
while a < 42 do
  a = a + 1
end
```

### Repeat

Repeat is like in Lua:

```euluna
repeat
  a = a - 1
until a == 0
```

### Numeric For
All for loops always evaluate it's ending variable only once, so the user should
keep this in mind.

#### Inclusive For

For is like in Lua, meaning they are inclusive for the first and the last
element, it's counter type is automatically deduced:

```euluna
for i = 0,5 do
  -- i is an int
  print(i) -- outputs 0 1 2 3 4 5
end
```

#### Exclusive For
An enhanced for is available to do exclusive for loops, they work using
comparison operators `~=` `<=` `>=` `<` `>`:

```euluna
for i = 0,<5 do
  print(i) -- outputs 0 1 2 3 4
end
```

#### Stepped For
The last parameter in for syntax is the step, it's counter is always incremented
with `i = i + step`, by default step is always 1,
with negative steps reverse for is possible:

```euluna
for i = 5,>0,-1 do
  print(i) -- outputs 5 4 3 2 1
end
```

#### Iterated For

```euluna
local a = {'a', 'b', 'c'}
for i,v in ipairs(a) do
  print(i, v)
end
-- outputs 1 a 2 b 3 c
```

Iterators are useful to create more complex for loops:

```euluna
function multiples_countdown(s, e)
  return function(e, i, b)
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
Continue for loops.

```euluna
for i=1,10 do
  if i<=5 do
    continue
  end
  print(i)
end
-- outputs: 6 7 8 9 10
```

### Break
Continue for loops.

```euluna
for i=1,10 do
  if i>5 do
    break
  end
  print(i)
end
-- outputs: 1 2 3 4 5
```

--------------------------------------------------------------------------------
## Modules

### Static Modules

Modules are useful to separate code scopes using local variables to avoid
type and function name clashing across the code base.

Creating module `hello`:
```euluna
-- hello.lua
local a = 1 -- private variable
local function get_a() -- private function
  return a
end

local b = 2 -- variable exported to the module
function foo()
  return get_a()
end
```

Using the module:
```euluna
import hello
hello.foo()
print(hello.b)

import hello as mymodule -- module name is mymodule
mymodule.foo()

use import hello -- all exported modules symbols are available in the current scope
foo()
```

### Dynamic Module

Dynamic modules uses tables and it can change on runtime.

Creating module `hello`:
```euluna
-- hello.lua
local M = {}
local a = 1 -- private variable
local function get_a() -- private function
  return a
end

M.b = 2
function M.foo()
  return get_a()
end

return M
```

Using the module:
```euluna
local hello = require 'hello'
hello.foo()
print(hello.b)

for k,v in pairs(require 'hello') _G[k] = v end -- import all functions to _G
foo()
```

--------------------------------------------------------------------------------
## Operators

### Operator overloading
```euluna
function `+=`(a: var& string, b: string)
  a = a .. b
end

local a = "hello"
a += "world"
print(a) -- outputs hello world
```

--------------------------------------------------------------------------------
## Error handling

### Returning errors

```euluna
function foo(dofail)
  if dofail then
    return nil, "fail"
  end
  return true, "success"
end

print(foo(true)) -- outputs "fail"
print(foo(false)) -- outputs "success"
```

### Exceptions

Exceptions are useful to raise and catch errors.

```euluna
function foo(err)
  error "failed" -- raise an exception with a string object
end

try
  foo()
except(e: string)
  -- catch error with string object
except(e: any)
  -- catch any error
end
```

--------------------------------------------------------------------------------
## Memory management

### Pointers

```euluna
@import 'euluna.std.memory'

local a = 1
local a_ptr: integer* = &a
local& c: integer = *a_ptr -- dereference is a shortcut for a_ptr[0]
b = 2
print(a) -- outputs 2
a_ptr[0] = 3
print(a) -- outputs 3
```

### Allocation

```euluna
@import 'euluna.std.memory'

local a = new(@integer) -- a type is: pointer<integer>
a[0] = 1
*a = 1
var& ra = *a; ra = 1
delete(a)

local a = new(@integer[10]) -- a is pointer<array<integer, 10>>
for i=0,<10 do
  a[i] = i
end
delete(a)
```

### Shared objects with smart pointers

```euluna
local shared_pointer = @import 'euluna.std.shared_pointer'

local Person = @struct{
  name: string,
  age: int
}

local PersonPtr = shared_pointer(Person)

local a = PersonPtr(new(@Person))
local b = a
b.name = "John"
print(a.name) -- outputs "John"
```

### Shared objects with garbage collector

```euluna
@import 'euluna.std.gc'

local Person = @struct{
  name: string,
  age: int
}

local a = gcnew(@Person)
local b = a
b.name = "John"
print(a.name) -- outputs "John"
```

--------------------------------------------------------------------------------
## Object oriented programming

The language has basic features for object oriented programming,
more advanced ones cna be achieved with metaprogramming.

### Methods
```euluna
local Person = @struct{
  name: string,
  age: integer
}

function Person:set_age(age)
  self.age = age
end

local a = Person()
a.name = "John"
a:set_age(20)
print(a.age)
```

### Inheritance

```euluna
local PolygonVTable @struct{
  area: function<(self: pointer): int>
}

local Polygon = @struct{
  vtable: PolygonVTable*,
}

function Polygon:area()
  return self.vtable.area(self)
end

local Square = @struct{
  Polygon,
  width: integer,
  height: integer
}
local squareTable: PolygonVTable

function squareTable:area()
  return self.width * self.height
end

function newSquare(...)
  local square = Square{...}
  square.vtable = &squareTable
end

polygonTable.area = Polygon.area
squareTable.area = Square.area

local castPolygon()
local square = newSquare{2, 2}
var& polygon = cast(@Polygon, square)
print(polygon:area()) -- outputs 4
```

--------------------------------------------------------------------------------
## Pragmas

Pragmas are used to inform the compiler different behaviours in the code
generator.

### Global pragmas

```euluna
{:cinclude '<stdio.h>':} -- include C header
{:cppinclude '<iostream>', cppflags "-DSOMETHING":} -- include C++ header
{:linkflags "-Lsomelib":} -- link a library
```

### Function pragmas

```euluna
function sum(a, b) {:inline:} -- inline function
  return a + b
end
```

### Variable pragmas

```euluna
local {:noinit:} a: integer -- don't initialize variable
local {:volatile:} a = 1 -- C volatile variable
```

--------------------------------------------------------------------------------
### Literals

Literals are used to convert string or numbers into arbitrary types.

```euluna
function _f32(v) {:literal:}
  return tofloat(v)
end

local a = "1234"_f32 -- a is float
```


--------------------------------------------------------------------------------
## Meta programming

The language offers advanced features for metaprogramming.

### Preprocessor

At compile time a Lua preprocessor is available to render arbitrary code:

```euluna
local a = 0
local b = 0
{% for i = 1,4 do %}
  a = a + 1 -- unroll this line 4 times
  b = b + {%=i%} -- will evaluate "i" values: 1, 2, 3 and 4
{% end %}
print(a) -- outputs 4

{% if something then %}
  print('hello') -- prints hello when compiling with "something" defined
{% end %}
```

### Templates

Templates are useful to render code with ease, they work similar to templates
in the web development world, they should not be confused with C++ templates.
Using the lua preprocessor with it you can render complex codes.

```euluna
local function unroll(count: ASTNumber, body: ASTBlock) {:template:}
  {% local typ,n,lit = count:args()
     if typ ~= 'int' or lit then return false end
     for i=1, n do %}
    {%= body %}
  {% end %}
end

local a = 0
unroll(4, do
  a = a + 1
end)
print(a) -- outputs 4


local function swap(a, b) {:template:}
  a, b = b, a
end

local x,y = 1,2
swap(x,y)
print(x,y)

```

--------------------------------------------------------------------------------
## Generics

Generics can be achieved with just macros and templates.

```euluna
function Point(T: ASTId) {:template:}
  local PointT = @struct { x: T, y: T }
  function PointT:length(a: T): T
    return math.sqrt(self.x ^ @T(2), self.y ^ @T(2))
  end
  return PointT
end

local a: Point(float32)
local b = @Point(@float32)
```

### Concepts?

```euluna
local has_area = @concept(T)
  return has_method(T, 'area')
end

function(A: has_area)
```

--------------------------------------------------------------------------------
## Standard library

### Dynamic arrays

```euluna
local vector = @import 'euluna.std.vector'

local a = @vector(int8) {1,2,3,4} -- dynamic array of int8
local a: vector(string) -- dynamic array of string
```

### Maps

```euluna
local map = @import 'euluna.std.map'

local m = @map(string, integer) {a = 1, b = 2} -- map of string -> integer
local m: map(string, integer) -- map of string -> int
```

{% endraw %}
