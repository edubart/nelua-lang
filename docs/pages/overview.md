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
  always match it's correspoding token
]=]
```

--------------------------------------------------------------------------------
## Variables

There are many types of variables:

```euluna
var a = 2 -- variable of type integer, type automatically deduced
var b: int -- variable of type integer, initialized to zero by default
var c: int = 1 -- variable of type integer, initialized
let d = 1 -- immutable constant variable
let e = a -- immutable reference to variable a
var& f = a -- mutable reference to variable a
var& f = a -- immutable reference to variable a
var g = nil -- variable of type any
var h: any -- variable of type any
var i: any = 2 -- variable of type any holding an integer 2
```

Variables are initilized to zero values.

### Constants
Constant are evaluated at compile time.

```euluna
const h = 1 + 2 -- constant variable evaluated at compile time
```

### Scope

Rules:
* `var` `let` `const` are local by default inside function blocks
* in code scope all variables are exported unless it is declated as `local`

```euluna
-- variables are locally available
local a
local var a
local let a = 1
local var& a = b
local const a = 1
local function a() end

-- variables are exported
a = nil -- only in lua compatible mode
var a
let a = 1
const a = 1
function a() end

function f()
  -- variables are locally available
  local a
  local var a
  local let a = 1
  local const a = 1
  local function a() end

  var a
  let a = 1
  const a = 1
end

function f()
  a = nil -- only in lua compatible mode
  function a() end -- only in lua compatible mode
end
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
function fib(n: int): int
  if n < 2 then return n end
  return fib(n - 2) + fib(n - 1)
end
```

### Parameters

```euluna
function foo(var a: int, var& b: int, let c: int, d: int)
  print(a,b,c)
  a = 1
  b = 2
  -- `c` is a read only variables and assignment on it is not allowed
  d = 4
end

var a, b, c, d = 0, 0, 0, 0
foo(a ,b, c, d)
print(a, b, c, d) -- outputs 0 2 0 0
```

By default function parameters are `var` unless changed.

### Closures

Closure are functions declared inside another function
that captures variables in the scope, by default they
capture values by shared references (this choice was
made to make it work similiar to lua closures), but can they be captured
by stack reference or by copy.


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
  local function foo[bycopy]()
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
  local function foo[bycopy a, byref b, byshare c]()
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

Value types are similiar to C with some changes:

```euluna
var b = true -- boolean
var i = 1234 -- integer
var h = 0x123 -- hexadecimal integer
var u = 1234_u64 -- unsigned integer of 64 bits
var f = 1234.56_f -- float
var d = 1234.56 -- double
var c = 'a'_c -- character
var p: pointer<integer> = nil -- pointer to integer type
var str1 = "hello world" -- string
var str2 = 'hello world' -- string
```

### Static arrays

```euluna
var a: array<integer, 4> = {1,2,3,4}
var b = @array<integer,4> {1,2,3,4}
var c = @array<integer> {1,2,3,4}
var c = @array {1,2,3,4}

```

### Tables

Similar to lua tables.

```euluna
var t1 = {} -- empty table
var t2: table -- empty table
var t3 = {x = 1, y = 2} -- simple table
var t4 = {1 , 2} -- simple table
var t5 = {a = 1, [2] = "a", 1} -- complex table
```

### Enum

Enums are used to list constant values in sequential order, if no
initial value is specified, the first value initiates at 1.

```euluna
typedef Weeks = enum {
  Sunday,
  Monday,
  Tuesday,
  Wednesday,
  Thursday,
  Friday,
  Saturday
}

var a: Weeks = Weeks.Sunday
print(Weeks.Sunday) -- outputs 1
print(tostring(Week.Sunday)) -- outputs Sunday

```

### Variant

```euluna
var a: variant<integer,string,nil>

-- syntax sugar
var b: (integer|string|nil)
```

### Optional

Optional types are used in variables to check if the variables is set.

```euluna
var b: optional<integer, nil>
var a: optional<integer, nil>
a = 1
print(a, b) -- outputs "1 nil"

-- syntax sugar
var b: integer?
```

### Struct

```euluna
typedef Person = struct {
  name: string,
  age: integer
}

var a: Person
a.name = "John"
a.age  = 20
print(a.age)

-- constructor
var b = @Person {name = 1, age = 2}
print(b.age)
```

### Pointer

```euluna
var a: pointer<integer>

