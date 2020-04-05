<img width="96" src="https://nelua.io/assets/images/nelua-logo.svg?sanitize=true" alt="Nelua Logo">

# Nelua Programming Language

[![Build Status](https://travis-ci.org/edubart/nelua-lang.svg?branch=master)](https://travis-ci.org/edubart/nelua-lang)
[![Coverage Status](https://coveralls.io/repos/github/edubart/nelua-lang/badge.svg?branch=master)](https://coveralls.io/github/edubart/nelua-lang?branch=master)
[![Discord](https://img.shields.io/discord/680417078959800322.svg)](https://discord.gg/7aaGeG7)
<a href="https://patreon.com/edubart">
<img height="20" src="https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fshieldsio-patreon.herokuapp.com%2Fedubart%2Fpledgesssss&style=for-the-badge"
style="max-width:100%;"/>
</a>

Nelua is a minimalistic, efficient, optionally typed, ahead of time compiled, meta programmable,
systems programming language with syntax and semantics similar to Lua.
It can work statically or dynamically depending on the code style and
compiles to native machine code. Nelua stands for *Native Extensible LUA*.

**NOTE: The language is in development.** Many features are implemented but some notable still
missing. However there are benchmarks, examples and games available ready to be run.

## About

Nelua is a [systems programming language](https://en.wikipedia.org/wiki/System_programming_language)
for performance sensitive applications where
[Lua](https://en.wikipedia.org/wiki/Lua_(programming_language))
would not be efficient, like operational systems, real-time applications and game engines.
It has syntax and semantics similar to Lua,
but is designed to be able to work free from a Lua interpreter,
instead it takes advantage of
[ahead of time compilation](https://en.wikipedia.org/wiki/Ahead-of-time_compilation).
When coding using Nelua idioms such as type annotations, records, arrays,
manual memory management, pointers the performance should be efficient as C.
But when using Lua idioms such as tables, metatables and untyped variables the compiler
uses a runtime library to provide the dynamic functionality.

Nelua can do compile-time [meta programming](https://en.wikipedia.org/wiki/Metaprogramming)
because it has a Lua preprocessor
capable to cooperate with the compiler as it compiles,
this is only possible because the compiler is fully made in Lua
and is fully accessible or modifiable by the preprocessor on the fly.
Therefore it's possible to implement higher constructs such as classes,
[generics](https://en.wikipedia.org/wiki/Generic_programming) and
[polymorphism](https://en.wikipedia.org/wiki/Polymorphism_(computer_science))
at compile time without having to make them into the language specification,
thus keeping the language simpler and compact.
For example in Lua classes don't exist but you can implement yourself using metatables,
in Nelua they don't exist neither but you can implement more efficiently at compile time
by meta programming or at runtime just like in Lua.

Nelua can do [extensible programming](https://en.wikipedia.org/wiki/Extensible_programming)
as the programmer may add extensions to the language such as new grammars, [AST](https://en.wikipedia.org/wiki/Abstract_syntax_tree) definitions, semantics, type checkers, code
generation and behaviors to the compiler at compile time via the preprocessor.

Nelua has multiple choices for
[memory management](https://en.wikipedia.org/wiki/Memory_management),
it's the developer choice to use
[garbage collection](https://en.wikipedia.org/wiki/Garbage_collection_(computer_science)),
[automatic reference counting](https://en.wikipedia.org/wiki/Automatic_Reference_Counting) or
[manual memory management](https://en.wikipedia.org/wiki/Manual_memory_management)
depending on his use case.

Nelua compiles to [C](https://en.wikipedia.org/wiki/C_(programming_language)) first
then to the target [native code](https://en.wikipedia.org/wiki/Machine_code),
this way existing C libraries and APIs can be reused and new C libraries can be created.
Any platform that a C99 compiler targets the language is capable of targeting so
the language can take advantage of highly optimized compilers such as
[GCC](https://en.wikipedia.org/wiki/GNU_Compiler_Collection) and
[Clang](https://en.wikipedia.org/wiki/Clang),
thus generating very efficient native code.

The motivation of the language is to replace C/C++ part of projects that uses
Lua today with a language that have syntax and semantics similar to Lua, but
without loosing performance or the ability to go low level. Therefore unifying the
syntax and semantics across both compiled and dynamic language.

As the Nelua syntax intends to be a superset of Lua syntax,
it can also be used to have basic type checking and extended features
for existing Lua projects by generating Lua code.

## Goals

* Be minimalistic with a small syntax, manual and API, but powerful
* Be efficient by compiling to optimized C code then native code
* Have syntax, semantics and features similar to Lua
* Optionally statically typed with type checking
* Generate native dependency free executable
* Achieve classes, generics, polymorphism and other higher constructs by meta programming
* Have an optional garbage collector
* Make possible to create clean DSLs by extending the language grammar
* Make programming safe for non experts by doing run/compile-time checks and avoiding undefined behavior
* Possibility to emit low level code (C, assembly)
* Be modular and make users capable of creating compiler plugins to extended
* Generate readable, simple and efficient C code
* Possibility to output freestanding code (dependency free, for kernel dev or minimal runtime)
* No single memory management model, choose for your use case GC, ARC or manual

## Why?

* We love to script in Lua.
* We love C performance.
* We want best of both worlds in a single language and with a unified syntax.
* We want to reuse or mix existing C/C++/Lua code.
* We want type safety and optimizations.
* We want to have efficient code while maintaining readability and safety.
* We want the language features and manual to be minimalistic and fit our brain.
* We want to deploy anywhere C runs.
* We want to extended the language features by meta programming or modding the compiler.
* We want to code with or without garbage collection depending on our use case.
* We want to abuse of static dispatch instead of dynamic dispatch to gain performance and correctness.

## Learning

More details about the language can be read on the following links:
* Check out the language [overview](https://nelua.io/overview/)
to get a quick view of the language syntax, features and usage.
* Check out the language [tutorial](https://nelua.io/tutorial/)
for learning the basics.

## Quick Installation

With [luarocks](https://luarocks.org/) and a C compiler properly installed first, in your shell
do the following command:

```bash
luarocks install https://raw.githubusercontent.com/edubart/nelua-lang/master/rockspecs/nelua-dev-1.rockspec
```

After installing the nelua compiler should be available in the luarocks binary path ready to be run.

For complete instructions on how to install on Windows see the [installing tutorial](https://nelua.io/installing/).

## Running

Create a file named `helloworld.nelua` containing:

```lua
print 'Hello world!'
```

Running by compiling to C then to native code (requires a GCC compiler):
```shell
nelua helloworld.nelua
```

## Examples

The folder [examples](https://github.com/edubart/nelua-lang/tree/master/examples)
contains some examples in Nelua, including some games,
most of the examples currently work only with the default C generator backend.

To run the Snake demo for example run:

```shell
nelua examples/snakesdl.nelua
```

## Benchmarks

Some benchmarks can be found in `benchmarks` folder, it contains nelua benchmarks
and pure C benchmark as reference. The Lua code of the benchmarks are generated
by nelua compiler, as it can compile to Lua too.

The benchmarks can be run with `make benchmark`, this is my last results:

|    benchmark |  lua 5.3 | luajit 2.1 |    nelua |        c |
|--------------|----------|------------|----------|----------|
|    ackermann | 2448.2 ms | 145.2 ms  |  47.8 ms |  47.4 ms |
|    fibonacci | 2612.4 ms | 951.7 ms  | 279.9 ms | 280.9 ms |
|       mandel | 2549.6 ms |  97.0 ms  |  88.5 ms |  88.2 ms |
|        sieve | 1240.4 ms | 265.3 ms  |  88.7 ms |  60.1 ms |
|     heapsort | 2602.1 ms | 274.0 ms  | 170.9 ms | 127.5 ms |

*NOTE*: Nelua can match C speed if all benchmarks were coded using optimized structures,
however to make the benchmarks comparisons fair with Lua/LuaJIT they were coded in Lua style
(using sequence tables and a garbage collector).

Environment that this benchmark was run:
LuaJIT 2.1.0-beta3,
GCC 9.3.0,
Lua 5.3.5,
CPU Intel Core i7-3770K CPU @ 3.50GHz,
OS ArchLinux
CFLAGS `-O3 -fno-plt -march=native -flto`

## Tests

To run the language test suit at your home do:

```
make test
```

You can run using docker if your system environment is not properly configured:
```
make docker-image
make docker-test
```

Previous test runs on the master branch can be seen in the
[github's actions tab](https://github.com/edubart/nelua-lang/actions).

## Syntax highlighting

Syntax definitions for the language is available for
Visual Studio Code in [nelua-vscode](https://github.com/edubart/nelua-vscode) and
for Sublime Text in [nelua-sublime](https://github.com/edubart/nelua-sublime).
At the moment only Sublime Text have full syntax definition, so I recommend using it.
If you use other code editor you can use Lua syntax highlighting
as Nelua syntax is very similar.

I recommend using the syntax highlighter,
it makes the experience of playing around with the language more pleasant because
it can highlight type notations.

## Roadmap

Language planned features and history of accomplished features can be seen
in the [github's projects tab](https://github.com/edubart/nelua-lang/projects).

## Contributing

You can support or contribute to Nelua in many ways,
through a [donation or sponsorship](https://patreon.com/edubart),
giving the project a star on github,
testing out its features,
reporting bugs,
discussing ideas,
spreading it to the world,
sharing projects made with it on github,
creating tutorials or blog posts,
creating [wiki](https://github.com/edubart/nelua-lang/wiki/Wiki-Home) pages that could be useful for newcomers
or
improving its documentation.

[![Become a Patron](https://c5.patreon.com/external/logo/become_a_patron_button.png)](https://www.patreon.com/edubart)

## License

MIT License
