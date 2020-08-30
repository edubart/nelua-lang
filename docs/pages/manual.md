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

This page is under construction and very incomplete.
{: .callout.callout-info}

## 1 - Introduction

Nelua is a minimal, simple, efficient, statically typed, compiled, meta programmable,
safe and extensible systems programming language with a [Lua](https://www.lua.org/about.html) flavor.

Nelua is designed for performance sensitive applications,
like real-time applications and game engines.
It has syntax and semantics similar to Lua,
but is designed to be able to work with optional garbage collection, type notations
and free from an interpreter.

Nelua uses ahead of time compilation to compile to optimized native binaries and
is meta programmable at compile-time using Lua, making possible to
specialize static code at compile-time with ease to create efficient applications.

Nelua has two choices for memory management,
it's the developer choice to use garbage collection or manual memory management
depending on his use case.
By default the garbage collection enabled,
to make the language more familiar and easy to use for users coming from Lua.

Nelua compiler is written in Lua, this makes Nelua extensible,
thus programmers may add new extensions to the language
at compile time using its Lua preprocessor, such as new grammars, AST definitions,
semantics, type checkers, code generation and behaviors to the compiler.

Nelua permits mixing two approaches when coding,
a more low-level approach using specific Nelua's idioms,
such as type notations, efficient data structures (records, static arrays), manual memory management and pointers, which makes the performance efficient as C.
Or a more high-level approach using Lua's idioms, such as tables, metatables and untyped variables,
which makes the compiler uses a runtime library to provide the dynamic functionality.

Nelua compiles to C first then to the target native binary.

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

This section describes the lexis, the syntax, and the semantics of Nelua.
In other words, this section describes which tokens are valid,
how they can be combined,
and what their combinations mean.

### 3.1 - Lexical Conventions

Nelua like Lua is a free-form language. It ignores spaces and comments between lexical
elements (tokens), except as delimiters between two tokens.
In source code, Nelua recognizes as spaces the standard ASCII whitespace characters space,
form feed, newline, carriage return, horizontal tab and vertical tab.

Names (also called *identifiers*) in Nelua can be any string of Latin letters, UTF-8 unicode character,
digits and underscores, not beginning with a digit and not being a reserved word.
Identifiers are used to name symbols, variables, types, table fields and labels.

The following same *keywords* from Lua are reserved and cannot be used as names:

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

Nelua is a case-sensitive language,
for example `and` is a reserved word, but `And` and `AND` are two different valid names.
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

*[free-form language]: A programming language in which the positioning of characters is insignificant.
*[ASCII]: American Standard Code for Information Interchange
*[UTF-8]: 8-bit Unicode Transformation Format

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

<a href="/draft/" class="btn btn-outline-primary btn-lg float-right">Draft >></a>
