---
layout: docs
title: Draft
permalink: /draft
categories: docs toc
order: 5
---

{% raw %}

This is a draft for features that are not implemented yet. Once a feature here is completed
its text will be moved into the overview page.
{: .lead}

Don't expect any of the examples
here **to work or be implemented** in the future exactly as presented here,
these are mostly ideias.
{: .callout.callout-warning}

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

## Modules

### Static Modules

Modules are useful to separate code scopes using local variables to avoid
type and function name clashing across the code base.

Creating module `hello`:
```nelua
-- mymodule.lua
local mymodule = @record{}

local a = 1 -- private variable
local function get_a() -- private function
  return a
end

global mymodule.b = 2 -- variable exported to the module
function mymodule.foo() -- function exported to the module
  return get_a()
end

return mymodule
```

Using the module:
```nelua
local mymodule = require 'mymodule'
mymodule.foo()
print(mymodule.b)
```

### Dynamic Module

Dynamic modules uses tables and it can change on runtime.

Creating module `mymodule`:
```nelua
-- mymodule.lua
local mymodule = {}
local a = 1 -- private variable
local function get_a() -- private function
  return a
end

mymodule.b = 2
function mymodule.foo()
  return get_a()
end

return mymodule
```

Using the module:
```nelua
local mymodule = require 'mymodule'
mymodule.foo()
print(mymodule.b)

for k,v in pairs(require 'mymodule')
  _G[k] = v
end -- import all functions to _G
foo()
```

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

{% endraw %}
