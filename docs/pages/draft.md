---
layout: default
title: Draft
permalink: /draft/
toc: true
---

{% raw %}

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

local a = new(@integer) -- a type is: pointer<integer>
a[0] = 1
*a = 1
var& ra = $a; ra = 1
delete(a)

local a = new(@integer[10]) -- a is pointer<array<integer, 10>>
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
  area: function<(self: pointer): integer>
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
### Literals

Literals are used to convert string or numbers into arbitrary types.

```nelua
function _f32(v) !literal
  return tofloat(v)
end

local a = "1234"_f32 -- a is float
```

--------------------------------------------------------------------------------
## Standard library

### Dynamic arrays

```nelua
local vector = @import 'nelua.std.vector'

local a = @vector(int8) {1,2,3,4} -- dynamic array of int8
local a: vector(string) -- dynamic array of string
```

### Maps

```nelua
local map = @import 'nelua.std.map'

local m = @map(string, integer) {a = 1, b = 2} -- map of string -> integer
local m: map(string, integer) -- map of string -> int
```

{% endraw %}
