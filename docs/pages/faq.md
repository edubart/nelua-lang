---
layout: docs
title: FAQ
permalink: /faq/
categories: docs toc
toc: true
order: 6
---

Answers to frequently asked questions about Nelua.
{: .lead}

**Is your question not here?** Use the search bar to search the documentation,
or ask it in the [Discord server](https://discord.gg/7aaGeG7). Commonly asked questions
from there will be moved here.
{: .callout.callout-info}

## Why Nelua?

Nelua was created with the intent to make an efficient compiled language
with syntax similar to Lua. It is one of the few programmable statically typed
languages that uses powerful compile-time metaprogramming capabilities to
generate efficient code. Nelua is developed by a game developer who uses it to
make games.

## What does Nelua mean?

Nelua stands for *Native Extensible Lua*.

## Where does Nelua come from?

Nelua is designed, created and maintained by [edubart](https://github.com/edubart).
The idea of the language was in the back of his mind over multiple years of
working with games in Lua and C++. Then, in 2019, it was born on GitHub
as an open source project.

## How stable is Nelua?

Nelua is in alpha state. Most of its syntax is well defined,
low level features that are found in C are implemented, and
most of the Lua standard APIs are implemented. However
some notable features found in Lua such as exceptions, tables,
runtime dynamic typing, closures are not implemented yet.

## How is Nelua licensed?

The Nelua compiler, its standard library, and its dependencies are MIT licensed.
This means you can use any license for programs developed with Nelua.

## Why does Nelua follow Lua syntax and semantics?

* Lua is minimal and simple, so not many features need to be replicated in Nelua,
thus the language can remain minimal, easy to use, efficient, and stable.
* Nelua was created to be mixed with Lua programs, where one
would use Nelua to make real-time efficient code and Lua for
runtime scripting and compile-time metaprogramming.
* The Nelua compiler uses Lua at compile time to enable advanced metaprogramming.
Using Lua makes the syntax of the Lua preprocessor and Nelua very similar.
* Nelua is being developed by a Lua lover who desires to have the same
syntax and semantics between his system programming language and scripting language.
* The Nelua compiler is written in Lua with the intent to be hackable.
Designing the language to have similar syntax and semantics to the compiler codebase
makes it easier for users to hack the compiler or to metaprogram.

## Why does Nelua compile to C first?

* C still one of the most efficient programming languages, thus Nelua can be as efficient as C.
* Any C compiler can be used. Most platforms support C, thus Nelua can run anywhere, including the web (with the Emscripten compiler).
* The generated C code can be reused if the user someday decides to move away from Nelua. The user can just take the generated C code, since it is very human readable, and can continue using C/C++.
* The generated C code can be reused to make C libraries, thus a library made in Nelua could be bound in any other language, because most other languages support some form of importing C libraries.
* Great C tools are available which can be used with Nelua,
such as debuggers, profilers, and static analyzers.
* C is easy to read, thus the user can read the C generated code to get a better low-level
understanding of the code.
* It makes it easy to import or use C code without costs in Nelua.
* C is simple to use and this makes the Nelua compiler simpler.

## Why does Nelua not use LLVM?

* By using LLVM, Nelua would have a huge dependency. This would go against one of its goals of being simple to compile and use.
* Being locked to LLVM would remove the option of using other great compilers that can perform better
in certain situations, such as GCC.
* LLVM can be slow to compile huge projects. By using C the user can, for example, use the TCC compiler when developing in order to compile huge projects in just a few milliseconds. LLVM would take minutes.
* LLVM generated code is not readable to most users. By using C the user
can read the generated code and have a low level understanding of the code.

## Why does Nelua have a garbage collector?

Because it tries to replicate Lua features and semantics. Some of these things require
a garbage collector. However, Nelua has additional constructs to work
with manual memory management, and the garbage collector can be completely disabled if needed.
When doing this, the programming style is slightly different.
The Nelua author believes that garbage collection is good for rapid prototyping
and for newcomers, and that manual memory management can be enabled later
when seeking performance, or when the user becomes experienced enough to manage the
memory manually.

## Does Nelua use an interpreter?

No. Nelua uses ahead-of-time compilation to create efficient native applications.
It doesn't do any kind of interpreting or JIT at runtime, which means it
can't parse or execute code generated at runtime. If you are looking
for something that can do this, then consider LuaJIT, which is an outstanding
JIT implementation for Lua, or Ravi, which is another JIT implementation
for Lua that supports type notations. However, Nelua does use a Lua
interpreter at compile time for metaprogramming in its preprocessor.

## What kinds of applications is Nelua good for?

Nelua is being developed with the intent to be used in real-time applications
that require efficiency and predictable performance, such as games, game engines,
libraries or almost any situation where one would normally use C.

## What have been the major influences in Nelua design?

Lua and C, as well as some modern languages that try to be a "better C,"
like Nim, Odin, and Zig.

## How can I have syntax highlighting for my Nelua code?

Nelua has syntax highlight plugins for the following editors:

* [Sublime Text](https://github.com/edubart/nelua-sublime)
* [Visual Studio Code](https://github.com/edubart/nelua-vscode)
* [Text Adept](https://github.com/Andre-LA/ta-nelua-mirror)

If you use another editor and make a plugin for Nelua, please share it with the community.

## How can I debug my application?

You can get backtraces of crashes by having GDB debugger installed
and running in debug mode with the `--debug` command line argument.
When doing this Nelua will run your application through GDB
and print out readable backtraces for your code. For more advanced debugging,
you can use any C debugger manually.

## How do I make my code more efficient?

Nelua compiles with optimizations disabled and runtime checks enabled by default.
To compile with optimization enabled and runtime checks disabled you must use the
`--release -P nochecks` command line argument. Nelua also uses a conservative
garbage collector by default, which can be heavy depending on use case.
Users seeking performance and predictable runtimes should switch to
manual memory management and disable the garbage collector with `-P nogc`.
If you want even more performance you can pass more aggresive
compilation flags to your C compiler, for example: `--cflags="-O3 -march=native -fno-plt -flto"`.

## Where can I report mistakes and issues?

You can report issues about Nelua and its documentation at the
[GitHub issues](https://github.com/edubart/nelua-lang/issues) page.

## How can I support Nelua?

In many ways. Giving a star on GitHub, using Nelua and sharing
your experience with others, reporting bugs, spreading it to the world,
sharing projects made with it, making a blog post about it,
helping to improve the documentation and tutorials,
or through a [donation](https://patreon.com/edubart).

## Where can I discuss Nelua?

Nelua developers and users generally discuss in the [Discord server](https://discord.gg/7aaGeG7).
There is also a [Reddit community ](https://www.reddit.com/r/nelua/), although is inactive at the moment.
