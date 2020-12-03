---
layout: docs
title: Manual
permalink: /manual/
categories: docs toc
toc: true
order: 4
---

Technical specification of the Nelua language.
{: .lead}

This page is under construction and is very incomplete.
{: .callout.callout-info}

## 1 - Introduction

Nelua is a minimal, simple, efficient, statically typed, compiled, metaprogrammable,
safe, and extensible systems programming language with a [Lua](https://www.lua.org/about.html) flavor.

Nelua is designed for performance-sensitive applications,
like real-time applications and game engines.
It has syntax and semantics similar to Lua,
but it is designed to work with optional garbage collection and type notations
and is free of an interpreter.

Nelua uses ahead-of-time compilation to compile to optimized native binaries, and
is metaprogrammable at compile-time using Lua, making it possible to
specialize static code at compile-time with ease in order to create efficient applications.

Nelua has two choices for memory management.
It is the developer's choice whether to use garbage collection or manual memory management.
By default garbage collection is enabled
to make the language more familiar and easy to use for users coming from Lua.

The Nelua compiler is written in Lua. This makes Nelua extensible.
Programmers may add new extensions to the language
at compile-time using the Lua preprocessor, such as new grammars, AST definitions,
semantics, type checkers, code generation, and other behaviors.

Nelua permits mixing two approaches when coding:
a more low-level approach using Nelua-specific idioms, e.g. type notations, records, static arrays, manual memory management, pointers, etc., which make the performance efficient as C,
or a more high-level approach using Lua's idioms, such as tables, metatables and untyped variables,
which makes the compiler use a runtime library to provide dynamic functionality.

Nelua compiles to C first, then to the target native binary.

Nelua stands for *Native Extensible Lua*.

## 2 - Basic Notions

This section describes the basic notions of the language.

## 2.1 - Symbols, Variables and Types
TODO

## 2.2 - Records
TODO

## 2.2 - Memory Management
TODO

## 2.2.1 - Garbage Collection
TODO

## 2.2.2 - Manual Management
TODO

## 3 - The Language

This section describes the lexis, syntax, and semantics of Nelua.
In other words, this section describes which tokens are valid,
how they can be combined,
and what their combinations mean.

### 3.1 - Lexical Conventions

Nelua, like Lua, is a free-form language. It ignores spaces and comments between lexical
elements (tokens), except as delimiters between two tokens.
In source code, Nelua recognizes as spaces the standard ASCII whitespace characters: space,
form feed, newline, carriage return, horizontal tab and vertical tab.

Names (also called *identifiers*) in Nelua can be any string of Latin letters, UTF-8 unicode character,
digits and underscores, as long as they do not begin with a digit and are not a reserved word.
Identifiers are used to name symbols, variables, types, table fields and labels.

The following *keywords* from Lua are reserved and cannot be used as identifiers:

```nelua
and       break     do        else      elseif    end
false     for       function  goto      if        in
local     nil       not       or        repeat    return
then      true      until     while
```

Plus the following *keywords*:

```nelua
case      continue  defer     global    switch
```

Nelua is a case-sensitive language.
For example `and` is a reserved word, but `And` and `AND` are two different valid identifiers.
As a convention, programs should avoid creating names that start with an underscore followed
by uppercase letters (such as `_VERSION`).

The following strings denote tokens used in the Nelua syntax:

| Token| Name | Usage |
|---|---|---|
| `(` `)` | parenthesis | function calls, enclosing expressions |
| `[` `]` | square brackets | array indexing |
| `{` `}` | curly braces | list initialization |
| `<` `>` | angle brackets | binary comparisons, symbol annotations |
| `[[` `]]`, `[=[` `]=]`, ... | double brackets | multi lining (comments, strings or preprocessor) |
| `#` | hash | length operation |
| `##` | double hash | preprocessor |
| `#[` `]#` | hashed square brackets | preprocessor expression |
| `#|` `|#` | hashed vertical bars | preprocessor name expression |
| `.` | dot | field index |
| `..` | double dots | concatenation |
| `...` | ellipsis | variable arguments |
| `:` | colon | method index |
| `::`  | double colon | label definition |
| `,` | comma | separator |
| `;` | semicolon | separator, statement separator |
| `"` | double quote | string quoting |
| `'` | single quote | alternative string quoting |
| `+` | plus | addition |
| `-` | minus | negation, subtraction |
| `--` | double minus | comment |
| `*` | asterisk | multiplication, pointer expression |
| `/` | slash | division |
| `//` | double slash | floor division |
| `%` | percent | modulo |
| `^` | caret | exponentiation |
| `&` | ampersand | bitwise AND, reference operation |
| `$` | dollar | dereference operation |
| `@` | at | type expression |
| `?` | question mark | optional type expression |
| `|` | vertical bar | bitwise OR |
| `=` | equals | assignment |
| `==` | double equals | equality comparison |
| `~` | tilde | bitwise not |
| `~=` | tilde + equals | not equal |
| `<` | left angle bracket | less |
| `<<` | double left angle bracket | bitwise left shift |
| `<=` | left angle bracket + equals | less than |
| `>` | right angle bracket | greater |
| `>>` | double right angle bracket | bitwise right shift |
| `>=` | right angle bracket + equals | greater than |
{: .table.table-bordered.table-striped.table-sm}

## 3.2 - Symbols
TODO

## 3.3 - Statements
TODO

## 3.4 - Expressions
TODO

## 4 - Meta Programming
TODO

## 5 - The Compiler
TODO

## 6 - The Standard Libraries
TODO

*[free-form language]: A programming language in which the positioning of characters is insignificant.
*[ASCII]: American Standard Code for Information Interchange
*[UTF-8]: 8-bit Unicode Transformation Format

<a href="/draft/" class="btn btn-outline-primary btn-lg float-right">Draft >></a>
