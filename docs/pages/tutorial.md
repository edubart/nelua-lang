---
layout: docs
title: Tutorial
permalink: /tutorial/
categories: docs toc
order: 2
---

{% raw %}

This is a basic tutorial for the Nelua Programming Language, for running
your first application.
{: .lead}

**Don't have Nelua installed yet?** Read the [installing tutorial](/installing/) first.
{: .callout.callout-info}

## Your first program

You can code in Nelua much like you would code in Lua. For example, a hello world program is written much like in Lua:

```nelua
print 'Hello world'
```

This example is already in the repository as an example. First clone the language repository
if you haven't yet:

```bash
git clone git@github.com:edubart/nelua-lang.git
cd nelua-lang
```

Now you can run it:
```bash
nelua examples/helloworld.nelua 
```

When running it you should get an output that looks like this:
```bash
generated /home/user/nelua-lang/nelua_cache/examples/helloworld.c
gcc -o "/home/user/nelua-lang/nelua_cache/examples/helloworld" \
       "/home/user/nelua-lang/nelua_cache/examples/helloworld.c" \
       -Wall -lm -fwrapv -g
/home/user/nelua-lang/nelua_cache/examples/helloworld
hello world
```

Note that the compiler has generated a file called `helloworld.c`.
This is your program translated to C source code.
If you know how to read C then I encourage you to open it and have a look.
The compiler tries to generate efficient, compact, and readable C sources.

After the C source file is generated, GCC is invoked to compile the C sources,
and then the program is executed.

If your machine does not have GCC, you can use another C compiler with the flag `--cc`. 
For example, if you are on MacOS, you probably want to use Clang. In that case 
do `nelua --cc clang examples/helloworld.nelua`.
If you are on Windows, you probably want to use MinGW, so
do `nelua --cc x86_64-w64-mingw32-gcc examples/helloworld.nelua`.

## Syntax highlighting for editors

Syntax definitions for the language are available for
Visual Studio Code with [nelua-vscode](https://github.com/edubart/nelua-vscode) and
for Sublime Text with [nelua-sublime](https://github.com/edubart/nelua-sublime).
At the moment, only Sublime Text has a full definition, so I recommend using it.
If you use another code editor you can use Lua syntax highlighting,
as it very similar (but of course, incomplete).

I recommend using the syntax highlighter,
as it makes the experience of playing around with the language more pleasant, since
it can highlight type notations.

## Language features

A quick tour of the language features can be found in the [overview page](/overview/),
I highly recommend reading it if you haven't yet.

## More examples 

As the language is being developed, this tutorial is quite short.
However you can see and run more interesting examples of the language in the
[examples](https://github.com/edubart/nelua-lang/tree/master/examples),
[benchmarks](https://github.com/edubart/nelua-lang/tree/master/benchmarks), or
[tests](https://github.com/edubart/nelua-lang/tree/master/tests)
 folders.

The most interesing examples are:
* `examples/fibonacci.nelua` multiple implementations of the classic [Fibonnaci sequence](https://en.wikipedia.org/wiki/Fibonacci_number)
* `examples/brainfuck.nelua` use of metaprogramming to code the esoteric [Brainfuck language](https://en.wikipedia.org/wiki/Brainfuck)
* `examples/snakesdl.nelua` the classic Snake game (requires SDL)
* `examples/condots.nelua` connected dots graphic animation made in parallel (requires SDL and OpenMP)

<a href="/overview/" class="btn btn-outline-primary btn-lg float-right">Overview >></a>

{% endraw %}
