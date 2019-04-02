# Euluna

[![Build Status](https://travis-ci.org/edubart/euluna-lang.svg?branch=master)](https://travis-ci.org/edubart/euluna-lang)
[![Coverage Status](https://coveralls.io/repos/github/edubart/euluna-lang/badge.svg?branch=master)](https://coveralls.io/github/edubart/euluna-lang?branch=master)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?label=license)](https://opensource.org/licenses/MIT)
[![Documentation](https://img.shields.io/website/https/edubart.github.io/euluna-lang.svg?label=docs&color=blue)](https://edubart.github.io/euluna-lang/overview/)
[![Join the chat at Gitter](https://badges.gitter.im/euluna-lang/Lobby.svg)](https://gitter.im/euluna-lang/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
![Project Status](https://img.shields.io/badge/status-experimental-red.svg)

Euluna is a minimalistic, performant, safe, optionally typed, compiled, meta programmable,
systems programming language with syntax and semantics similar to Lua
language that can work dynamically or statically depending on the code style and
compiles to C or Lua.

Euluna aims to be a language for performance sensitive applications where Lua
would not be efficient (like operational systems, real-time applications, game engines)
while maintaining syntax and semantics compatible with Lua and providing a
a seamless interface to Lua. Euluna is designed to be able to work free from a Lua VM
or garbage collector when using its new idioms, just like a C program would work.
When coding with types and using its new idioms (structs, arrays, manual memory
management, pointers, etc) the performance should be efficient as C. However when
using Lua idioms (like tables, metatables) or interacting with scripts, the compiler
uses a Lua VM such as Lua or LuaJIT, therefore Euluna has different goals of other JIT or VM
implementations of Lua, as it actually uses Lua to interact with scripts and to implement
some Lua idioms.

The motivation is to have a language to replace C/C++ part of projects that uses
Lua today with a language with syntax and semantics similar to Lua, but
without loosing performance or the ability to go low level. Therefore unifying the
syntax and semantics across both compiled and dynamic language. At the same time maintaining
the language safe for non-expert users.

By compiling to C existing C libraries and APIs can be reused, new C libraries can be created,
any platform that a C99 compiler targets the language will also target and the language can take
advantage of highly optimized compilers such as GCC and Clang, thus generating very
efficient native code.

The language also aims to be meta programmable by having a Lua preprocessor, template idioms,
AST and grammar manipulation. With that higher constructs such as classes, generics and DSLs
can be implemented at compile time without runtime costs and the language specification can
be more simpler and compact, just like in Lua classes
does not exist but you can implement yourself using mechanisms like metatables.

As Euluna syntax is a superset of Lua syntax it can also be used to have basic
type checking and extended features for existing Lua projects by generating Lua code.

**Warning this language is currently highly experimental and a WIP (work in progress).**

## Goals

* Be minimalistic with a small syntax, manual and API, but powerful
* Be performant by compiling to optimized C code then native code
* Possibility to output freestanding code (dependency free code, for kernel dev or minimal runtime)
* Have syntax, semantics and features compatible with Lua
* Optionally statically typed with type checking
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
* Once stable, make euluna compile itself

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

## Installation

To install the language you will need [luarocks](https://luarocks.org/) installed first.
If you want to compile to native code you will also need a C compiler such as GCC or Clang.

```bash
luarocks install https://raw.githubusercontent.com/edubart/euluna-lang/master/rockspec/euluna-dev-1.rockspec
```

## Running

Create a file named `helloworld.euluna` containing:

```lua
print 'Hello world!'
```

Running by compiling to Lua and using your system Lua's interpreter:
```shell
euluna helloworld.euluna
```

Running by compiling to C then to native code (requires a GCC compiler):
```shell
euluna -g c helloworld.euluna
```

Both ways it will output  ```Hello world!```

## Benchmarks

Some benchmarks can be found in `benchmarks` folder, the folder contains euluna benchmarks and pure C benchmark as reference. As Euluna can compile Lua, it's generated
Lua code can be used to test it's performance against Lua VM implementations.

The benchmarks can be run with `luajit ./tools/benchmarker.lua`

|    benchmark |  language |   min (ms) |   avg (ms) |   max (ms) |   std (ms) |
|--------------|-----------|------------|------------|------------|------------|
|    ackermann |       lua |   2269.235 |   2280.283 |   2303.618 |      9.718 |
|    ackermann |    luajit |    128.855 |    133.373 |    140.729 |      3.405 |
|    ackermann |  euluna c |     58.332 |     61.660 |     65.722 |      2.140 |
|    ackermann |         c |     60.166 |     61.411 |     63.280 |      1.049 |
|    fibonacci |       lua |   2348.139 |   2356.104 |   2364.382 |      5.583 |
|    fibonacci |    luajit |    872.809 |    886.653 |    928.692 |     20.471 |
|    fibonacci |  euluna c |    329.148 |    330.505 |    333.186 |      1.294 |
|    fibonacci |         c |    324.313 |    329.637 |    335.949 |      3.079 |
|       mandel |       lua |   2341.287 |   2358.073 |   2384.650 |     13.188 |
|       mandel |    luajit |     98.066 |    102.507 |    106.075 |      2.494 |
|       mandel |  euluna c |     91.281 |     94.466 |     96.893 |      1.689 |
|       mandel |         c |     92.334 |     95.158 |     97.407 |      1.438 |

Environment that this benchmark was run:
LuaJIT 2.1.0-beta3,
GCC 8.2.1,
Lua 5.3.5,
CPU Intel Core i7-3770K CPU @ 3.50GH,
OS ArchLinux
and compiled with C flags
`-std=c99 -pedantic -fno-strict-aliasing -rdynamic -O2 -fno-plt -flto -march=native -Wl,-O1,--sort-common,-z,relro,-z,now`

## Roadmap

- [x] Parse complete Lua 5.x syntax and generate its AST
- [x] Parse optional typed syntax
- [x] Basic type checking and inference

Lua Generator:
- [x] Generate Lua code with complete Lua features

C Generator:
- [x] Generate basic C code and compile
- [x] Primitives (integer, number, boolean)
- [x] Control structures
- [x] Primitives operators
- [x] Functions
- [x] Static string
- [x] Calls
- [ ] Any
- [ ] Tables
- [ ] Multiple returns and arguments
- [ ] Dynamic string
- [ ] Closures
- [ ] Iterators (for in)
- [ ] Exceptions
- [ ] Lua standard library API
- [ ] Metatables
- [ ] Memory management utilities
- [ ] Optional garbage collector
- [ ] Enums
- [ ] Structs
- [ ] Static array
- [ ] Slices
- [ ] Unions
- [ ] Pointers
- [ ] Modules
- [ ] FFI with C
- [ ] Seamless interface with Lua
- [ ] Rvalues
- [ ] Immutable values
- [ ] Ownership model for memory management
- [ ] Coroutines

Metaprogramming:
- [ ] Preprocessor
- [ ] Templates
- [ ] Concepts

## Learning more

* Check out the language [overview](https://edubart.github.io/euluna-lang/overview/)
to get a quick view of the language syntax, features and usage.
* Check out the language [tutorial](https://edubart.github.io/euluna-lang/tutorial/)
for learning the basics.
* Check out the language [manual](https://edubart.github.io/euluna-lang/manual/)
or learning the language whole design.
