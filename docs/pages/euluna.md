# Euluna

[![Build Status](https://travis-ci.org/edubart/euluna-lang.svg?branch=master)](https://travis-ci.org/edubart/euluna-lang)
[![Coverage Status](https://coveralls.io/repos/github/edubart/euluna-lang/badge.svg?branch=master)](https://coveralls.io/github/edubart/euluna-lang?branch=master)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg?label=license)](https://opensource.org/licenses/MIT)
[![Documentation](https://img.shields.io/website/https/edubart.github.io/euluna-lang.svg?label=docs&color=blue)](https://edubart.github.io/euluna-lang/overview/)
[![Join the chat at Gitter](https://badges.gitter.im/euluna-lang/Lobby.svg)](https://gitter.im/euluna-lang/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
![Project Status](https://img.shields.io/badge/status-experimental-red.svg)

Euluna is a minimalistic, performant, safe, optionally typed, meta programmable,
systems programming language with syntax close to Lua language that works
either dynamically or statically by compiling to Lua or C.

**Warning this language is currently highly experimental and a WIP (work in progress).**

## Goals

* Be minimalistic with a small syntax, manual and API, but powerful
* Be performant by compiling to native code
* Have syntax and features closer and compatible to Lua as much as possible
* Optionally statically typed with type checking
* Compile to both Lua or C
* Work dynamically or statically depending on the code generator (Lua or C)
* Generate readable, simple and performant C or Lua code
* Be a companion to Lua or C
* Have powerful meta programming capabilities by manipulating the AST
* Make possible to create clean DSLs by manipulating the language grammar
* Achieve classes, generics and other higher constructs by meta programming
* Be safe to code
* Have an optional garbage collector
* Allow us to go low level (C, assembly)
* Allow us to go higher level (use Lua or extend the language)
* Be modular, plugin in or out language syntaxes or features of your choice
* Once stable, make euluna compile itself
* Possibility to output freestanding code (for kernel dev and minimal runtime)

## Why?

* We love to script in Lua.
* We love C/C++ performance.
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

## Learning more

* Check out the language [overview](https://edubart.github.io/euluna-lang/overview/)
to get a quick view of the language syntax, features and usage.
* Check out the language [tutorial](https://edubart.github.io/euluna-lang/tutorial/)
for learning the basics.
* Check out the language [manual](https://edubart.github.io/euluna-lang/manual/)
or learning the language whole design.
