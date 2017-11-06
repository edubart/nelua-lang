# <img src="https://edubart.github.io/euluna-lang-website/images/euluna-logo.svg" height="32px"/> Euluna [![Build Status](https://travis-ci.org/edubart/euluna-lang.svg?branch=master)](https://travis-ci.org/edubart/euluna-lang) [![Coverage Status](https://coveralls.io/repos/github/edubart/euluna-lang/badge.svg)](https://coveralls.io/github/edubart/euluna-lang) [![Join the chat at https://gitter.im/euluna-lang/Lobby](https://badges.gitter.im/euluna-lang/Lobby.svg)](https://gitter.im/euluna-lang/Lobby?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

**Warning this language a WIP (work in progress).**

An elegant efficient system and applications programming language. Statically
typed compiled and can be mixed with C++ and Lua code. 

## Goals

Euluna has the following goals:

* Have a clean syntax similiar to Lua (but compatibility with it is not a goal)
* Statically type checked but without having to always specify the types
* Easy to go lower level by mixing C++/C/Assembly code
* Easy to go higher level by mixing Lua code
* Compile a subset to Lua
* Compile to C++17 then to native code using a modern compiler
* Meta programmable
* Work dynamically or statically depending on the backend (Lua or C++)
* Safe to code
* Generate readable, simple and performant C++ and Lua code

## Why?

* We love to script in Lua.
* We love C/C++ performance.
* We want best of both worlds in a single language and with similiar syntax.
* We want to reuse and mix existing C/C++/Lua code

## Overview and syntax

A quick overview of the language can be seen [here](https://edubart.github.io/euluna-lang-website/overview/#exceptions).

## Installing

First install gcc or clang with C++17 support into your system
(such as gcc>=7 or clang>=5.0).

Next install Euluna compiler using LuaRocks:

```bash
luarocks install --server=http://luarocks.org/dev euluna
```

You can now compiler and run hello world demo from this repository with:

```bash
euluna examples/helloworld.euluna
```

You can specify a different C++ compiler binary exporting the CXX environment
(for example `export CXX=clang++-5.0`).

If you want you can read the generated C++ code inside `euluna_cache` folder
or passing `--print-codegen` flag.

## Status

Very new, being developed.
Currently is coded in Lua 5.1, in the future it maybe coded using itself.
