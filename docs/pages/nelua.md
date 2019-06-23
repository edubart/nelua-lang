# Nelua

[![Build Status](https://travis-ci.org/edubart/nelua-lang.svg?branch=master)](https://travis-ci.org/edubart/nelua-lang)
[![Coverage Status](https://coveralls.io/repos/github/edubart/nelua-lang/badge.svg?branch=master)](https://coveralls.io/github/edubart/nelua-lang?branch=master)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?label=license)](https://opensource.org/licenses/MIT)
[![Documentation](https://img.shields.io/website/https/edubart.github.io/nelua-lang.svg?label=docs&color=blue)](https://edubart.github.io/nelua-lang/overview/)
[![Join the chat at Gitter](https://badges.gitter.im/euluna-lang/Lobby.svg)](https://gitter.im/nelua-lang/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
![Project Status](https://img.shields.io/badge/status-alpha-red.svg)

Nelua is a minimalistic, efficient, safe, optionally typed, ahead of time compiled, meta programmable,
systems programming language with syntax and semantics similar to Lua
language that can work statically or dynamically depending on the code style and
compiles to native machine code. Nelua stands for "Native Extensible LUA".

**The language is currently in alpha stage.** Many features are implemented but some notable still missing. There are some benchmarks, examples and games available in the repository that can be run.

## About

Nelua aims to be a language for performance sensitive applications where Lua
would not be efficient (like operational systems, real-time applications, game engines)
while maintaining syntax and semantics compatible with Lua and providing a
a seamless interface to Lua. Nelua is designed to be able to work free from a Lua VM
or garbage collector when using its new idioms, just like a C program would work.
When coding with types and using its new idioms (records, arrays, manual memory
management, pointers, etc) the performance should be efficient as C. However when
using dynamic Lua idioms (like tables, metatables), the compiler
uses a runtime library to provide the Lua functionality. Nelua uses ahead of time compilation
and there is no VM or interpreted code.

The motivation is to have a language to replace C/C++ part of projects that uses
Lua today with a language with syntax and semantics similar to Lua, but
without loosing performance or the ability to go low level. Therefore unifying the
syntax and semantics across both compiled and dynamic language. At the same time maintaining
the language safe for non-expert users.

Nelua compiles to C and then to the target native code, by doing it existing
C libraries and APIs can be reused, new C libraries can be created,
any platform that a C99 compiler targets the language will also target and the language can take
advantage of highly optimized compilers such as GCC and Clang, thus generating very
efficient native code.

The language also aims to be meta programmable by having a Lua preprocessor,
compile time code generation mechanisms, AST and grammar manipulation.
With that higher constructs such as classes, generics and DSLs
can be implemented at compile time without runtime costs by the users,
and the language specification can be more simpler and compact, just like in Lua classes
does not exist but you can implement yourself using mechanisms like metatables.

As Nelua syntax intends to have it's syntax as a superset of Lua syntax,
it can also be used to have basic type checking and extended features
for existing Lua projects by generating Lua code.

## Goals

* Be minimalistic with a small syntax, manual and API, but powerful
* Be performant by compiling to optimized C code then native code
* Possibility to output freestanding code (dependency free code, for kernel dev or minimal runtime)
* Have syntax, semantics and features compatible with Lua
* Optionally statically typed with type checking
* Generate native dependency free executable with no virtual machine
* Compile to both Lua or C
* Work dynamically or statically depending on the coding style (typed or untyped)
* Generate readable, simple and performant C or Lua code
* Be a companion to Lua or C
* Have powerful meta programming capabilities by manipulating the AST
* Make possible to create clean DSLs by extending the language grammar
* Achieve classes, generics and other higher constructs by meta programming
* Safe idioms to code safe
* Have an optional garbage collector
* Allow to go low level (C, assembly)
* Allow to go higher level (use Lua or extend the language)
* Be modular, plugin in or out language syntaxes and features of your choice
* Once stable, make nelua compile itself

## Why?

* We love to script in Lua.
* We love C performance.
* We want best of both worlds in a single language and with similar syntax.
* We want to reuse or mix existing C/C++/Lua code.
* We want type safety and optimizations.
* We want to be able to manipulate the language parser and make cleaner and elegant DSLs.
* We want to have performant code while maintaining readability and safety.
* We want the language features and manual to be minimalistic and fit our brain.
* We want to deploy anywhere Lua or C runs.
* We want to choose to run in a VM (Lua), a Jitted-VM (LuaJIT) or native code (C)
* We want to go crazy and extended the language features by meta programming or manipulating the language grammar.
* We want to code with or without garbage collection depending on our use case.
* We want to abuse of static dispatch instead of dynamic dispatch to gain performance and correctness.
* We want to choose which language features are allowed to use in our projects.

## Learning

More details about the language syntax can be learned on the following links:
* Check out the language [overview](https://edubart.github.io/nelua-lang/overview/)
to get a quick view of the language syntax, features and usage.
* Check out the language [tutorial](https://edubart.github.io/nelua-lang/tutorial/)
for learning the basics.

## Installation

To install the language you will need [luarocks](https://luarocks.org/) installed first.
If you want to compile to native code you will also need a C compiler such as GCC or Clang.

```bash
luarocks install https://raw.githubusercontent.com/edubart/nelua-lang/master/rockspec/nelua-dev-1.rockspec
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

Some benchmarks can be found in `benchmarks` folder, the folder contains nelua benchmarks and pure C benchmark as reference. As Nelua can compile Lua, it's generated
Lua code can be used to test it's performance against Lua VM implementations.

The benchmarks can be run with `luajit ./tools/benchmarker.lua`

|    benchmark |  language |   avg (ms) |   std (ms) |
|--------------|-----------|------------|------------|
|    ackermann |       lua |   2268.901 |      5.023 |
|    ackermann |    luajit |    132.504 |      2.300 |
|    ackermann |   nelua c |     60.481 |      2.319 |
|    ackermann |         c |     60.128 |      2.483 |
|    fibonacci |       lua |   2350.338 |      5.260 |
|    fibonacci |    luajit |    895.123 |     23.852 |
|    fibonacci |   nelua c |    329.366 |      2.069 |
|    fibonacci |         c |    331.008 |      1.132 |
|       mandel |       lua |   2352.519 |     11.367 |
|       mandel |    luajit |    103.191 |      2.395 |
|       mandel |   nelua c |     94.661 |      1.391 |
|       mandel |         c |     93.122 |      2.805 |
|        sieve |       lua |   1219.087 |      5.570 |
|        sieve |    luajit |    289.172 |      6.863 |
|        sieve |   nelua c |     98.785 |      6.499 |
|        sieve |         c |     80.538 |      4.423 |
|     heapsort |       lua |   2505.377 |    120.612 |
|     heapsort |    luajit |    278.048 |      6.031 |
|     heapsort |   nelua c |    181.156 |      5.473 |
|     heapsort |         c |    137.838 |      2.333 |

Environment that this benchmark was run:
LuaJIT 2.1.0-beta3,
GCC 8.2.1,
Lua 5.3.5,
CPU Intel Core i7-3770K CPU @ 3.50GH,
OS ArchLinux
and compiled with C flags
`-rdynamic -O2 -fno-plt -flto -march=native -Wl,-O1,--sort-common,-z,relro,-z,now`

## Roadmap

- [x] Parse complete Lua 5.x syntax and generate its AST
- [x] Parse optional typed syntax
- [x] Basic type checking and inference
- [x] Basic preprocessor in Lua

Lua Generator:
- [x] Generate Lua code with complete Lua features
- [ ] Implement Lua runtime for Nelua's additional features

C Generator:
- [x] Generate basic C code and compile
- [x] Primitives (integer, number, boolean)
- [x] Control structures
- [x] Primitives operators
- [x] Functions
- [x] Static string
- [ ] Dynamic string
- [x] Calls
- [ ] Any
- [ ] Tables
- [x] Multiple returns
- [x] Multiple arguments
- [ ] Closures
- [ ] Iterators (for in)
- [ ] Lua standard library API
- [ ] Metatables
- [x] Manual memory management
- [ ] Optional garbage collector
- [x] Enums
- [x] Records
- [x] Static arrays
- [ ] Slices
- [ ] Unions
- [x] Pointers
- [ ] Modules
- [x] C FFI
- [ ] Lua interface
- [ ] Exceptions
- [ ] Seamless interface with Lua
- [ ] Ownership model for memory management
- [ ] Coroutines
