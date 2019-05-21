---
layout: default
title: Manual
permalink: /manual/
toc: true
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

Additional keywords used in extensions:
```
switch case
continue
```


## Other symbols used in the language syntax

| Symbol| Syntax | Usage |
|---|---|---|
| `[]`  | array index |
| `{}`  | listing |
| `()`  | surrounding |
| `<>`  | inner type definition |
| `:`   | method access |
| `.`   | field index |
| `...` | varargs |
| `,`   | separator |
| `;`   | line separator |
| `""`  | string quoting |
| `''`  | alternative string quoting |
| `;`   | statement separator |
| `@`   | type inference |
| `::`  | label definition |
| `--`  | comment |
| `{: :}` | pragma |


## Variables mutabilities

* **var** is a mutable variable
* **val** is an immutable variable
* **const** is an immutable variable and it's expression is evaluated at compile time
