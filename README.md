![Nelua Logo](https://nelua.io/assets/img/nelua-logo-64px.png)

[nelua.io](https://nelua.io/)

[![Build Status](https://travis-ci.org/edubart/nelua-lang.svg?branch=master)](https://travis-ci.org/edubart/nelua-lang)
[![Coverage Status](https://coveralls.io/repos/github/edubart/nelua-lang/badge.svg?branch=master)](https://coveralls.io/github/edubart/nelua-lang?branch=master)
[![Discord](https://img.shields.io/discord/680417078959800322.svg)](https://discord.gg/7aaGeG7)
[![Try on Repl.it](https://repl.it/badge/github/edubart/nelua-lang)](https://repl.it/@edubart/nelua-lang#examples/replit.lua)

Nelua (stands for **N**ative **E**xtensible **Lua**) is a minimal,
statically-typed and meta-programmable systems programming language heavily
inspired by Lua, which compiles to C.

**Note:** The language is in alpha state and still evolving.

## Quick start

- For basic information, first steps and how to install Nelua, start at the
  [Tutorial](https://nelua.io/tutorial/).
- Read the [Overview](https://nelua.io/overview/) for a tour of the language's
  syntax, features and usage.
- Check out the [examples](./examples) folder for small programs written in
  Nelua.

After installing, you might want to check out the featured example: a Snake
game leveraging the famous [SDL2](https://www.libsdl.org) game engine.

``` nelua examples/snakesdl.nelua ```

Last, but not least, feel free to give feedback and ask questions over at the
[Discord server](https://discord.gg/7aaGeG7).

## Benchmarks

The benchmark suite lives in the [benchmark](./benchmark) folder and can be
ran with `make benchmark`. It compares:
  
- Pure C implementations
- C-compiled Nelua implementations
- Lua-compiled Nelua implementations

Master branch benchmark runs are recorded through
[Github Actions](https://github.com/edubart/nelua-lang/actions).

### Exemplary measurement reports

- LuaJIT 2.1.0-beta3
- GCC 9.3.0 `-O3 -fno-plt -march=native -flto`
- Lua 5.3.5
- CPU Intel Core i7-3770K CPU @ 3.50GHz
- Arch Linux

|    benchmark |  lua 5.3 | luajit 2.1 |    nelua |        c |
|--------------|----------|------------|----------|----------|
|    ackermann | 2448.2 ms | 145.2 ms  |  47.8 ms |  47.4 ms |
|    fibonacci  | 2612.4 ms | 951.7 ms  | 279.9 ms | 280.9 ms |
|       mandel | 2549.6 ms |  97.0 ms  |  88.5 ms |  88.2 ms |
|        sieve | 1240.4 ms | 265.3 ms  |  88.7 ms |  60.1 ms |
|     heapsort | 2602.1 ms | 274.0 ms  | 170.9 ms | 127.5 ms |

*NOTE*: Nelua could match C speed if all benchmarks were coded using optimized structures,
but to make fair comparisons with Lua/LuaJIT they were coded in Lua style
(using sequence tables and a garbage collector).

## About

Nelua is a [systems programming language](https://en.wikipedia.org/wiki/System_programming_language)
for performance-sensitive applications where [Lua](https://en.wikipedia.org/wiki/Lua_(programming_language))
would not be efficient, such as operating systems, real-time applications and
game engines. While it has syntax and semantics similar to Lua, it primarily
focuses on generating efficient C code and provide support for
highly-optimizable low-level programming. Using Nelua idioms such as records,
arrays, manual memory management and pointers should result in performance as
efficient as pure C; on the other hand, when using Lua idioms such as tables,
metatables and untyped variables, the compiler will bake a runtime library for
this sort of dynamic functionality into the program, which could incur some
runtime overhead.


Nelua can do [meta programming](https://en.wikipedia.org/wiki/Metaprogramming)
at compile time through preprocessor constructs written in Lua; since the
compiler itself is also written in Lua, it means that user-provided
preprocessor code can interact at any point with the compiler's internals and
the source code's [AST](https://en.wikipedia.org/wiki/Abstract_syntax_tree).
Such system allows for ad-hoc implementation of high level constructs such as
[classes](https://en.wikipedia.org/wiki/Class_(computer_programming)),
[generics](https://en.wikipedia.org/wiki/Generic_programming) and
[polymorphism](https://en.wikipedia.org/wiki/Polymorphism_(computer_science)),
all without having to add them into the core specification, thus keeping the
language simple, extensible and compact. The same way that Lua's
object-oriented patterns are not built into the language, but can be
nonetheless achieved through [metatables](https://webserver2.tecgraf.puc-rio.br/lua/local/pil/13.html),
in Nelua you could yourself implement a similar functionality which is fully
decided at compile time or dynamically dispatched at runtime.

Nelua can do [extensible programming](https://en.wikipedia.org/wiki/Extensible_programming)
as the programmer may add extensions to the language such as new grammars,
[AST](https://en.wikipedia.org/wiki/Abstract_syntax_tree) definitions,
semantics, type checkers, code generation and behaviors to the compiler at
compile time via the preprocessor.

Nelua provides support for both [garbage-collected](https://en.wikipedia.org/wiki/Garbage_collection_(computer_science))
and [manual](https://en.wikipedia.org/wiki/Manual_memory_management)
memory management in a way that the developer can easily choose between either
for each allocation in the program.

Nelua first compiles to
[C](https://en.wikipedia.org/wiki/C_(programming_language), then it executes a
C compiler to produce [native code](https://en.wikipedia.org/wiki/Machine_code).
This way existing C code and libraries can be leveraged and new C libraries can
be created. Another benefit is that Nelua can reach the same target platforms
as C99 compilers, such [GCC](https://en.wikipedia.org/wiki/GNU_Compiler_Collection)
or [Clang](https://en.wikipedia.org/wiki/Clang), while also enjoying
state-of-the-art compiler optimizations provided by them.

The initial motivation for its creation was to replace C/C++ parts of projects
which currently uses Lua with a language that has syntax and semantics similar
to Lua, but allows for fine-grained performance optimizations and does not lose
the ability to go low level, therefore unifying the syntax and semantics across
both compiled and dynamic languages.

## Goals

* Be minimal with a small syntax, manual and API, but powerful
* Be efficient by compiling to optimized C code then native code
* Have syntax, semantics and features similar to Lua
* Optionally statically typed with type checking
* Achieve classes, generics, polymorphism and other higher constructs by meta programming
* Have an optional garbage collector
* Make possible to create clean DSLs by extending the language grammar
* Make programming safe for non experts by doing run/compile-time checks and avoiding undefined behavior
* Possibility to emit low level code (C, assembly)
* Be modular and make users capable of creating compiler plugins to extended
* Generate readable, simple and efficient C code
* Possibility to output freestanding code (dependency free, for kernel dev or minimal runtime)
* No single memory management model, choose for your use case GC or manual

## Why?

* We love to script in Lua.
* We love C performance.
* We want best of both worlds in a single language and with a unified syntax.
* We want to reuse or mix existing C/C++/Lua code.
* We want type safety and optimizations.
* We want to have efficient code while maintaining readability and safety.
* We want the language features and manual to be minimal and fit our brain.
* We want to deploy anywhere C runs.
* We want to extended the language features by meta programming or modding the compiler.
* We want to code with or without garbage collection depending on our use case.
* We want to abuse of static dispatch instead of dynamic dispatch to gain performance and correctness.

## Contributing

You can support or contribute to Nelua in many ways,
giving the project a star on github,
testing out its features,
reporting bugs,
discussing ideas,
spreading it to the world,
sharing projects made with it on github,
creating tutorials or blog posts,
creating [wiki](https://github.com/edubart/nelua-lang/wiki/Wiki-Home) pages that could be useful for newcomers,
improving its documentation
or through a [donation or sponsorship](https://patreon.com/edubart),

[![Become a Patron](https://c5.patreon.com/external/logo/become_a_patron_button.png)](https://www.patreon.com/edubart)

## License

MIT License
