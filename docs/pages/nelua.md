# Nelua

[![Build Status](https://travis-ci.org/edubart/nelua-lang.svg?branch=master)](https://travis-ci.org/edubart/nelua-lang)
[![Coverage Status](https://coveralls.io/repos/github/edubart/nelua-lang/badge.svg?branch=master)](https://coveralls.io/github/edubart/nelua-lang?branch=master)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?label=license)](https://opensource.org/licenses/MIT)
[![Documentation](https://img.shields.io/website/https/edubart.github.io/nelua-lang.svg?label=docs&color=blue)](https://edubart.github.io/nelua-lang/overview/)
[![Gitter](https://badges.gitter.im/nelua-lang/community.svg)](https://gitter.im/nelua-lang/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)
![Project Status](https://img.shields.io/badge/status-alpha-red.svg)

Nelua is a minimalistic, efficient, optionally typed, ahead of time compiled, meta programmable,
systems programming language with syntax and semantics similar to [Lua](https://en.wikipedia.org/wiki/Lua_(programming_language)). It can work statically or dynamically depending on the code style and
compiles to native machine code. Nelua stands for "Native Extensible LUA".

**NOTE: The language is in development.** Many features are implemented but some notable still
missing. However there are benchmarks, examples and games available ready to be run.

## About

Nelua is a language for performance sensitive applications where Lua
would not be efficient, like operational systems, real-time applications and game engines.
It has syntax and semantics similar to Lua, but is designed to be able to work free from
a Lua interpreter, instead it takes advantage of ahead of time compilation. 
When coding using Nelua idioms such as type annotations, records, arrays,
manual memory management, pointers the performance should be efficient as C.
But when using Lua idioms such as tables, metatables and untyped variables the compiler
uses a runtime library to provide the dynamic functionality.

The language can do advanced meta programming because it has a preprocessor
capable to cooperate with the compiler as it compiles,
this is only possible because the compiler is fully made in Lua
and is fully accessible or modifiable by the preprocessor on the fly. 
Therefore it's possible to implement higher constructs such as classes, generics and DSLs at compile time without having to make them into the language specification, thus keeping the language simpler and compact.
For example in Lua classes don't exist but you can implement yourself using metatables,
in Nelua they don't exists too but you can implement by meta programming.

Nelua compiles to C and then to the target native code, this way existing
C libraries and APIs can be reused and new C libraries can be created.
Any platform that a C99 compiler targets the language is capable of targeting and
the language can take advantage of highly optimized compilers such as GCC and Clang, thus generating very
efficient native code.

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
* Achieve classes, generics and other higher constructs by meta programming
* Have an optional garbage collector
* Make possible to create clean DSLs by extending the language grammar
* Make programming safe for non experts by doing runtime/compile-time checks and avoiding undefined behavior
* Possibility to emit low level code (C, assembly)
* Be modular and make users capable of creating compiler plugins to extended
* Generate readable, simple and efficient C code
* Possibility to output freestanding code (dependency free, for kernel dev or minimal runtime)

## Why?

* We love to script in Lua.
* We love C performance.
* We want best of both worlds in a single language and with a unified syntax.
* We want to reuse or mix existing C/C++/Lua code.
* We want type safety and optimizations.
* We want to have efficient code while maintaining readability and safety.
* We want the language features and manual to be minimalistic and fit our brain.
* We want to deploy anywhere Lua or C runs.
* We want to extended the language features when by meta programming.
* We want to code with or without garbage collection depending on our use case.
* We want to abuse of static dispatch instead of dynamic dispatch to gain performance and correctness.

## Learning

More details about the language can be read on the following links:
* Check out the language [overview](https://edubart.github.io/nelua-lang/overview/)
to get a quick view of the language syntax, features and usage.
* Check out the language [tutorial](https://edubart.github.io/nelua-lang/tutorial/)
for learning the basics.

## Installation

To install the language you will need [luarocks](https://luarocks.org/) installed first.
If you want to compile to native code you will also need a C compiler such as GCC or Clang.

```bash
luarocks install https://raw.githubusercontent.com/edubart/nelua-lang/master/rockspecs/nelua-dev-1.rockspec
```

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

The benchmarks can be run with `make benchmark`:

|    benchmark |  language |   min (ms) |
|--------------|-----------|------------|
|    ackermann |       lua |   2441.924 |
|    ackermann |    luajit |    150.885 |
|    ackermann |     nelua |     64.643 |
|    ackermann |         c |     51.683 |
|    fibonacci |       lua |   2607.637 |
|    fibonacci |    luajit |    934.407 |
|    fibonacci |     nelua |    387.643 |
|    fibonacci |         c |    319.794 |
|       mandel |       lua |   2628.983 |
|       mandel |    luajit |    103.067 |
|       mandel |     nelua |     92.318 |
|       mandel |         c |     92.733 |
|        sieve |       lua |   1252.810 |
|        sieve |    luajit |    282.017 |
|        sieve |     nelua |     98.735 |
|        sieve |         c |     70.754 |
|     heapsort |       lua |   2680.691 |
|     heapsort |    luajit |    298.494 |
|     heapsort |     nelua |    186.525 |
|     heapsort |         c |    145.763 |

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

To run the language test suit do:

```
make test
```

You can run using docker if your system environment is not properly configured:
```
make docker-image
make docker-test
```

## License

MIT License
