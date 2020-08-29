---
layout: docs
title: FAQ
permalink: /faq
categories: docs toc
toc: true
order: 5
---

Answers to frequently asked questions about Nelua.
{: .lead}

**Is your question not here?** Use the search bar to search in the documentation
or ask in the [discord chat](https://discord.gg/7aaGeG7), common questions asked
there will be moved here.
{: .callout.callout-info}

## Why Nelua?

Nelua was created with the intent to have an efficient compiled language
with syntax and similar to Lua, it's one of the few programmable statically typed
languages that combines a powerful compile time meta programming capabilities to
make efficient code. Nelua is developed by a game developer to make
games with it.

## How stable is Nelua?

Nelua is in alpha state, most of its syntax are well defined,
low level features that are found in C are implemented and
most of the Lua standard APIs are implemented. However
some notable features found in Lua like exceptions, tables,
runtime dynamic typing, closures and coroutines are not implemented yet.

## How is Nelua licensed?

The Nelua compiler, its standard library and its dependencies are MIT licensed.
This means you can use any license for programs developed with Nelua.

## Why Nelua follows Lua syntax and semantics?

* Lua is minimal and simple, this means not many features need to be replicated in Nelua,
thus the language can remain minimal, easy to use, efficient and stable.
* Nelua was created to be mixed with Lua programs in mind, where one
would use Nelua to make real-time efficient code and Lua for
runtime scripting and compile-time meta programming.
* Nelua compiler uses Lua at compile time to enable advanced meta programming,
by using Lua makes the syntax of the Lua preprocessor and Nelua very similar.
* Nelua is being developed by a Lua lover who desires to have the same
syntax and semantics between his system programming language and scripting language.
* Nelua compiler is written in Lua with the intent to be hackable,
making the language  with similar syntax and semantics as the compiler code base
makes easier for users to hack the compiler or to meta program.

## Why Nelua compiles to C first?

* C still one of the most efficient programming languages, thus Nelua can be efficient as C.
* Any C compiler can be used, usually most platforms supports C, thus Nelua can run anywhere, including the web with the Emscripten compiler.
* C code can be reused if the user someday decides to move away from Nelua, he can just get the generated C code, that is very human readable and continue on using C/C++.
* The generated C code can be reused to make C libraries, thus a library made in Nelua could be bound in any other language because most other languages supports some form of importing C libraries.
* Great C tools are available out there, thus C tools can be used with Nelua,
like debuggers, profilers and static analyzers.
* C is easy to read, thus the user can read the C generated code to get better low level
understanding of his code.
* Makes easy to import or use C code without costs in Nelua.
* C is simple to use and this makes the Nelua compiler simpler.

## Why Nelua does not use LLVM?

* By using LLVM Nelua would have a huge dependency and this would go against of one of its goals of being simple to compile and use.
* Being locked to LLVM would take out other great compilers that can perform better.
in different situations than LLVM, like GCC can be more efficient in some cases.
* LLVM can be slow to compile huge projects, by using C the user can use for example the TCC compiler when developing to compile huge projects in a few milliseconds while LLVM would take minutes.
* LLVM generated code is not readable by most users, by using C the user.
can read the generated code and have a low level understanding of his code.

## Why Nelua have a garbage collector?

Because it tries to replicate Lua features and semantics which for some things requires
a garbage collector, however Nelua has additional constructs to work
with manual memory management and the garbage collector can be completely disabled.
But when doing this the programming style is slightly different. Also
the Nelua author believes that garbage collection is good for rapid prototyping
and for newcomers, and that manual memory management can be enabled later
when seeking performance or when the user becomes more experienced to manage the
memory on his own.

## Is Nelua interpreted or uses an interpreter?

No, Nelua uses ahead of time compilation to create efficient native applications,
it doesn't do any kind of interpreting or JIT at runtime, this means it
can't parse and execute code generated at runtime. If you are looking
for something that could do this then consider LuaJIT which is an outstanding
JIT implementation for Lua or Ravi that is another JIT implementation
for Lua that supports type notations. However Nelua uses a Lua
interpreter at compile time, to allow meta programming.

## What kind of application is Nelua good for?

Nelua is being created with the intent to be used in real-time applications
that requires efficiency and predictable performance such as games, game engines,
libraries or almost anything were one would use C.

## What have been the major influences in Nelua design?

Obviously Lua and C, then modern languages that tends to be a "better C",
like Nim, Odin, Zig.

## What about editor support?

Nelua has syntax highlight plugins for:

* [Sublime Text](https://github.com/edubart/nelua-sublime)
* [Visual Studio Code](https://github.com/edubart/nelua-vscode)
* [Text Adept](https://github.com/Andre-LA/ta-nelua-mirror)

If you use other editor and make a plugin for Nelua let me know.

## How can I debug my application?

You can get backtraces of crashes by having GDB debugger installed
and running in debug mode with the `--debug` command line argument,
when doing this Nelua will run your application through GDB
and print out readable backtraces for your code. For more advanced debugging
you could use any C debugger manually.

## How to make my code more efficient?

Nelua compiles by default with optimizations disabled and runtime checks enabled.
To compile with optimization enabled and runtime checks disabled you must use the
`--release -P nochecks` command line argument. Also Nelua uses the a conservative
garbage collector by default, which can be heavy depending on use case,
users seeking performance and predictable runtimes should switch to
manual memory management and disable the garbage collector with `-P nogc`.
If wanting even more performance you could pass more aggresive
compilation flags to your C compiler like `--cflags="-O3 -march=native -fno-plt -flto"`.