-- syntax sugar
var a: *pointer
```

### Tuple

```euluna
var a: tuple<integer, integer>
a = tuple{1,2}
a[1] = 0
```

### Slices

```euluna
var arr = @array<integer> {1,2,3,4}
print(arr[1:2]) -- outputs 1 2
print(arr[2:]) -- outputs 2 3 4
print(arr[:3]) -- outputs 1 2 3
print(arr[:]) -- outputs 1 2 3 4

var s: slice<integer>
```

### Function

```euluna
var f: function(a: integer, b: integer): boolean, boolean

var f = function(args) end

-- syntax sugar
function f(args) end
```

### Type alias

```euluna
typedef MyPair = tuple<integer, integer>
```

### Type conversions

```euluna
var i = 1
var d1 = cast(@float32, i)
var d2 = @float32(i)
```
Requires explicity conversions where data loss is possible.

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
Do blocks are useful to create arbritary scopes to avoid colision of
variable names, also useful to use in combination with defer statement:

```euluna
do
  var a = 0
end
do
  var a = 1 -- can declare variable named a again
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
var a = 1
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

### Numeric for
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
comparasion operators `~=` `<=` `>=` `<` `>`:

```euluna
for i = 0,<5 do
  print(i) -- outputs 0 1 2 3 4
end
```

#### Stepped For
The last paramter in for syntax is the step, it's counter is always incremented
with `i = i + step`, by default step is always 1,
with negative steps reverse for is possible:

```euluna
for i = 5,>0,-1 do
  print(i) -- outputs 5 4 3 2 1
end
```

#### Iterated for

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

### Static modules

Modules are useful to separate code scopes using local variables to avoid
type and function name clashing across the code base.

Creating module `hello`:
```euluna
-- hello.lua
local a = 1 -- private variable
local function get_a() -- private function
  return a
end

var b = 2 -- variable exported to the module
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

### Dynamic module

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

### Operator list

### Ternary if statement

```euluna
var a = 1 if true else 2
print(a) -- outputs 1
```

### Operator overloading
```euluna
function `+=`(var& a: string, b: string)
  a = a .. b
end

var a = "hello"
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

Exceptions are useful to throw and catch errors.

```euluna
function foo(err)
  error "failed" -- throw an exception with a string object
end

try
  foo()
catch(e: string)
  -- catch error with string object
catch(e: any)
  -- catch any error
end
```

--------------------------------------------------------------------------------
## Memory management

### Pointers

```euluna
import euluna.std.memory

var a = 1
var a_ptr: pointer<integer> = &a
var& c: int = *a_ptr -- dereference is a shortcut for a_ptr[0]
b = 2
print(a) -- outputs 2
a_ptr[0] = 3
print(a) -- outputs 3
```

### Allocation

```euluna
import euluna.std.memory

var a = new(@integer) -- a type is: pointer<integer>
a[0] = 1
*a = 1
var& ra = *a; ra = 1
delete(a)

let a = new(@integer[10]) -- a is pointer<array<integer, 10>>
for i=0,<10 do
  a[i] = i
end
delete(a)
```

### Shared objects with smart pointers

```euluna
import euluna.std.shared_pointer

struct Person {
  name: string,
  age: int
}

alias PersonPtr = shared_pointer<Person>

var a = PersonPtr(new(@Person))
var b = a
b.name = "John"
print(a.name) -- outputs "John"
```

### Shared objects with garbage collector

```euluna
import euluna.std.gc

struct Person {
  name: string,
  age: int
}

var a = gcnew(@Person)
var b = a
b.name = "John"
print(a.name) -- outputs "John"
```

--------------------------------------------------------------------------------
## Object oriented programming

The language has basic features for object oriented programming,
more advanced ones cna be achieved with metaprogramming.

### Methods
```euluna
struct Person {
  name: string,
  age: integer
}

function Person:set_age(age)
  self.age = age
end

var a = Person()
a.name = "John"
a:set_age(20)
print(a.age)
```

### Inheritance

```euluna
struct PolygonVTable {
  area: function<(self: pointer): int>
}

struct Polygon {
  vtable: pointer<PolygonVTable>,
}

function Polygon:area()
  return self.vtable.area(self)
end

struct Square {
  Polygon,
  width: int,
  height: int
}
var squareTable: PolygonVTable

function squareTable:area()
  return self.width * self.height
end

function newSquare()
  local square = Square{}
  square.vtable = addressof(squareTable)
end

polygonTable.area = Polygon.area
squareTable.area = Square.area

var square = Square{2, 2}
var& polygon = cast<Polygon>(square)
print(polygon:area()) -- outputs 4
```

