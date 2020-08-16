---
layout: default
title: Draft
permalink: /draft/
toc: true
categories: sidenav
order: 5
---

{% raw %}

# Draft

This is a draft for features that are not implemented yet. Once a feature here is completed
its text will be moved into the overview page. Don't expect any of the examples
here to work or be implemented in the future exactly as presented here.

--------------------------------------------------------------------------------

## Iterated For

```nelua
local a = {'a', 'b', 'c'}
for i,v in ipairs(a) do
  print(i, v) -- outputs 1 a 2 b 3 c
end
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

## Multiple cases switch

Switch statement is similar to C switches:

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

## Records as tuples

Records can also be used as tuples:

```nelua
local a: record{integer, integer}
a = {1,2}
a[1] = 0
```

### Function type

Functions can be define inside variables like in lua:

```nelua
local f1: function(a: integer, b: integer): (boolean, boolean)
local f2 = function(args) end
```

### Union

Union can store multiple types at the same block of memory:

```nelua
local u: union{integer,string} -- variable of type union, initialized to its first type 'integer'
print(u) -- outputs 0
u = 'string' -- u now holds a string
print(u) -- outputs 'string'

local u: union(uint16){integer,string} -- union that can hold more runtime types
local u: union(void){integer,string} -- union that holds all types at the same time (unsafe)
```

Unions are slightly different from C union by default, because it has an `uint8` internally that holds the current type at runtime, thus the union size will have at least the
size of the largest type plus the size of `uint8`. By default unions cannot hold more than 256 different types. The internal type

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

### Optional

Optional type is actually a union of a `niltype` and any other type, it
is used to declare a variable that may hold or not a variable:

```nelua
local a: union{niltype,string} -- variable that may hold a string, initialized to 'nil'
assert(a == nil)
assert(not a)
print(a) -- outputs 'nil'
a = 'hi'
print(a) -- outputs 'hi'

-- syntax sugar for union union{niltype,string}
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

### Block

Block variables are used to encapsulate arbitrary code inside a variable at compile time,
when the block variable is called the compiler replaces the call code with the block code:

```nelua
local a: block = do
  print 'hello'
end -- a is of type 'block'
a() -- compiler injects the block code here, prints 'hello world'
```

But block variables are not functions, think of block variables as a code replacement tool.
Later will be shown how them are more useful to do *meta programming*.

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
  local function foo() <byref>
    -- captured 'a' by stack reference
    a = 2
  end
  foo()
  print(a) -- outputs 2
end
main()
```

The advantage of capturing by its stack reference is that the closure becomes much more lightweight
because we don't need to promote to heap variables or use the garbage collector, but the disadvantage is that the function can not be called outside is parent scope, making this more unsafe and is responsibility of the programmer to make sure this doesn't happen otherwise would cause an undefined behavior and potentially a crash.


### Variable arguments

Variable arguments functions can be implemented as poly functions, the syntax is like in Lua
using the `...`, and can be used to forward to another variable argument function:

```nelua
local function print_proxy(a, ...)
  print(a, ...)
end
print_proxy(1,2,3) -- outputs 1 2 3
```

On each call a different types call a real function will be implemented.

The arguments can be accessed individually using the `select` builtin directive (like in Lua):

```nelua
local function print_first_two(...)
  local a = select(1, ...)
  local b = select(2, ...)
  local n = select('#', ...)
  print(a, b, n)
end
print_first_two('a','b') -- outputs "a b 2"
```

It can be combined with multiple return functions:

```nelua
local function get_two()
  return 1, 2
end
local function print_all(...)
  print(...)
end
print_all(get_two()) -- outputs "1 2"
```

### Generics

Generics can be achieved with poly functions:

```nelua
local function Point(T: type)
  local PointT = @record{ x: T, y: T }
  function PointT:length(a: T): T
    return math.sqrt(self.x ^ @T(2), self.y ^ @T(2))
  end
  return PointT
end

local PointFloat32 = Point(@float32)
local b: PointFloat32
```

### Poly functions with blocks

Blocks can be passed to poly functions, in this case the entire function code will be always
inlined in the call placement.

```nelua
local function unroll(count: integer <comptime>, body: block)
  ## for i=1,count.value do
    body()
  ## end
end

local a = 0
unroll(4, do a = a + 1 end) -- inline "a = a + 1" for times
print(a) -- outputs 4
```

--------------------------------------------------------------------------------
## Modules

### Static Modules

Modules are useful to separate code scopes using local variables to avoid
type and function name clashing across the code base.

Creating module `hello`:
```nelua
-- hello.lua
local a = 1 -- private variable
local function get_a() -- private function
  return a
end

local b = 2 -- variable exported to the module
local function foo()
  return get_a()
end
```

Using the module:
```nelua
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
```nelua
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
```nelua
local hello = require 'hello'
hello.foo()
print(hello.b)

for k,v in pairs(require 'hello') _G[k] = v end -- import all functions to _G
foo()
```

--------------------------------------------------------------------------------
## Operators

### Operator overloading
```nelua
local function `+`(a: string, b: string)
  return a .. b
end

local a = "hello " + "world"
print(a) -- outputs hello world
```

--------------------------------------------------------------------------------
## Error handling

### Returning errors

```nelua
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

```nelua
local function foo(err)
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

### Allocation

```nelua
@import 'nelua.std.memory'

local a = new(@integer) -- a type is: pointer(integer)
a[0] = 1
*a = 1
var& ra = $a; ra = 1
delete(a)

local a = new(@array(integer,10)) -- a is pointer(array(integer, 10))
for i=0,<10 do
  a[i] = i
end
delete(a)
```

### Shared objects with smart pointers

```nelua
local shared_pointer = @import 'nelua.std.shared_pointer'

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

```nelua
@import 'nelua.std.gc'

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
```nelua
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

```nelua
local PolygonVTable = @struct{
  area: function(self: pointer): integer
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
## Standard library

### Dynamic arrays

```nelua
local vector = @import 'nstd.vector'

local a = @vector(int8) {1,2,3,4} -- dynamic array of int8
local a: vector(string) -- dynamic array of string
```

### Maps

```nelua
local map = @import 'nstd.map'

local m = @map(string, integer) {a = 1, b = 2} -- map of string -> integer
local m: map(string, integer) -- map of string -> int
```

{% endraw %}
