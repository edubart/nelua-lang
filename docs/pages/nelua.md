<img width="96" src="https://nelua.io/assets/images/nelua-logo.svg?sanitize=true">

# The Nelua Programming Language

[![Build Status](https://travis-ci.org/edubart/nelua-lang.svg?branch=master)](https://travis-ci.org/edubart/nelua-lang)
[![Coverage Status](https://coveralls.io/repos/github/edubart/nelua-lang/badge.svg?branch=master)](https://coveralls.io/github/edubart/nelua-lang?branch=master)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?label=license)](https://opensource.org/licenses/MIT)
[![Gitter](https://badges.gitter.im/nelua-lang/community.svg)](https://gitter.im/nelua-lang/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

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
by meta programming or at runtime just like in Lua. Nelua can do some runtime meta programming
too in the Lua style, by using tables, metatables and metamethods.

Nelua can do [extensible programming](https://en.wikipedia.org/wiki/Extensible_programming)
as the programmer may add extensions to the language such as new grammars, [AST](https://en.wikipedia.org/wiki/Abstract_syntax_tree) definitions, semantics, typecheckers, code
generation and behaviours to the compiler at compile time via the preprocessor.

Nelua has mutiple choices for
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
* No single memory managment model, choose for your use case GC, ARC or manual

## Why?

* We love to script in Lua.
* We love C performance.
* We want best of both worlds in a single language and with a unified syntax.
* We want to reuse or mix existing C/C++/Lua code.
* We want type safety and optimizations.
* We want to have efficient code while maintaining readability and safety.
* We want the language features and manual to be minimalistic and fit our brain.
* We want to deploy anywhere Lua or C runs.
* We want to extended the language features by meta programming or modding the compiler.
* We want to code with or without garbage collection depending on our use case.
* We want to abuse of static dispatch instead of dynamic dispatch to gain performance and correctness.

## Learning

More details about the language can be read on the following links:
* Check out the language [overview](https://nelua.io/overview/)
to get a quick view of the language syntax, features and usage.
* Check out the language [tutorial](https://nelua.io/tutorial/)
for learning the basics.

## Installation

You will need [luarocks](https://luarocks.org/) and a C compiler
like GCC or Clang installed first.
In your shell do the following command to install:

```bash
luarocks install https://raw.githubusercontent.com/edubart/nelua-lang/master/rockspecs/nelua-dev-1.rockspec
```

After installing the nelua compiler should be available in the luarocks binary path ready to be run.

## Running

Create a file named `helloworld.nelua` containing:

```lua
print 'Hello world!'
```

Running by compiling to C then to native code (requires a GCC compiler):
```shell
nelua helloworld.nelua
```

Running by compiling to Lua and using your system Lua's interpreter:
```shell
nelua -g lua helloworld.nelua
```

Both ways it will output  ```Hello world!```


## Examples

The folder `examples` contains some examples in Nelua, including some games,
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

|    benchmark |  lua 5.3   | luajit 2.1 |      nelua |          c |
|--------------|------------|------------|------------|------------|
|    ackermann |  2441.9 ms |   150.8 ms |    64.6 ms |    51.6 ms |
|    fibonacci |  2607.6 ms |   934.4 ms |   387.6 ms |   319.7 ms |
|       mandel |  2628.9 ms |   103.0 ms |    92.3 ms |    92.7 ms |
|        sieve |  1252.8 ms |   282.0 ms |    98.7 ms |    70.7 ms |
|     heapsort |  2680.6 ms |   298.4 ms |   186.5 ms |   145.7 ms |

*NOTE*: Nelua can match C speed if the benchmarks were coded using arrays instead of tables,
however to make the benchmarks comparisons fair with Lua/LuaJIT they were coded in Lua style
(using tables and its API).

Environment that this benchmark was run:
LuaJIT 2.1.0-beta3,
GCC 9.2.0 with,
Lua 5.3.5,
CPU Intel Core i7-3770K CPU @ 3.50GH,
OS ArchLinux
compiled with C flags `-O2 -fno-plt -march=native`

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
At the moment only Sublime Text have full definition, so I recommend using it.
If you use other code editor you can use Lua syntax highlighting,
as Nelua syntax is very similar but of course will be incomplete.

I recommend using the syntax highlighter,
it makes the experience of playing around with the language more pleasant because
it can highlight type notations.

## Roadmap

Language planned features and history of accomplished features can be seen
in the [github's projects tab](https://github.com/edubart/nelua-lang/projects).

## License

MIT License