--------------------------------------------------------------------------------
### Literals

Literals are used to convert string or numbers into arbritary types.

```euluna
literal _f32(v)
  return tofloat(v)
end

var a = "1234"_f32 -- a is float
```

--------------------------------------------------------------------------------
## Pragmas

Pragmas are used to inform the compiler different behaviours in the code
generator.

### Global pragmas

```euluna
@[cinclude('<stdio.h>')] -- include C header
@[cppinclude('<iostream>')] -- include C++ header
@[cppflags("-DSOMETHING")] -- compile flags passed to C++ compiler
@[linkflags("-Lsomelib")] -- link a library
```

### Function pragmas

```euluna
function sum(a, b) @[inline] -- inline function
  return a + b
end
```

### Variable pragmas

```euluna
var @[noinit] a: int -- don't initialize variable
var @[volatile] a = 1 -- C++ volatile variable
```

--------------------------------------------------------------------------------
## Meta programming

The language offers advanced features for metaprogramming.

### Preprocessor

At compile time a Lua preprocessor is available to render arbritary code:

```euluna
var a = 0
var b = 0
{% for i = 1,4 do %}
  a = a + 1 -- unroll this line 4 times
  b = b + {%=i%} -- will evalute "i" values: 1, 2, 3 and 4
{% end %}
print(a) -- outputs 4

{% if something then %}
  print('hello') -- prints hello when compiling with "something" defined
{% end %}
```

### Templates

Templates are useful to render code with ease, they work similiar to templates
in the web development world, they should not be confused with C++ templates.
Using the lua preprocessor with it you can render complex codes.

```euluna
template unroll(count: ASTNumber, body: ASTBlock)
  {% local typ,n,lit = count:args()
     if typ ~= 'int' or lit then return false end
     for i=1, n do %}
    {%= body %}
  {% end %}
end

var a = 0
unroll(4, do
  a = a + 1
end)
print(a) -- outputs 4


local template swap(a, b)
  a, b = b, a
end

var x,y = 1,2
swap(x,y)
print(x,y)

```

--------------------------------------------------------------------------------
## Generics

Generics can be achieved with just macros and templates.

```euluna
template Point(T: ASTId)
  {%
    local typealias = 'PointT'
    local typename = 'Point' .. tostring(T)
    if has_type(typename) then return typename end
  %}

  typedef PointT = struct { x: T, y: T }
  function PointT:length(a: T): T
    return math.sqrt(self.x ^ @T(2), self.y ^ @T(2))
  end

  {% self:replace_type_id(typealias, typename) %}
  {% return PointT %}
end

var a: Point(@float32)
var b = @Point(float32)
```

```euluna
template generic(T: ASTId, GenericT: ASTId, body: ASTBlock)
  template {%= tostring(GenericT) %}(T: ASTId)
    {%%
      local typealias = tostring(GenericT)
      local typename = 'Point_' .. tostring(T)
      if has_type(typename) then return typename end
    %%}
    {%%= body %%}
    {%%
      self:replace_type_id(typealias, typename)
      return PointT
    %%}
  end
end

generic(T, Point, do
  typedef PointT = struct { x: T, y: T }
  function Point:length(a: T): T
    return math.sqrt(self.x ^ @T(2), self.y ^ @T(2))
  end
end)

Point(float32)
Point(float64)
```


### Concepts?

```euluna
typedef has_area = concept(T)
  return has_method(T, 'area')
end

function(A: has_area)
```

--------------------------------------------------------------------------------
## Standard library

### Dynamic arrays

```euluna
import euluna.std.vector

var arr1 = @vector {1,2,3,4} -- dynamic array of integer
var arr2 = @vector<int8> {1,2,3,4} -- dynamic array of int8
var arr3: @vector<string> -- dynamic array of string
```

### Maps

```euluna
import euluna.std.map

var m1 = @map {a = 1, b = 2} -- map of string -> integer
var m2 = @map<string, integer>{} -- map of string -> integer
var m3: @map<string, integer> -- map of string -> int
```

{% endraw %}
